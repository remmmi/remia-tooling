# Écrire un prisme

Un prisme est un prompt de réécriture versionné : un fichier markdown avec un frontmatter.

```markdown
---
id: copywriter-b2b
version: 1.0.0
description: Réécriture B2B sobre, concrète et fidèle pour lecteurs non spécialistes
entrees: public, support, objectif, voix, longueur, conserver
---
RÔLE
...
```

- `id` : nom court, stable. `version` : semver, montée à chaque changement de fond.
- `entrees` : les champs de `context` que le prisme utilise ; l'adaptateur et la config du
  projet les fournissent.
- Le corps est la consigne. Le format de sortie n'y figure pas : le contrat l'impose, et la
  consigne générée par `prismtext brief` l'ajoute (segments, carte des concepts, ajouts).

Gabarit : `prisms/_modele.md`. Un prisme partagé vit dans `prisms/` de ce dossier ; un prisme
propre à un projet dans `.prismtext/prisms/` du projet (`prisms_dirs` de la config).

## Empreinte

L'empreinte SHA-256 du fichier entier est tamponnée dans chaque variante. `check --prism` refuse
une variante dont le tampon ne correspond pas au fichier fourni : on sait toujours quel prompt,
dans quelle version exacte, a produit quel texte. Toute modification du fichier, même d'une
virgule, change l'empreinte ; monter la version si le fond change.

## Écrire des règles contrôlables

- Chaque règle doit pouvoir être jugée respectée ou violée sur une phrase donnée.
- Une règle qui demande de retirer quelque chose (fausse modestie, connivence fabriquée) produit
  des retraits : le rédacteur les déclare avec un `motif` qui cite la règle, et l'humain les
  confirme. Numéroter les règles aide à les citer.
- Ne pas demander au prisme d'inventer du contexte : `copywriter-b2b` interdit d'ajouter chiffres,
  témoignages, délais ou résultats absents de la source, et le moteur le vérifie pour les
  chiffres et les noms propres.

## Contrats d'entrée et de sortie : `requires` et `produces`

Un prisme branché entre un générateur d'entrées (adaptateur, harnais, script) et un dispatcheur
de sorties (base, CMS, fichier) porte lui-même ce qu'il attend et ce qu'il rend, dans le
frontmatter :

```
requires: references name(trust 1, text), specs(trust 1, facts), vision(trust 3, facts) ; segments description
produces: description = prose, 2 a 3 paragraphes, <strong> seul balisage ; resume = texte nu, 120 a 155 caracteres
```

- `requires` : références (id, `?` si optionnelle, et en option `trust N`, `text` ou `facts`) et
  segments que l'input doit porter. `prismtext brief` refuse (exit 2) un input incomplet, en nommant le
  manque ; l'amont sait donc exactement quoi produire.
- `produces` : pour chaque segment rendu, le format en clair ; c'est la promesse faite à l'aval.
  Le moteur ne l'interprète pas, le module `check` du prisme le fait respecter.
- `prismtext prism <fichier>` affiche les deux (JSON) ; les deux sont optionnels, un prisme sans
  contrat accepte tout input valide.

### En JSON Schema : `input_schema` et `output_schema`

Pour un générateur d'entrées ou un dispatcheur écrit dans n'importe quel langage, le contrat se
donne aussi en JSON Schema (draft 2020-12), deux fichiers à côté du prisme :

```
input_schema: fiche-produit-lcm.input.schema.json
output_schema: fiche-produit-lcm.output.schema.json
```

- `input_schema` s'applique à `input.json` entier : `brief` le valide et refuse (exit 2) avec le
  chemin JSON de chaque erreur (`$.references : aucun element ne satisfait contains`).
- `output_schema` s'applique à `result.json` entier : `check --prism` le valide et produit
  `contrat-sortie` (erreur) par écart.
- Les deux fichiers entrent dans l'empreinte SHA-256 du prisme.
- Le validateur est dans le moteur, sans dépendance (`engine/lib/schema.mjs`) ; il couvre type,
  const, enum, required, properties, additionalProperties, items, minItems, maxItems, contains,
  minLength, maxLength, pattern, minimum, maximum, allOf, anyOf, not, `$ref` local. Les autres
  mots-clés sont ignorés, pas refusés.
- Un schéma dit la forme (un segment `description`, pas d'autre balise que `<strong>`), pas le
  sens (« 2 à 3 paragraphes », « jamais de variante ») : le sens reste dans les règles du prisme,
  la section `VERIFICATEUR` et le module `check`. `requires` / `produces` restent le raccourci
  lisible ; quand les deux existent, les deux s'appliquent.

## Section `VERIFICATEUR` et module de contrôle

Le corps peut contenir une ligne `VERIFICATEUR` seule : ce qui précède va au rédacteur, ce qui
suit va au vérificateur inverse (`inverse-brief --prism`). On y écrit les règles de jugement que
le moteur ne sait pas vérifier (hiérarchie des références, emballage, imitation de matière), chacune
avec le code que le vérificateur pose dans `probleme` quand elle est violée.

Le frontmatter peut nommer un module de contrôle déterministe : `check: mon-prisme.check.mjs`
(chemin relatif au prisme). Il exporte `check({ input, result })` et rend des issues
`{ level, segment, code, msg }` ; `check --prism` l'exécute après les contrôles du contrat. Le
module entre dans l'empreinte SHA-256 du prisme : le changer change la version.

## Enchaîner des prismes

`config.chains` déclare des suites (`"site": ["copywriter-b2b", "noia"]`). `prismtext chain`
prépare l'input de l'étape suivante à partir d'une variante conforme ; il refuse une variante non
conforme. Les `constraints` des segments ne sont pas reportées : chaque prisme porte ses bornes
(`produces`, `output_schema`, module de contrôle).
