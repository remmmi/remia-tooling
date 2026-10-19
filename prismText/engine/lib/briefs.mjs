// Consignes ("briefs") donnees aux agents isoles. Une consigne est autonome :
// l'agent qui la recoit n'a aucun autre contexte (ni la conversation qui
// pilote PrismText, ni les autres sources du lot) et n'ouvre aucun autre
// fichier. Tout ce dont il a besoin y est : le prisme, le contexte, la page
// entiere telle que le visiteur la lit, tous les segments de l'item, le
// contrat de sortie et le chemin du fichier a ecrire.
//
// Trois consignes :
//   - redaction : produire une variante (result) ;
//   - correction : reprendre une variante non conforme, avec ses erreurs ;
//   - verification inverse : rattacher chaque morceau de la cible a sa source,
//     sans voir la carte des concepts du redacteur.

import { stamp } from './prism.mjs';
import { CONTRACT_VERSION } from './contract.mjs';
import { references } from './checks.mjs';

// References (nom, specs, lecture de photo...) par rang de confiance : le
// redacteur s'en sert, le verificateur les cite (ref:<id>.<cle>).
function referencesBlock(input, { forVerifier }) {
  const refs = references(input);
  if (!refs.length) return [];
  const out = ['## References, par rang de confiance (1 = le plus sur)', ''];
  out.push(forVerifier
    ? 'Une citation de source peut etre un extrait litteral d une reference, ou `ref:<id>` (son texte), ou `ref:<id>.<cle>` (un fait). Un rang plus petit l emporte : une phrase appuyee sur une reference de rang N contredite par un rang inferieur a N est fautive. Une cle "non citable" ne source rien.'
    : 'Ce que ces references disent peut entrer dans le texte ; une cle "non citable" ne doit pas y entrer. Un rang plus petit l emporte en cas de desaccord. Une valeur se recopie telle quelle.');
  out.push('');
  for (const r of refs) {
    const flags = [r.numeric ? '' : 'ses chiffres ne sourcent rien', r.citable ? '' : 'non citable : connue, jamais rattachee a une phrase'].filter(Boolean);
    out.push(`### ${r.id} (rang ${r.trust}${flags.length ? ', ' + flags.join(', ') : ''})${forVerifier && r.textCitable ? ` -> ref:${r.id}` : ''}`, '');
    if (r.text !== null) out.push(r.text, '');
    if (r.exclusive.length) out.push(`Valeurs exclusives (une seule vaut pour cet article, celle du nom s il en porte une) : ${r.exclusive.map((v) => `"${v}"`).join(', ')}`, '');
    for (const f of r.facts) out.push(`- ${f.key} : ${f.value}${f.citable ? (forVerifier ? `  -> ref:${r.id}.${f.key}` : '') : '  (non citable)'}`);
    if (r.facts.length) out.push('');
  }
  return out;
}

const CONTEXT_HIDDEN = new Set(['rendu', 'lengthTolerance']);

function frame(out, role) {
  return [
    '## Cadre',
    '',
    `Tu es un agent isole. ${role} Tu n'as pas d'autre contexte que ce document, et tu n'en as pas besoin : n'ouvre aucun autre fichier, ne lance aucune commande.`,
    '',
    `Ecris un seul fichier, \`${out}\`, avec l'outil d'ecriture de fichiers. Il contient uniquement le document JSON decrit en fin de consigne. Reponds ensuite en un mot : fait.`,
    '',
  ];
}

function pageRendue(input) {
  const r = input.context?.rendu;
  if (!r) return [];
  return [
    '## La page entiere, telle que le visiteur la lit (lecture seule)',
    '',
    'Texte extrait de la page publiee, dans l\'ordre de lecture : il inclut le texte fixe du gabarit (navigation, intertitres, libelles) que tu ne peux pas modifier. Sers-t\'en pour que ta reecriture reste coherente avec l\'ensemble : pas de repetition d\'un intertitre voisin, meme vocabulaire que le reste de la page, pas de contradiction.',
    '',
    '```text',
    r.trim(),
    '```',
    '',
  ];
}

function segmentsBlock(input) {
  const out = ['## Segments de la page (tous, dans l\'ordre)', ''];
  out.push('Les segments marques `freeze` sont fixes : recopie-les a l\'identique. Ils restent la pour le sens.');
  out.push('');
  for (const s of input.segments) {
    const c = s.constraints ? ` ${JSON.stringify(s.constraints)}` : '';
    out.push(`### ${s.id}${s.role ? ` (${s.role})` : ''}${c}`, '', s.text, '');
  }
  return out;
}

