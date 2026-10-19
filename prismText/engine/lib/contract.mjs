// Contrat PrismText : validation des documents d'entree (input) et de sortie
// (result). Zero dependance : les schemas JSON de contract/ documentent le
// format pour les outils externes ; ce module applique les memes regles.

export const CONTRACT_VERSION = '1';

function err(errors, path, msg) {
  errors.push(`${path} : ${msg}`);
}

function isObj(v) {
  return v !== null && typeof v === 'object' && !Array.isArray(v);
}

// forbid (termes interdits) et maxOccurrences (mot -> nombre maximal) valent
// au niveau du contexte (tous les segments) ou d'un segment (constraints).
function validateLexical(errors, path, o) {
  if (o.forbid !== undefined && !(Array.isArray(o.forbid) && o.forbid.every((f) => typeof f === 'string' && f))) {
    err(errors, `${path}.forbid`, 'tableau de chaines non vides attendu');
  }
  if (o.maxOccurrences !== undefined && !(isObj(o.maxOccurrences) && Object.values(o.maxOccurrences).every((n) => Number.isInteger(n) && n >= 0))) {
    err(errors, `${path}.maxOccurrences`, 'objet { mot: entier >= 0 } attendu');
  }
  if (o.forbidPatterns !== undefined) {
    if (!Array.isArray(o.forbidPatterns)) err(errors, `${path}.forbidPatterns`, 'tableau de regex attendu');
    else o.forbidPatterns.forEach((p, i) => { try { new RegExp(p, 'giu'); } catch (e) { err(errors, `${path}.forbidPatterns.${i}`, e.message); } });
  }
}

// References : matiere annexe a la source (nom, specs, lecture de photo...),
// chacune avec un rang de confiance (1 = le plus sur). `text` ou `facts`
// (cles -> valeurs texte). `numeric: false` : ses chiffres ne sourcent rien.
// `citable: false` : connue du redacteur et du verificateur, mais aucune
// phrase ne peut s y rattacher ; `uncitable` : memes effet, cle par cle.
// `exclusive` : valeurs mutuellement exclusives (tailles, coloris...) dont
// une seule peut figurer dans la cible.
function validateReferences(errors, refs) {
  if (!Array.isArray(refs)) return err(errors, 'references', 'tableau attendu');
  const seen = new Set();
  refs.forEach((r, i) => {
    const p = `references.${i}`;
    if (!isObj(r)) return err(errors, p, 'objet attendu');
    if (typeof r.id !== 'string' || !/^[a-zA-Z0-9_-]+$/.test(r.id)) err(errors, `${p}.id`, 'identifiant attendu (lettres, chiffres, - _)');
    else if (seen.has(r.id)) err(errors, `${p}.id`, `identifiant en double "${r.id}"`);
    else seen.add(r.id);
    if (!Number.isInteger(r.trust) || r.trust < 1) err(errors, `${p}.trust`, 'entier >= 1 attendu (1 = le plus sur)');
    const hasText = typeof r.text === 'string';
    const hasFacts = isObj(r.facts) && Object.values(r.facts).every((v) => typeof v === 'string');
    if (!hasText && !hasFacts) err(errors, p, '"text" (chaine) ou "facts" (objet cle -> chaine) attendu');
    for (const k of ['numeric', 'citable']) if (r[k] !== undefined && typeof r[k] !== 'boolean') err(errors, `${p}.${k}`, 'booleen attendu');
    for (const k of ['uncitable', 'exclusive']) if (r[k] !== undefined && !(Array.isArray(r[k]) && r[k].every((v) => typeof v === 'string' && v))) err(errors, `${p}.${k}`, 'tableau de chaines attendu');
  });
}

