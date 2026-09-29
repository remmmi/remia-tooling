// Rapport de relecture humaine (markdown) : pour chaque segment, la source et
// chaque variante cote a cote, puis les alertes du controle.

import { check } from './checks.mjs';

export function report(input, results) {
  const lines = [];
  lines.push(`# PrismText : ${input.source.ref}`);
  lines.push('');
  lines.push(`Adaptateur : ${input.source.adapter}`);
  lines.push('');
  lines.push('| Variante | Prisme | Erreurs | Alertes |');
  lines.push('| --- | --- | --- | --- |');
  const checks = results.map((r) => check(input, r));
  results.forEach((r, i) => {
    lines.push(`| ${r.variant} | ${r.prism.id}@${r.prism.version} (${r.prism.sha256.slice(0, 8)}) | ${checks[i].errors} | ${checks[i].warnings} |`);
  });
  lines.push('');
  // Decisions humaines, separees par nature : un retrait voulu par le prisme
  // se confirme, une perte sans motif se repare, un ajout s'accepte ou non.
  const DECISIONS = [
    ['Retraits voulus par le prisme (a confirmer, ne rien retablir par defaut)', ['concept-retire']],
    ['Pertes sans motif (bloquantes, a reparer)', ['concept-perdu']],
    ['Ajouts absents de la source (a accepter ou retirer)', ['ajout-sans-source', 'ajout-non-declare', 'ajout-declare']],
  ];
  results.forEach((r, i) => {
    const blocks = DECISIONS.map(([title, codes]) => [title, checks[i].issues.filter((x) => codes.includes(x.code))]).filter(([, l]) => l.length);
    if (!blocks.length) return;
    lines.push(`## Decisions : variante ${r.variant}`, '');
    for (const [title, list] of blocks) {
      lines.push(`**${title}**`, '');
      for (const x of list) lines.push(`- ${x.segment} : ${x.msg}`);
      lines.push('');
    }
  });
  for (const s of input.segments) {
    lines.push(`## ${s.id}`);
    lines.push('');
    lines.push('**Source**');
    lines.push('');
    lines.push(`> ${s.text.replace(/\n/g, '\n> ')}`);
    lines.push('');
    results.forEach((r, i) => {
      const d = r.segments.find((x) => x.id === s.id);
      lines.push(`**Variante ${r.variant}**`);
      lines.push('');
      lines.push(d ? `> ${d.text.replace(/\n/g, '\n> ')}` : '> [segment absent]');
      for (const iss of checks[i].issues.filter((x) => x.segment === s.id)) {
        lines.push(`- [${iss.level.toUpperCase()}] ${iss.code} : ${iss.msg}`);
      }
      lines.push('');
    });
  }
  const glob = checks.flatMap((c, i) => c.issues.filter((x) => x.segment === '*').map((x) => `- [${x.level.toUpperCase()}] variante ${results[i].variant} : ${x.code} : ${x.msg}`));
  if (glob.length) lines.push('## Document entier', '', ...glob, '');
  return lines.join('\n');
}
