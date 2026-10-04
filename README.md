# remia-tooling

Outils pour Claude Code sur les VPS et postes de travail (Linux, systemd utilisateur), distribués
comme une **marketplace de plugins Claude Code**. Chaque machine les voit, les installe, les règle,
les met à jour et les désactive depuis `/plugin`, sans cloner ce dépôt ni lancer d'`install.sh`.

Ce README est la procédure de référence. Pour mettre une machine sur ce système, dire à son agent :

> Lis le README de `git@github.com:remmmi/remia-tooling.git` et installe cette machine selon la
> section « Installer une machine ».

## Les plugins

| Plugin | Ce qu'il apporte | Réglage | Pose sur la machine |
|---|---|---|---|
| `remia` | propose les plugins jamais proposés ici (oui/non mémorisés), signale les installations à la main à migrer, fait le point dépôt vs local quand on parle de remia-tooling | — | rien |
| `rename-herdr` | l'onglet herdr (ou le pane) suit le `/rename` de la session | `target` : `tab`, `pane`, `both` | un script dans `~/.local/bin`, une unité systemd utilisateur |
| `usec` | quotas de l'abonnement : surveillance silencieuse, alerte seulement si critique, commande `usec` | `lang` : `fr`, `en` | `usec`, `usec-watch`, `quota_gate.sh` dans `~/.local` |
| `simple` | skill `/simple:simple` : rejouer une explication ratée dans un registre concret | — | rien (profil dans `~/.config/remia-tooling/simple/`) |
| `voxtunnel` | skill d'installation et de diagnostic de [Voxtunnel](https://github.com/remmmi/voxtunnel) (le micro du poste vers un serveur, par SSH) | — | rien d'automatique : l'application s'installe par le skill, à la demande |

Détail de chaque outil : le README de son dossier (`remia/`, `rename_herdr/`, `usec/`, `skills/simple/`).

Hors marketplace, installés à la main depuis un clone : [`prismText`](prismText/) (réécriture de textes
par prismes) et [`ctrlmajMDTerm`](ctrlmajMDTerm/) (liens `.md` ouverts dans mdterm sous herdr).
[`claudeBridge`](claudeBridge/) est à revoir et n'est pas proposé.

## Installer une machine

Vaut pour une machine neuve comme pour une machine où les outils ont été installés à la main avant ce
système. Toutes les étapes sont idempotentes : en cas de doute, relancer.

### 0. Prérequis

| Prérequis | Contrôle | Sinon |
|---|---|---|
| Claude Code récent (testé sur 2.1.289) | `claude --version` | `claude update` |
| `git`, `python3` | `command -v git python3` | paquets de la distribution |
| accès SSH à ce dépôt **sans mot de passe** | `git ls-remote git@github.com:remmmi/remia-tooling.git HEAD` | autoriser la clé de la machine sur le dépôt ; les mises à jour se font sans terminal, un mot de passe les bloquerait |
| systemd utilisateur (pour `rename-herdr`) | `systemctl --user is-system-running` répond `running` ou `degraded` | `sudo loginctl enable-linger $USER` |

Par outil : `rename-herdr` demande herdr ≥ 0.8 avec son intégration Claude (`herdr integration status`
→ `claude: current`) ; `usec` demande un abonnement Claude (pas une clé API).

### 1. Marketplace, mise à jour automatique, plugin `remia`

```bash
git clone --depth 1 git@github.com:remmmi/remia-tooling.git /tmp/remia-tooling   # ou git pull dans un clone existant
/tmp/remia-tooling/bootstrap.sh
```

`bootstrap.sh` vérifie les prérequis (et s'arrête sans rien modifier s'il en manque un), ajoute la
marketplace, active sa mise à jour automatique, installe le plugin `remia`, puis affiche l'état de la
machine et la suite. Le clone peut être supprimé ensuite : Claude Code tient le sien dans
`~/.claude/plugins/marketplaces/remia-tooling/`.

À la main, c'est l'équivalent de :

```bash
claude plugin marketplace add git@github.com:remmmi/remia-tooling.git
# /plugin → Marketplaces → remia-tooling → Enable auto-update   (coupée par défaut pour une marketplace tierce)
claude plugin install remia@remia-tooling
```

### 2. Migrer ce qui avait été installé à la main

Seulement si l'état affiché par `bootstrap.sh` contient des lignes `à la main : …`. Ces restes feraient
doublon avec les plugins (alertes de quota en double, skills en double).

```bash
R=~/.claude/plugins/marketplaces/remia-tooling/remia/bin/remia-tooling
$R migrate --dry-run    # la liste de ce qui serait retiré : la montrer à l'utilisateur
$R migrate              # avec son accord
```

`migrate` sauvegarde d'abord (`~/.config/remia-tooling/sauvegarde/<date>/`), puis retire les skills
copiés dans `~/.claude/skills/` (`simple`, `rename-herdr`), les hooks `usec-watch` et le hook de version
de rename_herdr dans `~/.claude/settings.json`, et le bloc usec de `~/.claude/CLAUDE.md`. Le profil et
le journal de `simple` sont reportés dans `~/.config/remia-tooling/simple/`. Les scripts de `~/.local`
et l'unité systemd restent en place. La commande finit par afficher les installations à lancer, avec
les réglages qu'avait la machine.

