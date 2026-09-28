# Installer le skill `simple` — procédure pour l'agent qui installe

À coller dans l'agent (Claude Code ou équivalent) de la machine cible : « Installe le skill
`simple` en suivant `skills/simple/INSTALL.md` ». L'agent fait tout, sauf écrire le profil sans accord.

## 1. Copier

Copier `SKILL.md` et `INSTALL.md` dans le dossier des skills utilisateur, par défaut
`~/.claude/skills/simple/` (un skill de projet va dans `<projet>/.claude/skills/simple/`).
Ne rien écrire ailleurs : ni CLAUDE.md, ni fichier de projet.

## 2. Déduire le profil (lecture seule)

**Niveau de compétence** — déduit des conversations précédentes avec cet utilisateur :
mémoire de l'agent (ex. `~/.claude/projects/*/memory/`), historiques de sessions disponibles,
CLAUDE.md. Relever des indices observables, pas des impressions : les termes qu'il emploie
seul, ceux qu'il a demandé d'expliquer, ses reformulations d'incompréhension, ce qu'il fait
lui-même (lire du code, écrire du SQL, configurer un serveur). Rendre UNE phrase de niveau
+ la liste courte des termes à définir d'office.

**Stack présente** — déduite du projet courant, pas supposée : fichiers de dépendances
(`composer.json`, `package.json`, `requirements.txt`, `Gemfile`, `go.mod`…), structure des
dossiers, fichiers de configuration, services en cours (`systemctl`, `docker ps`) si
accessibles. Nommer les briques et leurs versions quand elles sont lisibles.

**Ses couches, avec ses mots** — les catégories dans lesquelles il range un problème
(« c'est du template ? de la base ? de la config ? »), reprises de ses propres formulations.

Ne rien inventer : un champ sans indice reste « non renseigné » et le dit.

## 3. Proposer, puis écrire seulement avec accord

Montrer à l'utilisateur le bloc rempli, avec pour chaque ligne **l'indice qui la justifie**
(ex. « a demandé ce qu'est un override le 12/03 »). Lui demander : valider tel quel, corriger,
ou laisser vide. Puis remplacer dans le `SKILL.md` installé le contenu compris entre
`<!-- PROFIL:DEBUT` et `<!-- PROFIL:FIN -->` — et rien d'autre.

## 4. Confidentialité

Le profil décrit une personne : il reste dans la copie **installée** du skill, sur la machine
de l'utilisateur. Ne jamais le commiter dans ce dépôt, ni y mettre de nom, d'adresse, de
secret ou d'identifiant de projet sensible.

## 5. Vérifier

Le skill apparaît dans la liste des skills de la session suivante ; `/simple` sur une
explication récente applique le profil (niveau → termes définis, stack → cas réel, couches →
vocabulaire).
