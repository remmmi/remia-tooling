// Validateur JSON Schema minimal, zero dependance : le sous-ensemble dont les
// contrats d'un prisme ont besoin (draft 2020-12). Les mots-cles inconnus
// sont ignores, ce qui laisse les schemas lisibles par d'autres outils.
//
// Supportes : type (et tableaux de types), const, enum, required, properties,
// additionalProperties (false ou schema), items, minItems, maxItems, contains,
// minLength, maxLength, pattern, minimum, maximum, anyOf, allOf, not, $ref
// local (#/$defs/... ou #/definitions/...).

function typeOf(v) {
  if (v === null) return 'null';
  if (Array.isArray(v)) return 'array';
  if (typeof v === 'number') return Number.isInteger(v) ? 'integer' : 'number';
  return typeof v;
}

function matchesType(v, t) {
  const actual = typeOf(v);
  if (t === 'number') return actual === 'number' || actual === 'integer';
  return actual === t;
}

function resolveRef(ref, root) {
  if (!ref.startsWith('#/')) throw new Error(`$ref non supporte : ${ref}`);
  return ref.slice(2).split('/').reduce((o, k) => (o == null ? undefined : o[k.replace(/~1/g, '/').replace(/~0/g, '~')]), root);
}

// Rend la liste des erreurs [{ path, msg }] ; vide = conforme.
export function validateSchema(value, schema, root = schema, path = '$', errors = []) {
  if (schema === true || schema === undefined) return errors;
  if (schema === false) { errors.push({ path, msg: 'interdit' }); return errors; }
  if (schema.$ref) return validateSchema(value, resolveRef(schema.$ref, root), root, path, errors);
  const fail = (msg) => errors.push({ path, msg });

  if (schema.type !== undefined) {
    const types = Array.isArray(schema.type) ? schema.type : [schema.type];
    if (!types.some((t) => matchesType(value, t))) { fail(`type ${typeOf(value)}, ${types.join(' | ')} attendu`); return errors; }
  }
  if (schema.const !== undefined && JSON.stringify(value) !== JSON.stringify(schema.const)) fail(`valeur ${JSON.stringify(value)}, ${JSON.stringify(schema.const)} attendu`);
  if (schema.enum && !schema.enum.some((e) => JSON.stringify(e) === JSON.stringify(value))) fail(`valeur ${JSON.stringify(value)} hors de ${JSON.stringify(schema.enum)}`);
  if (schema.allOf) for (const s of schema.allOf) validateSchema(value, s, root, path, errors);
  if (schema.anyOf && !schema.anyOf.some((s) => validateSchema(value, s, root, path, []).length === 0)) fail('aucune branche de anyOf ne convient');
  if (schema.not && validateSchema(value, schema.not, root, path, []).length === 0) fail('interdit par not');

  if (typeof value === 'string') {
    if (schema.minLength !== undefined && value.length < schema.minLength) fail(`${value.length} caracteres < minLength ${schema.minLength}`);
    if (schema.maxLength !== undefined && value.length > schema.maxLength) fail(`${value.length} caracteres > maxLength ${schema.maxLength}`);
    if (schema.pattern !== undefined && !new RegExp(schema.pattern, 'u').test(value)) fail(`ne correspond pas au motif /${schema.pattern}/`);
  }
  if (typeof value === 'number') {
    if (schema.minimum !== undefined && value < schema.minimum) fail(`${value} < minimum ${schema.minimum}`);
    if (schema.maximum !== undefined && value > schema.maximum) fail(`${value} > maximum ${schema.maximum}`);
  }
  if (Array.isArray(value)) {
    if (schema.minItems !== undefined && value.length < schema.minItems) fail(`${value.length} elements < minItems ${schema.minItems}`);
    if (schema.maxItems !== undefined && value.length > schema.maxItems) fail(`${value.length} elements > maxItems ${schema.maxItems}`);
    if (schema.items !== undefined) value.forEach((v, i) => validateSchema(v, schema.items, root, `${path}[${i}]`, errors));
    if (schema.contains !== undefined && !value.some((v) => validateSchema(v, schema.contains, root, path, []).length === 0)) fail('aucun element ne satisfait contains');
  }
  if (value !== null && typeof value === 'object' && !Array.isArray(value)) {
    for (const k of schema.required || []) if (!(k in value)) fail(`propriete "${k}" manquante`);
    const props = schema.properties || {};
    for (const [k, v] of Object.entries(value)) {
      if (k in props) validateSchema(v, props[k], root, `${path}.${k}`, errors);
      else if (schema.additionalProperties === false) errors.push({ path: `${path}.${k}`, msg: 'propriete non prevue' });
      else if (schema.additionalProperties && typeof schema.additionalProperties === 'object') validateSchema(v, schema.additionalProperties, root, `${path}.${k}`, errors);
    }
  }
  return errors;
}

export const formatErrors = (errs) => errs.map((e) => `${e.path} : ${e.msg}`);
