# Installer / mettre à jour markitdown — procédure pour l'agent qui installe

**Chemin normal avec Claude Code : le plugin.** `claude plugin install markitdown@remia-tooling`, puis
une nouvelle session : le plugin apporte le skill et la règle, crée l'environnement Python et pose
`to-md`. La suite décrit l'installation depuis un clone, pour tout autre agent ou une machine sans
plugin. Ne pas cumuler les deux sur Claude Code (skill et règle en double).

À coller dans l'agent de la machine cible : « Installe (ou mets à jour) markitdown en suivant
`markitdown/INSTALL.md` du dépôt remia-tooling ». Relancer la même procédure = mise à jour (tout est
idempotent).

## 0. Déjà installé ?

`./install.sh --check` (depuis ce dossier) : environnement, version de markitdown, `to-md` comparé à
celui du dépôt. Tout `[ok]` : rien à faire, passer au §3 si le skill ou la règle manquent.

## 1. Prérequis

| Prérequis | Contrôle | Sinon |
|---|---|---|
| Python 3.10 ou plus récent | `python3 --version` | l'installer ; ou en désigner un autre : `MARKITDOWN_PYTHON=/chemin/python ./install.sh` |
| de quoi créer un environnement virtuel | `python3 -m venv --help` | Debian/Ubuntu : paquet `python3-venv` ; ou [uv](https://docs.astral.sh/uv/), que `install.sh` utilise s'il le trouve |
| `bash` | | Windows : WSL ou Git Bash (non testé) |
| accès à PyPI pendant l'installation | | derrière un proxy ou un miroir : variables habituelles de pip (`PIP_INDEX_URL`, `HTTPS_PROXY`) |

Aucun `sudo`, aucun paquet système, aucun secret, aucun compte. Si un prérequis manque, s'arrêter et
le dire à l'utilisateur : ne pas installer un paquet système sans son accord.

## 2. Installer l'outil

```bash
./install.sh
```

Crée `~/.local/share/markitdown/venv/` (350 Mo environ), y installe markitdown avec les formats
bureautiques, pose `~/.local/bin/to-md`. Compter une à deux minutes la première fois.

Si l'installeur signale que `~/.local/bin` n'est pas dans le `PATH` : appeler `~/.local/bin/to-md` par
son chemin, ou ajouter la ligne proposée à `~/.profile` après accord de l'utilisateur.

Tous les formats, transcription audio et YouTube compris (bien plus lourd) :
`MARKITDOWN_SPEC='markitdown[all]' ./install.sh`.

Vérifier : `./install.sh --check` tout `[ok]`, puis `to-md --version`.

## 3. Brancher le skill et la règle — seulement avec accord

L'outil seul ne change rien au comportement de l'agent : il lui faut le **skill** (la procédure
d'aiguillage) et la **règle** (courte, toujours en contexte, qui l'oblige à ouvrir le skill).
Où les mettre dépend de l'agent ; les deux options se cumulent.

| L'agent… | Faire |
|---|---|
| a un dossier de skills au format `SKILL.md` (`<dossier>/<nom>/SKILL.md`) | `./install.sh --skill-dir <dossier>` : copie `skills/markitdown/SKILL.md` dans `<dossier>/markitdown/` |
| lit un fichier d'instructions (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, règles de l'éditeur…) | `./install.sh --agents-md <fichier>` : insère la règle entre `<!-- markitdown:start` et `<!-- markitdown:end -->`, le reste du fichier intact, copie `.bak-markitdown` avant |
| n'a ni l'un ni l'autre | donner `skills/markitdown/SKILL.md` en contexte quand un document entre en jeu |

1. **Quel fichier, quel dossier** : ceux du compte de l'utilisateur plutôt que ceux d'un projet (les
   documents arrivent dans tous les projets). Demander en cas de doute.
2. Montrer à l'utilisateur la règle (`rule.md`) et l'endroit où elle ira.
3. Avec accord, lancer la commande. Relancer = remplacer, jamais dupliquer.
4. Sans dossier de skills, la règle renvoie à un skill que l'agent ne trouvera pas : mettre alors dans
   le fichier d'instructions, à la suite de la règle, le chemin du `SKILL.md` de ce clone.
5. Si le fichier contient déjà une règle markitdown **hors marqueurs** (écrite à la main), proposer de
   la supprimer pour ne pas en avoir deux versions.

## 4. Vérifier

- `./selftest.sh` finit sur `0 KO` (sans réseau ; `--full` refait une vraie installation à part).
- Une vraie conversion : `to-md <un PDF ou un .docx de la machine>`, puis lire le `.md` annoncé.
- Session suivante de l'agent : lui tendre un document et une question de fond. Il doit annoncer
  `[… => markitdown]` avant de convertir ; pour une demande de compression, `[… => PAS de markitdown]`.

## 5. Mettre à jour, retirer

- Mettre à jour : `git pull` dans le clone, puis les mêmes commandes qu'à l'installation.
- Retirer : `./install.sh --uninstall`, avec `--skill-dir` et `--agents-md` s'ils avaient servi.

## 6. Confidentialité

La conversion est locale, sans appel réseau. Rien de personnel dans ce dépôt : pas de nom, de chemin
de projet ni de document réel. Les documents convertis restent dans le dossier temporaire de la
machine : les y supprimer s'ils sont sensibles.
