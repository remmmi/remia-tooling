---
name: prismtext-install
description: Installer et brancher PrismText dans un projet (poste ou VPS) - entretien AskUserQuestion, ecriture des adaptateurs I/O propres au projet, config .prismtext/config.json, selftest, description de l'outil dans le CLAUDE.md du projet. Utiliser quand l'utilisateur dit "installe PrismText", "branche PrismText sur ce projet", "ajoute un adaptateur PrismText", ou quand le skill prismtext ne trouve pas de config.
---

# PrismText : installation et branchement

Le moteur est agnostique. Ton travail ici est d'ecrire les **adaptateurs** du projet hote : les petites commandes qui traduisent la source reelle vers le contrat PrismText (`extract`) et reversent une variante choisie (`preview`, `apply`, `verify`). Le moteur ne change pas d'un projet a l'autre.

## 1. Poser le moteur (une fois par machine)

```bash
cat ~/.config/prismtext/home 2>/dev/null || echo "absent"
```

Absent : demande (AskUserQuestion) ou se trouve le depot PrismText, ou clone-le si l'utilisateur donne une URL, puis :

```bash
<depot>/install.sh            # skills dans ~/.claude/skills, CLI dans ~/.local/bin, selftest
```

`install.sh` echoue si Node < 18 ou si le selftest ne passe pas : ne continue pas dans ce cas.

## 2. Comprendre le projet avant de poser des questions

Lis le CLAUDE.md du projet, repere ou vit le texte (fichiers markdown, YAML, JSON, base de donnees, CMS via API), comment il est publie (build, push, deploiement), et quels tokens ne doivent jamais bouger (liens internes, variables de gabarit, shortcodes, balises). Tu dois arriver a l'entretien avec des propositions, pas des questions ouvertes.

## 3. Entretien (AskUserQuestion, 4 questions maximum par appel, 2 appels maximum)

Chaque question porte une option recommandee, deduite de l'etape 2. A couvrir :

1. **Sources** : quels textes PrismText pourra transformer (types de fichiers ou d'objets, comment on les designe).
2. **Preview** : comment l'humain voit une variante avant de l'accepter (fichier a cote, page orpheline non indexee, branche git, brouillon dans le CMS, rapport seul).
3. **Apply** : ce qu'accepter une variante declenche (ecriture en place seulement, ou aussi commit, build, deploiement). Toute action sortante (push, publication, envoi) reste derriere la validation humaine.
4. **Protections** : les tokens a verrouiller (propose les regex trouvees a l'etape 2) et les elements a conserver mot pour mot.
5. **Contexte par defaut** : public, support, objectif, voix (je / nous, tutoiement / vouvoiement).
6. **Prismes** : lesquels activer (liste de `<PRISMTEXT_HOME>/prisms`), chaines a declarer.

## 4. Ecrire les adaptateurs

Dans `.prismtext/adapters/<nom>/`. Pars de `<PRISMTEXT_HOME>/adapters/reference-files/adapter.mjs` : meme interface, meme sobriete. Regles :
- l'unite est l'**item entier** (une page, une fiche, un email), jamais un fragment : un seul input par item ;
- `extract` produit un input valide (`prismtext validate`) ; les segments non editables (titres imposes, balises, metadonnees) sont `freeze`, pas omis ;
- `extract` fusionne le contexte du projet (`adapters.<nom>.context` de la config) dans `input.context` : le pilote n'ouvre jamais un input ;
- `extract` remplit `context.rendu` avec le texte visible de l'item entier tel que le lecteur le voit (page publiee ou construite, gabarit compris, dans l'ordre de lecture) : c'est ce qui permet au redacteur isole de rester coherent avec le texte qu'il ne peut pas modifier ;
- tout texte visible de l'item doit etre soit un segment, soit present dans `context.rendu` : faire l'inventaire du texte code en dur (gabarits, composants, scripts) avant d'ecrire l'adaptateur, et proposer a l'utilisateur de sortir du code celui qui doit pouvoir etre reecrit ;
- les `id` de segments sont stables d'une extraction a l'autre (chemin de cle, numero de paragraphe), sinon `apply` ecrit au mauvais endroit ;
- `apply` refuse un result auquel il manque un segment, et ne touche rien d'autre que les segments ;
- `preview` ne modifie jamais la source ;
- aucune logique de reecriture dans un adaptateur.

Puis `.prismtext/config.json`, conforme a `<PRISMTEXT_HOME>/contract/config.schema.json`, avec `gates.human_validation: true` (`false` seulement pour un flux automatique assume : la decision est alors `decide --auto`, conforme seulement).

## 5. Prouver le branchement

Sur une vraie source du projet :

```bash
PT=prismtext
RUN=$($PT run .prismtext/runs)
<extract> && $PT validate $RUN/input.json
```

Puis fabrique un result identite (chaque segment recopie, aucun concept), et verifie que `apply` sur ce result laisse la source strictement identique (`git diff --exit-code` ou comparaison d'empreintes). C'est le test qui prouve que l'aller-retour ne perd rien. Montre la sortie a l'utilisateur.

## 6. Decrire l'outil au projet

Ajoute au CLAUDE.md du projet une section courte :

```markdown
## PrismText

Transformation de textes par prompts versionnes, sous controle de bijection.
Config : `.prismtext/config.json` (adaptateurs : <liste>). Prismes projet :
`.prismtext/prisms/`. Trace de chaque run : `.prismtext/runs/`.
Lancer : skill `prismtext` ("passe le prompt X sur la page Y").
Rien ne s'applique sans validation humaine.
```

Ajoute `.prismtext/runs/` au `.gitignore` si l'utilisateur ne veut pas versionner la trace d'audit (question de l'etape 3 si doute).
