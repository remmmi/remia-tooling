---
id: nom-du-prisme
version: 1.0.0
description: Une phrase - ce que ce prisme change dans un texte
entrees: public, support, objectif, voix, longueur, conserver
---
ROLE

Qui ecrit, pour qui.

MISSION

Ce que la transformation doit changer, et ce qu'elle ne doit jamais changer.

REGLES

Les regles de reecriture, numerotees : un controle humain doit pouvoir dire
si chacune est respectee.

SORTIE

Le format de sortie est fixe par le contrat PrismText : il remplace toute
autre consigne de forme.

VERIFICATEUR

(Optionnel.) Regles de jugement pour le verificateur inverse, chacune avec
le code a poser dans "probleme" quand elle est violee. Un module de controle
deterministe peut etre declare dans le frontmatter : check: <prisme>.check.mjs

Versionnage : toute modification du corps change l'empreinte SHA-256 tamponnee
dans les results. Monter la version (semver) a chaque changement de fond.