export function validateInput(doc) {
  const errors = [];
  if (!isObj(doc)) return ['(racine) : objet attendu'];
  if (doc.prismtext !== CONTRACT_VERSION) err(errors, 'prismtext', `version de contrat "${CONTRACT_VERSION}" attendue`);
  if (!isObj(doc.source)) err(errors, 'source', 'objet attendu (adapter, ref)');
  else {
    if (typeof doc.source.adapter !== 'string') err(errors, 'source.adapter', 'chaine attendue');
    if (typeof doc.source.ref !== 'string') err(errors, 'source.ref', 'chaine attendue');
  }
  if (doc.context !== undefined && !isObj(doc.context)) err(errors, 'context', 'objet attendu');
  else if (doc.context) validateLexical(errors, 'context', doc.context);
  if (doc.references !== undefined) validateReferences(errors, doc.references);
  if (doc.protect !== undefined) {
    if (!Array.isArray(doc.protect)) err(errors, 'protect', 'tableau attendu');
    else doc.protect.forEach((r, i) => {
      if (!isObj(r) || typeof r.name !== 'string' || typeof r.regex !== 'string') {
        err(errors, `protect.${i}`, 'objet { name, regex } attendu');
        return;
      }
      try { new RegExp(r.regex, 'gu'); } catch (e) { err(errors, `protect.${i}.regex`, e.message); }
    });
  }
  if (!Array.isArray(doc.segments) || doc.segments.length === 0) {
    err(errors, 'segments', 'tableau non vide attendu');
  } else {
    const seen = new Set();
    doc.segments.forEach((s, i) => {
      const p = `segments.${i}`;
      if (!isObj(s)) return err(errors, p, 'objet attendu');
      if (typeof s.id !== 'string' || !s.id) err(errors, `${p}.id`, 'chaine non vide attendue');
      else if (seen.has(s.id)) err(errors, `${p}.id`, `identifiant en double "${s.id}"`);
      else seen.add(s.id);
      if (typeof s.text !== 'string') err(errors, `${p}.text`, 'chaine attendue');
      if (s.constraints !== undefined && !isObj(s.constraints)) err(errors, `${p}.constraints`, 'objet attendu');
      else if (s.constraints) validateLexical(errors, `${p}.constraints`, s.constraints);
    });
  }
  return errors;
}

export function validateResult(doc) {
  const errors = [];
  if (!isObj(doc)) return ['(racine) : objet attendu'];
  if (doc.prismtext !== CONTRACT_VERSION) err(errors, 'prismtext', `version de contrat "${CONTRACT_VERSION}" attendue`);
  if (!isObj(doc.prism) || typeof doc.prism.id !== 'string' || typeof doc.prism.version !== 'string' || typeof doc.prism.sha256 !== 'string') {
    err(errors, 'prism', 'objet { id, version, sha256 } attendu (tampon du prisme)');
  }
  if (typeof doc.variant !== 'string' || !doc.variant) err(errors, 'variant', 'chaine non vide attendue');
  if (!Array.isArray(doc.segments)) err(errors, 'segments', 'tableau attendu');
  else doc.segments.forEach((s, i) => {
    if (!isObj(s) || typeof s.id !== 'string' || typeof s.text !== 'string') err(errors, `segments.${i}`, 'objet { id, text } attendu');
  });
  if (!Array.isArray(doc.concepts)) err(errors, 'concepts', 'tableau attendu (carte des concepts source -> cible)');
  else doc.concepts.forEach((c, i) => {
    if (!isObj(c) || typeof c.segment !== 'string' || typeof c.concept !== 'string') {
      err(errors, `concepts.${i}`, 'objet { segment, concept, cible } attendu');
    } else if (c.cible !== null && typeof c.cible !== 'string') {
      err(errors, `concepts.${i}.cible`, 'chaine (citation exacte de la cible) ou null attendu');
    }
  });
  if (doc.ajouts !== undefined && !Array.isArray(doc.ajouts)) err(errors, 'ajouts', 'tableau attendu');
  else (doc.ajouts || []).forEach((a, i) => {
    if (!isObj(a) || typeof a.segment !== 'string') err(errors, `ajouts.${i}`, 'objet { segment, texte, nature? } attendu');
    else if (a.nature !== undefined && !['enjolivement', 'fait'].includes(a.nature)) err(errors, `ajouts.${i}.nature`, '"enjolivement" ou "fait" attendu');
  });
  if (doc.inverse !== undefined) errors.push(...validateInverse(doc.inverse, 'inverse'));
  return errors;
}

// Passe inverse : cible -> source. Produite de preference par un verificateur
// qui n'a pas ecrit la variante (commande `inverse`).
export function validateInverse(inv, path = 'inverse') {
  const errors = [];
  if (!Array.isArray(inv)) return [`${path} : tableau attendu (carte cible -> source)`];
  inv.forEach((e, i) => {
    if (!isObj(e) || typeof e.segment !== 'string' || typeof e.cible !== 'string') {
      err(errors, `${path}.${i}`, 'objet { segment, cible, source } attendu');
    } else if (e.source !== null && typeof e.source !== 'string') {
      err(errors, `${path}.${i}.source`, 'chaine (citation exacte de la source) ou null attendu');
    } else if (e.probleme !== undefined && !(typeof e.probleme === 'string' && /^[a-z0-9-]+$/.test(e.probleme))) {
      err(errors, `${path}.${i}.probleme`, 'code en minuscules-tirets attendu (regle du prisme violee)');
    }
  });
  return errors;
}
