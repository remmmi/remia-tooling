import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, writeFileSync, mkdtempSync, existsSync } from 'node:fs';
import { execFileSync, spawnSync } from 'node:child_process';
import { join, dirname } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { check, protectedTokens } from '../engine/lib/checks.mjs';
import { validateInput, validateResult } from '../engine/lib/contract.mjs';
import { loadPrism } from '../engine/lib/prism.mjs';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const FX = join(ROOT, 'tests', 'fixtures');
const load = (f) => JSON.parse(readFileSync(join(FX, f), 'utf8'));
const CLI = join(ROOT, 'engine', 'cli.mjs');
const input = load('site-web.input.json');
const good = load('site-web.result.json');

test('les fixtures respectent le contrat', () => {
  assert.deepEqual(validateInput(input), []);
  assert.deepEqual(validateResult(good), []);
});

test('cas reel site-web : conforme, retrait motive signale', () => {
  const r = check(input, good);
  assert.equal(r.ok, true);
  assert.ok(r.issues.some((i) => i.code === 'concept-retire'));
});

test('cas casse : chaque defaut est detecte', () => {
  const codes = new Set(check(input, load('site-web.result-casse.json')).issues.map((i) => i.code));
  for (const c of ['segment-perdu', 'token-protege', 'chiffre-invente', 'citation-introuvable', 'concept-perdu', 'ajout-non-declare', 'phrase-non-couverte', 'citation-cible-introuvable']) {
    assert.ok(codes.has(c), c);
  }
});

test('lien : ancre libre, destination verrouillee', () => {
  const rules = [{ name: 'lien', regex: '\\[[^\\]]+\\]\\((?<keep>[a-z-]+)\\)' }];
  assert.deepEqual(protectedTokens('voir [la methode](methode)', rules), protectedTokens('lire [nos tarifs](methode)', rules));
  assert.notDeepEqual(protectedTokens('[x](methode)', rules), protectedTokens('[x](contact)', rules));
});

test('passe inverse absente = erreur', () => {
  const r = structuredClone(good);
  delete r.inverse;
  assert.ok(check(input, r).issues.some((i) => i.code === 'passe-inverse-absente'));
});

test('passe inverse : source inventee = erreur, source d un autre segment = alerte', () => {
  const r = structuredClone(good);
  const e = r.inverse.find((x) => x.segment === 'offre.cartes.3.texte');
  e.source = 'une phrase qui n existe nulle part';
  assert.ok(check(input, r).issues.some((i) => i.code === 'citation-source-introuvable'));
  e.source = 'Rien ne part sans votre relecture.';
  assert.ok(check(input, r).issues.some((i) => i.code === 'source-autre-segment'));
});

test('CLI : check --inverse fusionne une carte produite a part', () => {
  const dir = mkdtempSync(join(tmpdir(), 'prismtext-'));
  const r = structuredClone(good);
  const inv = { inverse: r.inverse };
  delete r.inverse;
  writeFileSync(join(dir, 'r.json'), JSON.stringify(r));
  writeFileSync(join(dir, 'inv.json'), JSON.stringify(inv));
  assert.equal(spawnSync('node', [CLI, 'check', join(FX, 'site-web.input.json'), join(dir, 'r.json')]).status, 1);
  assert.equal(spawnSync('node', [CLI, 'check', join(FX, 'site-web.input.json'), join(dir, 'r.json'), '--inverse', join(dir, 'inv.json')]).status, 0);
});