### 3. Installer les plugins

Ceux qu'affiche `migrate`, ou au choix :

```bash
claude plugin install rename-herdr@remia-tooling --config target=tab    # ou pane, ou both
claude plugin install usec@remia-tooling --config lang=fr               # ou en
claude plugin install simple@remia-tooling
claude plugin install voxtunnel@remia-tooling
$R decide <plugin> oui     # pour chaque plugin installé ; « non » pour un plugin refusé : il ne sera plus proposé
```

Dans Claude Code, la même chose se fait par `/plugin` → onglet Discover. Un plugin ni installé ni
refusé est proposé par `remia` au démarrage de session suivant.

### 4. Ouvrir une nouvelle session Claude, et vérifier

Les hooks d'un plugin se chargent au démarrage d'une session ; c'est ce démarrage qui pose les scripts
et l'unité systemd. Un message `[remia-tooling] <plugin> X.Y.Z mis en place` apparaît pour chaque outil.

```bash
$R status                                                    # tout « à jour », plus aucune ligne « à la main »
cat ~/.config/remia-tooling/rename-herdr/installed-version   # version et cible mises en place
systemctl --user is-active rename-herdr.path                 # active
usec --version && usec-watch status                          # version du plugin, dernier relevé
```

Puis `/rename essai` dans une session ouverte sous herdr : l'onglet suit. `/simple:simple` figure dans
la liste des skills.

## Au quotidien

| Besoin | Geste |
|---|---|
| voir, installer, désactiver un plugin | `/plugin` |
| changer un réglage | `/plugin` → le plugin → Configure ; pris en compte au démarrage de session suivant |
| savoir où en est la machine | demander « où en est remia-tooling ? », ou `remia-tooling status` |
| nouveau plugin dans le dépôt | proposé au démarrage de session ; la réponse est mémorisée |
| revenir sur un refus | `remia-tooling decide <plugin> oubli` |
| forcer une mise à jour tout de suite | `claude plugin marketplace update remia-tooling && claude plugin update <plugin>@remia-tooling`, puis nouvelle session |
| retirer un outil | désactiver le plugin dans `/plugin`, puis nettoyer (plus bas) |

Dans une session, `remia-tooling` est dans le PATH de l'outil Bash. Hors session :
`~/.claude/plugins/marketplaces/remia-tooling/remia/bin/remia-tooling`.

## Comment ça marche

```
dépôt (ce dépôt, + github.com/remmmi/voxtunnel pour le plugin voxtunnel)
   │  .claude-plugin/marketplace.json : la liste des plugins et où les prendre
   ▼
Claude Code, au démarrage (mise à jour automatique activée)
   │  met à jour son clone de la marketplace, puis les plugins installés dont la version a monté
   ▼
~/.claude/plugins/cache/remia-tooling/<plugin>/<version>/      une copie par version
   │  la session suivante charge cette copie : skills, hooks, réglages
   ▼
hook SessionStart du plugin (rename-herdr, usec)  →  hooks/plugin-setup.sh
   │  compare « version + réglages » au témoin ~/.config/remia-tooling/<plugin>/installed-version
   │    identique : ne fait rien (une lecture de fichier)
   │    différent : lance l'install.sh de l'outil, écrit le témoin, le dit en une ligne
   │    échec     : le dit avec la raison, réessaie à la session suivante ; ne bloque jamais la session
   ▼
la machine : ~/.local/bin, unité systemd utilisateur
```

Trois conséquences à connaître :

- **La version de `plugin.json` commande tout.** Claude Code ne met un plugin à jour que si elle a
  monté ; l'outil n'est remis en place que si elle diffère du témoin.
- **Une nouvelle version arrive en deux démarrages** : le premier télécharge la mise à jour, le
  suivant la charge et remet l'outil en place.
- **Activer un plugin vaut accord pour sa mise en place.** Elle n'écrit que dans `~/.local`,
  `~/.config/systemd/user` et `~/.config/remia-tooling`, sans `sudo`. Exception : `voxtunnel`, dont
  l'application demande `sudo` et un module noyau ; son plugin n'installe rien, son skill le fait à la
  demande.

