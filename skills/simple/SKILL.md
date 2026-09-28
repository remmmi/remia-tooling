---
name: simple
description: >
  Rejouer la dernière explication dans un registre concret quand l'utilisateur ne
  l'a pas comprise. Déclenche sur /simple, et sur toute formulation
  d'incompréhension : "je comprends pas", "j'ai rien compris", "c'est quoi X",
  "réexplique", "de quoi tu parles", "et donc ?", "en clair", "tu parles de quoi",
  "je te suis pas", "redis-moi". N'ajoute JAMAIS de détail : change de registre.
---

<!-- PROFIL:DEBUT — rempli à l'installation (voir INSTALL.md), avec l'accord de l'utilisateur -->
## Profil de l'utilisateur

- **Niveau** : _(non renseigné)_
- **Stack du projet** : _(non renseignée)_
- **Ses couches, avec ses mots** : _(non renseignées)_
<!-- PROFIL:FIN -->

> Si le profil ci-dessus est encore « non renseigné », **proposer** d'abord de le remplir
> (procédure : `INSTALL.md`, à côté de ce fichier), puis appliquer le protocole. Ne jamais
> l'écrire sans l'accord de l'utilisateur.

Une fois renseigné, le profil règle le registre : niveau → quels termes définir d'office ;
stack → d'où tirer le « cas réel nommé » ; couches → le vocabulaire de l'étape 4.

L'utilisateur n'a pas compris le message précédent. La faute est du côté de l'explication,
pas de sa lecture. La réponse par défaut — répéter en plus détaillé, en plus rigoureux,
en plus long — **aggrave le problème**.

## La règle unique

> Ne pas re-expliquer. **Ré-ancrer.**

Une explication qui n'est pas passée ne repasse pas en ajoutant des mots. Elle repasse
en changeant de point d'entrée.

## Protocole en 4 temps

**1. Le verdict d'abord, en une phrase, sans condition.**
Ce que l'utilisateur doit savoir ou faire. Pas le mécanisme. Pas la nuance.
« Rien à faire de ton côté, c'est réglé. » / « Ça casse à l'étape de paiement depuis mardi. »
S'il n'y a pas de verdict ferme, le dire : « Je ne peux pas encore trancher — voilà pourquoi. »

**2. Un cas réel nommé.**
Pas un exemple générique, pas une métaphore. Un objet réel du projet avec son identifiant,
un enregistrement avec sa date, une URL qu'il peut ouvrir. Ce qu'on voit à l'écran avant,
ce qu'on voit après. Une métaphore **complète** un nom technique, elle ne le **remplace** jamais.

**3. Le mécanisme, en partant de ce que voit l'utilisateur final.**
Jamais en partant du nom d'une variable interne. `MAX_RETRY_SENTINEL` n'est pas un point
d'entrée ; « le client ne verra jamais ce message d'erreur » en est un.

**4. Le vocabulaire, calé sur ses couches à lui.**
Prendre les couches du profil (à défaut, repérer celles dans lesquelles l'utilisateur pense :
par exemple code, template, base de données, traduction, configuration, serveur) et dire dans
laquelle ça se passe, avec ses mots à lui. « C'est dans le code — ni le template, ni la base, ni la traduction. »

## Interdits pendant /simple

- Rallonger. Si la 1re version faisait 20 lignes, la 2e en fait 8.
- Un terme non défini au premier usage, même « évident » (`override`, `cache`, `seeder`, `hook`).
- Un sigle ou un nom interne au projet sans son rôle (nom de script, de fichier, identifiant nu).
- Un encart décoratif, un diagramme ASCII, un tableau qui n'apporte rien qu'une phrase ne dirait.
- « Comme je disais », « en fait », « pour être précis » — ce sont des marqueurs de re-explication,
  pas de ré-ancrage.

## Vérification avant d'envoyer

Trois questions, toutes à « oui » :

1. Les deux premières phrases suffisent-elles à savoir quoi faire ?
2. Chaque terme technique est-il défini à son premier usage, dans la phrase même ?
3. Y a-t-il au moins un objet réel nommé (identifiant, fichier, URL, date) que l'utilisateur
   peut aller voir ?

## Si ça rate deux fois

Ne pas tenter une troisième formulation. **Demander** : « Dis-moi où ça décroche —
le mot, la phrase, ou le pourquoi ? » Une question précise coûte moins cher qu'un
troisième pavé.
