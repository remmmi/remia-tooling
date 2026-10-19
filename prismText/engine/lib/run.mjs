// Un dossier de run = un item (une page, une fiche...) et tout son historique :
//
//   input.json                   extrait par l'adaptateur
//   brief-<v>.md                 consigne de redaction (ou de correction) de la variante v
//   result-<v>.json              variante v courante (ecrite par un agent isole)
//   result-<v>.r<n>.json         versions precedentes, archivees a chaque correction
//   inverse-brief-<v>.md         consigne du verificateur
//   inverse-<v>.json             carte inverse courante (ecrite par un autre agent isole)
//   check-<v>.json               dernier controle
//   rapport.md, decision.json, applied.json
//
// Le moteur gere seul ces fichiers : le pilote (la conversation qui orchestre)
// n'a jamais besoin d'ouvrir un texte, seulement les verdicts.

import { readFileSync, writeFileSync, existsSync, readdirSync, renameSync } from 'node:fs';
import { join } from 'node:path';
import { validateInput, validateResult, validateInverse } from './contract.mjs';
import { loadPrism, prismCheck, missingRequirements } from './prism.mjs';
import { check, checkRegression } from './checks.mjs';
import { writeBrief, fixBrief, inverseBrief } from './briefs.mjs';

export class RunError extends Error {
  constructor(msg, code = 2) { super(msg); this.code = code; }
}

const readJson = (p) => {
  try { return JSON.parse(readFileSync(p, 'utf8')); } catch (e) { throw new RunError(`${p} : ${e.message}`); }
};

export function loadRunInput(dir) {
  const p = join(dir, 'input.json');
  if (!existsSync(p)) throw new RunError(`${dir} : pas d input.json (etape extract non faite)`);
  const doc = readJson(p);
  const errs = validateInput(doc);
  if (errs.length) throw new RunError(`input invalide (${p}) :\n  - ${errs.join('\n  - ')}`);
  return doc;
}

function loadRunResult(p) {
  const doc = readJson(p);
  const errs = validateResult(doc);
  if (errs.length) throw new RunError(`result invalide (${p}) :\n  - ${errs.join('\n  - ')}`, 1);
  return doc;
}

function versions(dir, v) {
  return readdirSync(dir)
    .map((f) => f.match(new RegExp(`^result-${v}\\.r(\\d+)\\.json$`))?.[1])
    .filter(Boolean).map(Number).sort((a, b) => a - b);
}

function resolvePrism(prismPath, result) {
  if (!prismPath) return null;
  const p = loadPrism(prismPath);
  if (result && (p.sha256 !== result.prism.sha256 || p.id !== result.prism.id || p.version !== result.prism.version)) {
    return { prism: p, mismatch: `result tamponne ${result.prism.id}@${result.prism.version} (${result.prism.sha256.slice(0, 8)}), prisme fourni ${p.id}@${p.version} (${p.sha256.slice(0, 8)})` };
  }
  return { prism: p };
}

// Controle complet d'une variante : bijection directe et inverse, tampon du
// prisme et son module de controle, garde-fou de correction contre la
// version precedente.
export async function runCheck(dir, v, prismPath) {
  const input = loadRunInput(dir);
  const rp = join(dir, `result-${v}.json`);
  if (!existsSync(rp)) throw new RunError(`${dir} : pas de result-${v}.json (redaction non faite)`, 1);
  const result = loadRunResult(rp);
  const ip = join(dir, `inverse-${v}.json`);
  if (existsSync(ip)) {
    const inv = readJson(ip);
    const list = Array.isArray(inv) ? inv : inv.inverse;
    const errs = validateInverse(list, ip);
    if (errs.length) throw new RunError(`inverse invalide :\n  - ${errs.join('\n  - ')}`, 1);
    result.inverse = list;
  }
  const res = check(input, result);
  const prev = versions(dir, v).at(-1);
  if (prev !== undefined) {
    const reg = checkRegression(loadRunResult(join(dir, `result-${v}.r${prev}.json`)), result);
    res.issues.unshift(...reg);
    res.errors += reg.length;
  }
  const pr = resolvePrism(prismPath, result);
  if (pr?.mismatch) {
    res.issues.unshift({ level: 'error', segment: '*', code: 'tampon-prisme', msg: pr.mismatch });
    res.errors += 1;
  } else if (pr) {
    const extra = await prismCheck(pr.prism, input, result);
    res.issues.push(...extra);
    res.errors += extra.filter((i) => i.level === 'error').length;
    res.warnings += extra.filter((i) => i.level !== 'error').length;
  }
  res.ok = res.errors === 0;
  res.variant = v;
  res.round = versions(dir, v).length;
  writeFileSync(join(dir, `check-${v}.json`), JSON.stringify(res, null, 2) + '\n');
  return res;
}

