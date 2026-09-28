# Installer / mettre à jour le skill `simple` — procédure pour l'agent qui installe

*(English: same steps — use `en/SKILL.md` and its `PROFILE:START` / `PROFILE:END` markers.)*

À coller dans l'agent (Claude Code ou équivalent) de la machine cible : « Installe (ou mets à
jour) le skill `simple` en suivant `skills/simple/INSTALL.md` ». L'agent fait tout, sauf écrire
le profil sans accord.

## 1. Choisir la langue

Langue dans laquelle l'utilisateur écrit à l'agent (conversations précédentes, CLAUDE.md) :
français → `SKILL.md` ; sinon → `en/SKILL.md`. En cas de doute, demander.

## 2. Copier — sans perdre ce qui est déjà là

Cible par défaut : `~/.claude/skills/simple/` (skill de projet : `<projet>/.claude/skills/simple/`).
Ne rien écrire ailleurs : ni CLAUDE.md, ni fichier de projet.

**Mise à jour** (un `SKILL.md` existe déjà à la cible) :
1. extraire le bloc entre `<!-- PROFIL:DEBUT` et `<!-- PROFIL:FIN -->` (ou `PROFILE:START` /
   `PROFILE:END`) de la copie installée ;
2. copier la nouvelle version ;
3. réinjecter le bloc extrait à la place du bloc vide — en ajoutant les lignes que la nouvelle
   version aurait introduites (ex. « Termes à définir d'office »), laissées vides ;
4. ne jamais toucher à `journal.md`.

Copier aussi `INSTALL.md` (le skill y renvoie tant que le profil est vide).

## 3. Déduire le profil (lecture seule) — installation neuve, ou profil encore vide

**Niveau de compétence** — déduit des conversations précédentes avec cet utilisateur :
mémoire de l'agent (ex. `~/.claude/projects/*/memory/`), historiques de sessions disponibles,
CLAUDE.md. Relever des indices observables, pas des impressions : les termes qu'il emploie
seul, ceux qu'il a demandé d'expliquer, ses reformulations d'incompréhension, ce qu'il fait
lui-même (lire du code, écrire du SQL, configurer un serveur). Rendre UNE phrase de niveau.

**Termes à définir d'office** — ceux qu'il a déjà demandé d'expliquer, ou qu'il n'emploie jamais
alors que la conversation les impose.

**Stack présente** — déduite du projet courant, pas supposée : fichiers de dépendances
(`composer.json`, `package.json`, `requirements.txt`, `Gemfile`, `go.mod`…), structure des
dossiers, fichiers de configuration, services en cours (`systemctl`, `docker ps`) si
accessibles. Nommer les briques et leurs versions quand elles sont lisibles.

**Ses couches, avec ses mots** — les catégories dans lesquelles il range un problème
(« c'est du template ? de la base ? de la config ? »), reprises de ses propres formulations.

Ne rien inventer : un champ sans indice reste « non renseigné » et le dit.

## 4. Proposer, puis écrire seulement avec accord

Montrer à l'utilisateur le bloc rempli, avec pour chaque ligne **l'indice qui la justifie**
(ex. « a demandé ce qu'est un override le 12/03 »). Lui demander : valider tel quel, corriger,
ou laisser vide. Puis remplacer dans le `SKILL.md` installé le contenu du bloc Profil — et rien
d'autre.

## 5. Confidentialité

Le profil et `journal.md` décrivent une personne : ils restent dans la copie **installée**, sur
la machine de l'utilisateur. Ne jamais les commiter dans ce dépôt, ni y mettre de nom, d'adresse,
de secret ou d'identifiant de projet sensible.

## 6. Vérifier

- `selftest.sh` (à côté de ce fichier) : contrôle automatique d'un ré-ancrage, si `claude` est installé.
- Session suivante : le skill apparaît dans la liste ; `/simple` sur une explication récente
  applique le profil.
