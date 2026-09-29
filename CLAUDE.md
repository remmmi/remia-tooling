# PrismText : ce que tu dois savoir en arrivant dans ce depot

PrismText transforme un texte deja en place (page web, fiche produit, email,
doc) par un prompt versionne, appele **prisme**, et garantit que la version
transformee dit la meme chose que la source : meme decoupage, memes liens,
aucun chiffre ni nom invente, chaque idee de la source retrouvee dans la cible
par une citation exacte, et chaque phrase de la cible rattachee a sa source par
un verificateur qui ne l'a pas ecrite (passe inverse). Plusieurs prismes sur un meme texte donnent plusieurs
variantes cote a cote : un humain choisit, puis la variante est publiee.

## Si on te demande d'installer PrismText

1. `./install.sh` (ou `./install.sh --project <dossier>`) : verifie Node >= 18,
   lance le selftest, pose les skills `prismtext` et `prismtext-install` et la
   CLI `prismtext`.
2. Dans le projet cible, lance le skill `prismtext-install` : il mene
   l'entretien (AskUserQuestion), ecrit les adaptateurs du projet et
   `.prismtext/config.json`, prouve l'aller-retour sans perte, et decrit l'outil
   dans le CLAUDE.md du projet.

`prismtext describe` (ou `--json`) donne a tout moment le deroule, les
commandes et les codes de sortie.

## Ce qui est dans le depot, et ce qui n'y est pas

- `engine/` : le moteur, Node sans dependance. Deterministe : il ne fait
  appel a aucun LLM. Commandes : `describe`, `validate`, `prism`, `prompt`,
  `inverse`, `check`, `report`, `chain`, `run`, `selftest`.
- `contract/` : schemas JSON de l'input (produit par un adaptateur), du result
  (produit par le LLM, une variante) et de la config d'un projet hote. Le
  contrat est versionne (`"prismtext": "1"`) ; tout changement incompatible
  monte ce numero.
- `prisms/` : prismes livres. `_modele.md` est le gabarit d'un nouveau prisme.
  L'empreinte SHA-256 d'un prisme est tamponnee dans chaque result.
- `adapters/reference-files/` : adaptateur de reference (fichier texte ou
  markdown, un segment par paragraphe). Modele de tout adaptateur.
- `skills/` : `prismtext` (executer une transformation), `prismtext-install`
  (brancher un projet).
- Les adaptateurs d'un projet ne sont **jamais** dans ce depot : ils vivent
  dans `.prismtext/adapters/` du projet hote. Le moteur ne sait rien de ce qui
  se trouve de l'autre cote.

## Invariants a ne pas casser

- Le moteur n'appelle aucun reseau et aucun LLM. La seule etape non
  deterministe est l'ecriture d'un result ; elle est isolee derriere la
  commande `prompt`, ce qui permet de la confier a Claude (skill) ou plus tard
  a un runner API, sans toucher au reste.
- Un concept source perdu sans `motif` est une erreur bloquante. Un concept
  retire avec `motif` est une alerte presentee a l'humain. Une citation `cible`
  introuvable dans le texte cible est une erreur : c'est le garde-fou contre
  une carte des concepts inventee.
- Passe inverse obligatoire : chaque phrase modifiee de la cible doit etre
  couverte (au moins la moitie de ses caracteres) par la carte inverse. Un
  morceau sans source non declare dans `ajouts` est une erreur. La carte
  inverse est produite par un agent qui n'a pas ecrit la variante.
- Rien ne s'applique a une source sans validation humaine
  (`gates.human_validation`).
- Codes de sortie : 0 conforme, 1 contenu non conforme, 2 usage ou contrat
  invalide. Les scripts et la CI s'appuient dessus.

## Travailler sur le moteur

```bash
npm test                          # suite node:test, zero dependance
node engine/cli.mjs selftest      # cas reel site-web : conforme + 8 defauts detectes
```

Les fixtures `tests/fixtures/site-web.*` viennent d'une vraie reecriture
(page /site-web/ de latelier-automatise.fr, prisme `copywriter-b2b` 1.0.0) :
toute evolution des controles doit continuer a accepter le cas conforme et a
detecter les huit defauts du cas casse.

Documentation au present uniquement : l'historique vit dans git.
