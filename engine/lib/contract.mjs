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
  return errors;
}
