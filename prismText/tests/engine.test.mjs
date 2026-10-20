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
  const p = loadPrism(join(FX, 'copywriter-b2b-1.0.0.md'));
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
const PRISM = join(FX, 'copywriter-b2b-1.0.0.md');

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

test('controles lexicaux : minChars, forbid, maxOccurrences (segment et contexte)', () => {
  const i2 = structuredClone(input);
  i2.context.forbid = ['Découvrez', 'dimensions généreuses'];
  i2.context.maxOccurrences = { montagne: 1 };
  const seg = i2.segments.find((s) => s.id === 'offre.cartes.0.texte');
  seg.constraints = { ...(seg.constraints || {}), minChars: 5000, forbid: ['CMS'] };
  const r = structuredClone(good);
  const d = r.segments.find((s) => s.id === 'offre.cartes.0.texte');
  d.text = 'Découvrez la montagne et la Montagne avec un CMS. ' + d.text;
  const codes = check(i2, r).issues.filter((x) => x.segment === 'offre.cartes.0.texte');
  const by = (code) => codes.filter((x) => x.code === code && x.level === 'error');
  assert.equal(by('longueur-min').length, 1);
  assert.equal(by('terme-interdit').length, 2, 'Découvrez (contexte) et CMS (segment)');
  assert.equal(by('occurrences-max').length, 1, 'montagne 2 fois, insensible a la casse');
  assert.ok(!check(input, good).issues.some((x) => ['longueur-min', 'terme-interdit', 'occurrences-max'].includes(x.code)));
  assert.deepEqual(validateInput(i2), []);
  i2.context.forbid = 'Découvrez';
  assert.ok(validateInput(i2).some((e) => e.includes('context.forbid')));
});

test('decide --auto : decision automatique sur check vert, jamais forcee, applied l accepte', () => {
  const dir = runDir(good);
  const out = execFileSync('node', [CLI, 'decide', dir, 'a', '--auto'], { encoding: 'utf8' });
  assert.match(out, /decision a enregistree/);
  const dec = JSON.parse(readFileSync(join(dir, 'decision.json'), 'utf8'));
  assert.equal(dec.par, 'auto');
  assert.equal(dec.auto, true);
  assert.equal(spawnSync('node', [CLI, 'applied', dir, 'a']).status, 0);
  const bad = runDir(load('site-web.result-casse.json'));
  assert.equal(spawnSync('node', [CLI, 'decide', bad, 'a', '--auto']).status, 1, 'non conforme : refuse');
  assert.equal(spawnSync('node', [CLI, 'decide', bad, 'a', '--auto', '--force']).status, 2, '--auto et --force sont incompatibles');
  assert.ok(!existsSync(join(bad, 'decision.json')));
});

// Entrees structurees de reference : matiere annexe a la source (specs,
// vision, nom...), rangee par rang de confiance, citable par le verificateur.
function withRefs() {
  const i2 = structuredClone(input);
  i2.references = [
    { id: 'name', trust: 1, text: 'Bahut Tolentino chêne huilé 3 portes' },
    { id: 'specs', trust: 1, facts: { dimensions: '153x85x50', weight: '48 kg' } },
    { id: 'vision', trust: 3, facts: { colors: 'brun clair', branding: 'étiquette Tolentino', size_impression: 'environ 2 m' }, numeric: false, uncitable: ['branding', 'size_impression'] },
  ];
  return i2;
}

test('references : validation du contrat', () => {
  const i2 = withRefs();
  assert.deepEqual(validateInput(i2), []);
  i2.references.push({ id: 'specs', trust: 1, text: 'doublon' });
  assert.ok(validateInput(i2).some((e) => e.includes('references.3.id')));
  i2.references = [{ id: 'x', trust: 0, text: 'rang invalide' }];
  assert.ok(validateInput(i2).some((e) => e.includes('references.0.trust')));
  i2.references = [{ id: 'x', trust: 1 }];
  assert.ok(validateInput(i2).some((e) => e.includes('references.0')), 'text ou facts obligatoire');
});

