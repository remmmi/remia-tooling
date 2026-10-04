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
| `claude-md.fr.md`, `claude-md.en.md` | la règle (quand lire `usec`, quels seuils) : injectée en début de session par le plugin, ou posée dans CLAUDE.md sans plugin |
| `.claude-plugin/plugin.json`, `hooks/` | le plugin : version, réglage `lang`, hooks (mise en place, règle en début de session, surveillance ; `hooks/plugin-setup.sh` est une copie de `lib/plugin-setup.sh`) |
| `install.sh` | installe les scripts ; `--check` compare l'installé au dépôt, `--uninstall` retire tout. Sans plugin : `--hooks` branche usec-watch dans settings.json, `--claude-md` pose la règle |
| `INSTALL.md` | procédure pour l'agent qui installe à la main, sans plugin |
| `selftest.sh` | autotest sans quota consommé (fixture) ; `--live` pour un vrai appel |

Ce n'est pas un skill : un skill ne se charge qu'à la demande, alors que la surveillance doit être
active en permanence. Deux couches :

1. **Hook `usec-watch`** (la garantie) — branché sur `UserPromptSubmit` et `PostToolUse`. Il sort
   en quelques ms tant que le dernier relevé a moins de 20 min ; sinon il relance `usec` détaché,
   sans bloquer. Il garde un historique et projette : session au rythme des 90 dernières minutes, semaine à la moyenne depuis le début de la semaine (après 6 h — une rafale de travail ne se prolonge pas 24 h/24). Silence
   tant que rien n'est critique ; sinon une ligne `[usec-watch] …` arrive dans le contexte de
   l'agent, qui prévient l'utilisateur. Une même alerte ne revient pas avant 1 h dans une session.
2. **Règle en contexte** (le jugement) — injectée en début de session par le plugin : l'agent peut lire `usec-watch status` (gratuit) après ou
   avant une étape lourde, et n'en parle que si c'est critique.

**Critique** = session ou semaine ≥ 85 %, ou 100 % atteint avant le reset au rythme actuel ; une
session qui se réinitialise dans moins de 30 min ne compte pas. Réglages : `USEC_WATCH_TTL`,
`USEC_WATCH_CRIT`, `USEC_WATCH_SESSION_GUARD`, `USEC_WATCH_REALERT` (voir `usec-watch --help`).
État dans `~/.local/state/usec/`. Coût : ~3 appels `/usage` par heure d'activité, zéro au repos.

## Installer

Plugin `usec` de la marketplace `remia-tooling` (voir le README à la racine du dépôt) :

```bash
claude plugin install usec@remia-tooling                    # alertes et règle en français
claude plugin install usec@remia-tooling --config lang=en   # en anglais
```

Au démarrage de session suivant, le plugin pose `usec`, `usec-watch` et `quota_gate.sh` dans
`~/.local` (ils servent aussi hors de Claude : terminal, cron, lots), injecte la règle dans le contexte
et branche la surveillance. Rien n'est écrit dans `settings.json` ni dans `CLAUDE.md`.

À la main, depuis un clone (sans plugin) : `./install.sh --hooks --claude-md ~/.claude/CLAUDE.md` puis
`./selftest.sh` ; procédure complète dans `INSTALL.md`. Ne pas cumuler les deux : avec le plugin, des
hooks posés à la main donneraient chaque alerte en double (`remia-tooling migrate usec` les retire).

## Porte quota dans un script

```bash
source ~/.local/share/usec/quota_gate.sh
export USEC_GATE_DIR=./etat_du_lot; usec_gate_reset
for id in $(cat ids.txt); do usec_gate || { echo "pause : $(usec_gate_motif)"; break; }; claude -p …; done
```

Seuils : `USEC_GATE_SESSION_MAX` (70), `USEC_GATE_WEEK_MAX` (85). Cache 120 s partagé entre workers.

## Versions

Version de l'outil (usec, usec-watch, quota_gate.sh ensemble), pas du dépôt : `version` de
`.claude-plugin/plugin.json` (celle que compare Claude Code) et `USEC_VERSION` dans `usec`, affichée par
`usec --version`, montées ensemble (`tests/check.sh` le vérifie). Mineure = correctif ou option, majeure = changement de
comportement visible (format JSON, seuils par défaut, hooks). `./install.sh --check` compare
l'installé au dépôt. Un `usec` qui répond « argument inconnu » à `--version` est antérieur à 1.0.0.

| Version | Changements |
|---|---|
| 1.1.0 | Plugin de la marketplace `remia-tooling` : hooks et règle apportés par le plugin (plus rien dans `settings.json` ni `CLAUDE.md`), réglage `lang`, mise en place automatique au démarrage de session. `install.sh --uninstall`. |
| 1.0.0 | Première version numérotée : `usec --version`, `install.sh --check`. |

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
