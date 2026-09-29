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
| Idee retiree avec un motif tire du prisme | non, signalee |
| Nom propre nouveau, chiffre deplace, ecart de longueur | non, signale |

Plusieurs prismes, ou plusieurs tirages, donnent plusieurs variantes dans un
seul rapport, cote a cote. L'humain choisit ; l'adaptateur du projet publie.

## Installer

```bash
git clone <depot> ~/outils/prismtext
~/outils/prismtext/install.sh
```

Puis, dans le projet ou vivent les textes, demander a Claude : « branche
PrismText sur ce projet ». Claude pose quelques questions (ou vivent les
textes, comment previsualiser, que declenche une validation) et ecrit les
adaptateurs propres au projet.

## Utiliser

« Passe le prisme copywriter-b2b sur la page contact », « fais-moi trois
variantes de la fiche produit X », « applique la chaine publication a
l'article Y ». Chaque run laisse sa trace dans `.prismtext/runs/<horodatage>/` :
source extraite, consignes, variantes, rapport, decision.

## Ajouter un prisme

Copier `prisms/_modele.md`, ecrire les regles, poser une version. Le prisme
peut vivre dans le depot (partage) ou dans `.prismtext/prisms/` d'un projet.

## Architecture

```
source reelle --[adaptateur: extract]--> input.json
input.json + prisme --[moteur: prompt]--> consigne --[LLM]--> result.json
input.json + result.json --[moteur: check, report]--> rapport --[humain]--> choix
result.json choisi --[adaptateur: preview / apply / verify]--> source reelle
```

Le moteur (`engine/`, Node >= 18, sans dependance) ne connait que le contrat
JSON (`contract/`). Les adaptateurs appartiennent au projet hote. Details pour
un agent : `CLAUDE.md`.