test('inverse-brief : source et cible seulement, jamais la carte directe du redacteur', () => {
  const r = structuredClone(good);
  delete r.inverse;
  const dir = runDir(r);
  execFileSync('node', [CLI, 'inverse-brief', dir]);
  const b = readFileSync(join(dir, 'inverse-brief-a.md'), 'utf8');
  assert.match(b, /Tu es un agent isole/);
  assert.ok(b.includes(join(dir, 'inverse-a.json')));
  assert.match(b, /## methode\.corps/);
  assert.doesNotMatch(b, /## h1/);
  assert.doesNotMatch(b, /concept/);
  assert.doesNotMatch(b, /"motif"/);
  assert.equal(spawnSync('node', [CLI, 'check', dir]).status, 1, 'sans carte inverse : bloque');
  writeFileSync(join(dir, 'inverse-a.json'), JSON.stringify({ inverse: good.inverse }));
  assert.equal(spawnSync('node', [CLI, 'check', dir]).status, 0);
});

test('--previous : retrait motive puis reintroduit = erreur, perte reparee = ok', () => {
  const dir = mkdtempSync(join(tmpdir(), 'prismtext-'));
  const annule = structuredClone(good);
  annule.concepts.find((c) => c.concept === "il n'est pas parfait").cible = 'Ce site en est un exemple.';
  delete annule.concepts.find((c) => c.concept === "il n'est pas parfait").motif;
  writeFileSync(join(dir, 'annule.json'), JSON.stringify(annule));
  const out = spawnSync('node', [CLI, 'check', join(FX, 'site-web.input.json'), join(dir, 'annule.json'), '--previous', join(FX, 'site-web.result.json')], { encoding: 'utf8' });
  assert.equal(out.status, 1);
  assert.match(out.stdout, /retrait-annule/);
  const avant = structuredClone(good);
  const c = avant.concepts.find((x) => x.concept === 'pas de cout cache');
  c.cible = null;
  writeFileSync(join(dir, 'avant.json'), JSON.stringify(avant));
  assert.equal(spawnSync('node', [CLI, 'check', join(FX, 'site-web.input.json'), join(FX, 'site-web.result.json'), '--previous', join(dir, 'avant.json')]).status, 0);
});

test('report : section Decisions separe retraits voulus et ajouts', () => {
  const md = execFileSync('node', [CLI, 'report', runDir(good)], { encoding: 'utf8' });
  assert.match(md, /## Decisions : variante a/);
  assert.match(md, /Retraits voulus par le prisme[\s\S]*il n'est pas parfait/);
  assert.match(md, /Ajouts absents de la source[\s\S]*décrits plus bas/);
  assert.doesNotMatch(md, /Pertes sans motif/);
});

test('segment gele modifie = erreur', () => {
  const r = structuredClone(good);
  r.segments.find((s) => s.id === 'h1').text = 'Autre titre';
  assert.ok(check(input, r).issues.some((i) => i.code === 'gel-viole'));
});

test('element a conserver retire = erreur', () => {
  const i2 = structuredClone(input);
  i2.context.conserver = ['PrestaShop'];
  const r = structuredClone(good);
  const s = r.segments.find((x) => x.id === 'offre.cartes.0.texte');
  s.text = s.text.replace('PrestaShop', 'Un CMS');
  r.concepts = r.concepts.filter((c) => c.segment !== 'offre.cartes.0.texte');
  assert.ok(check(i2, r).issues.some((x) => x.code === 'element-a-conserver'));
});

test('prisme : tampon stable et verifie par check --prism', () => {
  const p = loadPrism(join(ROOT, 'prisms', 'copywriter-b2b.md'));
  assert.equal(p.sha256, good.prism.sha256);
  const bad = structuredClone(good);
  bad.prism.sha256 = '0'.repeat(64);
  const dir = mkdtempSync(join(tmpdir(), 'prismtext-'));
  writeFileSync(join(dir, 'r.json'), JSON.stringify(bad));
  const out = spawnSync('node', [CLI, 'check', join(FX, 'site-web.input.json'), join(dir, 'r.json'), '--prism', p.path], { encoding: 'utf8' });
  assert.equal(out.status, 1);
  assert.match(out.stdout, /tampon-prisme/);
});

test('CLI : codes de sortie', () => {
  assert.equal(spawnSync('node', [CLI, 'check', join(FX, 'site-web.input.json'), join(FX, 'site-web.result.json')]).status, 0);
  assert.equal(spawnSync('node', [CLI, 'check', join(FX, 'site-web.input.json'), join(FX, 'site-web.result-casse.json')]).status, 1);
  assert.equal(spawnSync('node', [CLI, 'check', join(FX, 'site-web.input.json')]).status, 2);
  assert.equal(spawnSync('node', [CLI, 'inconnue']).status, 2);
});

function runDir(result) {
  const dir = mkdtempSync(join(tmpdir(), 'prismtext-run-'));
  const inp = structuredClone(input);
  inp.context.rendu = 'Site web et boutique en ligne\nCe que je fais\nTEXTE-DU-GABARIT-VISIBLE';
  writeFileSync(join(dir, 'input.json'), JSON.stringify(inp));
  if (result) writeFileSync(join(dir, 'result-a.json'), JSON.stringify(result));
  return dir;
}
const PRISM = join(ROOT, 'prisms', 'copywriter-b2b.md');

test('brief : consigne autonome (cadre isole, prisme, page rendue, segments, destination)', () => {
  const dir = runDir();
  const out = execFileSync('node', [CLI, 'brief', PRISM, dir, '--variant', 'b'], { encoding: 'utf8' });
  assert.match(out, /^redaction : .*brief-b\.md\necrit par l agent : .*result-b\.json/);
  const b = readFileSync(join(dir, 'brief-b.md'), 'utf8');
  assert.match(b, /Tu es un agent isole/);
  assert.match(b, /n'ouvre aucun autre fichier/);
  assert.ok(b.includes(join(dir, 'result-b.json')), 'la consigne porte son chemin de sortie');
  assert.match(b, /PRÉSERVER LE FOND/);
  assert.match(b, /TEXTE-DU-GABARIT-VISIBLE/);
  assert.match(b, /### offre\.cartes\.3\.texte/);
  assert.match(b, /### h1 \{"freeze":true\}/, 'les segments geles sont montres pour le sens');
  assert.doesNotMatch(b, /- rendu :/, 'la page rendue n est pas dupliquee dans le contexte');
});

test('brief : variante non conforme -> consigne de correction, version archivee, erreurs listees', () => {
  const dir = runDir(load('site-web.result-casse.json'));
  const out = execFileSync('node', [CLI, 'brief', PRISM, dir], { encoding: 'utf8' });
  assert.match(out, /^correction 1 :/);
  assert.ok(existsSync(join(dir, 'result-a.r1.json')));
  assert.ok(!existsSync(join(dir, 'result-a.json')), 'la variante fautive est archivee, pas ecrasee');
  const b = readFileSync(join(dir, 'brief-a.md'), 'utf8');
  assert.match(b, /## Erreurs a corriger/);
  assert.match(b, /chiffre-invente/);
  assert.match(b, /Ne retablis JAMAIS une idee que le prisme a retiree/);
  writeFileSync(join(dir, 'result-a.json'), readFileSync(join(FX, 'site-web.result.json')));
  assert.equal(spawnSync('node', [CLI, 'check', dir]).status, 0);
  assert.equal(spawnSync('node', [CLI, 'brief', PRISM, dir]).status, 1, 'rien a corriger sur une variante conforme');
});

test('brief : une correction qui reintroduit un retrait motive est bloquee', () => {
  const dir = runDir(good);
  const annule = structuredClone(good);
  const c = annule.concepts.find((x) => x.concept === "il n'est pas parfait");
  c.cible = 'Ce site en est un exemple.';
  delete c.motif;
  writeFileSync(join(dir, 'result-a.r1.json'), JSON.stringify(good));
  writeFileSync(join(dir, 'result-a.json'), JSON.stringify(annule));
  const out = spawnSync('node', [CLI, 'check', dir], { encoding: 'utf8' });
  assert.equal(out.status, 1);
  assert.match(out.stdout, /retrait-annule/);
});

test('chain : refuse une variante non conforme, prepare l input suivant sinon', () => {
  const bad = runDir(load('site-web.result-casse.json'));
  assert.equal(spawnSync('node', [CLI, 'chain', bad, 'a', join(bad, 'suite')]).status, 1);
  const dir = runDir(good);
  execFileSync('node', [CLI, 'chain', dir, 'a', join(dir, 'suite')]);
  const next = JSON.parse(readFileSync(join(dir, 'suite', 'input.json'), 'utf8'));
  assert.equal(next.lineage.length, 1);
  assert.equal(next.segments.find((x) => x.id === 'chapo').text, good.segments.find((x) => x.id === 'chapo').text);
});

test('report : variantes cote a cote depuis le dossier de run', () => {
  const dir = runDir(good);
  writeFileSync(join(dir, 'result-casse.json'), readFileSync(join(FX, 'site-web.result-casse.json')));
  const md = execFileSync('node', [CLI, 'report', dir], { encoding: 'utf8' });
  assert.match(md, /\*\*Variante a\*\*/);
  assert.match(md, /\*\*Variante casse\*\*/);
  assert.match(md, /\[ERROR\] chiffre-invente/);
});

test('adaptateur de reference : aller-retour sans perte', () => {
  const dir = mkdtempSync(join(tmpdir(), 'prismtext-'));
  const f = join(dir, 'page.md');
  const src = '# Titre\n\nPremier paragraphe avec [un lien](https://ex.fr).\n\nSecond paragraphe.\n';
  writeFileSync(f, src);
  const AD = join(ROOT, 'adapters', 'reference-files', 'adapter.mjs');
  execFileSync('node', [AD, 'extract', f, join(dir, 'in.json')]);
  const inp = JSON.parse(readFileSync(join(dir, 'in.json'), 'utf8'));
  assert.deepEqual(validateInput(inp), []);
  assert.equal(inp.segments[0].constraints.freeze, true);
  const res = {
    prismtext: '1', prism: { id: 't', version: '0.0.1', sha256: 'x' }, variant: 'b',
    segments: inp.segments.map((s) => ({ id: s.id, text: s.id === 'p003' ? 'Deuxieme paragraphe.' : s.text })),
    concepts: [], ajouts: [],
  };
  writeFileSync(join(dir, 'r.json'), JSON.stringify(res));
  const preview = execFileSync('node', [AD, 'preview', join(dir, 'r.json'), f], { encoding: 'utf8' }).trim();
  assert.equal(readFileSync(preview, 'utf8'), src.replace('Second', 'Deuxieme'));
  assert.equal(readFileSync(f, 'utf8'), src, 'preview ne touche pas la source');
});

test('lot : creation, etat par source, rapport consolide, decision, application', () => {
  const base = mkdtempSync(join(tmpdir(), 'prismtext-lot-'));
  const dir = execFileSync('node', [CLI, 'lot', base, 'essai', 'src/pages/a.yaml', 'src/pages/b.yaml'], { encoding: 'utf8' }).trim();
  const a = join(dir, 'src-pages-a');
  writeFileSync(join(a, 'input.json'), readFileSync(join(FX, 'site-web.input.json')));
  writeFileSync(join(a, 'result-a.json'), readFileSync(join(FX, 'site-web.result.json')));
  let st = JSON.parse(execFileSync('node', [CLI, 'lot-status', dir, '--json'], { encoding: 'utf8' }));
  assert.equal(st.sources[0].stage, 'verifie', 'la carte inverse est embarquee dans le result');
  assert.equal(st.sources[1].stage, 'a-faire');
  assert.equal(st.sources[0].checks[0].retraits, 1);
  assert.equal(spawnSync('node', [CLI, 'applied', a, 'a']).status, 1, 'pas d application sans decision humaine');
  writeFileSync(join(a, 'result-z.json'), readFileSync(join(FX, 'site-web.result-casse.json')));
  assert.equal(spawnSync('node', [CLI, 'decide', a, 'z']).status, 1, 'variante non conforme refusee sans --force');
  assert.equal(spawnSync('node', [CLI, 'decide', a, 'z', '--force']).status, 0);
  execFileSync('node', [CLI, 'decide', a, 'a']);
  assert.equal(spawnSync('node', [CLI, 'applied', a, 'b']).status, 1, 'pas d application d une autre variante que celle choisie');
  execFileSync('node', [CLI, 'applied', a, 'a']);
  st = JSON.parse(execFileSync('node', [CLI, 'lot-status', dir, '--json'], { encoding: 'utf8' }));
  assert.equal(st.sources[0].stage, 'applique');
  const md = execFileSync('node', [CLI, 'lot-report', dir], { encoding: 'utf8' });
  assert.match(md, /\| src\/pages\/a\.yaml \| applique \| a \|/);
  assert.match(md, /\| src\/pages\/b\.yaml \| a-faire \|/);
  assert.match(md, /Retraits voulus par le prisme/);
  assert.equal(spawnSync('node', [CLI, 'lot', base, 'Mauvais Nom', 'x']).status, 2);
});

test('selftest', () => {
  assert.equal(spawnSync('node', [CLI, 'selftest']).status, 0);
});
