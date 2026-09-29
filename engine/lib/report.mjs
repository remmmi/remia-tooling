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
