#!/usr/bin/env node
// PrismText : moteur de transformation de textes sous contrat de bijection.
//
// Le moteur ne lit ni n'ecrit aucune source reelle : il travaille sur des
// documents JSON (contract/) ranges dans des dossiers de run (lib/run.mjs).
// Les adaptateurs, ecrits par le Claude qui installe l'outil, font le lien
// avec le monde (fichiers, CMS, API...).
//
// Separation des contextes : le pilote (la conversation qui orchestre) ne lit
// jamais un texte. Il fait ecrire des consignes autonomes (brief,
// inverse-brief) sur le disque, les confie a des agents isoles, et ne lit que
// des verdicts courts (check, lot-status).
//
// Codes de sortie : 0 = conforme, 1 = contenu non conforme, 2 = usage ou
// contrat invalide.

import { readFileSync, writeFileSync, mkdirSync, existsSync, readdirSync } from 'node:fs';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { validateInput, validateResult, validateInverse, CONTRACT_VERSION } from './lib/contract.mjs';
import { loadPrism } from './lib/prism.mjs';
import { check, checkRegression } from './lib/checks.mjs';
import { report } from './lib/report.mjs';
import { createLot, lotStatus, lotReport } from './lib/lot.mjs';
import { RunError, loadRunInput, runCheck, runBrief, runInverseBrief, runDecide, runApplied } from './lib/run.mjs';

const HOME = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const PKG = JSON.parse(readFileSync(join(HOME, 'package.json'), 'utf8'));

function die(msg, code = 2) {
  process.stderr.write(`[ERROR] ${msg}\n`);
  process.exit(code);
}

function guard(fn) {
  try { return fn(); } catch (e) { die(e.message, e instanceof RunError ? e.code : 2); }
}

function readJson(path) {
  try { return JSON.parse(readFileSync(path, 'utf8')); } catch (e) { die(`${path} : ${e.message}`); }
}

function loadInput(path) {
  const doc = readJson(path);
  const errs = validateInput(doc);
  if (errs.length) die(`input invalide (${path}) :\n  - ${errs.join('\n  - ')}`);
  return doc;
}

function loadResult(path) {
  const doc = readJson(path);
  const errs = validateResult(doc);
  if (errs.length) die(`result invalide (${path}) :\n  - ${errs.join('\n  - ')}`);
  return doc;
}

function flag(args, name) {
  const i = args.indexOf(name);
  if (i === -1) return undefined;
  const v = args[i + 1];
  args.splice(i, 2);
  return v;
}

function has(args, name) {
  const i = args.indexOf(name);
  if (i === -1) return false;
  args.splice(i, 1);
  return true;
}

const isDir = (p) => { try { return readdirSync(p) && true; } catch { return false; } };

