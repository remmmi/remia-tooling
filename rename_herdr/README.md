# rename_herdr : `/rename` dans Claude Code → l'onglet herdr suit

Sous [herdr](https://github.com/), chaque session Claude Code vit dans un pane. Claude Code met bien
le nom de session dans le titre du terminal, mais herdr affiche son propre libellé d'onglet, qu'on
renomme à la main. Ce pack fait suivre ce libellé au `/rename`, dans la seconde, sans démon.

Le pack ne suppose aucun nom de machine ni d'utilisateur : tout passe par `$HOME`.

## Installer

```bash
cd rename_herdr
./install.sh        # script, unités systemd utilisateur, activation, premier passage
./selftest.sh       # attendu : "0 KO"
```

Puis `/rename foo` dans une session Claude Code ouverte sous herdr : l'onglet s'appelle `foo`.

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

## Contenu

| Fichier | Rôle |
|---|---|
| `herdr-session-name-sync` | le script (python3, sans dépendance) |
| `units/rename-herdr.path`, `units/rename-herdr.service` | déclencheur et service systemd utilisateur |
| `install.sh`, `selftest.sh` | installation idempotente, vérification sans fausse session |
| `INSTALL.md` | procédure pour l'agent qui installe |
| `skills/rename-herdr/SKILL.md` | skill Claude Code : installer, diagnostiquer, et **reconstruire sans le dépôt** (les trois savoirs, avec les pièges Debian) |
