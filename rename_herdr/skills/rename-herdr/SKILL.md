---
name: rename-herdr
description: >
  Faire suivre le libellé d'onglet herdr au /rename d'une session Claude Code. Déclenche sur
  "l'onglet herdr ne suit pas le rename", "renomme l'onglet quand je renomme la session",
  "installe rename_herdr", "le rename ne renomme plus l'onglet", ou toute demande de lier le
  nom d'une session Claude Code à un pane, onglet ou titre herdr. Contient de quoi installer
  depuis le dépôt remia-tooling, diagnostiquer, et reconstruire l'outil sans le dépôt.
---

# rename-herdr

Objectif : quand l'utilisateur tape `/rename foo` dans Claude Code, l'onglet herdr qui héberge
cette session s'appelle `foo` dans la seconde. Rien d'autre ne bouge.

Avec le dépôt sur Linux : §1 puis §3. Sur une autre plateforme, ou sans le dépôt : §2, qui renvoie
à `TECHNIQUE.md`, le document agnostique dont ce dossier est l'implémentation Linux.

## 1. Installer depuis le dépôt (cas normal)

```bash
git clone git@github.com:remmmi/remia-tooling.git   # ou mise à jour d'un clone existant
cd remia-tooling/rename_herdr && ./install.sh && ./selftest.sh   # attendu : "0 KO"
```

`install.sh` est idempotent (relancer = mettre à jour). Il pose `~/.local/bin/herdr-session-name-sync`
et `~/.config/systemd/user/rename-herdr.{path,service}`, active l'unité, fait un premier passage.
Puis demander à l'utilisateur un `/rename` dans une session ouverte sous herdr : l'onglet doit suivre.
Détails de la procédure et des choix à lui soumettre : `INSTALL.md` à côté de ce fichier.

## 2. Reconstruire ailleurs (macOS, Windows, Linux sans systemd)

Tout le savoir indépendant de l'OS est dans `TECHNIQUE.md` (à la racine de `rename_herdr/`, ou
sur `github.com/remmmi/remia-tooling`) : le signal (`~/.claude/sessions/<pid>.json`, pas de hook),
l'appariement (`herdr agent list`), l'action (`herdr tab rename`, une fois par nouveau nom), et une
table des déclencheurs par plateforme plus une variante portable par hook `UserPromptSubmit`.
Lire ce fichier en entier avant d'écrire une ligne ; l'implémentation de ce dossier est la référence
Linux, pas un modèle à copier tel quel (test de pid POSIX, unités systemd).

Résumé pour ne pas se tromper d'approche :

| Situation | Faire |
|---|---|
| Linux avec systemd utilisateur | §1, c'est le cas de référence |
| autre OS, effet immédiat voulu | `TECHNIQUE.md` § « déclencheur B » (launchd, FileSystemWatcher, watchexec) + le script porté |
| autre OS, « au prochain message » suffit | `TECHNIQUE.md` § « déclencheur A » : le script en hook `UserPromptSubmit`, zéro service |
| Windows | **ne pas** utiliser `os.kill(pid, 0)` pour tester un pid : ça tue le processus |

## 3. Diagnostiquer « l'onglet ne suit plus »

Dans l'ordre, s'arrêter au premier `[!!]` :

```bash
~/.local/bin/herdr-session-name-sync --dry-run --verbose   # qui serait renommé, et pourquoi pas
./install.sh --check                                        # fichiers, unité, herdr joignable
```

Lectures : « pas de pane herdr pour cette session » = intégration herdr/claude absente (TECHNIQUE.md, appariement) ou
session lancée hors herdr ; « déjà appliqué » alors que l'onglet a un autre nom = renommage
manuel après le `/rename`, comportement voulu (TECHNIQUE.md, action), `--reset` si l'utilisateur veut réappliquer ;
unité inactive = `systemctl --user enable --now rename-herdr.path` ou problème de linger (TECHNIQUE.md, déclencheur B).
