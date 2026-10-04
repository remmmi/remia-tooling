---
name: remia-tooling
description: >
  Point dépôt vs local des plugins de la marketplace remia-tooling (remia, rename-herdr, usec,
  simple, voxtunnel) : ce qui est installé, en retard, nouveau, encore installé à la main ;
  proposer installations et migrations, mémoriser les réponses, nettoyer après une désactivation.
  Déclenche sur toute mention de remia-tooling ou "remia", "mes tools", "mes outils du dépôt",
  "qu'est-ce qui est à jour", "installe <outil du dépôt>", "mets à jour mes outils", "migre cette
  machine", et sur un message [remia-tooling] injecté par un hook.
version: 1.0.1
---

# remia-tooling

Les outils du dépôt `remmmi/remia-tooling` sont des plugins Claude Code. `/plugin` les installe, les
met à jour et les désactive ; la commande `remia-tooling` (fournie par le plugin `remia`) dit ce que
`/plugin` ne dit pas. Ce skill dit quoi en faire. Ne jamais installer, migrer ni nettoyer sans accord
explicite de l'utilisateur.

Si `remia-tooling` n'est pas dans le PATH (session ouverte avant l'installation du plugin) :
`~/.claude/plugins/marketplaces/remia-tooling/remia/bin/remia-tooling`.

## 1. Faire le point (à chaque mention de remia-tooling)

```bash
claude plugin marketplace update remia-tooling && remia-tooling status
```

Résumer en quelques lignes, pas le tableau brut : ce qui est à jour (en bloc), ce qui est en retard,
ce qui n'est pas installé et pas encore proposé, ce qui reste installé à la main. Ce qui change dans
une version : section « Versions » du README de l'outil, dans `$(remia-tooling path)/<dossier>/README.md`.
Les refus mémorisés ne sont rappelés que si l'utilisateur demande tout.

| État | Sens | Quoi faire |
|---|---|---|
| à jour | version installée = version au dépôt | rien |
| en retard | le dépôt a une version plus récente | `claude plugin update <plugin>@remia-tooling`, effet à la session suivante ; normalement fait seul par la mise à jour automatique |
| non installé | jamais installé ici | proposer une fois (§2) |
| désactivé | installé, coupé dans `/plugin` | ne rien proposer ; nettoyage possible (§5) |
| installé (voxtunnel) | la version se lit dans un autre dépôt | rien ; l'état de l'application est donné à part |
| local plus récent | plugin chargé depuis un clone de travail | rien |
| `à la main : …` | restes d'une installation d'avant les plugins | proposer la migration (§3) |

Ligne « mise à jour automatique : NON » : le dire. Sans elle, la machine ne suit plus le dépôt.
La rétablir : `/plugin` → Marketplaces → remia-tooling → Enable auto-update (ou relancer `bootstrap.sh`).

## 2. Proposer, puis mémoriser la réponse

Une question groupée (une ligne par plugin), pas un plugin par message. Chaque réponse se mémorise
tout de suite, pour que le hook de démarrage ne la repose pas :

| Réponse | Commande |
|---|---|
| oui | `claude plugin install <plugin>@remia-tooling` (ajouter les `--config` que donne `remia-tooling status --json`, champ `install`), puis `remia-tooling decide <plugin> oui` |
| non | `remia-tooling decide <plugin> non` |
| revenir sur un choix | `remia-tooling decide <plugin> oubli` |

Un « non » ne bloque rien : si l'utilisateur demande le plugin plus tard, l'installer et passer à `oui`.
Après une installation, dire que l'effet arrive à la **prochaine session** : les hooks d'un plugin se
chargent au démarrage, et c'est le premier démarrage qui pose les scripts et l'unité systemd.

Réglages : `rename-herdr` a `target` (`tab`, `pane`, `both`), `usec` a `lang` (`fr`, `en`). Les changer :
`/plugin` → le plugin → Configure, ou `echo '{"target":"both"}' | claude plugin configure rename-herdr@remia-tooling --values-stdin`.

`voxtunnel` est à part : le plugin n'apporte qu'un skill. L'application (paquet Debian, module noyau)
s'installe par ce skill, à la demande, avec `sudo` : jamais automatiquement.

## 3. Migrer une installation à la main

Avant les plugins, les outils s'installaient par `install.sh` depuis un clone : skills copiés dans
`~/.claude/skills/`, hooks écrits dans `~/.claude/settings.json`, bloc usec dans `~/.claude/CLAUDE.md`.
Le plugin apporte tout cela lui-même ; les restes feraient doublon (alertes en double, skill en double).

```bash
remia-tooling migrate --dry-run     # montrer la liste à l'utilisateur
remia-tooling migrate               # avec accord
```

`migrate` sauvegarde avant de toucher (`~/.config/remia-tooling/sauvegarde/<date>/`), reporte le profil
et le journal de `simple` vers `~/.config/remia-tooling/simple/`, retire les doublons, puis affiche les
commandes d'installation avec les réglages d'avant (par exemple `--config target=both`). Les lancer,
mémoriser `oui`, et demander une nouvelle session. Les scripts déjà posés dans `~/.local` et l'unité
systemd restent en place : le premier démarrage de session les réécrit à la version du plugin.

## 4. Vérifier après installation (nouvelle session)

| Plugin | Contrôle |
|---|---|
| rename-herdr | `cat ~/.config/remia-tooling/rename-herdr/installed-version` ; `systemctl --user is-active rename-herdr.path` ; un `/rename` fait suivre l'onglet |
| usec | `cat ~/.config/remia-tooling/usec/installed-version` ; `usec-watch status` |
| simple | `/simple:simple` apparaît dans la liste des skills |
| tous | `remia-tooling status` : tout « à jour », plus aucun « à la main » |

Un message `[remia-tooling] <plugin> X : mise en place en échec` au démarrage donne la fin de la sortie
de l'`install.sh` ; corriger la cause (souvent : pas de session systemd utilisateur, voir le README de
l'outil), la mise en place est retentée à chaque démarrage de session tant qu'elle échoue.

## 5. Nettoyer après une désactivation

Désactiver ou désinstaller un plugin arrête ses hooks mais laisse ce qu'il a posé sur la machine.
Avec accord, depuis le clone de la marketplace :

```bash
"$(remia-tooling path)/rename_herdr/install.sh" --uninstall   # unité systemd, script, état
"$(remia-tooling path)/usec/install.sh" --uninstall           # scripts, porte quota, état
```

`simple` ne pose rien hors de `~/.config/remia-tooling/simple/` (profil et journal, à garder sauf demande).
Ne pas lancer ces commandes pour un plugin encore actif : il se remettrait en place au démarrage suivant.