const MANIFEST = {
  name: 'prismtext',
  version: PKG.version,
  contract: CONTRACT_VERSION,
  home: HOME,
  purpose: 'Transformer un texte par un ou plusieurs prompts versionnes (prismes) en garantissant une bijection de concepts avec la source, puis soumettre les variantes a une validation humaine.',
  principle: 'Le moteur est agnostique : il ne manipule que des documents JSON dans des dossiers de run. Les adaptateurs (list, extract, preview, apply, verify) sont ecrits par le Claude qui installe PrismText et declares dans .prismtext/config.json du projet hote. Le pilote ne lit jamais un texte : redaction, correction et verification sont confiees a des agents isoles qui ne recoivent qu un fichier de consigne autonome.',
  flow: [
    'extract (adaptateur) : <run>/input.json, un item entier (page, fiche...) avec la page rendue en contexte',
    'brief : consigne autonome de redaction -> un agent isole ecrit <run>/result-<v>.json',
    'inverse-brief : consigne autonome de verification -> un AUTRE agent isole ecrit <run>/inverse-<v>.json',
    'check : bijection dans les deux sens ; en echec, brief produit une consigne de correction (version archivee) et on reprend',
    'report / lot-report : rapport de relecture, decisions separees par nature',
    'decide : choix humain ; applied refuse toute application sans lui',
    'preview, apply, verify (adaptateur) : la variante choisie rejoint la source',
  ],
  commands: {
    describe: 'describe [--json] : ce manifeste',
    validate: 'validate <input.json> | validate --result <result.json>',
    prism: 'prism <prism.md> : metadonnees et tampon SHA-256 du prisme',
    run: 'run <base-dir> : cree un dossier de run horodate et affiche son chemin absolu',
    brief: 'brief <prism.md> <run-dir> [--variant a] : ecrit la consigne de redaction, ou de correction si la variante echoue au controle ; affiche son chemin et le fichier que l agent doit ecrire',
    'inverse-brief': 'inverse-brief <run-dir> [--variant a] : ecrit la consigne du verificateur ; affiche son chemin',
    check: 'check <run-dir> [--variant a] [--prism <prism.md>] [--json] | check <input.json> <result.json> [--inverse <f>] [--previous <f>] [--prism <f>] [--json]',
    report: 'report <run-dir> [--out rapport.md] : variantes cote a cote et decisions',
    chain: 'chain <run-dir> <variante> <nouveau-run-dir> : input de l etape suivante d une chaine de prismes',
    lot: 'lot <base-dir> <nom> <ref>... : cree un lot (un dossier de run par item) et affiche son chemin absolu',
    'lot-status': 'lot-status <lot-dir> [--json] : etape atteinte par chaque item (reprise d un lot interrompu)',
    'lot-report': 'lot-report <lot-dir> [--out rapport.md] : rapport consolide du lot',
    decide: 'decide <run-dir> <variante|aucune> [--par <qui>] [--force] : decision humaine (--force pour une variante non conforme, sur demande explicite)',
    applied: 'applied <run-dir> <variante> : enregistre l application ; refuse sans decision humaine',
    selftest: 'selftest : rejoue les cas de reference du depot',
  },
  exit_codes: { 0: 'conforme', 1: 'contenu non conforme', 2: 'usage ou contrat invalide' },
};

function describe(args) {
  if (has(args, '--json')) return console.log(JSON.stringify(MANIFEST, null, 2));
  const m = MANIFEST;
  console.log(`PrismText ${m.version} (contrat ${m.contract})\n\n${m.purpose}\n\n${m.principle}\n\nDeroule :`);
  m.flow.forEach((f, i) => console.log(`  ${i + 1}. ${f}`));
  console.log('\nCommandes :');
  for (const c of Object.values(m.commands)) console.log(`  prismtext ${c}`);
  console.log('\nCodes de sortie : 0 conforme, 1 contenu non conforme, 2 usage ou contrat invalide');
}

function printCheck(res, asJson) {
  if (asJson) return console.log(JSON.stringify(res, null, 2));
  for (const i of res.issues) console.log(`[${i.level === 'error' ? 'FAIL' : 'WARN'}] ${i.segment} : ${i.code} : ${i.msg}`);
  console.log(`${res.ok ? '[OK]' : '[FAIL]'} ${res.errors} erreur(s), ${res.warnings} alerte(s)`);
}

function fileCheck(args, asJson) {
  const prismPath = flag(args, '--prism');
  const inversePath = flag(args, '--inverse');
  const previousPath = flag(args, '--previous');
  const input = loadInput(args[0]);
  const result = loadResult(args[1]);
  if (inversePath) {
    const inv = readJson(inversePath);
    const list = Array.isArray(inv) ? inv : inv.inverse;
    const errs = validateInverse(list, inversePath);
    if (errs.length) die(`inverse invalide :\n  - ${errs.join('\n  - ')}`);
    result.inverse = list;
  }
  const res = check(input, result);
  if (previousPath) {
    const reg = checkRegression(loadResult(previousPath), result);
    res.issues.unshift(...reg);
    res.errors += reg.length;
  }
  if (prismPath) {
    const p = guard(() => loadPrism(prismPath));
    if (p.sha256 !== result.prism.sha256 || p.id !== result.prism.id || p.version !== result.prism.version) {
      res.issues.unshift({ level: 'error', segment: '*', code: 'tampon-prisme', msg: `result tamponne ${result.prism.id}@${result.prism.version} (${result.prism.sha256.slice(0, 8)}), prisme fourni ${p.id}@${p.version} (${p.sha256.slice(0, 8)})` });
      res.errors += 1;
    }
  }
  res.ok = res.errors === 0;
  printCheck(res, asJson);
  process.exit(res.ok ? 0 : 1);
}

