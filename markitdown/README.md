# markitdown — les documents non-markdown passent par un aiguillage

Un agent à qui l'on tend un PDF, un `.docx` ou un classeur Excel a deux mauvais réflexes : lire le
binaire brut, ou déverser le document entier dans son contexte. Ce skill impose une question avant
toute action : **le document est-il une source de contenu, ou l'objet du travail ?**

- **Source de contenu** (lire, chercher, citer, résumer, produire à partir du fond) : conversion en
  Markdown par [markitdown](https://github.com/microsoft/markitdown) de Microsoft, vers un fichier,
  puis lecture ciblée de ce fichier.
- **Opération sur le fichier** (éditer, compresser, convertir, expertiser) : le skill s'arrête et rend
  la main aux outils dédiés.

Dans les deux cas l'agent l'annonce en une ligne : `[recherche d'info dans le PDF => markitdown]`,
`[compression du PDF => PAS de markitdown]`.

## Installer

**Claude Code** : plugin `markitdown` de la marketplace `remia-tooling` (`/plugin`, ou
`claude plugin install markitdown@remia-tooling`), puis une nouvelle session. Le plugin apporte le
skill et la règle, crée l'environnement Python et pose `to-md`. Rien d'autre à faire.

**Tout autre agent** (ou Claude Code sans plugin) : dire à l'agent « installe markitdown en suivant
`markitdown/INSTALL.md` du dépôt remia-tooling ». La procédure tient en un `./install.sh`, plus deux
options pour brancher le skill et la règle là où l'agent les lit.

Prérequis : Python 3.10 ou plus récent, `bash`, un accès à PyPI le temps de l'installation. Ni `sudo`
ni paquet système. Linux et macOS ; sous Windows, par WSL ou Git Bash (non testé).

## Ce que la mise en place pose sur la machine

| Chemin | Contenu |
|---|---|
| `~/.local/share/markitdown/venv/` (ou `$XDG_DATA_HOME/markitdown/venv`, ou `$MARKITDOWN_VENV`) | environnement Python à part : markitdown et ses dépendances, 350 Mo environ |
| `~/.local/bin/to-md` | la commande de conversion |
| `~/.config/remia-tooling/markitdown/installed-version` | témoin de mise en place (plugin seulement) |

Le Python de la machine n'est pas touché. Retirer : `./install.sh --uninstall`.

## La commande `to-md`

```
to-md <fichier> [sortie.md]   convertit vers un fichier ; affiche son chemin, ses lignes et ses mots
to-md --stdout <fichier>      écrit le Markdown sur la sortie standard (petits fichiers)
to-md --version               version de to-md et de markitdown
```

Sans sortie nommée, le fichier va dans le dossier temporaire (`$TMPDIR`, sinon `/tmp`) sous le nom du
document. Une conversion en échec ne laisse ni fichier vide ni fichier tronqué. Codes de sortie :
0 converti, 1 fichier introuvable ou conversion en échec, 2 mauvais usage, 3 environnement absent.

Formats installés : PDF, Word, PowerPoint, Excel (`.xlsx`, `.xls`), Outlook (`.msg`), HTML, CSV, JSON,
XML, EPUB, ZIP. Transcription audio, YouTube et Azure Document Intelligence ne le sont pas
(dépendances lourdes) : `MARKITDOWN_SPEC='markitdown[all]' ./install.sh` les ajoute.

La conversion est locale : le document ne quitte pas la machine.

## Fichiers

| Fichier | Rôle |
|---|---|
| `.claude-plugin/plugin.json` | le plugin (nom, version) |
| `skills/markitdown/SKILL.md` | le skill : classer, annoncer, brancher, convertir puis lire |
| `rule.md` | la règle d'aiguillage, courte, qui renvoie au skill |
| `bin/to-md` | la commande ; dans le `PATH` des sessions Claude par le plugin, copiée dans `~/.local/bin` pour le reste |
| `install.sh` | environnement Python et `to-md` ; options `--skill-dir`, `--agents-md`, `--check`, `--uninstall` |
| `INSTALL.md` | procédure pour l'agent qui installe hors plugin |
| `hooks/hooks.json` | branche le hook `SessionStart` : mise en place puis règle |
| `hooks/setup.sh`, `hooks/plugin-setup.sh` | mise en place (copie de `lib/plugin-setup.sh`), qui appelle `install.sh` |
| `hooks/rule.sh` | injecte `rule.md` en contexte de session |
| `selftest.sh` | autotest dans un HOME jetable ; `--full` fait une vraie installation et de vraies conversions |

## Versions

`version` de `.claude-plugin/plugin.json`, `VERSION` dans `bin/to-md` et `version:` du frontmatter de
`SKILL.md`, montées ensemble (`tests/check.sh` le vérifie). La version de markitdown lui-même est
bornée dans `install.sh` (`SPEC`) : la changer, c'est monter la version du plugin.

| Version | Changements |
|---|---|
| 1.0.0 | Première version, en plugin de la marketplace : skill, règle en début de session, `to-md`, environnement Python hors du plugin. markitdown série 0.1 (0.1.6 ou plus récent). |

## Tester

`./selftest.sh` (sans réseau, quelques secondes) ; `./selftest.sh --full` (vraie installation, une à
deux minutes, dans un HOME jetable).
