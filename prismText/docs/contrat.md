# Le contrat PrismText (version 1)

Le moteur ne connaît que des documents JSON rangés dans des dossiers de run. Les schémas
formels sont dans `contract/` ; ce document dit ce que chaque champ garantit.

## input.json — produit par l'adaptateur (`extract`)

Un input = **un item entier** (une page, une fiche, un email), jamais un fragment.

```json
{
  "prismtext": "1",
  "source": { "adapter": "pages-astro", "ref": "src/contenu/pages/methode.yaml" },
  "context": {
    "public": "...", "support": "site", "objectif": "obtenir un contact", "voix": "je, vouvoiement",
    "conserver": ["PrestaShop"],
    "lengthTolerance": 0.35,
    "rendu": "texte visible de la page entière, gabarit compris, dans l'ordre de lecture"
  },
  "protect": [
    { "name": "lien", "regex": "\\[[^\\]]+\\]\\((?<keep>[^)\\s]+)\\)", "note": "ancre libre, cible fixe" }
  ],
  "segments": [
    { "id": "h1", "text": "...", "constraints": { "freeze": true } },
    { "id": "etapes.2.texte", "text": "..." }
  ]
}
```

- `segments[].id` : stable d'une extraction à l'autre (chemin de clé, numéro de paragraphe) ;
  c'est lui qui dit à `apply` où écrire.
- `constraints.freeze` : segment non modifiable (titre imposé, SEO, libellé). Il reste dans
  l'input pour le sens ; le rédacteur le recopie.
- `constraints.maxChars`, `constraints.lengthTolerance` : limites par segment.
- `protect` : un token protégé doit rester identique, même nombre d'occurrences dans le même
  segment. Un groupe nommé `(?<keep>...)` limite la protection à cette partie (la cible d'un
  lien, pas son ancre).
- `context.conserver` : éléments à garder mot pour mot.
- `context.rendu` : lecture seule, n'entre dans aucun contrôle ; il donne au rédacteur le texte
  qu'il ne peut pas modifier, pour rester cohérent avec la page.
- Contrôles lexicaux, au niveau du contexte (tous les segments) ou d'un segment (`constraints`),
  insensibles à la casse : `forbid` (termes interdits, erreur `terme-interdit`), `forbidPatterns`
  (regex, erreur `motif-interdit`), `maxOccurrences` (`{ "montagne": 1 }`, mot entier, erreur
  `occurrences-max`), `constraints.minChars` (erreur `longueur-min`).

Un prisme peut exiger certaines références et certains segments (`requires` dans son
frontmatter, voir `docs/prismes.md`) : `brief` refuse un input qui ne les porte pas.

### `references` : la matière annexe, par rang de confiance

Un texte se réécrit à partir de sa source, mais une fiche produit s'appuie aussi sur un nom, des
caractéristiques, une lecture de photo. Ce sont des **références** : le rédacteur les reçoit avec
la source, le vérificateur peut y rattacher une phrase de la cible.

```json
"references": [
  { "id": "name",   "trust": 1, "text": "Bahut chêne huilé 3 portes" },
  { "id": "specs",  "trust": 1, "facts": { "dimensions": "153x85x50", "weight": "48 kg" } },
  { "id": "vision", "trust": 3, "facts": { "colors": "brun clair", "branding": "étiquette" },
    "numeric": false, "uncitable": ["branding"] },
  { "id": "capacite", "trust": 1, "facts": { "number_of_persons": "2, 4 et 6 personnes" },
    "exclusive": ["2 personnes", "4 personnes", "6 personnes"] },
  { "id": "prix", "trust": 1, "text": "730 euros", "citable": false, "numeric": false }
]
```

- `trust` : 1 = le plus sûr. Un rang plus petit l'emporte en cas de désaccord ; la règle qui en
  tire les conséquences vit dans le prisme (section `VERIFICATEUR`), pas dans le moteur.
- `text` ou `facts` (clé -> valeur texte). Une valeur se recopie telle quelle.
- Les chiffres et noms propres d'une référence comptent comme source (`chiffre-invente`,
  `nom-propre-nouveau`), sauf `numeric: false` : ses chiffres ne sourcent rien (une photo ne
  donne pas une dimension).
- `citable: false` (toute la référence) ou `uncitable` (clé par clé) : connue du rédacteur et du
  vérificateur, mais aucune citation ne peut l'invoquer (`reference-non-citable`) ; sert à
  montrer un prix, un emballage, une impression sans qu'ils entrent dans le texte.