function runResults(dir) {
  return readdirSync(dir).map((f) => f.match(/^result-([a-z0-9]+)\.json$/)?.[1]).filter(Boolean).sort();
}

function main() {
  const args = process.argv.slice(2);
  const cmd = args.shift();
  switch (cmd) {
    case undefined:
    case 'describe':
    case 'help':
    case '--help':
      return describe(args);

    case 'validate': {
      const asResult = has(args, '--result');
      if (!args[0]) die('usage : validate <input.json> | validate --result <result.json>');
      if (asResult) loadResult(args[0]); else loadInput(args[0]);
      return console.log(`[OK] ${args[0]} conforme au contrat ${CONTRACT_VERSION}`);
    }

    case 'prism': {
      if (!args[0]) die('usage : prism <prism.md>');
      const { body, ...meta } = guard(() => loadPrism(args[0]));
      return console.log(JSON.stringify(meta, null, 2));
    }

    case 'run': {
      if (!args[0]) die('usage : run <base-dir>');
      const ts = new Date().toISOString().replace(/[:]/g, '').replace(/\..+/, 'Z');
      const dir = resolve(join(args[0], ts));
      mkdirSync(dir, { recursive: true });
      return console.log(dir);
    }

    case 'brief': {
      const v = flag(args, '--variant') || 'a';
      if (args.length < 2) die('usage : brief <prism.md> <run-dir> [--variant a]');
      const b = guard(() => runBrief(args[1], v, args[0]));
      return console.log(`${b.kind} : ${resolve(b.path)}\necrit par l agent : ${resolve(b.out)}`);
    }

    case 'inverse-brief': {
      const v = flag(args, '--variant') || 'a';
      if (!args[0]) die('usage : inverse-brief <run-dir> [--variant a]');
      const b = guard(() => runInverseBrief(args[0], v));
      return console.log(`verification : ${resolve(b.path)}\necrit par l agent : ${resolve(b.out)}`);
    }

    case 'check': {
      const asJson = has(args, '--json');
      if (!args[0]) die('usage : check <run-dir> [--variant a] [--prism <prism.md>] | check <input.json> <result.json> [...]');
      if (!isDir(args[0])) {
        if (args.length < 2) die('usage : check <input.json> <result.json> [--inverse <f>] [--previous <f>] [--prism <f>]');
        return fileCheck(args, asJson);
      }
      const v = flag(args, '--variant') || 'a';
      const prismPath = flag(args, '--prism');
      const res = guard(() => runCheck(args[0], v, prismPath));
      printCheck(res, asJson);
      return process.exit(res.ok ? 0 : 1);
    }

    case 'report': {
      const outPath = flag(args, '--out');
      if (!args[0] || !isDir(args[0])) die('usage : report <run-dir> [--out rapport.md]');
      const input = guard(() => loadRunInput(args[0]));
      const results = runResults(args[0]).map((v) => {
        const r = loadResult(join(args[0], `result-${v}.json`));
        const ip = join(args[0], `inverse-${v}.json`);
        if (existsSync(ip)) { const inv = readJson(ip); r.inverse = Array.isArray(inv) ? inv : inv.inverse; }
        return r;
      });
      if (!results.length) die(`${args[0]} : aucune variante`, 1);
      const md = report(input, results);
      if (outPath) { writeFileSync(outPath, md); return console.log(`[OK] rapport ecrit : ${resolve(outPath)}`); }
      return console.log(md);
    }

    case 'chain': {
      if (args.length < 3) die('usage : chain <run-dir> <variante> <nouveau-run-dir>');
      const [dir, v, next] = args;
      const res = guard(() => runCheck(dir, v));
      if (!res.ok) { printCheck(res, false); die('chainage refuse : la variante n est pas conforme', 1); }
      const input = guard(() => loadRunInput(dir));
      const result = loadResult(join(dir, `result-${v}.json`));
      const texts = new Map(result.segments.map((s) => [s.id, s.text]));
      mkdirSync(next, { recursive: true });
      writeFileSync(join(next, 'input.json'), JSON.stringify({
        ...input,
        segments: input.segments.map((s) => ({ ...s, text: texts.get(s.id) })),
        lineage: [...(input.lineage || []), { ...result.prism, variant: result.variant }],
      }, null, 2) + '\n');
      return console.log(resolve(join(next, 'input.json')));
    }

    case 'lot': {
      if (args.length < 3) die('usage : lot <base-dir> <nom> <ref>...');
      return console.log(resolve(guard(() => createLot(args[0], args[1], args.slice(2)))));
    }

    case 'lot-status': {
      const asJson = has(args, '--json');
      if (!args[0]) die('usage : lot-status <lot-dir> [--json]');
      const st = guard(() => lotStatus(args[0]));
      if (asJson) {
        for (const s of st.sources) for (const c of s.checks) delete c.issues;
        return console.log(JSON.stringify(st, null, 2));
      }
      for (const s of st.sources) {
        const c = s.checks.map((x) => `${x.variant}:${x.ok ? 'ok' : 'NON'}`).join(' ');
        console.log(`${s.stage.padEnd(10)} ${s.ref}${c ? `  [${c}]` : ''}${s.decision ? `  choix=${s.decision.choix}` : ''}`);
      }
      return;
    }

    case 'lot-report': {
      const outPath = flag(args, '--out');
      if (!args[0]) die('usage : lot-report <lot-dir> [--out rapport.md]');
      const md = guard(() => lotReport(args[0]));
      if (outPath) { writeFileSync(outPath, md); return console.log(`[OK] rapport de lot ecrit : ${resolve(outPath)}`); }
      return console.log(md);
    }

    case 'decide': {
      const par = flag(args, '--par') || 'humain';
      const force = has(args, '--force');
      if (args.length < 2) die('usage : decide <run-dir> <variante|aucune> [--par <qui>] [--force]');
      guard(() => runDecide(args[0], args[1], { par, force }));
      return console.log(`[OK] decision ${args[1]} enregistree dans ${args[0]}`);
    }

    case 'applied': {
      if (args.length < 2) die('usage : applied <run-dir> <variante>');
      guard(() => runApplied(args[0], args[1]));
      return console.log(`[OK] variante ${args[1]} marquee appliquee`);
    }

    case 'selftest': {
      const fx = join(HOME, 'tests', 'fixtures');
      const input = loadInput(join(fx, 'site-web.input.json'));
      const good = check(input, loadResult(join(fx, 'site-web.result.json')));
      const bad = check(input, loadResult(join(fx, 'site-web.result-casse.json')));
      const codes = new Set(bad.issues.map((i) => i.code));
      const expected = ['token-protege', 'chiffre-invente', 'citation-introuvable', 'concept-perdu', 'segment-perdu', 'ajout-non-declare', 'phrase-non-couverte', 'citation-cible-introuvable'];
      const missing = expected.filter((c) => !codes.has(c));
      if (!good.ok) { printCheck(good, false); die('selftest : le cas conforme est rejete', 1); }
      if (missing.length) die(`selftest : defauts non detectes : ${missing.join(', ')}`, 1);
      return console.log(`[PASS] selftest PrismText ${PKG.version} : cas conforme accepte, ${expected.length} defauts detectes`);
    }

    default:
      die(`commande inconnue "${cmd}" (prismtext describe)`);
  }
}

main();