test('references : chiffres et noms propres pris dans une reference = source ; vision numeric:false ne source aucun chiffre', () => {
  const i2 = withRefs();
  const r = structuredClone(good);
  const seg = 'offre.cartes.0.texte';
  const d = r.segments.find((s) => s.id === seg);
  d.text += ' Il mesure 153x85x50 cm et pèse 48 kg, signé Tolentino.';
  r.inverse.push({ segment: seg, cible: 'Il mesure 153x85x50 cm et pèse 48 kg, signé Tolentino.', source: 'ref:specs.dimensions' });
  const codes = check(i2, r).issues.filter((x) => x.segment === seg);
  assert.ok(!codes.some((x) => x.code === 'chiffre-invente'), JSON.stringify(codes));
  assert.ok(!codes.some((x) => x.code === 'nom-propre-nouveau' && x.msg.includes('Tolentino')));
  i2.references[2].facts.size_impression = 'environ 7 m';
  d.text = d.text.replace('48 kg', '7 m');
  r.inverse.at(-1).cible = r.inverse.at(-1).cible.replace('48 kg', '7 m');
  assert.ok(check(i2, r).issues.some((x) => x.code === 'chiffre-invente' && x.msg.includes('"7"')), 'un chiffre que seule la vision porte est invente');
});

test('references : citation ref:<id>.<cle> resolue, non citable ou inconnue = erreur, extrait litteral d une reference texte accepte', () => {
  const i2 = withRefs();
  const r = structuredClone(good);
  const seg = 'offre.cartes.0.texte';
  const d = r.segments.find((s) => s.id === seg);
  d.text += ' Brun clair, trois portes.';
  const e = { segment: seg, cible: 'Brun clair, trois portes.', source: 'ref:vision.colors' };
  r.inverse.push(e);
  const run = () => check(i2, r).issues.filter((x) => x.segment === seg && x.level === 'error').map((x) => x.code);
  assert.deepEqual(run(), []);
  e.source = 'ref:vision.branding';
  assert.ok(run().includes('reference-non-citable'));
  e.source = 'ref:specs.inconnue';
  assert.ok(run().includes('citation-source-introuvable'));
  e.source = 'ref:nulle';
  assert.ok(run().includes('citation-source-introuvable'));
  e.source = 'chêne huilé 3 portes';
  assert.deepEqual(run(), [], 'extrait litteral de la reference name');
});

test('inverse : "probleme" nomme par le verificateur = erreur portant ce code', () => {
  const r = structuredClone(good);
  const e = r.inverse.find((x) => x.segment === 'offre.cartes.3.texte');
  e.probleme = 'conflit-de-rang';
  const iss = check(input, r).issues.find((x) => x.code === 'conflit-de-rang');
  assert.equal(iss?.level, 'error');
  assert.equal(iss?.segment, 'offre.cartes.3.texte');
});

test('forbidPatterns : regex interdite (prix en euros)', () => {
  const i2 = structuredClone(input);
  i2.context.forbidPatterns = ['\\d[\\d\\s,.]*\\s?(€|euros?)'];
  const r = structuredClone(good);
  const d = r.segments.find((s) => s.id === 'offre.cartes.0.texte');
  d.text += ' Supplément de 172,50 euros.';
  assert.ok(check(i2, r).issues.some((x) => x.code === 'motif-interdit' && x.level === 'error'));
  i2.context.forbidPatterns = ['(']; 
  assert.ok(validateInput(i2).some((e) => e.includes('forbidPatterns')));
});

