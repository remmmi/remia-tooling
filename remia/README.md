# remia — le point dépôt vs local

`/plugin` installe, met à jour et désactive les plugins de la marketplace `remia-tooling`. Ce plugin
ajoute ce que `/plugin` ne fait pas :

- **proposer** au démarrage de session les plugins du dépôt jamais proposés sur cette machine, et
  **mémoriser** les oui/non pour ne pas redemander ;
- **signaler** les installations d'avant les plugins (faites à la main par `install.sh`) et les migrer ;
- **signaler** une mise à jour automatique coupée pour la marketplace ;
- **refaire le point** dépôt vs local quand l'utilisateur parle de remia-tooling.

Il ne clone et ne télécharge rien : il lit le clone de la marketplace que Claude Code tient à jour
(`~/.claude/plugins/marketplaces/remia-tooling/`) et `~/.claude/plugins/installed_plugins.json`. Il
n'installe ni ne met à jour aucun plugin lui-même.

## Commande

```
remia-tooling status [--json]            version au dépôt / installée, état, décision, restes à la main
remia-tooling decide <plugin> oui|non|oubli
remia-tooling migrate [--dry-run] [plugin…]
remia-tooling path                       dossier du clone de la marketplace
```

Dans une session Claude, `remia-tooling` est dans le PATH de l'outil Bash (dossier `bin/` du plugin).
Hors session : `~/.claude/plugins/marketplaces/remia-tooling/remia/bin/remia-tooling`.

## Ce que fait `migrate`

| Plugin | Retiré (après sauvegarde dans `~/.config/remia-tooling/sauvegarde/<date>/`) | Conservé |
|---|---|---|
| simple | `~/.claude/skills/simple/` | profil et journal, reportés dans `~/.config/remia-tooling/simple/` |
| rename-herdr | `~/.claude/skills/rename-herdr/`, hook de version de la 1.2.0 | script, unité systemd, réglage `target` (repris dans la commande d'installation) |
| usec | hooks `usec-watch` de `~/.claude/settings.json`, bloc usec de `~/.claude/CLAUDE.md` | scripts, état, langue (reprise dans la commande d'installation) |

## Fichiers

| Fichier | Rôle |
|---|---|
| `bin/remia-tooling` | la commande (python3, sans dépendance) |
| `hooks/hooks.json` | `SessionStart` (propositions) et `UserPromptSubmit` (rappel sur mention, une fois par heure et par session) |
| `skills/remia-tooling/SKILL.md` | la procédure pour l'agent |
| `selftest.sh` | autotest dans un HOME jetable |

État sur la machine : `~/.config/remia-tooling/decisions.json` (réponses mémorisées),
`~/.cache/remia-tooling/` (témoins de rappel).

## Versions

`version` de `.claude-plugin/plugin.json`, `VERSION` dans `bin/remia-tooling` et `version:` du skill,
montées ensemble (`tests/check.sh` le vérifie).

| Version | Changements |
|---|---|
| 1.0.1 | Les commandes d'installation proposées donnent toujours les réglages (`--config target=…`, `--config lang=…`), y compris par défaut : sans cela Claude Code signale une option « not yet set ». |
| 1.0.0 | Première version, en plugin de la marketplace. |
