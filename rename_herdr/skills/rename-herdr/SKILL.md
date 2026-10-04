---
name: rename-herdr
description: >
  Faire suivre le libellé d'onglet herdr au /rename d'une session Claude Code. Déclenche sur
  "l'onglet herdr ne suit pas le rename", "renomme l'onglet quand je renomme la session",
  "installe rename_herdr", "le rename ne renomme plus l'onglet", ou toute demande de lier le
  nom d'une session Claude Code à un pane, onglet ou titre herdr. Contient de quoi vérifier la
  mise en place faite par le plugin, diagnostiquer, et reconstruire l'outil sur une autre plateforme.
  Aussi : "rename_herdr est-il à jour", "mets à jour rename_herdr".
version: 1.3.0
---

# rename-herdr

Objectif : quand l'utilisateur tape `/rename foo` dans Claude Code, l'onglet herdr qui héberge
cette session s'appelle `foo` dans la seconde. Rien d'autre ne bouge.

Ce skill vient avec le plugin `rename-herdr` (marketplace `remia-tooling`). Le plugin met l'outil en
place tout seul ; ce skill sert à vérifier (§0, §1), diagnostiquer (§3) et reconstruire ailleurs (§2).
Les fichiers cités (`install.sh`, `INSTALL.md`, `TECHNIQUE.md`, `README.md`) sont à la racine du plugin,
deux dossiers au-dessus de ce fichier.

## 1. Mise en place (faite par le plugin)

Au démarrage de session, le plugin compare sa version et son réglage `target` au témoin
`~/.config/remia-tooling/rename-herdr/installed-version` ; s'ils diffèrent, il lance `install.sh`
(idempotent) : `~/.local/bin/herdr-session-name-sync`, `~/.config/systemd/user/rename-herdr.{path,service}`,
activation, premier passage. Une ligne `[remia-tooling] rename-herdr X.Y.Z mis en place` le signale.

Forcer une remise en place : supprimer le témoin et ouvrir une nouvelle session, ou lancer
`install.sh --target <tab|pane|both>` à la main. Changer la cible : `/plugin` → rename-herdr →
Configure. Prérequis (herdr et son intégration Claude, systemd utilisateur, python3) : `INSTALL.md` §1.

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

## 0. Est-ce à jour ? (à faire avant tout diagnostic ou toute modification)

```bash
~/.local/bin/herdr-session-name-sync --version               # ce qui tourne
cat ~/.config/remia-tooling/rename-herdr/installed-version   # ce que le plugin a mis en place, et avec quelle cible
remia-tooling status                                         # version au dépôt vs version du plugin
```

Les trois doivent s'accorder. Script en retard sur le plugin : la mise en place a échoué au dernier
démarrage (le message de démarrage donne la raison) ; `install.sh --check` détaille. Plugin en retard
sur le dépôt : `claude plugin update rename-herdr@remia-tooling`, puis nouvelle session. Historique :
`README.md` § Versions.

## 3. Diagnostiquer « l'onglet ne suit plus »

Dans l'ordre, s'arrêter au premier `[!!]` :

```bash
~/.local/bin/herdr-session-name-sync --dry-run --verbose   # qui serait renommé, et pourquoi pas
<racine du plugin>/install.sh --check                       # fichiers, unité, herdr joignable
```

Lectures : « pas de pane herdr pour cette session » = intégration herdr/claude absente (TECHNIQUE.md, appariement) ou
session lancée hors herdr ; « déjà appliqué » alors que l'onglet a un autre nom = renommage
manuel après le `/rename`, comportement voulu (TECHNIQUE.md, action), `--reset` si l'utilisateur veut réappliquer ;
unité inactive = `systemctl --user enable --now rename-herdr.path` ou problème de linger (TECHNIQUE.md, déclencheur B).