// Consigne de redaction, ou de correction si une variante non conforme existe.
// Retourne { path, kind, out }.
export async function runBrief(dir, v, prismPath) {
  const input = loadRunInput(dir);
  const prism = loadPrism(prismPath);
  const missing = missingRequirements(prism, input);
  if (missing.length) throw new RunError(`input ne satisfait pas le contrat d entree du prisme ${prism.id}@${prism.version} :\n  - ${missing.join('\n  - ')}`);
  const rp = join(dir, `result-${v}.json`);
  const bp = join(dir, `brief-${v}.md`);
  if (!existsSync(rp)) {
    writeFileSync(bp, writeBrief({ prism, input, variant: v, out: rp }));
    return { path: bp, kind: 'redaction', out: rp };
  }
  const res = await runCheck(dir, v, prismPath);
  if (res.ok) throw new RunError(`variante ${v} deja conforme : rien a corriger`, 1);
  const previous = loadRunResult(rp);
  const n = versions(dir, v).length + 1;
  renameSync(rp, join(dir, `result-${v}.r${n}.json`));
  const ip = join(dir, `inverse-${v}.json`);
  if (existsSync(ip)) renameSync(ip, join(dir, `inverse-${v}.r${n}.json`));
  writeFileSync(bp, fixBrief({ prism, input, previous, issues: res.issues, out: rp }));
  return { path: bp, kind: `correction ${n}`, out: rp };
}

// Avec le prisme, la consigne du verificateur recoit sa section VERIFICATEUR.
export function runInverseBrief(dir, v, prismPath) {
  const input = loadRunInput(dir);
  const rp = join(dir, `result-${v}.json`);
  if (!existsSync(rp)) throw new RunError(`${dir} : pas de result-${v}.json`, 1);
  const result = loadRunResult(rp);
  const pr = resolvePrism(prismPath, result);
  if (pr?.mismatch) throw new RunError(pr.mismatch, 1);
  const out = join(dir, `inverse-${v}.json`);
  const bp = join(dir, `inverse-brief-${v}.md`);
  writeFileSync(bp, inverseBrief({ input, result, out, prism: pr?.prism || null }));
  return { path: bp, out };
}

// Decision : humaine par defaut. `auto` (gates.human_validation false dans la
// config du projet) n'accepte qu'une variante conforme et ne force jamais :
// la trace reste dans decision.json (par: "auto") et dans les rapports.
export async function runDecide(dir, choix, { par = 'humain', force = false, auto = false, prismPath } = {}) {
  if (auto && force) throw new RunError('--auto ne force jamais une variante non conforme');
  if (choix !== 'aucune') {
    const res = await runCheck(dir, choix, prismPath);
    if (!res.ok && !force) throw new RunError(`variante ${choix} non conforme (${res.errors} erreur(s)) : la choisir quand meme demande --force, sur demande explicite de l humain`, 1);
  }
  const dec = { choix, par: auto ? 'auto' : par, le: new Date().toISOString(), ...(auto ? { auto: true } : {}), ...(force ? { force: true } : {}) };
  writeFileSync(join(dir, 'decision.json'), JSON.stringify(dec, null, 2) + '\n');
}

export function runApplied(dir, v) {
  const dp = join(dir, 'decision.json');
  if (!existsSync(dp)) throw new RunError(`pas de decision humaine dans ${dir} : rien ne s applique sans elle`, 1);
  const dec = readJson(dp);
  if (dec.choix !== v) throw new RunError(`la decision humaine est "${dec.choix}", pas "${v}"`, 1);
  writeFileSync(join(dir, 'applied.json'), JSON.stringify({ variant: v, le: new Date().toISOString() }, null, 2) + '\n');
}
