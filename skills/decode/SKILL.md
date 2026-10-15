---
name: decode
description: >
  Faire comprendre à l'utilisateur, paragraphe par paragraphe, un texte technique écrit
  par quelqu'un d'autre : réponse de mainteneur, issue, PR, changelog, doc, message d'un
  autre agent ou d'un LLM. Déclenche sur /decode:decode, et sur "traduis-moi ça",
  "décode", "je comprends pas ce qu'il veut", "qu'est-ce qu'il dit", "explique-moi sa
  réponse point par point". Ne résume JAMAIS : chaque paragraphe est rendu.
version: 1.0.0
---

## Profil de l'utilisateur

Lire `~/.config/remia-tooling/simple/profil.md` (le profil du skill `simple`, partagé : niveau,
termes à définir d'office, stack, couches). Puis le glossaire propre à ce skill :
`~/.config/remia-tooling/decode/glossaire.md` (tournures déjà décodées). Fichiers absents : faire
sans, et proposer de les remplir à la fin (jamais sans accord).

## Ce que ce skill n'est pas

`simple` répare **ma** explication ratée, et raccourcit. `decode` fait comprendre le texte
**d'un autre**, et garde tout. L'utilisateur comprend les concepts ; ce qui bloque, ce sont les
raccourcis (idiomes de développeur, tournures de texte rédigé par une IA) et le code qu'il ne
connaît pas par cœur. Une règle « terse » ou « pas de récap » de ses instructions générales ne
s'applique pas ici : la complétude est la consigne.

## Protocole

**1. La source exacte, jamais de mémoire.** Récupérer le texte mot pour mot (API publique de la
forge, fichier, collage) **et** ce à quoi il répond (notre message précédent, l'issue d'origine) :
sans lui, ses allusions (« your two asides », « as today ») restent opaques.

**2. Contexte, 3 à 5 lignes.** Qui parle, à quoi il répond, ce qu'on lui avait demandé, avec
les noms réels (fichier, fonction, numéro d'issue).

**3. Paragraphe par paragraphe, dans l'ordre, sans en sauter.** Pour chacun :
- **sa phrase d'ouverture**, citée (le paragraphe entier s'il est court) ;
- **ce qu'il dit**, en français simple, phrases complètes ;
- **chaque raccourci décodé dans la phrase même** : idiome (« sharp edge », « reached the wire »),
  mot de métier (« caller », « contract », « entry point », « coerce »), sigle — sa définition en
  moins de 15 mots, entre parenthèses ou après un tiret, au premier usage ;
- **dans le code**, seulement quand ça éclaire l'enjeu : `fichier:ligne` vérifié par `grep -n`,
  l'extrait de 1 à 3 lignes qui porte le point, et ce qu'il fait concrètement (un exemple de
  valeur qui entre, ce qui sort) ;
- **pour nous**, si le paragraphe change quelque chose pour l'utilisateur ou son projet.

Une liste à puces de l'auteur se décode puce par puce. Un bloc de code de l'auteur se lit ligne
par ligne.

**4. Garder le ton.** Un compliment, un refus poli, une réserve, une concession, une question
qui attend une réponse précise : chacun est nommé pour ce qu'il est (« c'est un refus, adouci
par… »). Séparer toujours « il dit » de « j'en déduis » ; aucune intention prêtée sans le texte.

**5. Finir par « ce qu'il attend de toi »** : questions à répondre, décisions à prendre, gestes
promis de part et d'autre. Si une réponse existe déjà (brouillon), la nommer par son chemin.

## Forme

- Un fichier dans le projet, à côté de la source quand elle y est (ex. `docs/pr/<sujet>-traduit.md`),
  sinon dans le dossier de docs du projet ; pas dans le chat : il se relit à côté du texte d'origine.
- **Un paragraphe par ligne** (aucun retour à la ligne dur au milieu d'une phrase) ; titres `##` par
  paragraphe source, numérotés dans l'ordre.
- Le proposer ouvert dans un éditeur confortable s'il y a un terminal à côté, par exemple
  `nano --softwrap --atblanks --mouse --indicator --smarthome --zap --minibar --stateflags <fichier>`.
- Dans le chat : une ligne de verdict (où est le fichier), puis les 1 ou 2 points où le détour par
  le code change la compréhension. Rien d'autre.

## Vérification avant d'envoyer

1. Chaque paragraphe de la source a sa section (compter) ?
2. Chaque idiome ou mot de métier est-il défini à son premier usage, dans la phrase même ?
3. Chaque `fichier:ligne` cité a-t-il été vérifié par `grep -n` dans cette session ?
4. Rien de résumé, rien d'ajouté que l'auteur n'a pas dit sans la marque « j'en déduis » ?

## Après chaque /decode : apprendre (toujours avec accord)

- **Glossaire** — proposer d'ajouter à `~/.config/remia-tooling/decode/glossaire.md` les tournures
  décodées cette fois (`tournure · sens en français · exemple`). Une tournure déjà au glossaire est
  rappelée en 3 mots la fois suivante, plus définie en entier.
- **Profil** — un terme de métier qui revient : proposer de l'ajouter aux « termes à définir
  d'office » du profil de `simple`.
- Jamais de secret, de donnée client ni de nom de personne dans le glossaire.
