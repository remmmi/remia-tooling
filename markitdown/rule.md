<!-- markitdown:start — bloc géré par remia-tooling/markitdown, remplacé à chaque mise à jour -->
## Documents non-markdown : passer par le skill markitdown

Dès qu'un document non-markdown entre en jeu (PDF, Word `.docx`, Excel `.xlsx`/`.xls`, PowerPoint
`.pptx`, Outlook `.msg`, HTML, CSV, JSON, XML, EPUB, ZIP), appliquer le skill `markitdown` **avant
toute autre action sur ce fichier**. Il tranche et s'annonce en une ligne :

- **le document est une source de contenu** (lire, chercher, citer, résumer, produire quelque chose
  à partir du fond) : `[<cas> => markitdown]`, puis conversion en Markdown par `to-md` et lecture
  du `.md` produit ;
- **le fichier est l'objet du travail** (l'éditer, le compresser, le convertir, l'expertiser :
  métadonnées, structure interne, signatures, générateur) : `[<cas> => PAS de markitdown]`, puis
  les outils dédiés.

But : ne pas dépenser de contexte à lire du binaire brut, ni à déverser un document entier quand
une partie suffit.
<!-- markitdown:end -->
