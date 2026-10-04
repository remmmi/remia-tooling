# Faire suivre un onglet herdr au `/rename` de Claude Code : la technique, sans OS

Ce document est écrit pour être lu par un agent (ou un humain) sur n'importe quelle machine, et
lui permettre de reconstruire l'outil avec les moyens de sa plateforme. Le dossier contient une
implémentation de référence pour Linux (systemd) ; tout ce qui n'est pas dans la table
« déclencheur » ci-dessous est valable partout.

## Le problème en une phrase

Claude Code met le nom de session dans le titre du terminal, mais herdr affiche son propre libellé
d'onglet ; on veut que ce libellé suive `/rename` sans intervention.

## La technique en trois étapes

```
(1) signal   : Claude Code écrit le nom dans un fichier          -> à surveiller
(2) appariement : herdr sait quelle session occupe quel onglet   -> à interroger
(3) action   : herdr renomme l'onglet, une fois par nouveau nom  -> à mémoriser
```

### (1) Le signal : un fichier, pas un hook

Claude Code n'a **aucun événement de hook** pour `/rename`. Vérifié sur 2.1.285 : les événements
sont SessionStart, SessionEnd, UserPromptSubmit, PreToolUse, PostToolUse, Stop, SubagentStop,
Notification, PreCompact, PostCompact, ConfigChange. À re-vérifier sur une autre version en cherchant
les chaînes `Session…` et `…Rename…` dans le binaire, ou dans la doc des hooks.

Ce que `/rename` écrit : un fichier par processus Claude Code, dans le dossier `sessions` du
dossier `.claude` de l'utilisateur :

| Plateforme | Dossier attendu | Vérifié ? |
|---|---|---|
| Linux, macOS | `~/.claude/sessions/<pid>.json` | Linux oui |
| Windows | `%USERPROFILE%\.claude\sessions\<pid>.json` | non : faire un `/rename` et lister le dossier |

Contenu utile : `{"pid": 4111385, "sessionId": "f766e645-…", "name": "lighthouse", "nameSource": "user", …}`.
Le fichier est réécrit à chaque `/rename` **et** à chaque changement d'état (busy/idle), donc
souvent : le traitement doit être idempotent et bon marché.

Règles de lecture :
- `nameSource == "user"` seulement. `derived` est un nom automatique (`dev-88`), à ignorer.
- `pid` vivant seulement : les fichiers de sessions terminées restent sur disque.
  **Piège Windows** : `os.kill(pid, 0)` n'est pas un test d'existence sous Windows, Python y
  **termine le processus** pour tout signal autre que CTRL_C/CTRL_BREAK. Utiliser `psutil.pid_exists`,
  `tasklist /FI "PID eq N"`, ou `OpenProcess` via ctypes.
- Un autre signal existe, moins pratique : la ligne `{"type":"custom-title","customTitle":"…"}` dans le
  transcript `~/.claude/projects/<slug>/<sessionId>.jsonl`. Gros fichier, chemin dépendant du projet.

### (2) L'appariement : `herdr agent list`

herdr (≥ 0.8) sait quelle session Claude occupe quel pane **si son intégration Claude est posée**
(`herdr integration status` → `claude: current` ; c'est un hook SessionStart que herdr installe
dans `~/.claude/hooks/`). Sans elle, rien n'est appariable : c'est le prérequis à vérifier en premier.

```
herdr agent list
  → .result.agents[] : { agent_session: { value: "<sessionId>" }, tab_id: "w2:t1N", pane_id: "w2:p2F", … }
```

Clé de jointure : `sessionId` du fichier de session == `agent_session.value`.

Le CLI herdr doit répondre depuis le contexte où tourne le déclencheur (service, tâche planifiée,
hook) : il trouve son socket par défaut sans variable d'environnement sous Linux ; ailleurs,
tester `herdr agent list` depuis ce contexte avant d'aller plus loin.

### (3) L'action : renommer une fois par nouveau nom

| Commande herdr | Effet | Quand |
|---|---|---|
| `herdr tab rename <tab_id> "<nom>"` | libellé d'onglet dans la barre | **défaut** : c'est ce que l'utilisateur renomme à la main |
| `herdr pane rename <pane_id> "<nom>"` | libellé du pane | plusieurs panes par onglet |
| `herdr agent rename <cible> <name>` | nom d'agent pour le CLI (`[a-z][a-z0-9_-]{0,31}`, unique) | non : ce n'est pas de l'affichage |

Le déclencheur tire souvent (voir (1)). Renommer à chaque passage écraserait un libellé changé à la
main entre deux `/rename`. Règle : mémoriser le dernier `/rename` appliqué **par sessionId** (un petit
fichier par session dans un dossier de cache) et n'agir que s'il change. Un `/rename` gagne toujours ;
un renommage manuel survit jusqu'au `/rename` suivant.

