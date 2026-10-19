// Mode lot : plusieurs sources traitees dans un meme run. Un lot est un
// dossier contenant lot.json et un sous-dossier par source, chacun etant un
// run ordinaire (input, prompts, results, inverses, rapport, decision).
// L'etat de chaque source se lit sur le disque : un lot interrompu reprend
// la ou il s'est arrete.

import { readFileSync, writeFileSync, mkdirSync, existsSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import { runCheck } from './run.mjs';

export function slug(ref) {
  return ref.replace(/\.[a-z]+$/i, '').replace(/[^a-zA-Z0-9]+/g, '-').replace(/^-|-$/g, '').toLowerCase();
}

export function createLot(base, name, refs) {
  if (!/^[a-z0-9-]+$/.test(name)) throw new Error(`nom de lot "${name}" : minuscules, chiffres et tirets seulement`);
  if (!refs.length) throw new Error('aucune source dans le lot');
  const slugs = refs.map(slug);
  const dup = slugs.filter((s, i) => slugs.indexOf(s) !== i);
  if (dup.length) throw new Error(`sources en collision : ${dup.join(', ')}`);
  const ts = new Date().toISOString().replace(/[:]/g, '').replace(/\..+/, 'Z');
  const dir = join(base, `lot-${name}-${ts}`);
  mkdirSync(dir, { recursive: true });
  const lot = { prismtext: '1', name, created: new Date().toISOString(), sources: refs.map((ref, i) => ({ ref, dir: slugs[i] })) };
  for (const s of lot.sources) mkdirSync(join(dir, s.dir));
  writeFileSync(join(dir, 'lot.json'), JSON.stringify(lot, null, 2) + '\n');
  return dir;
}

const readJson = (p) => JSON.parse(readFileSync(p, 'utf8'));

// Etat d'une source, deduit des fichiers presents.
export function sourceState(dir) {
  const files = existsSync(dir) ? readdirSync(dir) : [];
  const variants = files.map((f) => f.match(/^result-([a-z0-9]+)\.json$/)?.[1]).filter(Boolean);
  const out = { input: files.includes('input.json'), variants: [] };
  for (const v of variants) {
    let embedded = false;
    try { embedded = Array.isArray(readJson(join(dir, `result-${v}.json`)).inverse); } catch { /* result illisible : vu au check */ }
    out.variants.push({ variant: v, inverse: files.includes(`inverse-${v}.json`) || embedded });
  }
  out.decision = files.includes('decision.json') ? readJson(join(dir, 'decision.json')) : null;
  out.applied = files.includes('applied.json') ? readJson(join(dir, 'applied.json')) : null;
  out.stage = out.applied ? 'applique'
    : out.decision ? 'decide'
    : out.variants.length && out.variants.every((v) => v.inverse) ? 'verifie'
    : out.variants.length ? 'transforme'
    : out.input ? 'extrait'
    : 'a-faire';
  return out;
}

export async function lotStatus(lotDir) {
  const lot = readJson(join(lotDir, 'lot.json'));
  const sources = [];
  for (const s of lot.sources) {
    const dir = join(lotDir, s.dir);
    const st = sourceState(dir);
    const checks = [];
    if (st.input) {
      for (const v of st.variants) {
        const c = await runCheck(dir, v.variant);
        const count = (codes) => c.issues.filter((i) => codes.includes(i.code)).length;
        const r = readJson(join(dir, `result-${v.variant}.json`));
        checks.push({
          variant: v.variant,
          prism: `${r.prism.id}@${r.prism.version}`,
          ok: c.ok,
          round: c.round,
          errors: c.errors,
          warnings: c.warnings,
          retraits: count(['concept-retire']),
          pertes: count(['concept-perdu']),
          ajouts: count(['ajout-sans-source', 'ajout-non-declare', 'ajout-declare']),
          issues: c.issues,
        });
      }
    }
    sources.push({ ref: s.ref, dir: s.dir, stage: st.stage, decision: st.decision, applied: st.applied, checks });
  }
  return { name: lot.name, created: lot.created, dir: lotDir, sources };
}

export async function lotReport(lotDir) {
  const st = await lotStatus(lotDir);
  const L = [];
  L.push(`# PrismText : lot ${st.name}`, '', `Cree le ${st.created}. Dossier : ${st.dir}`, '');
  L.push('| Source | Etape | Variante | Prisme | Conforme | Erreurs | Alertes | Retraits voulus | Pertes | Ajouts | Decision |');
  L.push('| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |');
  for (const s of st.sources) {
    const dec = s.decision ? s.decision.choix : '';
    if (!s.checks.length) L.push(`| ${s.ref} | ${s.stage} | | | | | | | | | ${dec} |`);
    for (const c of s.checks) {
      L.push(`| ${s.ref} | ${s.stage} | ${c.variant} | ${c.prism} | ${c.ok ? 'oui' : 'NON'} | ${c.errors} | ${c.warnings} | ${c.retraits} | ${c.pertes} | ${c.ajouts} | ${dec} |`);
    }
  }
  const DECISIONS = [
    ['Retraits voulus par le prisme (a confirmer, ne rien retablir par defaut)', ['concept-retire']],
    ['Pertes sans motif (bloquantes, a reparer)', ['concept-perdu']],
    ['Ajouts absents de la source (a accepter ou retirer)', ['ajout-sans-source', 'ajout-non-declare', 'ajout-declare']],
    ['Autres erreurs bloquantes', null],
  ];
  for (const s of st.sources) {
    for (const c of s.checks) {
      const blocks = DECISIONS.map(([title, codes]) => [title, c.issues.filter((i) => (codes ? codes.includes(i.code) : i.level === 'error' && !['concept-perdu', 'ajout-non-declare'].includes(i.code)))]).filter(([, l]) => l.length);
      if (!blocks.length) continue;
      L.push('', `## ${s.ref} : variante ${c.variant}`, '', `Detail cote a cote : ${join(s.dir, 'rapport.md')}`, '');
      for (const [title, list] of blocks) {
        L.push(`**${title}**`, '');
        for (const i of list) L.push(`- ${i.segment} : ${i.msg}`);
        L.push('');
      }
    }
  }
  return L.join('\n');
}
