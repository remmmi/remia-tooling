# herdr-vues — saisir, lire, montrer dans un pane, pas dans le chat

Quand l'utilisateur doit **fournir** quelque chose (un secret, le résultat d'un outil lancé ailleurs),
**lire ou corriger** un texte long (brouillon de mail, d'issue, réponse à envoyer, texte et son
décodage) ou **voir vivre** une commande (log, import, tests), l'agent l'ouvre dans un pane herdr à côté
de sa session au lieu de le mettre dans la conversation. Il n'attend pas qu'on le lui demande.

Le skill est écrit à partir de deux semaines d'usage réel (3 → 17 octobre 2026 : 51 `pane run`, 44
`split`, 22 `close`) : les fois où l'utilisateur a dû réclamer le pane, les commandes herdr qui ont
échoué, les vérifications de secrets qui ont jeté un jeton vide. Il remplace le skill fait main
`herdr-montrer`.

## Avant / après

> **Avant** — « Colle-moi le jeton Gandi ici. » Le jeton entre dans le transcript.
>
> **Après** — Un pane s'ouvre à droite sur `~/.secrets/gandi_token` (droits 600), avec la consigne en
> ligne 1. L'utilisateur colle, Ctrl+O, Entrée, Ctrl+X : le pane se ferme seul, l'agent est réveillé,
> `vue secret` lui dit « ligne 1 : GANDI_TOKEN = 40 car. », un appel d'API ne rend que son code (200).

## La commande `vue`

| Sous-commande | Rôle |
|---|---|
| `vue saisir <fichier> "<consigne>" [--secret]` | nano dans un pane neuf, focus dessus ; consigne posée si le fichier est vide ; `--secret` : 600/700, refusé dans un dépôt git qui ne l'ignore pas ; le pane se ferme à la sortie de nano |
| `vue lire <fichier> [+N] [--numeros] [--sous <fichier2>]` | nano confortable (retour à la ligne, souris) ; `--sous` : original en haut, second texte en dessous ; couleurs de `decode` pour `*-traduit.md` |
| `vue montrer <nom> <commande…>` | commande dans un pane nommé, sans prendre le focus ; réutilise le pane du même nom |
| `vue etat <pane>` | `nano ouvert`, `shell`, `occupé : <prog>` ou `fermé` |
| `vue attendre <pane> [s]` | rend la main quand le pane est fermé (à lancer en arrière-plan) |
| `vue fermer <pane> [--force]` | refuse si nano est encore ouvert |
| `vue secret <fichier>` | droits, âge, longueur par ligne, espaces et guillemets suspects, empreinte ; jamais le contenu |
| `vue nettoyer <fichier>` | retire les lignes de consigne `vue:` |

Géométrie : à droite au-dessus de 120 colonnes, en dessous sinon. Sans herdr, tmux ; sans tmux, `vue`
imprime la ligne `! nano …` à proposer (code 3).

## Installer

Plugin `herdr-vues` de la marketplace `remia-tooling` : `/plugin` dans Claude Code, ou
`claude plugin install herdr-vues@remia-tooling`. Demande `herdr` (≥ 0.8) ou `tmux`, `nano`, `jq`,
`python3`. La commande `vue` est dans le PATH des sessions ouvertes après l'installation.

Ancien skill `~/.claude/skills/herdr-montrer/` : `remia-tooling migrate herdr-vues` le met de côté dans
`~/.config/remia-tooling/sauvegarde/`.

## Fichiers

| Fichier | Rôle |
|---|---|
| `.claude-plugin/plugin.json` | le plugin (nom, version) |
| `skills/herdr-vues/SKILL.md` | le skill : quand ouvrir quoi, comment attendre, vérifier, ranger ; pièges herdr constatés |
| `bin/vue` | la commande |
| `selftest.sh` | autotest à blanc (`VUE_DRY=1`) : géométrie, focus, droits d'un secret, refus git, consigne, empreinte |

## Versions

| Version | Changement |
|---|---|
| 1.0.0 | Première version : skill réécrit depuis l'usage du 3 au 17/10/2026, commande `vue` (saisir, lire, montrer, etat, attendre, fermer, secret, nettoyer). |
