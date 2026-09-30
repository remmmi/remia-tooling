# Installer / mettre à jour rename_herdr — procédure pour l'agent qui installe

À coller dans l'agent de la machine cible : « Installe rename_herdr en suivant
`rename_herdr/INSTALL.md` ». Relancer la même procédure = mise à jour (tout est idempotent).

## 1. Prérequis, à vérifier avant de toucher quoi que ce soit

- `herdr agent list` répond du JSON, et `herdr integration status` dit `claude: current`. Sinon
  herdr ne sait pas quelle session occupe quel pane et rien ne pourra être apparié : le dire et
  s'arrêter (l'intégration se pose avec `herdr integration install claude`, avec accord).
- `systemctl --user is-system-running` répond (`running` ou `degraded`). Sinon il n'y a pas de
  session utilisateur systemd : proposer `sudo loginctl enable-linger $USER` (Debian), sinon s'arrêter.
- `python3` présent (Debian : dans l'installation de base).
- `~/.claude/sessions/` existe dès qu'une session Claude Code a tourné. Absent = Claude Code jamais
  lancé par cet utilisateur ; l'unité s'installe quand même, elle attendra le dossier.

## 2. Installer

`./install.sh` (depuis ce dossier). Il pose `~/.local/bin/herdr-session-name-sync`,
`~/.config/systemd/user/rename-herdr.{path,service}`, active l'unité et fait un premier passage
en `--verbose` : les sessions déjà nommées par l'utilisateur (`nameSource: user`) voient leur onglet
renommé immédiatement. Le dire avant de lancer : c'est le seul effet visible de l'installation.

Choix à soumettre seulement si l'utilisateur travaille avec plusieurs panes par onglet :
`--target both` renomme aussi le libellé du pane (défaut : l'onglet seul).

## 3. Vérifier

`./selftest.sh` doit finir sur `0 KO` (un `[skip]` herdr n'est pas un KO). Puis demander à
l'utilisateur un `/rename` dans une session ouverte sous herdr et regarder
`journalctl --user -u rename-herdr.service -n 5` : une ligne `w?:t?? -> <nom>` doit apparaître.

## 4. Skill

Copier `skills/rename-herdr/` dans `~/.claude/skills/` (avec accord). Il sert au diagnostic
(« l'onglet ne suit plus ») et contient de quoi reconstruire l'outil sans ce dépôt.

## 5. Confidentialité

Rien de personnel dans ce dossier : pas de nom de machine, d'utilisateur ni de chemin de projet.
L'état local (`~/.cache/rename-herdr/`) ne contient que des noms de session.
