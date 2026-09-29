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

## Enchaîner des prismes

`config.chains` déclare des suites (`"site": ["copywriter-b2b", "noia"]`). `prismtext chain`
prépare l'input de l'étape suivante à partir d'une variante conforme ; il refuse une variante non
conforme.