Le plugin `remia` n'installe et ne met à jour rien. Il lit le clone de la marketplace et
`~/.claude/plugins/installed_plugins.json`, et parle par deux hooks : au démarrage (plugin jamais
proposé, reste d'installation à la main, mise à jour automatique coupée) et quand un message mentionne
remia-tooling (au plus une fois par heure et par session). Il se tait quand il n'a rien à dire.

### Où sont les choses sur une machine

| Chemin | Contenu | Tenu par |
|---|---|---|
| `~/.claude/plugins/marketplaces/remia-tooling/` | clone de ce dépôt | Claude Code |
| `~/.claude/plugins/cache/remia-tooling/` | les plugins installés, une copie par version | Claude Code |
| `~/.claude/settings.json` | `extraKnownMarketplaces` (marketplace, `autoUpdate`), `enabledPlugins`, `pluginConfigs` (réglages) | Claude Code, `bootstrap.sh` pour `autoUpdate` |
| `~/.config/remia-tooling/<plugin>/installed-version` | témoin de mise en place : version et réglages | `plugin-setup.sh` |
| `~/.config/remia-tooling/decisions.json` | oui/non mémorisés | `remia-tooling decide` |
| `~/.config/remia-tooling/simple/` | profil et journal du skill `simple` | le skill, avec accord |
| `~/.config/remia-tooling/sauvegarde/<date>/` | ce que `migrate` a retiré | `remia-tooling migrate` |
| `~/.local/bin/herdr-session-name-sync`, `~/.config/systemd/user/rename-herdr.*` | rename_herdr | son `install.sh` |
| `~/.local/bin/usec`, `usec-watch`, `~/.local/share/usec/`, `~/.local/state/usec/` | usec et son historique | son `install.sh`, `usec-watch` |

## Retirer un outil

Désactiver ou désinstaller un plugin arrête ses hooks et retire ses skills, mais laisse ce que sa mise
en place a posé. Pour nettoyer, plugin désactivé :

```bash
"$(remia-tooling path)/rename_herdr/install.sh" --uninstall   # unité systemd, script, état
"$(remia-tooling path)/usec/install.sh" --uninstall           # scripts, porte quota, état
```

Tout retirer d'une machine : `claude plugin uninstall <plugin>@remia-tooling` pour chacun, les deux
commandes ci-dessus, `claude plugin marketplace remove remia-tooling`, puis `rm -rf ~/.config/remia-tooling`.

## Dépannage

| Symptôme | Cause probable | Faire |
|---|---|---|
| `mise en place en échec` au démarrage | prérequis de l'outil manquant ; la fin de la sortie d'`install.sh` est dans le message | corriger, ouvrir une session ; détail : `<clone>/<outil>/install.sh --check` |
| plugin installé mais outil absent ou ancien | session ouverte avant l'installation, ou témoin en avance sur la machine | nouvelle session ; sinon supprimer `~/.config/remia-tooling/<plugin>/installed-version` et rouvrir |
| la machine ne suit plus le dépôt | mise à jour automatique coupée (`remia-tooling status` le dit), ou clé SSH refusée | relancer `bootstrap.sh` ; tester `git ls-remote` du prérequis |
| alertes de quota en double | hooks `usec-watch` restés dans `settings.json` | `remia-tooling migrate usec` |
| un réglage changé n'a pas d'effet | il se lit au démarrage de session | nouvelle session |
| `remia-tooling` introuvable | session ouverte avant l'installation de `remia` | chemin complet (plus haut), ou nouvelle session |
| un plugin refusé devrait être reproposé | refus mémorisé | `remia-tooling decide <plugin> oubli` |

## Faire évoluer le dépôt

```
.claude-plugin/marketplace.json   la marketplace : 4 plugins en chemins relatifs, voxtunnel en source externe
bootstrap.sh                      mise d'une machine sur la marketplace
lib/plugin-setup.sh               hook de mise en place commun ; copié dans rename_herdr/hooks/ et usec/hooks/
tests/check.sh                    contrôle avant de pousser
remia/  rename_herdr/  usec/  skills/simple/     un dossier par plugin (.claude-plugin/plugin.json, hooks/, skills/)
docs/superpowers/specs/           la conception de ce système
```

Publier une modification d'un outil :

1. modifier, puis **monter la version** partout où l'outil la porte (`plugin.json`, le script, le
   `SKILL.md`) et ajouter la ligne au tableau « Versions » de son README. Sans montée de version, aucune
   machine ne reçoit la modification ;
2. `lib/plugin-setup.sh` modifié : le recopier dans `rename_herdr/hooks/` et `usec/hooks/`, et monter la
   version de ces deux plugins ;
3. `tests/check.sh` : versions cohérentes, copies identiques, manifestes valides
   (`claude plugin validate`), autotests, rien de personnel dans les fichiers distribués. Attendu : `0 KO` ;
4. pousser sur `main`. Les machines suivent à leurs deux prochains démarrages de session.

Ajouter un outil : un dossier avec `.claude-plugin/plugin.json`, une entrée dans
`.claude-plugin/marketplace.json`, `"dependencies": ["remia"]` pour que `remia` vienne avec. Un outil qui
pose des fichiers sur la machine fournit un `install.sh` idempotent (avec `--uninstall`) et un hook
`SessionStart` qui appelle une copie de `lib/plugin-setup.sh`. `remia` le proposera de lui-même sur
chaque machine.

Le plugin `voxtunnel` vit dans le dépôt public de Voxtunnel (dossier `claude-plugin/`), d'où la
marketplace le prend par une source `git-subdir`. Sa version suit celle de l'application ; un test de
ce dépôt-là le vérifie.
