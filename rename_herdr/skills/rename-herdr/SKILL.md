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

Trois choses à savoir, une par section. Avec le dépôt : sections 1 et 5. Sans le dépôt :
les sections 2 à 4 suffisent à tout réécrire (un script python de 80 lignes et deux unités systemd).

## 1. Installer depuis le dépôt (cas normal)

```bash
git clone git@github.com:remmmi/remia-tooling.git   # ou mise à jour d'un clone existant
cd remia-tooling/rename_herdr && ./install.sh && ./selftest.sh   # attendu : "0 KO"
```

`install.sh` est idempotent (relancer = mettre à jour). Il pose `~/.local/bin/herdr-session-name-sync`
et `~/.config/systemd/user/rename-herdr.{path,service}`, active l'unité, fait un premier passage.
Puis demander à l'utilisateur un `/rename` dans une session ouverte sous herdr : l'onglet doit suivre.
Détails de la procédure et des choix à lui soumettre : `INSTALL.md` à côté de ce fichier.

## 2. Objectif « réagir au /rename » : Claude Code n'a pas de hook pour ça

Vérifié sur Claude Code 2.1.285 : les événements de hook sont SessionStart, SessionEnd,
UserPromptSubmit, PreToolUse, PostToolUse, Stop, SubagentStop, Notification, PreCompact,
PostCompact, ConfigChange. Aucun « rename ». Pour le re-vérifier sur une autre version :

```bash
grep -a -o -E '"(Session[A-Za-z]+|[A-Za-z]*Rename[A-Za-z]*)"' "$(readlink -f "$(command -v claude)")" | sort | uniq -c
```

Ce que `/rename` laisse sur disque, et qui sert de signal :

| Où | Quoi | Utile ? |
|---|---|---|
| `~/.claude/sessions/<pid>.json` | `{"sessionId": "...", "name": "foo", "nameSource": "user", "pid": N, ...}` | **oui** : réécrit à chaque `/rename` (et à chaque changement d'état busy/idle) |
| transcript `~/.claude/projects/<slug>/<sessionId>.jsonl` | ligne `{"type":"custom-title","customTitle":"foo",...}` | non : le chemin dépend du projet, et le fichier est gros |
| titre du terminal (OSC) | Claude Code y met déjà le nom | déjà fait, mais herdr n'en fait pas un libellé d'onglet |

Règles de lecture du json : ne considérer que `nameSource == "user"` (`derived` = nom automatique
du genre `dev-88`, à ignorer) ; vérifier que `pid` est vivant (`os.kill(pid, 0)`) car les fichiers
de sessions mortes traînent.

Déclencheur sans démon ni polling, sur Debian : une **unité systemd utilisateur de type path**.
`PathModified=%h/.claude/sessions` pose un inotify sur le dossier et lance un service `oneshot`
à chaque écriture dedans. Il n'y a rien à installer (`inotify-tools` inutile). Le `.path` :

```ini
[Path]
PathModified=%h/.claude/sessions
Unit=rename-herdr.service
[Install]
WantedBy=default.target
```

Pièges Debian rencontrés :

- Le PATH d'un service utilisateur est `/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin` : ni
  `~/.local/bin` ni `~/.cargo/bin`. `ExecStart=` en chemin absolu, et le script cherche `herdr` lui-même.
- `systemctl --user` exige une session utilisateur (login ssh ou console). Si herdr tourne depuis un
  service ou après logout : `sudo loginctl enable-linger <user>`.
- `Type=oneshot` : les écritures pendant l'exécution sont rejouées après. Aucun risque de rater un rename.
- Journal : `journalctl --user -u rename-herdr.service -n 20`. Preuve que ça tire sans fausse session :
  `touch ~/.claude/sessions` puis comparer `systemctl --user show rename-herdr.service -p ExecMainStartTimestampMonotonic`.
- Ne jamais écrire de faux fichier dans `~/.claude/sessions/` pour tester : Claude Code lit ce dossier
  pour lister ses sessions sœurs.

## 3. Objectif « retrouver l'onglet herdr d'une session Claude Code »

herdr (≥ 0.8) sait quelle session Claude occupe quel pane, grâce à son hook `SessionStart`
(`~/.claude/hooks/herdr-agent-state.sh`, posé par `herdr integration install claude`). Sans ce
hook, `agent_session` est vide et rien ne peut être apparié : c'est le prérequis à vérifier
(`herdr integration status` → `claude: current`).

```bash
herdr agent list   # JSON : .result.agents[] avec agent_session.value = sessionId, tab_id, pane_id
```

Appariement : `sessionId` du json de session == `agent_session.value`. On renomme alors :

| Commande | Ce que ça change | Choix |
|---|---|---|
| `herdr tab rename <tab_id> "<nom>"` | le libellé d'onglet visible dans la barre | **défaut** : c'est ce que l'utilisateur nomme à la main |
| `herdr pane rename <pane_id> "<nom>"` | le libellé du pane (visible si plusieurs panes par onglet) | `RENAME_HERDR_TARGET=pane` ou `both` |
| `herdr agent rename <cible> <name>` | le nom d'agent (`[a-z][a-z0-9_-]{0,31}`, unique) | non : contraint, sert aux commandes CLI, pas à l'affichage |

Le CLI herdr fonctionne hors d'un pane (socket par défaut `~/.config/herdr/herdr.sock`), donc
depuis systemd. Si le socket est ailleurs : `Environment=HERDR_SOCKET_PATH=...` dans le service.

## 4. Objectif « ne pas se battre avec l'utilisateur »

Le service tourne à chaque écriture du dossier, soit plusieurs fois par minute par session active.
Renommer à chaque passage écraserait un libellé changé à la main dans herdr. Règle : mémoriser le
dernier nom appliqué par session (`~/.cache/rename-herdr/<sessionId>`) et n'agir que s'il change.
Un `/rename` gagne toujours, un renommage manuel d'onglet survit jusqu'au prochain `/rename`.
`herdr-session-name-sync --reset` oublie cet état (réapplique tous les noms).

## 5. Diagnostiquer « l'onglet ne suit plus »

Dans l'ordre, s'arrêter au premier `[!!]` :

```bash
~/.local/bin/herdr-session-name-sync --dry-run --verbose   # qui serait renommé, et pourquoi pas
./install.sh --check                                        # fichiers, unité, herdr joignable
```

Lectures : « pas de pane herdr pour cette session » = intégration herdr/claude absente (§3) ou
session lancée hors herdr ; « déjà appliqué » alors que l'onglet a un autre nom = renommage
manuel après le `/rename`, comportement voulu (§4), `--reset` si l'utilisateur veut réappliquer ;
unité inactive = `systemctl --user enable --now rename-herdr.path` ou problème de linger (§2).
