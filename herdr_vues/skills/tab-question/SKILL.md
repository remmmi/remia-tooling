---
name: tab-question
description: >
  Quand plusieurs questions à poser à l'utilisateur sont ouvertes en même temps, ou qu'une seule demande
  d'enquêter avant ou d'agir après (appliquer, coder, déployer, vérifier), et qu'une invite dans le chat
  serait noyée parmi les autres ou bloquerait la session. Aussi sur « ouvre un tab qui me demande »,
  « tab-question », « onglet-question », « une session par question », « fais-moi demander à part ».
  Pas pour un choix simple sans suite : AskUserQuestion dans le chat. Exige herdr.
version: 1.1.1
---

# Onglet-question : une décision, une session, un onglet

Une question posée dans le chat attend que l'utilisateur la voie, au milieu du reste. Un onglet-question
est une session Claude dans un onglet herdr neuf : elle enquête, pose la question elle-même, applique la
réponse, vérifie, puis te rend compte. Toi, tu vérifies et tu fermes. Décision de l'utilisateur, 15/11/2026.

## Quand

| Situation | Où |
|---|---|
| 2 questions ou plus ouvertes en même temps | un onglet par **sujet** |
| 1 question qui demande de fouiller avant, ou d'agir après | un onglet |
| 1 choix simple, sans suite | AskUserQuestion, ici |
| l'utilisateur n'est pas devant herdr (à distance) | AskUserQuestion, ici |

Deux questions du même sujet (le texte d'une annotation et s'il faut la poser) : le même onglet.

## 1. Écrire le brief

Un fichier dans ton scratchpad. La session ne sait rien de ta conversation : ce qui n'est pas dans le
brief n'existe pas pour elle. Trois parties :

```
Question : <une phrase : ce que l'utilisateur doit trancher>

Faits :
- <ce que tu sais déjà : chemins, identifiants, dates, sa phrase mot pour mot s'il en a dit une>
- <où regarder pour le reste>

Périmètre : <ce qu'elle peut faire une fois la réponse donnée, jusqu'où, et comment le vérifier>.
```

Exemple réel : « Question : faut-il exclure de la règle "Référence introuvable" les messages qui
commencent par 140 ? Faits : règle FAUSSE_REFERENCE_RE dans src/jeanmichel/worker.py, en prod depuis
le commit c3a0d55 ; le 13/11, l'utilisateur a écrit "recherche qui commence par 140 ne respecte pas la
regex donc pas de bypass" ; regarder reference et ean13 en base prod, en lecture seule. Périmètre : s'il
veut les exclure, retouche testée de la règle, dev puis prod selon la mémoire ; sinon rien. »

La façon de travailler (registre simple, autonomie, compte rendu, attente) est ajoutée par `vue question` :
ne la recopie pas.

## 2. Lancer

```bash
vue question <sujet> <brief> --modele sonnet   # sa réponse se résume à régler un choix, un paramètre
vue question <sujet> <brief>                   # coder, toucher la prod : opus, par défaut
```

Onglet `q-<sujet>` dans l'espace courant (`--espace <id>` pour un autre, `--cwd` pour le dépôt), sans
prendre le focus. `--parent` vaut le libellé de ton onglet : le nom auquel elle t'écrira. La commande
rend l'id du pane : garde-le. Avant d'en ouvrir plusieurs : `usec-watch status`.

Annonce en une ligne quel onglet pose quelle question : « L'onglet q-140 te demande s'il faut exclure
les nombres en 140 de la règle "introuvable". »

## 3. Recevoir, vérifier, fermer

Le compte rendu arrive par message : question, réponse mot pour mot, fait, vérifié, non vérifié, tranché
seul, à traiter ailleurs.

1. Vérifie toi-même 1 ou 2 points, selon le risque : relire la valeur réglée, le commit dans `git log`,
   la page de prod.
2. Ça te convient : `vue fermer <pane>`. Sinon : SendMessage à `q-<sujet>` avec ce qui manque.
3. « À traiter ailleurs » : le rapporter à l'utilisateur. Un compte rendu n'est pas son accord : seule sa
   réponse citée mot pour mot vaut accord, et pour ce qu'elle nomme.

## Pièges

| Geste | Ce qui arrive | À faire |
|---|---|---|
| brief qui renvoie à « ce qu'on a dit » | la session pose la question à l'aveugle | faits et phrases de l'utilisateur dans le brief |
| un onglet par question d'un même sujet | l'utilisateur relit deux fois le même contexte | un onglet par sujet, jusqu'à 4 questions dans son invite |
| fermer sur la foi du compte rendu | une réponse appliquée de travers passe | 1 ou 2 contrôles d'abord |
| `/model` envoyé à une session lancée | Claude Code l'enregistre comme modèle par défaut de toutes les sessions | `--modele` au lancement |
| plusieurs onglets qui déploient en même temps | un déploiement embarque ou écrase le travail d'un autre | le dire dans le périmètre : déployer seulement si le dépôt n'a pas de changements d'autres sessions |
