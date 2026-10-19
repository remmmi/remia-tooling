// Un prisme = un fichier markdown : frontmatter (id, version, description,
// entrees, check) + corps (le prompt de transformation). Son empreinte SHA-256
// est tamponnee dans chaque resultat : on sait toujours quel prompt, dans
// quelle version exacte, a produit quel texte.
//
// Le corps peut porter une section VERIFICATEUR (une ligne "VERIFICATEUR"
// seule) : ce qui suit va au verificateur inverse, pas au redacteur. Le
// frontmatter peut nommer un module de controle (`check: <fichier>.mjs`,
// relatif au prisme) : il exporte check({ input, result }) et rend des issues
// { level, segment, code, msg } ; il entre dans l'empreinte du prisme.
//
// Contrats portes par le prisme, lisibles par l'amont (generateur d'input)
// et l'aval (dispatcheur des textes), optionnels :
//   requires: references name(trust 1, text), specs?(trust 1, facts) ; segments description
//   (un `?` apres l id = reference optionnelle, verifiee seulement si presente)
//   produces: description = prose, 2 a 3 paragraphes, <strong> seul balisage ; autre = texte nu
// `brief` refuse un input qui ne porte pas une reference ou un segment requis.

import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { resolve, dirname } from 'node:path';
import { validateSchema, formatErrors } from './schema.mjs';

export function loadPrism(path) {
  const raw = readFileSync(path, 'utf8');
  const m = raw.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
  if (!m) throw new Error(`${path} : frontmatter "---" manquant`);
  const meta = {};
  for (const line of m[1].split('\n')) {
    const kv = line.match(/^([a-z_]+):\s*(.*)$/);
    if (kv) meta[kv[1]] = kv[2].replace(/^["']|["']$/g, '');
  }
  for (const k of ['id', 'version', 'description']) {
    if (!meta[k]) throw new Error(`${path} : champ "${k}" manquant dans le frontmatter`);
  }
  if (!/^\d+\.\d+\.\d+$/.test(meta.version)) throw new Error(`${path} : version "${meta.version}" non semver`);
  const hash = createHash('sha256').update(raw);
  let check = null;
  if (meta.check) {
    check = resolve(dirname(path), meta.check);
    let mod;
    try { mod = readFileSync(check, 'utf8'); } catch (e) { throw new Error(`${path} : module de controle "${meta.check}" illisible (${e.message})`); }
    hash.update('\n--- check ---\n').update(mod);
  }
  // Contrats JSON Schema : fichiers relatifs au prisme, tamponnes avec lui.
  const schemas = {};
  for (const k of ['input_schema', 'output_schema']) {
    if (!meta[k]) { schemas[k] = null; continue; }
    const sp = resolve(dirname(path), meta[k]);
    let raw2;
    try { raw2 = readFileSync(sp, 'utf8'); } catch (e) { throw new Error(`${path} : ${k} "${meta[k]}" illisible (${e.message})`); }
    try { schemas[k] = JSON.parse(raw2); } catch (e) { throw new Error(`${sp} : JSON invalide (${e.message})`); }
    hash.update(`\n--- ${k} ---\n`).update(raw2);
  }
  const [body, verifier] = m[2].trim().split(/^VERIFICATEUR\s*$/mu);
  const requires = meta.requires ? parseRequires(meta.requires, path) : null;
  const produces = meta.produces ? parseProduces(meta.produces) : null;
  return {
    id: meta.id,
    version: meta.version,
    description: meta.description,
    entrees: meta.entrees ? meta.entrees.split(',').map((s) => s.trim()).filter(Boolean) : [],
    body: body.trim(),
    verifier: verifier ? verifier.trim() : null,
    requires,
    produces,
    inputSchema: schemas.input_schema,
    outputSchema: schemas.output_schema,
    check,
    sha256: hash.digest('hex'),
    path,
  };
}

// "references a(trust 1, text), b(facts) ; segments x, y"
function parseRequires(src, path) {
  const out = { references: [], segments: [] };
  for (const part of src.split(';')) {
    const m = part.trim().match(/^(references|segments)\s+(.*)$/s);
    if (!m) throw new Error(`${path} : requires illisible : "${part.trim()}"`);
    for (const item of m[2].split(/,(?![^(]*\))/)) {
      const t = item.trim();
      if (!t) continue;
      if (m[1] === 'segments') { out.segments.push(t); continue; }
      const r = t.match(/^([a-zA-Z0-9_-]+)(\?)?(?:\(([^)]*)\))?$/);
      if (!r) throw new Error(`${path} : reference requise illisible : "${t}"`);
      const ref = { id: r[1], ...(r[2] ? { optional: true } : {}) };
      for (const opt of (r[3] || '').split(',')) {
        const o = opt.trim();
        const tr = o.match(/^trust\s+(\d+)$/);
        if (tr) ref.trust = Number(tr[1]);
        else if (o === 'text' || o === 'facts') ref.kind = o;
      }
      out.references.push(ref);
    }
  }
  return out;
}

// "description = prose, 2 a 3 paragraphes ; short = texte nu, 120-155 caracteres"
function parseProduces(src) {
  return src.split(';').map((p) => p.trim()).filter(Boolean).map((p) => {
    const m = p.match(/^([a-zA-Z0-9_.-]+)\s*=\s*(.*)$/s);
    return m ? { segment: m[1], format: m[2].trim() } : { segment: p, format: '' };
  });
}

// Verifie qu'un input satisfait le contrat d'entree du prisme (requires et
// input_schema) ; rend la liste des manques (vide = conforme).
export function missingRequirements(prism, input) {
  const out = [];
  if (prism.inputSchema) out.push(...formatErrors(validateSchema(input, prism.inputSchema)));
  if (!prism.requires) return out;
  const refs = new Map((input.references || []).map((r) => [r.id, r]));
  for (const need of prism.requires.references) {
    const r = refs.get(need.id);
    if (!r) { if (!need.optional) out.push(`reference "${need.id}" absente`); continue; }
    if (need.trust !== undefined && r.trust !== need.trust) out.push(`reference "${need.id}" : trust ${r.trust}, ${need.trust} attendu`);
    if (need.kind === 'text' && typeof r.text !== 'string') out.push(`reference "${need.id}" : "text" attendu`);
    if (need.kind === 'facts' && (typeof r.facts !== 'object' || r.facts === null)) out.push(`reference "${need.id}" : "facts" attendu`);
  }
  const segs = new Set(input.segments.map((s) => s.id));
  for (const id of prism.requires.segments) if (!segs.has(id)) out.push(`segment "${id}" absent`);
  return out;
}

// Contrat de sortie (output_schema) puis module de controle du prisme.
export async function prismCheck(prism, input, result) {
  const out = [];
  if (prism?.outputSchema) {
    for (const e of formatErrors(validateSchema(result, prism.outputSchema))) out.push({ level: 'error', segment: '*', code: 'contrat-sortie', msg: e });
  }
  if (!prism?.check) return out;
  const mod = await import(`file://${prism.check}`);
  if (typeof mod.check !== 'function') throw new Error(`${prism.check} : export "check" attendu`);
  const issues = await mod.check({ input, result });
  if (!Array.isArray(issues)) throw new Error(`${prism.check} : check doit rendre un tableau d issues`);
  return out.concat(issues.map((i) => ({ level: i.level === 'error' ? 'error' : 'warn', segment: i.segment || '*', code: String(i.code), msg: String(i.msg || '') })));
}

export function stamp(prism) {
  return { id: prism.id, version: prism.version, sha256: prism.sha256 };
}