function contextBlock(input) {
  const ctx = input.context || {};
  const out = ['## Contexte fourni par le projet', ''];
  const keys = Object.keys(ctx).filter((k) => !CONTEXT_HIDDEN.has(k));
  if (!keys.length) out.push('(aucun : s\'appuyer sur le texte source, ne rien inventer)');
  for (const k of keys) out.push(`- ${k} : ${typeof ctx[k] === 'string' ? ctx[k] : JSON.stringify(ctx[k])}`);
  out.push('');
  return out;
}

function contractRules(input) {
  const rules = input.protect || [];
  const ctx = input.context || {};
  const out = ['## Contraintes du contrat (non negociables, verifiees automatiquement)', ''];
  out.push('- Chaque segment source a exactement un segment cible, meme id. Aucun segment ajoute ni retire.');
  out.push('- Un segment "freeze" est recopie a l identique.');
  out.push('- Aucun chiffre absent de la source. Aucun nom propre absent de la source.');
  if (rules.length) {
    out.push('- Tokens proteges (le groupe "keep", ou le token entier, reste identique, meme nombre d occurrences dans le meme segment) :');
    for (const r of rules) out.push(`  - ${r.name} : /${r.regex}/${r.note ? ` (${r.note})` : ''}`);
  }
  if (ctx.conserver?.length) out.push(`- Elements a conserver mot pour mot : ${ctx.conserver.map((c) => `"${c}"`).join(', ')}`);
  if (ctx.forbid?.length) out.push(`- Termes interdits dans tous les segments (quelle que soit la casse) : ${ctx.forbid.map((f) => `"${f}"`).join(', ')}`);
  if (ctx.maxOccurrences && Object.keys(ctx.maxOccurrences).length) out.push(`- Nombre maximal d occurrences par segment : ${Object.entries(ctx.maxOccurrences).map(([w, n]) => `"${w}" ${n}`).join(', ')}`);
  out.push('- Les contraintes propres a un segment (minChars, maxChars, forbid, maxOccurrences) sont affichees a cote de son id.');
  out.push('- Carte des concepts : pour chaque idee de chaque segment source, un objet { segment, concept, cible } ou "cible" est une citation EXACTE (copier-coller) du segment cible qui porte cette idee.');
  out.push('- Idee retiree parce qu une regle du prisme l exige : cible = null et "motif" cite la regle. Sans motif, c est une erreur bloquante. Un humain confirmera chaque retrait.');
  out.push('- Tout ajout d idee absente de la source est declare dans "ajouts" : [{ segment, texte, nature }]. nature = "enjolivement" (ambiance, usage, tournure : aucun chiffre, matiere, norme ni compatibilite) ou "fait" ; un ajout de nature "fait" est une erreur bloquante, un enjolivement est une alerte. Un verificateur independant relira chaque phrase de la cible pour lui trouver sa source : un ajout non declare bloque la variante.');
  out.push('');
  return out;
}

function outputBlock(prism, input, variant) {
  return [
    '## Sortie attendue',
    '',
    '```json',
    JSON.stringify({
      prismtext: CONTRACT_VERSION,
      prism: stamp(prism),
      variant,
      segments: [{ id: input.segments[0].id, text: '...' }],
      concepts: [{ segment: input.segments[0].id, concept: '...', cible: '...' }],
      ajouts: [{ segment: input.segments[0].id, texte: '...', nature: 'enjolivement' }],
    }, null, 2),
    '```',
    '',
    'Le tampon "prism" est a recopier tel quel.',
  ];
}

export function writeBrief({ prism, input, variant, out }) {
  return [
    `# Redaction PrismText : prisme ${prism.id}@${prism.version}, variante "${variant}"`,
    '',
    ...frame(out, 'Tu reecris le texte d une page selon la consigne du prisme ci-dessous.'),
    '## Consigne du prisme',
    '',
    prism.body,
    '',
    ...contextBlock(input),
    ...referencesBlock(input, { forVerifier: false }),
    ...pageRendue(input),
    ...segmentsBlock(input),
    ...contractRules(input),
    ...outputBlock(prism, input, variant),
  ].join('\n');
}

