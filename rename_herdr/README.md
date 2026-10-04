# rename_herdr : `/rename` dans Claude Code → l'onglet herdr suit

Sous [herdr](https://github.com/), chaque session Claude Code vit dans un pane. Claude Code met bien
le nom de session dans le titre du terminal, mais herdr affiche son propre libellé d'onglet, qu'on
renomme à la main. Ce pack fait suivre ce libellé au `/rename`, dans la seconde, sans démon.

Le pack ne suppose aucun nom de machine ni d'utilisateur : tout passe par `$HOME`.

## Installer

Plugin `rename-herdr` de la marketplace `remia-tooling` (voir le README à la racine du dépôt) :

```bash
claude plugin install rename-herdr@remia-tooling                        # l'onglet suit
claude plugin install rename-herdr@remia-tooling --config target=both   # l'onglet et le libellé du pane
```

Au démarrage de session suivant, le plugin lance `install.sh` (script, unités systemd utilisateur,
activation, premier passage) et le dit en une ligne. Il le relance seul quand la version ou le
réglage `target` change (`/plugin` → rename-herdr → Configure). Puis `/rename foo` dans une session
Claude Code ouverte sous herdr : l'onglet s'appelle `foo`.

À la main, depuis un clone (sans plugin, ou pour diagnostiquer) :

```bash
cd rename_herdr
./install.sh        # script, unités systemd utilisateur, activation, premier passage
./selftest.sh       # attendu : "0 KO"
```

| Commande | Effet |
|---|---|
| `./install.sh` | installe ou met à jour (idempotent) |
| `./install.sh --check` | diagnostic, ne modifie rien |
| `./install.sh --target both` | renomme aussi le libellé du pane (`tab` par défaut, ou `pane`) |
| `./install.sh --uninstall` | retire tout (unités, script, état) |
| `herdr-session-name-sync --dry-run` | montre ce qui serait renommé et pourquoi pas |
| `herdr-session-name-sync --reset` | oublie les noms déjà appliqués (réapplique tout) |

Prérequis : Claude Code, herdr ≥ 0.8 avec son intégration Claude posée (`herdr integration status`
→ `claude: current`), python3, un systemd utilisateur joignable (`systemctl --user`). Testé sur
Debian 13, Claude Code 2.1.285, herdr 0.8.0.

## Comment ça marche

```
/rename foo  --Claude Code écrit-->  ~/.claude/sessions/<pid>.json  {name: "foo", nameSource: "user", sessionId}
                                              |
                     rename-herdr.path (systemd --user, PathModified = inotify sur le dossier)
                                              |
                     rename-herdr.service (oneshot) --> herdr-session-name-sync
                                              |
        herdr agent list  : sessionId == agent_session.value  -->  tab_id
        herdr tab rename <tab_id> "foo"   (une fois par nouveau nom : état ~/.cache/rename-herdr/<sessionId>)
```

Claude Code n'a **pas** d'événement de hook sur `/rename` (vérifié sur 2.1.285), d'où le
déclencheur sur le fichier. Les noms automatiques (`nameSource: derived`) sont ignorés. Un onglet
renommé à la main après le `/rename` reste tel quel jusqu'au `/rename` suivant.

## Autre plateforme (macOS, Windows, Linux sans systemd)

Ce dossier est l'implémentation **Linux** ; la technique elle-même ne dépend pas de l'OS et est
décrite dans [`TECHNIQUE.md`](TECHNIQUE.md) : signal, appariement, action, et une table des
déclencheurs par plateforme (launchd, FileSystemWatcher, watchexec) plus une variante portable par
hook Claude Code. Un agent qui lit ce fichier peut reconstruire l'outil sans rien d'autre.

## Versions

Version de l'outil, pas du dépôt : `version` de `.claude-plugin/plugin.json` (celle que compare Claude
Code), `VERSION` dans `herdr-session-name-sync` (affichée par `--version`) et `version:` dans
`skills/rename-herdr/SKILL.md`, montées ensemble (`tests/check.sh` le vérifie). Mineure = correctif
ou option, majeure = changement de comportement visible. `./install.sh --check` compare l'installé au dépôt.

| Version | Changements |
|---|---|
| 1.3.0 | Plugin de la marketplace `remia-tooling` : installation et mises à jour par `/plugin`, réglage `target` dans le plugin, mise en place automatique au démarrage de session. Le hook de version de la 1.2.0 est retiré (et nettoyé à l'installation). |
| 1.2.0 | Hook SessionStart posé par `install.sh` (`--no-hook` pour s'en passer) : un agent démarré sur une machine en retard est prévenu qu'une version plus récente existe au dépôt. Fetch en arrière-plan (clone nu minimal dans `~/.cache/rename-herdr/`), au plus une fois par 24 h ; signalé à la session suivant le fetch. `--check` le vérifie, `--uninstall` le retire de `settings.json`. |
| 1.1.0 | `--version` ; service sans limite de démarrage (`StartLimitIntervalSec=0`, sinon l'unité `.path` mourait en rafale) ; cache par onglet + pane (un `--resume` dans un autre onglet est renommé) ; `install.sh --target` respecté au premier passage ; `--check` compare les versions. À la mise à jour, chaque session nommée est renommée une fois. |
| 1.0.0 | Première version (sans `--version`). |

## Contenu

| Fichier | Rôle |
|---|---|
| `herdr-session-name-sync` | le script (python3, sans dépendance) |
| `units/rename-herdr.path`, `units/rename-herdr.service` | déclencheur et service systemd utilisateur |
| `.claude-plugin/plugin.json`, `hooks/` | le plugin : version, réglage `target`, hook de démarrage qui lance `install.sh` (`hooks/plugin-setup.sh` est une copie de `lib/plugin-setup.sh`) |
| `install.sh`, `selftest.sh` | installation idempotente, vérification sans fausse session |
| `INSTALL.md` | procédure pour l'agent qui installe à la main, sans plugin (Linux) |
| `TECHNIQUE.md` | la technique sans OS : de quoi reconstruire sur macOS, Windows, ou sans systemd |
| `skills/rename-herdr/SKILL.md` | skill Claude Code : installer, diagnostiquer, et renvoyer à `TECHNIQUE.md` pour reconstruire ailleurs |
