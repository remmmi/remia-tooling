# usec — lire les quotas de l'abonnement Claude avant de foncer dans le mur

`usec` rend en JSON ce qu'affiche `/usage` dans Claude Code : fenêtre de session (5 h glissantes),
semaine tous modèles, semaine par modèle, avec le pourcentage consommé et l'heure du reset. Un
agent (ou un script) le lit avant une tâche lourde, au lieu de découvrir le quota épuisé au
milieu d'un lot.

```
$ usec
{"quotas": [{"period": "session", "models": "all models", "used_percent": 42.0,
             "reset_at": "2026-09-29T02:20:00+02:00", "timezone": "Europe/Paris"}, …]}
```

## Ce que contient ce dossier

| Fichier | Rôle |
|---|---|
| `usec` | le script : `claude -p "/usage"` → JSON. `--raw` (sortie brute), `--stdin` (parse une sortie fournie) |
| `usec-watch` | surveillance silencieuse par hook Claude Code : relevé en arrière-plan, projection, alerte seulement si critique ; `status` = dernier relevé sans appel |
| `quota_gate.sh` | porte quota à sourcer dans un script qui enchaîne des `claude -p` : pause propre au seuil |
| `claude-md.fr.md`, `claude-md.en.md` | la règle à mettre dans CLAUDE.md : quand lire `usec`, quels seuils |
| `install.sh` | installe les scripts ; `--hooks` branche usec-watch dans settings.json, `--claude-md` pose la règle |
| `INSTALL.md` | procédure pour l'agent qui installe sur une nouvelle machine |
| `selftest.sh` | autotest sans quota consommé (fixture) ; `--live` pour un vrai appel |

Ce n'est pas un skill : un skill ne se charge qu'à la demande, alors que la surveillance doit être
active en permanence. Deux couches :

1. **Hook `usec-watch`** (la garantie) — branché sur `UserPromptSubmit` et `PostToolUse`. Il sort
   en quelques ms tant que le dernier relevé a moins de 20 min ; sinon il relance `usec` détaché,
   sans bloquer. Il garde un historique et projette au rythme des 90 dernières minutes. Silence
   tant que rien n'est critique ; sinon une ligne `[usec-watch] …` arrive dans le contexte de
   l'agent, qui prévient l'utilisateur. Une même alerte ne revient pas avant 1 h dans une session.
2. **Règle CLAUDE.md** (le jugement) — l'agent peut lire `usec-watch status` (gratuit) après ou
   avant une étape lourde, et n'en parle que si c'est critique.

**Critique** = session ou semaine ≥ 85 %, ou 100 % atteint avant le reset au rythme actuel ; une
session qui se réinitialise dans moins de 30 min ne compte pas. Réglages : `USEC_WATCH_TTL`,
`USEC_WATCH_CRIT`, `USEC_WATCH_SESSION_GUARD`, `USEC_WATCH_REALERT` (voir `usec-watch --help`).
État dans `~/.local/state/usec/`. Coût : ~3 appels `/usage` par heure d'activité, zéro au repos.

## Installer

Dire à l'agent de la machine cible : « installe usec en suivant `usec/INSTALL.md` ».
À la main : `./install.sh --hooks --claude-md ~/.claude/CLAUDE.md` puis `./selftest.sh`.

## Porte quota dans un script

```bash
source ~/.local/share/usec/quota_gate.sh
export USEC_GATE_DIR=./etat_du_lot; usec_gate_reset
for id in $(cat ids.txt); do usec_gate || { echo "pause : $(usec_gate_motif)"; break; }; claude -p …; done
```

Seuils : `USEC_GATE_SESSION_MAX` (70), `USEC_GATE_WEEK_MAX` (85). Cache 120 s partagé entre workers.

## Pièges

- **Alias dans `.bashrc` = inutilisable** hors terminal : `.bashrc` s'arrête pour un shell non
  interactif (préfixe `!` de Claude Code, cron). D'où un script dans le PATH, déclaré dans `~/.profile`.
- Chaque `usec` est un appel `claude -p` (~5-20 s) : cache côté script, jamais en boucle serrée.
- `usec` illisible (format de `/usage` changé, pas d'abonnement, clé API) → rc 1, et la porte
  reste **ouverte** : garder un coupe-circuit (3 échecs rapides d'affilée = arrêt).
- Un échec de quota ressemble à un échec de modèle (rc 1) : c'est la durée de l'appel qui les distingue.
- Purger l'état au démarrage d'un lot (`usec_gate_reset`) : sinon un vieux seuil franchi bloque le run suivant.
- Le `claude -p /usage` lancé par le relevé déclenche lui-même les hooks : `USEC_WATCH_INNER` et
  un verrou l'empêchent de se surveiller en boucle.
- Aucun quota mensuel n'apparaît dans `/usage` sur un abonnement standard ; si une ligne apparaît,
  elle n'est suivie que si elle a la forme `Current …: N% used · resets …`.
- Mesuré sur un drain : 4 workers parallèles ont vidé une fenêtre de session en 50 min ; 2 est un bon défaut.
