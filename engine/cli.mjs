#!/usr/bin/env node
// PrismText : moteur de transformation de textes sous contrat de bijection.
//
// Le moteur ne lit ni n'ecrit aucune source reelle : il travaille sur des
// documents JSON (contract/). Les adaptateurs, ecrits par le Claude qui
// installe l'outil, font le lien avec le monde (fichiers, CMS, API...).
//
// Codes de sortie : 0 = conforme, 1 = contenu non conforme (erreurs de
// bijection), 2 = usage ou contrat invalide.

import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { validateInput, validateResult, validateInverse, CONTRACT_VERSION } from './lib/contract.mjs';
import { loadPrism, stamp } from './lib/prism.mjs';
import { check } from './lib/checks.mjs';
import { report } from './lib/report.mjs';

const HOME = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const PKG = JSON.parse(readFileSync(join(HOME, 'package.json'), 'utf8'));

function die(msg, code = 2) {
  process.stderr.write(`[ERROR] ${msg}\n`);
  process.exit(code);
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

const MANIFEST = {
  name: 'prismtext',
  version: PKG.version,
  contract: CONTRACT_VERSION,
  home: HOME,
  purpose: 'Transformer un texte par un ou plusieurs prompts versionnes (prismes) en garantissant une bijection de concepts avec la source, puis soumettre les variantes a une validation humaine.',
  principle: 'Le moteur est agnostique : il ne manipule que des documents JSON. Les adaptateurs (extract, preview, apply) sont ecrits par le Claude qui installe PrismText et declares dans .prismtext/config.json du projet hote.',
  flow: [
    'extract : l adaptateur produit input.json (segments + tokens proteges + contexte)',
    'prompt : le moteur assemble la consigne de transformation pour un prisme',
    'transform : le LLM (Claude, ou un runner API) produit result.json',
    'inverse : un verificateur qui n a pas ecrit la variante cartographie cible -> source',
    'check : le moteur verifie la bijection dans les deux sens (bloquant si erreur)',
    'report : le moteur produit le rapport de relecture, variantes cote a cote',
    'validation humaine : choix d une variante',
    'preview puis apply : l adaptateur publie la variante choisie',
  ],
  commands: {
    describe: 'describe [--json] : ce manifeste',
    validate: 'validate <input.json> | validate --result <result.json>',
    prism: 'prism <prism.md> : metadonnees et tampon SHA-256 du prisme',
    prompt: 'prompt <prism.md> <input.json> [--variant a] : consigne complete a donner au LLM',
    inverse: 'inverse <input.json> <result.json> : consigne du verificateur (passe inverse cible -> source)',
    check: 'check <input.json> <result.json> [--inverse <inverse.json>] [--prism <prism.md>] [--json]',
    report: 'report <input.json> <result.json>... [--out rapport.md]',
    chain: 'chain <input.json> <result.json> : nouvel input (etape suivante d une chaine de prismes)',
    run: 'run <base-dir> : cree un dossier de run horodate (trace d audit) et affiche son chemin',
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

function buildPrompt(prism, input, variant) {
  const ctx = input.context || {};
  const rules = input.protect || [];
  const out = [];
  out.push(`# Transformation PrismText : prisme ${prism.id}@${prism.version}, variante "${variant}"`);
  out.push('');
  out.push('## Consigne du prisme');
  out.push('');
  out.push(prism.body);
  out.push('');
  out.push('## Contexte fourni par l adaptateur');
  out.push('');
  const keys = Object.keys(ctx);
  if (!keys.length) out.push('(aucun : s appuyer sur le texte source, ne rien inventer)');
  for (const k of keys) out.push(`- ${k} : ${typeof ctx[k] === 'string' ? ctx[k] : JSON.stringify(ctx[k])}`);
  out.push('');
  out.push('## Contraintes du contrat (non negociables, verifiees par `prismtext check`)');
  out.push('');
  out.push('- Chaque segment source a exactement un segment cible, meme id. Aucun segment ajoute ni retire.');
  out.push('- Un segment "freeze" est recopie a l identique.');
  out.push('- Aucun chiffre absent de la source. Aucun nom propre absent de la source.');
  if (rules.length) {
    out.push('- Tokens proteges (le groupe "keep", ou le token entier, doit rester identique, meme nombre d occurrences dans le meme segment) :');
    for (const r of rules) out.push(`  - ${r.name} : /${r.regex}/${r.note ? ` (${r.note})` : ''}`);
  }
  if (ctx.conserver?.length) out.push(`- Elements a conserver mot pour mot : ${ctx.conserver.map((c) => `"${c}"`).join(', ')}`);
  out.push('- Carte des concepts : pour chaque idee de chaque segment source, un objet { segment, concept, cible } ou "cible" est une citation EXACTE (copier-coller) du segment cible qui porte cette idee. Si une idee est volontairement abandonnee (parce que le prisme l exige), cible = null et un champ "motif" cite la regle du prisme : le relecteur humain tranchera. Sans motif, c est une erreur bloquante.');
  out.push('- Tout ajout d idee absente de la source est declare dans "ajouts" : [{ segment, texte }]. Un verificateur independant relira ensuite chaque phrase de la cible pour lui trouver sa source : un ajout non declare sera une erreur bloquante.');
  out.push('');
  out.push('## Segments source');
  out.push('');
  for (const s of input.segments) {
    const c = s.constraints ? ` ${JSON.stringify(s.constraints)}` : '';
    out.push(`### ${s.id}${s.role ? ` (${s.role})` : ''}${c}`);
    out.push('');
    out.push(s.text);
    out.push('');
  }
  out.push('## Sortie attendue');
  out.push('');
  out.push('Un unique document JSON, sans commentaire autour :');
  out.push('');
  out.push('```json');
  out.push(JSON.stringify({
    prismtext: CONTRACT_VERSION,
    prism: stamp(prism),
    variant,
    segments: [{ id: input.segments[0].id, text: '...' }],
    concepts: [{ segment: input.segments[0].id, concept: '...', cible: '...' }],
    ajouts: [],
  }, null, 2));
  out.push('```');
  return out.join('\n');
}

function buildInversePrompt(input, result) {
  const out = [];
  out.push(`# Verification inverse PrismText : variante "${result.variant}" (${result.prism.id}@${result.prism.version})`);
  out.push('');
  out.push('Tu n as pas ecrit ce texte. Ton role est de le soupconner. Pour chaque segment ci-dessous, decoupe le texte CIBLE en morceaux (propositions ou phrases) qui couvrent la totalite de la cible, et pour chacun donne la citation EXACTE (copier-coller) du texte SOURCE qui porte la meme idee.');
  out.push('');
  out.push('- Si un morceau dit quelque chose que la source ne dit pas (engagement, precision, nuance, cause, promesse, interpretation, changement de sujet grammatical qui change le sens, "je" devenu "nous"...), sa source vaut null. Ne rattache pas un ajout a une source vague pour le faire passer.');
  out.push('- Une reformulation fidele n est pas un ajout.');
  out.push('- "cible" et "source" sont des copier-coller exacts, sans guillemets ajoutes ni ponctuation modifiee.');
  out.push('- Les segments identiques ou gelés sont omis.');
  out.push('');
  const dst = new Map(result.segments.map((s) => [s.id, s.text]));
  for (const s of input.segments) {
    const d = dst.get(s.id);
    if (s.constraints?.freeze || d === undefined || d === s.text) continue;
    out.push(`## ${s.id}`, '', '**Source**', '', s.text, '', '**Cible**', '', d, '');
  }
  out.push('## Sortie attendue', '', 'Un unique document JSON, sans commentaire autour :', '', '```json');
  out.push(JSON.stringify({ inverse: [{ segment: '<id>', cible: '<citation exacte de la cible>', source: '<citation exacte de la source ou null>' }] }, null, 2));
  out.push('```');
  return out.join('\n');
}

function printCheck(res, asJson) {
  if (asJson) return console.log(JSON.stringify(res, null, 2));
  for (const i of res.issues) console.log(`[${i.level === 'error' ? 'FAIL' : 'WARN'}] ${i.segment} : ${i.code} : ${i.msg}`);
  console.log(`${res.ok ? '[OK]' : '[FAIL]'} ${res.errors} erreur(s), ${res.warnings} alerte(s)`);
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
      let p;
      try { p = loadPrism(args[0]); } catch (e) { die(e.message); }
      const { body, ...meta } = p;
      return console.log(JSON.stringify(meta, null, 2));
    }

    case 'prompt': {
      const variant = flag(args, '--variant') || 'a';
      if (args.length < 2) die('usage : prompt <prism.md> <input.json> [--variant a]');
      let p;
      try { p = loadPrism(args[0]); } catch (e) { die(e.message); }
      return console.log(buildPrompt(p, loadInput(args[1]), variant));
    }

    case 'inverse': {
      if (args.length < 2) die('usage : inverse <input.json> <result.json>');
      return console.log(buildInversePrompt(loadInput(args[0]), loadResult(args[1])));
    }

    case 'check': {
      const prismPath = flag(args, '--prism');
      const inversePath = flag(args, '--inverse');
      const asJson = has(args, '--json');
      if (args.length < 2) die('usage : check <input.json> <result.json> [--prism <prism.md>] [--json]');
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
      if (prismPath) {
        let p;
        try { p = loadPrism(prismPath); } catch (e) { die(e.message); }
        if (p.sha256 !== result.prism.sha256 || p.id !== result.prism.id || p.version !== result.prism.version) {
          res.issues.unshift({ level: 'error', segment: '*', code: 'tampon-prisme', msg: `result tamponne ${result.prism.id}@${result.prism.version} (${result.prism.sha256.slice(0, 8)}), prisme fourni ${p.id}@${p.version} (${p.sha256.slice(0, 8)})` });
          res.errors += 1;
          res.ok = false;
        }
      }
      printCheck(res, asJson);
      return process.exit(res.ok ? 0 : 1);
    }

    case 'report': {
      const outPath = flag(args, '--out');
      if (args.length < 2) die('usage : report <input.json> <result.json>... [--out rapport.md]');
      const input = loadInput(args[0]);
      const md = report(input, args.slice(1).map(loadResult));
      if (outPath) { writeFileSync(outPath, md); return console.log(`[OK] rapport ecrit : ${outPath}`); }
      return console.log(md);
    }

    case 'chain': {
      if (args.length < 2) die('usage : chain <input.json> <result.json>');
      const input = loadInput(args[0]);
      const result = loadResult(args[1]);
      const res = check(input, result);
      if (!res.ok) { printCheck(res, false); die('chainage refuse : le result precedent n est pas conforme', 1); }
      const texts = new Map(result.segments.map((s) => [s.id, s.text]));
      const next = {
        ...input,
        segments: input.segments.map((s) => ({ ...s, text: texts.get(s.id) })),
        lineage: [...(input.lineage || []), { ...result.prism, variant: result.variant }],
      };
      return console.log(JSON.stringify(next, null, 2));
    }

    case 'run': {
      if (!args[0]) die('usage : run <base-dir>');
      const ts = new Date().toISOString().replace(/[:]/g, '').replace(/\..+/, 'Z');
      const dir = join(args[0], ts);
      mkdirSync(dir, { recursive: true });
      return console.log(dir);
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