- `exclusive` : valeurs mutuellement exclusives (tailles, coloris, capacités) ; une seule peut
  figurer dans la cible, et si une référence texte (le nom de l'article) en porte exactement
  une, c'est celle-là (`hors-perimetre`).
- Citation d'une référence dans la carte inverse : extrait littéral, `ref:<id>` (son texte) ou
  `ref:<id>.<clé>` (un fait).

## result-<v>.json — une variante, écrite par le rédacteur isolé

```json
{
  "prismtext": "1",
  "prism": { "id": "copywriter-b2b", "version": "1.0.0", "sha256": "..." },
  "variant": "a",
  "segments": [{ "id": "etapes.2.texte", "text": "..." }],
  "concepts": [
    { "segment": "chapo", "concept": "prix ferme", "cible": "citation exacte de la cible" },
    { "segment": "preuve", "concept": "il n'est pas parfait", "cible": null, "motif": "règle 2 du prisme" }
  ],
  "ajouts": [{ "segment": "chapo", "texte": "renvoi interne ajouté" }]
}
```

- `prism` : tampon recopié de la consigne ; `check --prism` refuse un tampon qui ne correspond
  pas au fichier du prisme (id, version, SHA-256).
- `concepts` (sens source → cible) : chaque idée de la source pointe une **citation exacte** du
  segment cible. Citation introuvable = erreur (garde-fou contre une carte inventée).
  `cible: null` sans `motif` = idée perdue, erreur ; avec `motif` = retrait voulu, présenté à
  l'humain.
- `ajouts` : idées absentes de la source, déclarées par le rédacteur, avec leur `nature` :
  `enjolivement` (ambiance, usage, tournure : ni chiffre, ni matière, ni norme, ni
  compatibilité), alerte acceptée telle quelle en mode automatique ; `fait`, erreur `ajout-fait`
  dans tous les modes, un fait sans source n'existe pas.

## inverse-<v>.json — écrit par le vérificateur isolé

```json
{ "inverse": [{ "segment": "chapo", "cible": "citation exacte de la cible", "source": "citation exacte de la source" }] }
```

Sens cible → source. Chaque phrase modifiée de la cible doit être couverte (au moins la moitié de
ses caractères) par des citations `cible`. `source: null` = morceau sans équivalent : erreur s'il
n'est pas déclaré dans `ajouts`, alerte sinon. `source` peut citer une référence (voir plus haut).
`probleme: "<code>"` : le vérificateur déclare qu'une règle de la section `VERIFICATEUR` du prisme
est violée ; le contrôle produit une erreur portant ce code, même si le morceau a une source.

## Dossier de run

| Fichier | Écrit par |
|---|---|
| `input.json` | l'adaptateur |
| `brief-<v>.md` | `prismtext brief` (rédaction, ou correction si la variante échoue) |
| `result-<v>.json`, `result-<v>.r<n>.json` | le rédacteur ; les versions précédentes sont archivées par `brief` |
| `inverse-brief-<v>.md` | `prismtext inverse-brief` |
| `inverse-<v>.json`, `inverse-<v>.r<n>.json` | le vérificateur |
| `check-<v>.json` | `prismtext check` |
| `rapport.md` | `prismtext report` |
| `decision.json` | `prismtext decide` (refuse une variante non conforme sans `--force`) ; `--auto` quand `gates.human_validation` est `false` : conforme seulement, jamais forcée, `par: "auto"` |
| `applied.json` | `prismtext applied` (refuse sans décision, ou pour une autre variante) |

Un lot est un dossier `lot-<nom>-<horodatage>/` avec `lot.json` et un dossier de run par item.

## Codes d'erreur des contrôles

| Code | Niveau | Sens |
|---|---|---|
| `segment-perdu`, `segment-invente` | erreur | ids différents entre source et cible |
| `gel-viole` | erreur | segment gelé modifié |
| `token-protege` | erreur | lien, variable ou token protégé différent |
| `chiffre-invente` | erreur | chiffre absent de toute la source |
| `element-a-conserver` | erreur | élément de `context.conserver` retiré |
| `longueur-max`, `longueur-min` | erreur | `maxChars` dépassé, `minChars` non atteint |
| `terme-interdit`, `motif-interdit`, `occurrences-max` | erreur | `forbid`, `forbidPatterns`, `maxOccurrences` |
| `reference-non-citable` | erreur | citation d'une référence `citable: false` ou d'une clé `uncitable` |
| `hors-perimetre` | erreur | plusieurs valeurs `exclusive`, ou une autre que celle du nom |
| `ajout-fait` | erreur | ajout déclaré de nature `fait` |
| `<code du prisme>` | erreur | `probleme` déclaré par le vérificateur, ou issue du module `check` du prisme |
| `concept-perdu` | erreur | idée source sans cible ni motif |
| `citation-introuvable` | erreur | citation `cible` absente du segment cible |
| `passe-inverse-absente` | erreur | pas de carte inverse |
| `ajout-non-declare` | erreur | morceau de cible sans source, non déclaré |
| `phrase-non-couverte` | erreur | phrase modifiée non rattachée par la carte inverse |
| `citation-cible-introuvable`, `citation-source-introuvable` | erreur | citation de la carte inverse inexacte |
| `retrait-annule`, `retrait-disparu` | erreur | une correction a remis ou effacé un retrait voulu par le prisme |
| `tampon-prisme` | erreur | variante produite par un autre prisme que celui fourni |
| `concept-retire` | alerte | retrait avec motif, à confirmer par l'humain |
| `ajout-sans-source`, `ajout-declare` | alerte | ajout déclaré, à accepter ou retirer |
| `chiffre-deplace`, `chiffre-retire`, `nom-propre-nouveau`, `longueur`, `longueur-globale`, `source-autre-segment`, `concepts-non-cartographies` | alerte | à regarder |
