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

import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { resolve, dirname } from 'node:path';

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
  const [body, verifier] = m[2].trim().split(/^VERIFICATEUR\s*$/mu);
  return {
    id: meta.id,
    version: meta.version,
    description: meta.description,
    entrees: meta.entrees ? meta.entrees.split(',').map((s) => s.trim()).filter(Boolean) : [],
    body: body.trim(),
    verifier: verifier ? verifier.trim() : null,
    check,
    sha256: hash.digest('hex'),
    path,
  };
}

// Execute le module de controle du prisme, s'il en a un.
export async function prismCheck(prism, input, result) {
  if (!prism?.check) return [];
  const mod = await import(`file://${prism.check}`);
  if (typeof mod.check !== 'function') throw new Error(`${prism.check} : export "check" attendu`);
  const issues = await mod.check({ input, result });
  if (!Array.isArray(issues)) throw new Error(`${prism.check} : check doit rendre un tableau d issues`);
  return issues.map((i) => ({ level: i.level === 'error' ? 'error' : 'warn', segment: i.segment || '*', code: String(i.code), msg: String(i.msg || '') }));
}

export function stamp(prism) {
  return { id: prism.id, version: prism.version, sha256: prism.sha256 };
}
