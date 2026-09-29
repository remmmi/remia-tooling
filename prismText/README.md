# PrismText

Passer un texte existant a travers un ou plusieurs prompts de reecriture, et
etre sur que la nouvelle version dit la meme chose que l'ancienne.

Un **prisme** est un prompt de reecriture versionne (ex. `copywriter-b2b` :
sobre, concret, sans cliche commercial). PrismText decoupe la source en
segments, fait reecrire chaque segment par Claude selon le prisme, puis
**verifie** le resultat avant qu'un humain ne le voie :

| Controle | Bloquant |
| --- | --- |
| Chaque segment source a son segment cible, et inversement | oui |
| Liens, variables, tokens proteges identiques | oui |
| Aucun chiffre absent de la source | oui |
| Chaque idee de la source retrouvee par une citation exacte de la cible | oui |
| Chaque phrase de la cible rattachee a sa source par un verificateur independant | oui |
| Ajout d'idee declare (absente de la source) | non, signale |
| Idee retiree avec un motif tire du prisme | non, signalee |
| Nom propre nouveau, chiffre deplace, ecart de longueur | non, signale |

Plusieurs prismes, ou plusieurs tirages, donnent plusieurs variantes dans un
seul rapport, cote a cote. L'humain choisit ; l'adaptateur du projet publie.

## Installer

PrismText vit dans le dossier `prismText/` du depot remia-tooling :

```bash
git clone https://github.com/remmmi/remia-tooling.git
remia-tooling/prismText/install.sh
```

Les skills et la CLI installes sont des liens vers ce dossier : un `git pull`
du depot met tout a jour.

Puis, dans le projet ou vivent les textes, demander a Claude : « branche
PrismText sur ce projet ». Claude pose quelques questions (ou vivent les
textes, comment previsualiser, que declenche une validation) et ecrit les
adaptateurs propres au projet.

## Utiliser

« Passe le prisme copywriter-b2b sur la page contact », « fais-moi trois
variantes de la fiche produit X », « applique la chaine publication a
l'article Y », « prisme copywriter-b2b sur toutes les pages, en lot ». Chaque run laisse sa trace dans `.prismtext/runs/<horodatage>/` :
source extraite, consignes, variantes, rapport, decision.

## Ajouter un prisme

Copier `prisms/_modele.md`, ecrire les regles, poser une version. Le prisme
peut vivre dans le depot (partage) ou dans `.prismtext/prisms/` d'un projet.

## Architecture

```
source reelle --[adaptateur: extract]--> input.json
input.json + prisme --[moteur: brief]--> consigne autonome --[agent redacteur isole]--> result.json
input.json + result.json --[moteur: inverse-brief]--> consigne --[agent verificateur isole]--> inverse.json
dossier de run --[moteur: check]--> en echec : brief ecrit une consigne de correction, on reprend
dossier de run --[moteur: report, lot-report]--> rapport --[humain: decide]--> choix
result.json choisi --[adaptateur: preview / apply / verify]--> source reelle
```

Chaque agent ne recoit qu'un fichier de consigne : la page entiere (segments
et texte visible du gabarit), jamais la conversation qui pilote. Le moteur
(`engine/`, Node >= 18, sans dependance) ne connait que le contrat
JSON (`contract/`). Les adaptateurs appartiennent au projet hote. Details pour
un agent : `CLAUDE.md`.
