import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, writeFileSync, mkdtempSync } from 'node:fs';
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
  for (const c of ['segment-perdu', 'token-protege', 'chiffre-invente', 'citation-introuvable', 'concept-perdu']) {
    assert.ok(codes.has(c), c);
  }
});

test('lien : ancre libre, destination verrouillee', () => {
  const rules = [{ name: 'lien', regex: '\\[[^\\]]+\\]\\((?<keep>[a-z-]+)\\)' }];
  assert.deepEqual(protectedTokens('voir [la methode](methode)', rules), protectedTokens('lire [nos tarifs](methode)', rules));
  assert.notDeepEqual(protectedTokens('[x](methode)', rules), protectedTokens('[x](contact)', rules));
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

test('CLI : prompt contient consigne, contraintes et segments', () => {
  const out = execFileSync('node', [CLI, 'prompt', join(ROOT, 'prisms', 'copywriter-b2b.md'), join(FX, 'site-web.input.json'), '--variant', 'b'], { encoding: 'utf8' });
  assert.match(out, /PRÉSERVER LE FOND/);
  assert.match(out, /Tokens proteges/);
  assert.match(out, /### offre\.cartes\.3\.texte/);
  assert.match(out, /"variant": "b"/);
});

test('CLI : chain refuse un result non conforme, accepte un conforme', () => {
  assert.equal(spawnSync('node', [CLI, 'chain', join(FX, 'site-web.input.json'), join(FX, 'site-web.result-casse.json')]).status, 1);
  const next = JSON.parse(execFileSync('node', [CLI, 'chain', join(FX, 'site-web.input.json'), join(FX, 'site-web.result.json')], { encoding: 'utf8' }));
  assert.equal(next.lineage.length, 1);
  assert.equal(next.segments.find((s) => s.id === 'chapo').text, good.segments.find((s) => s.id === 'chapo').text);
});

test('CLI : report produit les variantes cote a cote', () => {
  const md = execFileSync('node', [CLI, 'report', join(FX, 'site-web.input.json'), join(FX, 'site-web.result.json'), join(FX, 'site-web.result-casse.json')], { encoding: 'utf8' });
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

test('selftest', () => {
  assert.equal(spawnSync('node', [CLI, 'selftest']).status, 0);
});
