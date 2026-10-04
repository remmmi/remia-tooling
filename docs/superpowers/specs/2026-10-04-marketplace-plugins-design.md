# remia-tooling en marketplace de plugins Claude Code — design

Date : 2026-10-04. Statut : **réalisé** le 2026-10-04 (voir « Réalisation » en fin de document). La
procédure d'usage est dans le README à la racine ; ce document garde la conception et ses raisons.

## But

Chaque machine (VPS et postes de travail, tous sous Linux avec systemd) utilise les outils du dépôt
comme des plugins Claude Code : les voir, les installer, les mettre à jour et les désactiver depuis
`/plugin` dans le TUI, sans cloner le dépôt ni lancer un `install.sh` à la main.

En plus de ce que `/plugin` fait déjà :

- proposer les plugins du dépôt jamais proposés sur cette machine, et mémoriser les oui/non pour
  ne pas redemander ;
- refaire le point dépôt contre local quand l'utilisateur parle de remia-tooling.

Critère de réussite : sur une machine neuve, `bootstrap.sh` puis une session Claude suffisent pour
qu'un outil activé dans `/plugin` soit en place et se mette à jour seul (sauf voxtunnel, voir sa section).

## Décisions prises

| Sujet | Décision |
|---|---|
| Distribution | marketplace native (`.claude-plugin/marketplace.json`), pas de gestionnaire maison |
| Plateformes | Linux + systemd utilisateur partout : pas de mode de repli sans systemd |
| Mise en place système | automatique au démarrage de session ; activer le plugin vaut accord |
| Premier lot | `remia`, `rename-herdr`, `usec`, `simple`, `voxtunnel` |
| voxtunnel | reste dans son dépôt public (`github.com/remmmi/voxtunnel`) ; la marketplace y pointe par une entrée à source externe |
| `simple` en anglais | abandonné ; `skills/simple/en/` est supprimé du dépôt (reste dans l'historique git) |
| Mod | aucun : `/plugin` est l'interface, et aucun événement de mod ne se déclenche sur `/rename` (types du build 2.1.286) |
| prismText, ctrlmajMDTerm | hors lot, installés à la main, signalés dans le README racine |
| claudeBridge | à revoir, jamais proposé |

## Structure du dépôt

Additif : aucun dossier existant ne bouge.

```
.claude-plugin/marketplace.json      name: "remia-tooling", 4 plugins en chemins relatifs + voxtunnel en source externe
bootstrap.sh                         machine neuve : marketplace + autoUpdate + plugin remia
README.md                            racine : ce qu'est le dépôt, bootstrap, outils hors marketplace
tests/check.sh                       versions cohérentes + claude plugin validate sur chaque plugin
lib/plugin-setup.sh                  hook de mise en place commun (voir plus bas), copié dans chaque plugin qui s'en sert
remia/            plugin "remia"
rename_herdr/     plugin "rename-herdr"   (source "./rename_herdr")
usec/             plugin "usec"
skills/simple/    plugin "simple"
```

Un plugin installé est copié dans le cache de Claude Code : il ne peut pas lire un fichier hors de
son dossier. `lib/plugin-setup.sh` est donc la source, et `tests/check.sh` vérifie que la copie
dans `rename_herdr/hooks/` et `usec/hooks/` lui est identique.

## Les plugins

### remia

Rôle : ce que `/plugin` ne fait pas. Pas de clone ni de fetch à lui : il lit le clone de la
marketplace que Claude Code tient à jour et `~/.claude/plugins/installed_plugins.json`.

- `bin/remia-tooling` (python3, sans dépendance) :
  - `status [--json]` : par plugin de la marketplace, version au dépôt, version installée, état
    (à jour, en retard, non installé), décision mémorisée ; plus les installations anciennes
    détectées (voir Migration).
  - `decide <plugin> oui|non|oubli` : mémorise dans `~/.config/remia-tooling/decisions.json`.
  - `hook` : appelé par les deux hooks ci-dessous, toujours code 0, muet s'il n'a rien à dire.
- Hook `SessionStart` : s'il existe un plugin jamais proposé (ni installé ni décidé), une
  installation ancienne à migrer, ou une mise à jour automatique désactivée pour la marketplace,
  injecte un contexte demandant à Claude de le signaler en une ou deux lignes et de proposer, sans
  rien installer sans accord.
- Hook `UserPromptSubmit` : si le message mentionne remia-tooling, injecte un contexte demandant
  de faire le point avant de répondre. Au plus une fois par heure et par session.
- Skill `remia-tooling` : faire le point (`claude plugin marketplace update remia-tooling` puis
  `remia-tooling status`), proposer en une question groupée, mémoriser chaque réponse, installer
  avec accord (`claude plugin install <plugin>@remia-tooling`), nettoyer ce qu'un plugin désactivé
  a laissé sur la machine (`install.sh --uninstall` de l'outil).

Les mises à jour des plugins installés sont le travail de Claude Code (autoUpdate). `remia` ne les
installe pas ; il signale seulement qu'autoUpdate est coupé.

### rename-herdr

- `plugin.json` : version = `VERSION` de `herdr-session-name-sync` ; `userConfig.target`
  (`tab` | `pane` | `both`, défaut `tab`) ; `dependencies: ["remia"]`.
- Hook `SessionStart` : mise en place (voir plus bas) avec `install.sh --target <réglage>`.
- Skill `rename-herdr` existant (diagnostic) ; sa section « est-ce à jour » renvoie à `/plugin`.
- Le hook de version propre à la 1.2.0 est supprimé ; `install.sh` le nettoie s'il traîne.

### usec

- `plugin.json` : version = `USEC_VERSION` ; `userConfig.lang` (`fr` | `en`, défaut `fr`) ;
  `dependencies: ["remia"]`.
- Hooks, tous déclarés par le plugin (plus rien dans `settings.json`) :
  - `SessionStart` : mise en place (`install.sh`, sans `--hooks` ni `--claude-md`), puis injection
    de la règle quotas (le contenu de `claude-md.<lang>.md`) en contexte de session. La règle
    n'est plus écrite dans `CLAUDE.md`.
  - `UserPromptSubmit` et `PostToolUse` : `usec-watch hook`, lancé depuis le dossier du plugin.
- `usec`, `usec-watch` et `quota_gate.sh` restent posés dans `~/.local` par la mise en place :
  ils servent hors de Claude (terminal, cron, lots).

### simple

- `plugin.json` : version = `version:` du `SKILL.md` ; `dependencies: ["remia"]`. Pas de hook.
- Le profil et le journal sortent du `SKILL.md` : `~/.config/remia-tooling/simple/profil.md` et
  `journal.md`. Le skill les lit à cet endroit ; absent = profil vide, le skill propose de le
  remplir (procédure d'`INSTALL.md`, inchangée sur le fond).
- `en/` supprimé.

### voxtunnel (dépôt externe)

Voxtunnel n'est pas un outil pour Claude : c'est une application système (client à icône sur le
poste, carte son virtuelle `snd-aloop` côté serveur), avec ses paquets Debian, ses releases GitHub
et sa propre mise à jour depuis le client. Le plugin n'y ajoute qu'un skill.

- Dans le dépôt voxtunnel, un dossier `claude-plugin/` : `.claude-plugin/plugin.json` (version =
  `__version__` de `client/voxtunnel-tray.py`) et `skills/voxtunnel/SKILL.md`.
- Entrée de la marketplace :
  `{"source": "git-subdir", "url": "https://github.com/remmmi/voxtunnel.git", "path": "claude-plugin"}`.
  Dépôt public en https : aucune clé SSH nécessaire.
- Skill `voxtunnel` : reconnaître le rôle de la machine (serveur ou poste), installer avec accord
  depuis la dernière release (`voxtunnel-server_*.deb` ou `voxtunnel_*.deb`), vérifier
  (`aplay -l | grep Loopback`, enregistrement test), diagnostiquer, revenir en arrière. Reprend les
  règles de `server/CLAUDE.md` et `client/CLAUDE.md` (ne jamais toucher à la config audio existante,
  pas de redémarrage).
- **Pas de mise en place automatique** : l'installation demande `sudo` et charge un module noyau.
  C'est l'exception à la règle du lot ; elle se fait par le skill, à la demande, avec accord.
- Les mises à jour de l'application restent celles de voxtunnel (client → release, serveur poussé
  depuis le client). Le plugin ne met à jour que le skill.
- `remia-tooling status` signale en plus l'état de l'application : paquet `voxtunnel-server` ou
  `voxtunnel` installé et sa version, ou `snd-aloop` chargé sans paquet.
- Un test dans le dépôt voxtunnel (`tests/`) échoue si la version du `plugin.json` diffère de
  `__version__`.
- Pas de dépendance à `remia` : le plugin doit rester installable depuis le dépôt voxtunnel seul.

État de ce serveur au 2026-10-04 : `snd-aloop` chargé et persistant (mis en place à la main en
août), paquet `voxtunnel-server` non installé. Le skill doit reconnaître ce cas comme
« fonctionnel, hors paquet » et proposer le paquet sans l'imposer.

## Mise en place automatique (`plugin-setup.sh`)

Appelé par le hook `SessionStart` de `rename-herdr` et de `usec`.

1. Lit la version du plugin et la compare à `~/.config/remia-tooling/<plugin>/installed-version`
   (qui contient aussi les réglages utilisés, pour relancer si `target` ou `lang` change).
2. Identique : sort sans rien faire (lecture d'un fichier, quelques millisecondes).
3. Différent : lance l'`install.sh` de l'outil depuis le dossier du plugin, écrit le fichier, et
   affiche une ligne (`rename-herdr 1.3.0 mis en place`).
4. Échec : affiche la raison (dernières lignes de l'`install.sh`), n'écrit pas le fichier, donc
   réessaie à la session suivante. Toujours code 0 : un hook en échec ne doit pas gêner la session.

Les `install.sh` restent le seul chemin d'installation : le plugin les appelle, et ils continuent
de marcher à la main depuis un clone.

## Machine neuve (`bootstrap.sh`)

```
claude plugin marketplace add git@github.com:remmmi/remia-tooling.git
active autoUpdate pour cette marketplace
claude plugin install remia@remia-tooling
```

Prérequis vérifiés par le script : `claude`, `git`, et un accès SSH au dépôt sans mot de passe
(les mises à jour se font sans terminal). Il s'arrête en le disant si l'un manque. Le premier
démarrage de session suivant propose les trois autres plugins.

## Migration d'une machine installée à la main

`remia-tooling status` détecte une installation ancienne quand l'outil est présent sur la machine
(`~/.local/bin/herdr-session-name-sync`, `~/.local/bin/usec`, `~/.claude/skills/simple/`,
`~/.claude/skills/rename-herdr/`) sans que le plugin soit installé. Le skill `remia-tooling`
propose alors la migration, qui retire ce qui ferait doublon :

- skills copiés dans `~/.claude/skills/` (`simple`, `rename-herdr`) ; le profil de `simple` est
  d'abord extrait vers `~/.config/remia-tooling/simple/profil.md`, `journal.md` déplacé ;
- hooks `usec-watch` et `rename-herdr-version-check` dans `~/.claude/settings.json` ;
- bloc `<!-- usec:start … usec:end -->` de `~/.claude/CLAUDE.md` ;
- les scripts et l'unité systemd restent : la mise en place du plugin les réécrit.

Puis installe le plugin correspondant.

État de ce serveur au 2026-10-04, à migrer : rename_herdr 1.2.0 (`--target both`, avec son hook de
version), usec 1.0.0 (hooks + bloc CLAUDE.md), simple 1.0.0 (profil rempli), skill rename-herdr.

## Versions

- La version comparée par Claude Code est celle de `plugin.json`. Elle doit être montée à chaque
  changement, sinon les machines ne se mettent pas à jour.
- `tests/check.sh` échoue si la version de `plugin.json` diffère de celle du script ou du
  `SKILL.md` de l'outil, ou si l'entrée de `marketplace.json` en déclare une autre.
- Versions de départ : `remia` 1.0.0, `rename-herdr` 1.3.0, `usec` 1.1.0, `simple` 1.1.0,
  `voxtunnel` 1.3.0 (sa version actuelle ; ajouter le plugin ne change pas l'application).

## Tests

- `tests/check.sh` : cohérence des versions, copies de `plugin-setup.sh` identiques,
  `claude plugin validate` sur la marketplace et chaque plugin.
- `remia/selftest.sh` : HOME jetable, fausse marketplace et faux `installed_plugins.json` ;
  couvre status, décisions mémorisées, silence quand rien à dire, détection d'installation
  ancienne, rappel sur mention (une fois par session).
- `plugin-setup.sh` : HOME jetable, faux `install.sh` ; couvre première mise en place, rien à
  faire, changement de version, changement de réglage, échec puis nouvel essai.
- Selftests existants de `rename_herdr` et `usec` inchangés et verts.
- Bout en bout sur ce serveur : migration, installation des quatre plugins depuis la vraie
  marketplace, puis nouvelle session pour constater les hooks (à faire par l'utilisateur :
  les hooks d'un plugin ne se chargent qu'au démarrage d'une session).

## Limites acceptées

- Le plugin voxtunnel demande un commit dans le dépôt public `remmmi/voxtunnel`. Accord donné le
  2026-10-04, à deux conditions, vérifiées avant de pousser :
  - **rien de secret** : le dépôt est public. Aucun nom de machine, d'utilisateur, d'hôte SSH,
    d'adresse IP, de chemin personnel ni de détail de ce VPS dans le `plugin.json`, le skill ou le
    message de commit. Relecture du diff complet avant le push ;
  - **rien de cassé pour qui installe depuis le dépôt** (paquets Debian, `client/install.sh`,
    `server/setup-vps.sh`, releases) : le changement est un dossier `claude-plugin/` ajouté et un
    test de version, sans toucher aux fichiers existants ; `build-deb.sh` ne doit pas embarquer
    ce dossier dans les paquets ; les tests et la CI du dépôt restent verts.

- Désactiver ou désinstaller un plugin arrête ses hooks mais ne retire pas ce qu'il a posé
  (unité systemd, scripts dans `~/.local`). Nettoyage par le skill `remia-tooling`.
- Une nouvelle version d'un outil arrive au démarrage de session qui suit la mise à jour de la
  marketplace par Claude Code, pas dans la seconde.
- La découverte d'un nouveau plugin dépend de `remia` : une machine sans `remia` ne voit les
  nouveautés que dans l'onglet Discover de `/plugin`.

## À vérifier en construisant

Faits tirés de la documentation mais pas encore constatés sur ce build (2.1.289) ; chacun a un
repli si la vérification échoue.

| Point | Repli |
|---|---|
| Nom du skill quand `SKILL.md` est à la racine du plugin `simple` (`/simple` ou `/simple:simple`) | déplacer en `skills/simple/skills/simple/SKILL.md` |
| Le réglage `userConfig` arrive aux hooks en `CLAUDE_PLUGIN_OPTION_<CLÉ>` | fichier de réglage dans `~/.config/remia-tooling/<plugin>/` écrit par le skill |
| Chemin du clone de la marketplace (`~/.claude/plugins/marketplaces/remia-tooling/`) et forme de `installed_plugins.json` | lire `known_marketplaces.json` (`installLocation`), constaté présent sur ce serveur |
| Activation d'autoUpdate par `bootstrap.sh` (clé `autoUpdate` de `known_marketplaces.json` ou `extraKnownMarketplaces` de `settings.json`) | le dire à l'utilisateur : `/plugin` → Marketplaces → activer la mise à jour automatique |
| `dependencies: ["remia"]` installe bien `remia` avec le plugin | `remia` installé par `bootstrap.sh` seulement, les plugins fonctionnent sans lui |
| Une entrée `git-subdir` vers un dépôt externe s'installe et se met à jour comme les autres | entrée `url` sur le dépôt entier (le plugin embarque alors tout le dépôt, images comprises) |
| `bin/` du plugin dans le PATH de l'outil Bash | le skill appelle `remia-tooling` par son chemin complet |

## Réalisation (2026-10-04)

Les sept points « à vérifier en construisant » sont constatés sur le build 2.1.289, sans recours aux replis :

| Point | Constat |
|---|---|
| Skill à la racine du plugin `simple` | reconnu ; son nom est `simple:simple` (un skill de plugin porte toujours le préfixe du plugin, le repli n'y aurait rien changé) |
| `userConfig` vers les hooks | `CLAUDE_PLUGIN_OPTION_TARGET=both` reçu par le hook : témoin `1.3.0 --target both`, unité réécrite |
| Clone de la marketplace, forme de `installed_plugins.json` | conformes ; `remia` lit `installLocation` dans `known_marketplaces.json` |
| Activation d'autoUpdate | clé `autoUpdate` de l'entrée `extraKnownMarketplaces` de `settings.json` et de `known_marketplaces.json` (ce qu'écrit le bouton de `/plugin`) ; `bootstrap.sh` écrit les deux |
| `dependencies: ["remia"]` | installe `remia` avec le plugin |
| Entrée `git-subdir` externe | voxtunnel s'installe, seul le dossier `claude-plugin/` est copié, version lue dans son `plugin.json` |
| `bin/` dans le PATH de l'outil Bash | constaté dans une session |

Non constaté : le téléchargement automatique d'une nouvelle version au démarrage d'une session
**interactive** (l'essai s'est fait par sessions `claude -p`, qui ne le déclenchent pas). Le chemin manuel
(`claude plugin marketplace update` puis `claude plugin update`) est constaté de 1.0.0 à 1.0.1 pour `remia`.
`simple` est laissé en 1.1.0 sur ce serveur pour l'observer : il doit passer seul en 1.1.1.

Écarts par rapport au design ci-dessus, tous de détail :

- **`remia-tooling migrate`** (non prévu comme commande) : la migration d'une installation à la main
  était décrite comme une procédure du skill. C'est une commande, testée dans un HOME jetable, parce
  qu'elle édite `settings.json` et `CLAUDE.md` et doit se rejouer à l'identique sur chaque machine.
  Elle sauvegarde avant de toucher et affiche les commandes d'installation avec les réglages d'avant.
- **`usec/install.sh --uninstall`** ajouté : le nettoyage après désactivation en avait besoin.
- **Dépôt voxtunnel** : une ligne ajoutée à `.github/workflows/smoke.yml` pour que la CI lance le test
  de version (le design disait « sans toucher aux fichiers existants »). Aucun fichier du client, du
  serveur ni des paquets n'est modifié ; les paquets construits ne contiennent pas le dossier du plugin.
  Le commit porte l'identité déjà publique de ce dépôt, pas celle de ce serveur.
- **Réglages toujours explicites à l'installation** (`--config lang=fr`) : sans valeur, Claude Code
  signale une option « not yet set » même quand le manifeste donne un défaut.
- Versions publiées : `remia` 1.0.1, `rename-herdr` 1.3.0, `usec` 1.1.0, `simple` 1.1.1, `voxtunnel` 1.3.0.

Ce serveur est migré : marketplace ajoutée, mise à jour automatique activée, `remia`, `rename-herdr`
(`target=both`), `usec` et `simple` installés en plugins, restes de l'installation à la main retirés
(sauvegarde dans `~/.config/remia-tooling/sauvegarde/`). `voxtunnel` reste à proposer : c'est `remia`
qui le fait au démarrage de session.
