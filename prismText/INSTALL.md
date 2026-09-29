# Installer / mettre à jour PrismText — procédure pour l'agent qui installe

À coller dans l'agent de la machine cible : « Installe (ou mets à jour) PrismText en suivant
`prismText/INSTALL.md` ». Relancer la même procédure = mise à jour (tout est idempotent).

## 1. Prérequis

- Node.js ≥ 18 (`node --version`). Sinon, s'arrêter et le dire : ne pas installer Node sans accord.
- Claude Code (ou un agent capable de lancer des sous-agents isolés) : le skill `prismtext` confie
  la rédaction et la vérification à des agents qui ne reçoivent qu'un fichier de consigne.
- Le dépôt remia-tooling cloné ; ce dossier est `<depot>/prismText`.

## 2. Poser le moteur et les skills

Depuis ce dossier :

```bash
./install.sh                      # skills dans ~/.claude/skills (toutes les sessions)
./install.sh --project <dossier>  # ou : skills dans <dossier>/.claude/skills (ce projet seulement)
```

L'installeur vérifie Node, lance le selftest (il échoue s'il ne passe pas), pose en liens
symboliques les skills `prismtext` et `prismtext-install` et la CLI `~/.local/bin/prismtext`, et
enregistre l'emplacement du moteur dans `~/.config/prismtext/home`. Un `git pull` du dépôt met
donc tout à jour sans réinstaller.

Si `~/.claude/skills/prismtext` existe et n'est pas un lien PrismText, l'installeur s'arrête :
le signaler à l'utilisateur, ne rien écraser. Si `~/.local/bin` n'est pas dans le PATH, les
skills utilisent le chemin enregistré ; proposer d'ajouter la ligne à `~/.profile` (pas
`.bashrc`), avec accord.

Retirer : `./install.sh --uninstall`.

## 3. Vérifier

```bash
prismtext describe | head -1      # PrismText <version> (contrat 1)
npm test                          # depuis ce dossier : 0 fail
```

Les skills sont lus au démarrage d'une session : ils sont disponibles à la session suivante.

## 4. Brancher un projet

Dans le projet où vivent les textes, demander à l'agent : « branche PrismText sur ce projet ».
Le skill `prismtext-install` mène la suite :

1. il lit le projet (où vit le texte, comment il est publié, quels tokens ne doivent pas bouger)
   et fait l'inventaire du texte visible codé en dur ;
2. il pose ses questions par AskUserQuestion, chacune avec une option recommandée : sources,
   prévisualisation, ce que déclenche une validation, protections, contexte (public, voix) ;
3. il écrit les adaptateurs dans `.prismtext/adapters/` et `.prismtext/config.json` ;
4. il prouve l'aller-retour sans perte (variante identité : le fichier ne bouge pas d'un octet) ;
5. il décrit l'outil dans le CLAUDE.md du projet.

Toute action sortante (push, publication, envoi) reste derrière un accord explicite.

## 5. Mettre à jour

`git pull` dans le dépôt, puis `./install.sh` (idempotent) pour relancer le selftest. Si le
numéro de contrat change (`"prismtext": "1"` dans `contract/`), les adaptateurs des projets
branchés sont à revoir : `prismtext validate` sur un input extrait le dit.