export function fixBrief({ prism, input, previous, issues, out }) {
  const errs = issues.filter((i) => i.level === 'error');
  const warns = issues.filter((i) => i.level !== 'error');
  return [
    `# Correction PrismText : prisme ${prism.id}@${prism.version}, variante "${previous.variant}"`,
    '',
    ...frame(out, 'Tu corriges une variante qui a echoue au controle automatique.'),
    '## Erreurs a corriger',
    '',
    ...errs.map((i) => `- ${i.segment} : ${i.code} : ${i.msg}`),
    '',
    ...(warns.length ? ['Alertes (pour information, ne pas les "corriger" a tout prix) :', '', ...warns.map((i) => `- ${i.segment} : ${i.code} : ${i.msg}`), ''] : []),
    '## Regles de correction',
    '',
    '- Ne touche qu aux segments en erreur ; recopie les autres a l identique.',
    '- concept-perdu : si le retrait est voulu par une regle du prisme, ajoute "motif" et laisse le texte ; si c est un oubli, retablis l idee dans le texte.',
    '- Ne retablis JAMAIS une idee que le prisme a retiree avec un motif pour obtenir un controle vert : c est une decision humaine.',
    '- ajout-non-declare ou phrase-non-couverte : retire l ajout du texte, ou declare-le dans "ajouts".',
    '- citation introuvable : corrige la citation pour qu elle soit un copier-coller exact du texte.',
    '',
    '## Variante a corriger',
    '',
    '```json',
    JSON.stringify({ ...previous, inverse: undefined }, null, 2),
    '```',
    '',
    '## Consigne du prisme (rappel)',
    '',
    prism.body,
    '',
    ...contextBlock(input),
    ...referencesBlock(input, { forVerifier: false }),
    ...pageRendue(input),
    ...segmentsBlock(input),
    ...contractRules(input),
    ...outputBlock(prism, input, previous.variant),
  ].join('\n');
}

export function inverseBrief({ input, result, out, prism = null }) {
  const dst = new Map(result.segments.map((s) => [s.id, s.text]));
  const hasRefs = (input.references || []).length > 0;
  const lines = [
    `# Verification inverse PrismText : variante "${result.variant}" (${result.prism.id}@${result.prism.version})`,
    '',
    ...frame(out, 'Tu n as pas ecrit le texte cible : ton role est de le soupconner.'),
    '## Consigne',
    '',
    `Pour chaque segment ci-dessous, decoupe le texte CIBLE en morceaux (propositions ou phrases) qui couvrent la totalite de la cible, et pour chacun donne la citation EXACTE (copier-coller) du texte SOURCE${hasRefs ? ' ou d une reference' : ''} qui porte la meme idee.`,
    '',
    '- Si un morceau dit quelque chose que la source ne dit pas (engagement, precision, nuance, cause, promesse, interpretation, "je" devenu "nous"...), sa source vaut null. Ne rattache pas un ajout a une source vague pour le faire passer.',
    '- Une reformulation fidele n est pas un ajout.',
    '- "cible" et "source" sont des copier-coller exacts, sans guillemets ajoutes ni ponctuation modifiee.',
    '- Les segments inchanges ou geles sont omis.',
    ...(prism?.verifier ? ['- Si un morceau viole une regle du prisme (section ci-dessous), ajoute "probleme" avec le code que la regle nomme : c est une erreur bloquante, meme si le morceau a une source.'] : []),
    '',
    ...(prism?.verifier ? ['## Regles du prisme pour le verificateur', '', prism.verifier, ''] : []),
    ...referencesBlock(input, { forVerifier: true }),
  ];
  for (const s of input.segments) {
    const d = dst.get(s.id);
    if (s.constraints?.freeze || d === undefined || d === s.text) continue;
    lines.push(`## ${s.id}`, '', '**Source**', '', s.text, '', '**Cible**', '', d, '');
  }
  lines.push('## Sortie attendue', '', '```json');
  const ex = { segment: '<id>', cible: '<citation exacte de la cible>', source: `<citation exacte de la source${hasRefs ? ', ref:<id>.<cle>,' : ''} ou null>` };
  if (prism?.verifier) ex.probleme = '<code d une regle violee, sinon omis>';
  lines.push(JSON.stringify({ inverse: [ex] }, null, 2));
  lines.push('```');
  return lines.join('\n');
}
