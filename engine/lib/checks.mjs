// Controles de bijection entre un input et un result. Tout est deterministe :
// le LLM produit le texte et declare sa carte des concepts, ce module verifie
// qu'il n'a rien perdu, rien casse et rien invente de verifiable.
//
// Niveaux : "error" bloque (exit 1), "warn" est signale au relecteur humain.

const norm = (s) => s.replace(/\s+/g, ' ').trim();

// Tokens proteges : chaque regle a une regex ; si elle porte un groupe nomme
// "keep", seule cette partie doit etre conservee (ex. la cible d'un lien dont
// on peut reecrire l'ancre) ; sinon le token entier doit l'etre.
export function protectedTokens(text, rules) {
  const out = [];
  for (const r of rules) {
    for (const m of text.matchAll(new RegExp(r.regex, 'gu'))) {
      out.push(`${r.name}:${m.groups?.keep ?? m[0]}`);
    }
  }
  return out.sort();
}

const NUM = /\d+(?:[.,]\d+)?/gu;
const numbers = (t) => (t.match(NUM) || []).map((n) => n.replace(',', '.'));

// Mots a majuscule hors debut de phrase : heuristique de nom propre.
function properNouns(text) {
  const out = new Set();
  for (const sentence of text.split(/(?<=[.!?:])\s+|\n+/u)) {
    const words = sentence.trim().split(/\s+/u).slice(1);
    for (const w of words) {
      const m = w.match(/^[("'\u00ab]*(\p{Lu}[\p{L}\p{M}'-]+)/u);
      if (m) out.add(m[1]);
    }
  }
  return out;
}

export function check(input, result) {
  const issues = [];
  const add = (level, segment, code, msg) => issues.push({ level, segment, code, msg });
  const rules = input.protect || [];
  const src = new Map(input.segments.map((s) => [s.id, s]));
  const dst = new Map(result.segments.map((s) => [s.id, s]));
  const allSource = input.segments.map((s) => s.text).join('\n');
  const keep = (input.context?.conserver || []).map(String);

  for (const id of src.keys()) if (!dst.has(id)) add('error', id, 'segment-perdu', 'segment absent du resultat');
  for (const id of dst.keys()) if (!src.has(id)) add('error', id, 'segment-invente', 'segment absent de la source');

  let srcLen = 0;
  let dstLen = 0;
  for (const [id, s] of src) {
    const d = dst.get(id);
    if (!d) continue;
    const c = s.constraints || {};
    srcLen += s.text.length;
    dstLen += d.text.length;

    if (c.freeze && d.text !== s.text) add('error', id, 'gel-viole', 'segment gele modifie');

    const a = protectedTokens(s.text, rules).join('|');
    const b = protectedTokens(d.text, rules).join('|');
    if (a !== b) add('error', id, 'token-protege', `tokens proteges differents : source [${a}] / cible [${b}]`);

    const srcNums = new Set(numbers(s.text));
    const allNums = new Set(numbers(allSource));
    for (const n of numbers(d.text)) {
      if (!allNums.has(n)) add('error', id, 'chiffre-invente', `chiffre "${n}" absent de toute la source`);
      else if (!srcNums.has(n)) add('warn', id, 'chiffre-deplace', `chiffre "${n}" venu d'un autre segment`);
    }
    const dstNums = new Set(numbers(d.text));
    for (const n of srcNums) if (!dstNums.has(n)) add('warn', id, 'chiffre-retire', `chiffre "${n}" de la source absent de la cible`);

    for (const w of properNouns(d.text)) {
      if (!allSource.includes(w) && !keep.some((k) => k.includes(w))) {
        add('warn', id, 'nom-propre-nouveau', `"${w}" n'apparait pas dans la source`);
      }
    }

    if (c.maxChars && d.text.length > c.maxChars) add('error', id, 'longueur-max', `${d.text.length} caracteres > ${c.maxChars}`);
    const tol = c.lengthTolerance ?? input.context?.lengthTolerance ?? 0.35;
    if (s.text.length >= 40) {
      const ratio = d.text.length / s.text.length;
      if (Math.abs(ratio - 1) > tol) add('warn', id, 'longueur', `ratio ${ratio.toFixed(2)} hors tolerance +/-${tol}`);
    }
    for (const k of keep) {
      if (s.text.includes(k) && !d.text.includes(k)) add('error', id, 'element-a-conserver', `"${k}" retire`);
    }
  }
  if (srcLen && Math.abs(dstLen / srcLen - 1) > 0.2) {
    add('warn', '*', 'longueur-globale', `volume total ${dstLen}/${srcLen} caracteres (ratio ${(dstLen / srcLen).toFixed(2)})`);
  }

  // Carte des concepts : chaque concept source doit pointer une citation
  // exacte de la cible ; une citation introuvable est un mensonge du LLM.
  const covered = new Set();
  for (const c of result.concepts) {
    covered.add(c.segment);
    if (!src.has(c.segment)) { add('error', c.segment, 'concept-segment-inconnu', `concept "${c.concept}" rattache a un segment inconnu`); continue; }
    if (c.cible === null) {
      if (typeof c.motif === 'string' && c.motif.trim()) add('warn', c.segment, 'concept-retire', `concept "${c.concept}" retire, motif : ${c.motif}`);
      else add('error', c.segment, 'concept-perdu', `concept "${c.concept}" sans correspondant dans la cible ni motif de retrait`);
      continue;
    }
    const d = dst.get(c.segment);
    if (d && !norm(d.text).includes(norm(c.cible))) {
      add('error', c.segment, 'citation-introuvable', `citation "${c.cible}" absente du segment cible`);
    }
  }
  for (const [id, s] of src) {
    if (!s.constraints?.freeze && s.text.trim().length >= 40 && !covered.has(id)) {
      add('warn', id, 'concepts-non-cartographies', 'aucun concept declare pour ce segment');
    }
  }
  for (const a of result.ajouts || []) add('warn', a.segment || '*', 'ajout-declare', `ajout declare : ${a.texte || JSON.stringify(a)}`);

  const errors = issues.filter((i) => i.level === 'error').length;
  const warnings = issues.length - errors;
  return { ok: errors === 0, errors, warnings, issues };
}
