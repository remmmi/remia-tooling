---
name: markitdown
description: >
  Aiguillage pour TOUT document non-markdown (PDF, Word .docx, Excel .xlsx/.xls, PowerPoint .pptx,
  Outlook .msg, HTML, CSV, JSON, XML, EPUB, ZIP). Appliquer ce skill dès qu'un tel fichier entre en
  jeu, QUEL QUE SOIT le besoin : il tranche et branche tout seul. Cas SOURCE DE CONTENU (lire,
  chercher, citer, résumer le fond, ou produire quelque chose à partir du contenu : rédiger un
  article à partir d'un rapport PDF, écrire une fonction conforme à une norme fournie en PDF,
  répondre à une question dont la réponse est dans un .docx ou un .xlsx) : conversion en Markdown
  par markitdown (Microsoft), puis lecture du Markdown. Cas OPÉRATION SUR LE FICHIER (éditer,
  compresser, convertir vers un autre format, expertiser : métadonnées, structure, signatures,
  générateur qui a produit le fichier) : le skill s'arrête et rend la main aux outils dédiés.
  Il s'annonce en une ligne dans les deux cas. À utiliser même si l'utilisateur ne nomme pas
  markitdown et dit juste « ce document », « ce PDF », « ce tableau Excel », « cette présentation ».
version: 1.0.0
---

# markitdown : aiguillage des documents non-markdown

Ce skill est le **point d'entrée obligé** pour tout document non-markdown. Une fois ouvert, ne pas
revenir en arrière avant d'avoir (1) classé le besoin, (2) émis l'annonce, (3) continué ou arrêté en
conséquence. Il évite de dépenser du contexte pour rien : lire du binaire brut, ou déverser un PDF
entier quand trois pages suffisaient.

## Étape 1 : source de contenu, ou opération sur le fichier ?

La question n'est PAS « quel type de fichier ? » mais « **le document est-il une source de contenu,
ou l'objet du travail ?** ».

- **Source de contenu.** Ce qui compte est ce qui est *écrit dedans* : y chercher une information,
  citer, résumer, ou produire quelque chose à partir du fond (un article, une réponse, une fonction
  fondée sur une norme ou une spécification fournie en PDF).
- **Opération sur le fichier.** Le travail porte *sur le fichier lui-même* : l'éditer, le compresser,
  le convertir vers un autre format, ou l'expertiser (métadonnées, structure interne, signatures,
  outil qui l'a produit). Le fond textuel n'entre pas en ligne de compte.

## Étape 2 : annoncer la décision (une ligne, dans LES DEUX cas)

Avant de continuer ou de s'arrêter, émettre une ligne entre crochets, télégraphique, qui dit le cas
et la décision :

- `[recherche d'info dans le PDF => markitdown]`
- `[inspection du générateur du PDF => PAS de markitdown]`
- `[compression du PDF => PAS de markitdown]`

## Étape 3 : brancher

- **Source de contenu : continuer.** Convertir, puis exploiter le Markdown (section suivante).
- **Opération sur le fichier : s'arrêter.** Ne rien convertir, ce serait hors sujet et coûteux.
  Traiter la demande avec les outils dédiés (`pdfinfo`, `exiftool`, `qpdf`, `pikepdf`, `ghostscript`…).

## Convertir, puis lire

Un document réel est souvent volumineux : un PDF de 200 pages donne plus de 30 000 lignes de
Markdown. Le convertir **vers un fichier**, puis lire ce fichier :

```bash
to-md <fichier> [sortie.md]
```

- Sans second argument : écrit `<dossier temporaire>/<nom>.md`. La commande affiche le chemin du
  fichier produit, son nombre de lignes et de mots.
- Lire ensuite ce `.md` avec l'outil de lecture de fichiers. Au-delà de 1 500 lignes environ, ne pas
  le charger en entier : chercher dedans (`grep -n`), puis lire les tranches utiles.
- Fichier court, réponse immédiate (un CSV de quelques lignes, un `.docx` d'une page) :
  `to-md --stdout <fichier>` écrit le Markdown directement. En cas de doute sur la taille, passer
  par le fichier : le nombre de lignes dit s'il peut être chargé d'un coup.

`to-md` introuvable : essayer `~/.local/bin/to-md` (dossier absent du `PATH`). `to-md` qui répond
« environnement markitdown absent » (code 3), ou absent partout : l'outil n'est pas installé sur
cette machine, voir « Installer » plus bas. Ne pas contourner en lisant le binaire.

## Formats

| Pris en charge | Remarque |
|---|---|
| PDF | texte seulement : un PDF scanné (images de pages) ne donne rien d'utile sans OCR |
| Word `.docx`, PowerPoint `.pptx` | titres, listes et tableaux conservés ; mise en page perdue |
| Excel `.xlsx`, `.xls` | une section Markdown par feuille |
| Outlook `.msg` | en-têtes et corps |
| HTML, CSV, JSON, XML, EPUB | |
| ZIP | parcourt l'archive et convertit chaque fichier reconnu |
| images | métadonnées seulement ; pour *voir* une image, la lire avec l'outil de lecture d'images |

Non installés par défaut (dépendances lourdes) : transcription audio, sous-titres YouTube, Azure
Document Intelligence. Les ajouter : relancer `install.sh` avec `MARKITDOWN_SPEC='markitdown[all]'`.

## Limites

- **Lecture seule.** markitdown extrait ; il n'édite pas et ne produit ni PDF ni `.docx`.
- **Mise en page perdue.** Tableaux complexes, colonnes multiples, en-têtes et pieds de page peuvent
  sortir aplatis ou dans le désordre. Un chiffre lu dans un tableau converti se vérifie sur sa ligne
  et sa colonne avant d'être cité.
- **Aucun réseau à l'usage.** La conversion est locale ; le document ne quitte pas la machine.

## Installer

- **Claude Code, plugin `markitdown` de la marketplace `remia-tooling`** : rien à faire. Le plugin
  crée l'environnement Python et pose `to-md` au premier démarrage de session qui suit son
  installation. Environnement absent malgré cela : `remia-tooling status`, puis
  `"$(remia-tooling path)/markitdown/install.sh"`.
- **Tout autre agent, ou sans plugin** : suivre `INSTALL.md` du dossier `markitdown` du dépôt
  `remia-tooling`. En bref : `./install.sh` (Python 3.10 ou plus récent, sans `sudo`).

Contrôle : `to-md --version` donne la version de `to-md` et celle de markitdown.
