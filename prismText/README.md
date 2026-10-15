# prismText — réécrire un texte en place sans lui faire dire autre chose

PrismText fait passer un texte existant (page web, fiche produit, email, doc) par un prompt de
réécriture versionné, appelé **prisme**, et vérifie que la nouvelle version dit la même chose que
l'ancienne avant qu'un humain ne la voie. Une page seule ou tout un site en lot. Rien ne s'applique
sans validation humaine.

```
$ prismtext check .prismtext/runs/lot-essai/src-contenu-pages-methode --prism prisms/copywriter-b2b.md
[WARN] etapes.2.texte : ajout-sans-source : "et je corrige ce qui coince." sans equivalent dans la source (declare)
[OK] 0 erreur(s), 1 alerte(s)
```

## Ce que contient ce dossier

| Chemin | Rôle |
|---|---|
| `engine/` | le moteur : CLI `prismtext`, Node ≥ 18, sans dépendance, sans LLM ni réseau |
| `contract/` | schémas JSON : `input` (produit par un adaptateur), `result` (une variante), `config` (projet hôte) |
| `prisms/` | prismes livrés (`copywriter-b2b`) et gabarit d'un nouveau prisme (`_modele.md`) |
| `adapters/reference-files/` | adaptateur de référence : un fichier texte ou markdown, un segment par paragraphe |
| `skills/prismtext/` | skill de pilotage : une page ou un lot, de l'extraction à la publication |
| `skills/prismtext-install/` | skill de branchement d'un projet : entretien, adaptateurs, preuve d'aller-retour |
| `install.sh` | pose les deux skills et la CLI (liens vers ce dossier), vérifie Node, lance le selftest |
| `INSTALL.md` | procédure pour l'agent qui installe sur une nouvelle machine |
| `docs/` | références : le contrat, écrire un adaptateur, écrire un prisme |
| `tests/` | suite `node:test` et cas réel (une page réécrite, une variante cassée) |
| `CLAUDE.md` | ce qu'un agent doit savoir en arrivant dans ce dossier |
| `AGENTS.md` | renvoi vers `CLAUDE.md` pour les agents qui lisent `AGENTS.md` |
| `package.json` | déclare la CLI `prismtext` (Node ≥ 18) et les scripts `test` et `selftest` ; aucune dépendance |
| `.gitignore` | écarte `node_modules/` et les traces d'exécution `.prismtext/runs/` |

## Ce qui est vérifié

| Contrôle | Bloquant |
|---|---|
| Chaque segment source a son segment cible, et inversement | oui |
| Segments gelés recopiés à l'identique | oui |
| Liens, variables, tokens protégés identiques (l'ancre d'un lien peut changer, pas sa cible) | oui |
| Aucun chiffre absent de la source | oui |
| Chaque idée de la source retrouvée par une citation exacte de la cible | oui |
| Chaque phrase de la cible rattachée à sa source par un vérificateur qui ne l'a pas écrite | oui |
| Une idée retirée par le prisme n'est jamais réintroduite par une correction | oui |
| Idée retirée avec un motif tiré du prisme | non, présentée à l'humain |
| Ajout d'idée déclaré, nom propre nouveau, écart de longueur | non, présenté à l'humain |

## Comment ça tourne

Trois rôles, trois contextes séparés :

- le **pilote** (la conversation qui orchestre) ne lit jamais un texte à transformer : il lance des
  commandes et lit des verdicts courts ;
- un **rédacteur** isolé par page reçoit un seul fichier de consigne autonome : le prisme, le
  contexte du projet, la page entière telle que le visiteur la lit, tous les segments de la page et
  le chemin du fichier à écrire. Il écrit toute la page d'un coup : la cohérence de la page ne
  dépend pas du découpage en segments ;
- un **vérificateur** isolé, distinct du rédacteur, ne voit que la source et la cible, jamais la
  carte du rédacteur, et rattache chaque phrase de la cible à sa source.

```
source --[adaptateur: extract]--> input.json (segments + page rendue + contexte projet)
input + prisme --[brief]--> consigne --[rédacteur isolé]--> result-a.json
input + result --[inverse-brief]--> consigne --[vérificateur isolé]--> inverse-a.json
dossier de run --[check]--> en échec : brief écrit une consigne de correction, version archivée, on reprend
dossier de run --[report, lot-report]--> rapport --[humain: decide]--> choix
variante choisie --[adaptateur: preview, apply, verify]--> source ; after_batch (commit, tag) ; publish sur accord
```

Chaque page a son dossier de run : input, consignes, versions successives de la variante, cartes
inverses, contrôles, décision. C'est la trace d'audit, et `lot-status` s'en sert pour reprendre un
lot interrompu. `prismtext describe` liste les commandes et les codes de sortie (0 conforme,
1 contenu non conforme, 2 usage ou contrat invalide).

## Installer

Dire à l'agent de la machine cible : « installe PrismText en suivant `prismText/INSTALL.md` ».
À la main : `./install.sh`, puis dans le projet où vivent les textes, demander à l'agent
« branche PrismText sur ce projet ».

## Utiliser

Dans un projet branché, en langage naturel : « prisme copywriter-b2b sur la page contact »,
« trois variantes de la fiche produit X », « prisme copywriter-b2b sur toutes les pages en lot
"copywriter-1", sauf site-web ». Le skill `prismtext` pilote tout ; il pose ses questions par
AskUserQuestion et s'arrête avant toute action sortante.

## Pièges

- **Le pilote qui rédige lui-même** pollue la page avec sa conversation de gestion. Toujours un
  agent isolé, lancé sur la seule consigne, jamais un fork du pilote.
- **Un rédacteur ne se vérifie pas** : il déclare rarement ses propres ajouts. Le vérificateur
  distinct les trouve (cas réel : « et je corrige ce qui coince. », ajout non déclaré).
- **Une correction qui « répare » en remettant ce que le prisme a retiré** annule le prisme :
  `check` compare à la version précédente et bloque (`retrait-annule`). Rétablir est une décision
  humaine.
- **Texte codé en dur hors des fichiers de contenu** : le rédacteur ne le voit que s'il est dans
  la page rendue (`context.rendu`), et ne peut pas le réécrire. Faire l'inventaire avant d'écrire
  l'adaptateur (`docs/adaptateurs.md`).
- **Réécrire tout un fichier structuré** (YAML, JSON) pour changer un champ change aussi sa mise
  en forme ailleurs : l'adaptateur remplace les seuls champs modifiés, puis relit et compare.
- **Page rendue périmée** : si le build est plus ancien que la source, le rédacteur travaille sur
  un contexte faux. L'adaptateur doit refuser d'extraire dans ce cas.
