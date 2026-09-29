#!/usr/bin/env node
// Adaptateur de reference : un fichier texte ou markdown, decoupe en segments
// par paragraphe (ligne vide). Il sert de modele : un adaptateur ne fait que
// traduire une source reelle vers le contrat PrismText (extract) et reverser
// un result dans la source (preview, apply). Aucune logique de transformation.
//
//   adapter.mjs extract <fichier> <input.json>
//   adapter.mjs preview <result.json> <fichier>   -> ecrit <fichier>.prismtext-<variante>, affiche son chemin
//   adapter.mjs apply   <result.json> <fichier>   -> reecrit <fichier> en place
//
// Les titres markdown (#), blocs de code et lignes de tableau sont geles.

import { readFileSync, writeFileSync } from 'node:fs';

const [cmd, a, b] = process.argv.slice(2);

function segments(text) {
  return text.split(/\n{2,}/).map((block, i) => {
    const frozen = /^(#|```|\||<!--)/.test(block.trim());
    return { id: `p${String(i + 1).padStart(3, '0')}`, text: block, ...(frozen ? { constraints: { freeze: true } } : {}) };
  });
}

function rebuild(result, source) {
  const texts = new Map(result.segments.map((s) => [s.id, s.text]));
  const segs = segments(readFileSync(source, 'utf8'));
  const missing = segs.filter((s) => !texts.has(s.id)).map((s) => s.id);
  if (missing.length) throw new Error(`segments absents du result : ${missing.join(', ')}`);
  const trailing = readFileSync(source, 'utf8').endsWith('\n') ? '\n' : '';
  return segs.map((s) => texts.get(s.id)).join('\n\n').replace(/\n*$/, '') + trailing;
}

try {
  if (cmd === 'extract' && a && b) {
    const input = {
      prismtext: '1',
      source: { adapter: 'reference-files', ref: a },
      context: {},
      protect: [
        { name: 'lien-md', regex: '\\[[^\\]]+\\]\\((?<keep>[^)]+)\\)', note: 'ancre libre, URL fixe' },
        { name: 'code', regex: '`[^`]+`' },
      ],
      segments: segments(readFileSync(a, 'utf8')),
    };
    writeFileSync(b, JSON.stringify(input, null, 2) + '\n');
    console.log(`[OK] ${input.segments.length} segments -> ${b}`);
  } else if (cmd === 'preview' && a && b) {
    const result = JSON.parse(readFileSync(a, 'utf8'));
    const out = `${b}.prismtext-${result.variant}`;
    writeFileSync(out, rebuild(result, b));
    console.log(out);
  } else if (cmd === 'apply' && a && b) {
    writeFileSync(b, rebuild(JSON.parse(readFileSync(a, 'utf8')), b));
    console.log(`[OK] ${b} reecrit`);
  } else {
    console.error('usage : adapter.mjs extract <fichier> <input.json> | preview <result.json> <fichier> | apply <result.json> <fichier>');
    process.exit(2);
  }
} catch (e) {
  console.error(`[ERROR] ${e.message}`);
  process.exit(1);
}