La clé mémorisée n'est pas le nom seul : c'est (onglet, pane, `nameSince`, nom). `nameSince` est
l'horodatage du `/rename` dans le fichier de session. Avec le nom seul, deux cas cassent : une
session reprise (`--resume`, même sessionId) dans un autre onglet ne serait jamais renommée, et un
`/rename` refait avec le même nom après un renommage manuel serait ignoré.

## Le déclencheur : la seule partie qui dépend de l'OS

Deux familles. La première est portable et suffit souvent ; la seconde donne l'effet immédiat.

### A. Portable : un hook Claude Code, effet au prochain message

Les hooks `UserPromptSubmit` et `Stop` existent partout. Y brancher le script de synchronisation
donne l'effet au **prochain prompt** (ou à la fin du prochain tour), pas à la seconde. Pour la
plupart des usages (`/rename` puis on tape le message suivant) c'est invisible. Dans `~/.claude/settings.json` :

```json
{ "hooks": { "UserPromptSubmit": [ { "hooks": [
    { "type": "command", "command": "python3 /chemin/herdr-session-name-sync", "timeout": 5 } ] } ] } }
```

Le script ignore son stdin (le JSON du hook) et doit rester sous la seconde : `herdr agent list`
plus quelques lectures de fichiers, c'est le cas. Sous Windows, `python` au lieu de `python3`, et
chemin en `\\` ou `/` (les deux passent).

### B. Immédiat : surveiller le dossier `sessions` avec l'outil natif

| Plateforme | Mécanisme | Ce qu'il faut savoir |
|---|---|---|
| Linux (systemd) | unité utilisateur `.path` avec `PathModified=%h/.claude/sessions` + service `oneshot` | inotify natif, rien à installer ; PATH des services sans `~/.local/bin` (chemin absolu) ; `loginctl enable-linger` si pas de session de login ; journal via `journalctl --user`. **Implémentation de référence dans ce dossier.** |
| Linux (sans systemd) | `inotifywait -m -e close_write,create,moved_to ~/.claude/sessions` dans une boucle lancée au login | paquet `inotify-tools` ; c'est un démon, à superviser |
| macOS | `launchd` agent utilisateur (`~/Library/LaunchAgents/*.plist`) avec `WatchPaths` = le dossier `sessions` | `WatchPaths` tire sur toute modification du dossier ; `launchctl load` ; PATH minimal aussi (chemin absolu vers `herdr` et `python3`) |
| Windows | PowerShell `System.IO.FileSystemWatcher` sur le dossier, `Register-ObjectEvent` sur `Changed`/`Created`, lancé au logon par une tâche planifiée (`schtasks` ou `Register-ScheduledTask`) | c'est un processus résident, à démarrer caché (`-WindowStyle Hidden`) ; débouncer (le fichier est écrit plusieurs fois de suite) ; vérifier d'abord que `herdr` répond dans PowerShell |
| Tous | `watchexec` ou `fswatch` (binaires multi-plateformes) sur le dossier | une dépendance de plus, mais un seul mécanisme à documenter |

Quel que soit le mécanisme : le déclencheur lance **le même script** qu'en A. Le script porte toute
la logique ; le déclencheur ne fait que l'appeler.

## Tester sans casser

- Ne jamais écrire de faux fichier dans `sessions/` : Claude Code lit ce dossier pour lister ses
  sessions sœurs. Pour prouver que le déclencheur tire, modifier la date du dossier lui-même
  (`touch` du dossier sous Linux/macOS) ou attendre un vrai `/rename`.
- Le script doit sortir en code 0, silencieux, quand herdr n'est pas lancé ou pas trouvé : un
  hook qui échoue affiche une erreur à chaque prompt.
- Test de bout en bout : `/rename foo` dans une session ouverte sous herdr, puis `herdr tab list`
  doit montrer `foo` ; renommer l'onglet à la main en `bar`, taper un message : `bar` doit rester.

## Reconstruire : le script, en pseudo-code

```
herdr   = HERDR_BIN | herdr dans le PATH | ~/.local/bin/herdr | ~/.cargo/bin/herdr   (sinon : exit 0)
agents  = json(herdr agent list).result.agents  (échec : exit 0)
par_sid = { a.agent_session.value : a }
pour chaque fichier sessions/*.json :
    meta = json(fichier)                        (illisible : suivant)
    si meta.nameSource != "user" : suivant
    si pid mort : suivant                       (attention Windows, voir (1))
    a = par_sid[meta.sessionId]                 (absent : suivant)
    cle = (a.tab_id, a.pane_id, meta.nameSince, meta.name)
    si cache[sessionId] == cle : suivant
    herdr tab rename a.tab_id meta.name ; cache[sessionId] = cle
```

L'implémentation de référence, `herdr-session-name-sync` (python3, sans dépendance, ~90 lignes),
suit exactement ce pseudo-code et refuse de tourner sous Windows tant que le test de pid n'y est pas
porté : c'est le seul point à adapter.