test('briefs : les references sont donnees au redacteur et au verificateur, par rang, avec la syntaxe de citation ; section VERIFICATEUR du prisme', () => {
  const dir = mkdtempSync(join(tmpdir(), 'prismtext-run-'));
  const i2 = withRefs();
  i2.context.rendu = 'x';
  writeFileSync(join(dir, 'input.json'), JSON.stringify(i2));
  const prismPath = join(dir, 'p.md');
  writeFileSync(prismPath, '---\nid: p\nversion: 1.0.0\ndescription: test\n---\nROLE\n\nRedige.\n\nVERIFICATEUR\n\nV5 Emballage : probleme "emballage".\n');
  execFileSync('node', [CLI, 'brief', prismPath, dir]);
  const b = readFileSync(join(dir, 'brief-a.md'), 'utf8');
  assert.match(b, /## References/);
  assert.match(b, /rang 1[\s\S]*specs[\s\S]*dimensions : 153x85x50/);
  assert.match(b, /branding[^\n]*non citable/);
  assert.doesNotMatch(b, /V5 Emballage/, 'la section VERIFICATEUR ne va pas au redacteur');
  const r = structuredClone(good);
  delete r.inverse;
  const p = loadPrism(prismPath);
  r.prism = { id: p.id, version: p.version, sha256: p.sha256 };
  writeFileSync(join(dir, 'result-a.json'), JSON.stringify(r));
  execFileSync('node', [CLI, 'inverse-brief', dir, '--prism', prismPath]);
  const ib = readFileSync(join(dir, 'inverse-brief-a.md'), 'utf8');
  assert.match(ib, /## References/);
  assert.match(ib, /ref:specs\.dimensions/);
  assert.match(ib, /V5 Emballage/);
  assert.match(ib, /"probleme"/);
  assert.doesNotMatch(ib, /Redige\./, 'le corps redacteur du prisme ne va pas au verificateur');
});

test('prisme : module de controle declare dans le frontmatter, tamponne avec le prisme, execute par check --prism', () => {
  const dir = mkdtempSync(join(tmpdir(), 'prismtext-run-'));
  const i2 = withRefs();
  writeFileSync(join(dir, 'input.json'), JSON.stringify(i2));
  const prismPath = join(dir, 'p.md');
  writeFileSync(prismPath, '---\nid: p\nversion: 1.0.0\ndescription: test\ncheck: p.check.mjs\n---\nROLE\n');
  writeFileSync(join(dir, 'p.check.mjs'), 'export function check({ input, result }) { return result.segments.some((s) => /bahut/i.test(s.text)) ? [{ level: "error", segment: "*", code: "mot-bahut", msg: "bahut vu" }] : []; }\n');
  const p1 = loadPrism(prismPath);
  assert.equal(p1.check, join(dir, 'p.check.mjs'));
  writeFileSync(join(dir, 'p.check.mjs'), 'export function check() { return []; }\n');
  assert.notEqual(loadPrism(prismPath).sha256, p1.sha256, 'le module compte dans l empreinte');
  writeFileSync(join(dir, 'p.check.mjs'), 'export function check({ input, result }) { return result.segments.some((s) => /bahut/i.test(s.text)) ? [{ level: "error", segment: "*", code: "mot-bahut", msg: "bahut vu" }] : []; }\n');
  const r = structuredClone(good);
  r.prism = { id: p1.id, version: p1.version, sha256: p1.sha256 };
  writeFileSync(join(dir, 'result-a.json'), JSON.stringify(r));
  { const o = spawnSync("node", [CLI, "check", dir, "--prism", prismPath], { encoding: "utf8" }); assert.equal(o.status, 0, o.stdout + o.stderr); }
  const seg = r.segments.find((s) => s.id === 'offre.cartes.0.texte');
  seg.text += ' Un bahut.';
  r.inverse.push({ segment: seg.id, cible: 'Un bahut.', source: 'ref:name' });
  writeFileSync(join(dir, 'result-a.json'), JSON.stringify(r));
  const out = spawnSync('node', [CLI, 'check', dir, '--prism', prismPath], { encoding: 'utf8' });
  assert.equal(out.status, 1);
  assert.match(out.stdout, /mot-bahut/);
  assert.equal(spawnSync('node', [CLI, 'check', dir]).status, 0, 'sans --prism le module ne tourne pas');
});

test('references : citable:false sur la reference entiere, exclusive = une seule valeur, celle du nom', () => {
  const i2 = withRefs();
  i2.references.push({ id: 'prix', trust: 1, text: '730 euros', citable: false, numeric: false });
  i2.references.push({ id: 'capacite', trust: 1, facts: { number_of_persons: '2, 4 et 6 personnes' }, exclusive: ['2 personnes', '4 personnes', '6 personnes'] });
  i2.references[0].text = 'Appareil à raclette 4 personnes';
  assert.deepEqual(validateInput(i2), []);
  const r = structuredClone(good);
  const seg = 'offre.cartes.0.texte';
  const d = r.segments.find((s) => s.id === seg);
  d.text += ' Prévu pour 4 personnes.';
  r.inverse.push({ segment: seg, cible: 'Prévu pour 4 personnes.', source: 'ref:prix' });
  const codes = () => check(i2, r).issues.filter((x) => x.segment === seg && x.level === 'error').map((x) => x.code);
  assert.ok(codes().includes('reference-non-citable'));
  r.inverse.at(-1).source = 'ref:capacite.number_of_persons';
  assert.deepEqual(codes(), []);
  d.text += ' Existe aussi en 6 personnes.';
  r.inverse.push({ segment: seg, cible: 'Existe aussi en 6 personnes.', source: 'ref:capacite.number_of_persons' });
  assert.ok(codes().includes('hors-perimetre'));
});

test('ajouts : nature "fait" = erreur, "enjolivement" = alerte, autre nature = contrat invalide', () => {
  const r = structuredClone(good);
  r.ajouts = [{ segment: 'offre.cartes.3.texte', texte: 'décrits plus bas', nature: 'enjolivement' }];
  assert.deepEqual(validateResult(r), []);
  assert.ok(!check(input, r).issues.some((x) => x.code === 'ajout-fait'));
  r.ajouts[0].nature = 'fait';
  assert.ok(check(input, r).issues.some((x) => x.code === 'ajout-fait' && x.level === 'error'));
  r.ajouts[0].nature = 'autre';
  assert.ok(validateResult(r).some((e) => e.includes('ajouts.0.nature')));
});

// Contrats portes par le prisme : ce qu il attend de l input (requires) et
// ce qu il produit (produces), lisibles par l amont et l aval du moteur.
test('prisme : requires / produces lus, affiches, et brief refuse un input incomplet', () => {
  const dir = mkdtempSync(join(tmpdir(), 'prismtext-run-'));
  const prismPath = join(dir, 'p.md');
  writeFileSync(prismPath, [
    '---', 'id: p', 'version: 1.0.0', 'description: test',
    'requires: references name(trust 1, text), specs(trust 1, facts), prix?(text) ; segments description',
    'produces: description = prose, 2 a 3 paragraphes, <strong> seul balisage',
    '---', 'ROLE', '',
  ].join('\n'));
  const p = loadPrism(prismPath);
  assert.deepEqual(p.requires.references.map((r) => r.id), ['name', 'specs', 'prix']);
  assert.equal(p.requires.references[2].optional, true);
  assert.equal(p.requires.references[1].trust, 1);
  assert.equal(p.requires.references[1].kind, 'facts');
  assert.deepEqual(p.requires.segments, ['description']);
  assert.equal(p.produces[0].segment, 'description');
  assert.match(p.produces[0].format, /prose/);
  const out = execFileSync('node', [CLI, 'prism', prismPath], { encoding: 'utf8' });
  assert.match(out, /"requires"/);
  assert.match(out, /"produces"/);
  const i2 = withRefs();
  i2.references = i2.references.filter((r) => r.id !== 'specs');
  writeFileSync(join(dir, 'input.json'), JSON.stringify(i2));
  const r = spawnSync('node', [CLI, 'brief', prismPath, dir], { encoding: 'utf8' });
  assert.equal(r.status, 2, r.stderr);
  assert.match(r.stderr, /specs/);
  i2.references = withRefs().references;
  writeFileSync(join(dir, 'input.json'), JSON.stringify(i2));
  assert.equal(spawnSync('node', [CLI, 'brief', prismPath, dir]).status, 2, 'segment description absent');
  i2.segments[0].id = 'description';
  writeFileSync(join(dir, 'input.json'), JSON.stringify(i2));
  assert.equal(spawnSync('node', [CLI, 'brief', prismPath, dir]).status, 0);
  assert.equal(loadPrism(PRISM).requires, null, 'contrat optionnel : copywriter-b2b n en declare pas');
});

// Contrats JSON Schema portes par le prisme : input_schema (verifie par
// brief) et output_schema (verifie par check --prism), tamponnes.
test('prisme : input_schema et output_schema, validateur zero dependance, tamponnes, verifies par brief et check', () => {
  const dir = mkdtempSync(join(tmpdir(), 'prismtext-run-'));
  const prismPath = join(dir, 'p.md');
  writeFileSync(join(dir, 'in.schema.json'), JSON.stringify({
    type: 'object', required: ['references', 'segments'],
    properties: {
      references: { type: 'array', contains: { type: 'object', properties: { id: { const: 'specs' } }, required: ['id'] } },
      segments: { type: 'array', minItems: 1, items: { type: 'object', required: ['id'], properties: { id: { enum: ['description'] } } } },
    },
  }));
  writeFileSync(join(dir, 'out.schema.json'), JSON.stringify({
    type: 'object', required: ['segments'],
    properties: { segments: { type: 'array', minItems: 1, maxItems: 1, items: { type: 'object', properties: { text: { type: 'string', minLength: 10, pattern: '^[^<]*(<strong>[^<]*</strong>[^<]*)*$' } } } } },
  }));
  writeFileSync(prismPath, '---\nid: p\nversion: 1.0.0\ndescription: test\ninput_schema: in.schema.json\noutput_schema: out.schema.json\n---\nROLE\n');
  const p1 = loadPrism(prismPath);
  assert.equal(p1.inputSchema.required[0], 'references');
  assert.equal(p1.outputSchema.properties.segments.maxItems, 1);
  writeFileSync(join(dir, 'out.schema.json'), JSON.stringify({ type: 'object' }));
  assert.notEqual(loadPrism(prismPath).sha256, p1.sha256, 'les schemas comptent dans l empreinte');
  writeFileSync(join(dir, 'out.schema.json'), JSON.stringify({
    type: 'object', required: ['segments'],
    properties: { segments: { type: 'array', minItems: 1, maxItems: 1, items: { type: 'object', properties: { text: { type: 'string', minLength: 10, pattern: '^[^<]*(<strong>[^<]*</strong>[^<]*)*$' } } } } },
  }));
  const i2 = withRefs();
  i2.segments = [{ id: 'description', text: i2.segments[1].text }];
  i2.references = i2.references.filter((r) => r.id !== 'specs');
  writeFileSync(join(dir, 'input.json'), JSON.stringify(i2));
  const r1 = spawnSync('node', [CLI, 'brief', prismPath, dir], { encoding: 'utf8' });
  assert.equal(r1.status, 2);
  assert.match(r1.stderr, /references : aucun element ne satisfait contains/);
  i2.references = withRefs().references;
  writeFileSync(join(dir, 'input.json'), JSON.stringify(i2));
  assert.equal(spawnSync('node', [CLI, 'brief', prismPath, dir]).status, 0);
  const res = { prismtext: '1', prism: { id: p1.id, version: p1.version, sha256: p1.sha256 }, variant: 'a',
    segments: [{ id: 'description', text: 'Un texte en <strong>gras</strong> conforme.' }],
    concepts: [], ajouts: [], inverse: [] };
  writeFileSync(join(dir, 'result-a.json'), JSON.stringify(res));
  const ok = spawnSync('node', [CLI, 'check', dir, '--prism', prismPath], { encoding: 'utf8' });
  assert.ok(!/contrat-sortie/.test(ok.stdout), ok.stdout);
  res.segments[0].text = 'Un texte avec <em>autre</em> balise.';
  writeFileSync(join(dir, 'result-a.json'), JSON.stringify(res));
  const ko = spawnSync('node', [CLI, 'check', dir, '--prism', prismPath], { encoding: 'utf8' });
  assert.equal(ko.status, 1);
  assert.match(ko.stdout, /contrat-sortie/);
  assert.equal(loadPrism(PRISM).inputSchema, null);
});

test('exclusive : seule une reference texte de rang 1 ancre la valeur ; la source de rang 2 qui les enumere n ancre rien', () => {
  const i2 = withRefs();
  i2.references[0].text = 'Appareil à raclette 4 personnes';
  i2.references.push({ id: 'src', trust: 2, text: 'Existe en 2, 4 et 6 personnes.' });
  i2.references.push({ id: 'capacite', trust: 1, facts: { number_of_persons: '2, 4 et 6 personnes' }, exclusive: ['2 personnes', '4 personnes', '6 personnes'] });
  const r = structuredClone(good);
  const seg = 'offre.cartes.0.texte';
  const d = r.segments.find((s) => s.id === seg);
  d.text += ' Prévu pour 6 personnes.';
  r.inverse.push({ segment: seg, cible: 'Prévu pour 6 personnes.', source: 'ref:capacite.number_of_persons' });
  const codes = () => check(i2, r).issues.filter((x) => x.segment === seg && x.level === 'error').map((x) => x.code);
  assert.ok(codes().includes('hors-perimetre'), 'le nom dit 4 personnes : 6 personnes est hors perimetre meme si la source les enumere');
  d.text = d.text.replace('6 personnes', '4 personnes');
  r.inverse.at(-1).cible = 'Prévu pour 4 personnes.';
  assert.deepEqual(codes(), []);
});

test('maxOccurrences : les occurrences dans le nom de l article (reference texte de rang 1) ne comptent pas', () => {
  const i2 = withRefs();
  i2.references[0].text = 'Interrupteur décoré chalet';
  i2.context.maxOccurrences = { chalet: 1 };
  const r = structuredClone(good);
  const seg = 'offre.cartes.0.texte';
  const d = r.segments.find((s) => s.id === seg);
  d.text = 'L Interrupteur décoré chalet habille une pièce de chalet. ' + d.text;
  const by = () => check(i2, r).issues.filter((x) => x.segment === seg && x.code === 'occurrences-max');
  assert.equal(by().length, 0, 'une fois dans le nom, une fois dans la prose');
  d.text = d.text.replace('une pièce de chalet', 'une pièce de chalet ou un chalet');
  assert.equal(by().length, 1);
});

test('chain : les constraints du segment ne sont pas reportees a l etape suivante', () => {
  const dir = runDir(good);
  execFileSync('node', [CLI, 'chain', dir, 'a', join(dir, 'suite')]);
  const next = JSON.parse(readFileSync(join(dir, 'suite', 'input.json'), 'utf8'));
  assert.ok(input.segments.some((s) => s.constraints), 'la fixture porte des constraints');
  assert.ok(next.segments.every((s) => s.constraints === undefined));
});
