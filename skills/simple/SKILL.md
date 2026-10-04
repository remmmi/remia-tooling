---
name: simple
description: >
  Rejouer la dernière explication dans un registre concret quand l'utilisateur ne
  l'a pas comprise. Déclenche sur /simple:simple, et sur toute formulation
  d'incompréhension : "je comprends pas", "j'ai rien compris", "c'est quoi X",
  "réexplique", "de quoi tu parles", "et donc ?", "en clair", "tu parles de quoi",
  "je te suis pas", "redis-moi". N'ajoute JAMAIS de détail : change de registre.
version: 1.1.1
---

## Profil de l'utilisateur

Avant d'appliquer le protocole, lire `~/.config/remia-tooling/simple/profil.md` : niveau, termes à
définir d'office, stack, couches de l'utilisateur. Le fichier est propre à la machine et survit aux
mises à jour du skill.

> Fichier absent, ou champ « non renseigné » : appliquer le protocole sans profil, puis **proposer**
> de le remplir (procédure : `INSTALL.md`, à côté de ce fichier). Ne jamais l'écrire sans l'accord de
> l'utilisateur.

Le profil règle le registre : niveau et termes à définir → ce qu'on explique d'office ;
stack → d'où tirer le « cas réel nommé » ; couches → le vocabulaire de l'étape 4.

L'utilisateur n'a pas compris le message précédent. La faute est du côté de l'explication,
pas de sa lecture. La réponse par défaut — répéter en plus détaillé, en plus rigoureux,
en plus long — **aggrave le problème**.

## La règle unique

> Ne pas re-expliquer. **Ré-ancrer.**

Une explication qui n'est pas passée ne repasse pas en ajoutant des mots. Elle repasse
en changeant de point d'entrée. **Une explication ratée longue se rejoue plus courte ; une explication
ratée courte et dense, en 6 phrases courtes et 110 mots au plus.** Les 4 temps ci-dessous tiennent souvent en une phrase chacun.

## Protocole en 4 temps

**1. Le verdict d'abord, en une phrase courte, sans condition.**
Ce que l'utilisateur doit savoir ou faire. Pas le mécanisme. Pas la nuance. Pas de parenthèse
ni de définition dans cette phrase : elles viennent après.
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

## Exemple

**Avant (raté)** : « Le cache d'opcodes n'était pas invalidé après le déploiement, donc le
worker FPM servait l'ancien bytecode ; un reload du master purge le segment partagé. »

**Après (ré-ancré)** : « Une commande à lancer et c'est réglé : `sudo systemctl reload php-fpm`.
Ce que tu voyais : la page `/panier` affichait encore l'ancien bouton alors que le fichier était
bien modifié. Pourquoi : le serveur garde en mémoire une copie des fichiers PHP pour aller plus
vite (c'est le « cache ») ; la commande vide cette copie. C'est côté serveur — ni le code, ni la
base. »

Verdict en tête, un objet réel (`/panier`, le bouton), le mécanisme vu depuis l'écran, un seul
terme technique défini dans la phrase même, la couche nommée. Trois lignes au lieu d'un pavé.

## Interdits pendant un ré-ancrage

- Rallonger. Si la 1re version faisait 20 lignes, la 2e en fait 8. Si elle tenait en une ou deux
  phrases denses, la 2e tient en **6 phrases courtes, 110 mots au plus** — on retire du jargon, on
  n'ajoute pas de chapitres. Pas d'intertitres ni de gras en cascade.
- Un terme non défini au premier usage, même « évident » (`override`, `cache`, `seeder`, `hook`).
- Un sigle ou un nom interne au projet sans son rôle (nom de script, de fichier, identifiant nu).
- Un encart décoratif, un diagramme ASCII, un tableau qui n'apporte rien qu'une phrase ne dirait.
- « Comme je disais », « en fait », « pour être précis » — ce sont des marqueurs de re-explication,
  pas de ré-ancrage.

## Vérification avant d'envoyer

Quatre questions, toutes à « oui » :

1. Les deux premières phrases suffisent-elles à savoir quoi faire ?
2. Chaque terme technique est-il défini à son premier usage, dans la phrase même ?
3. Y a-t-il au moins un objet réel nommé (identifiant, fichier, URL, date) que l'utilisateur
   peut aller voir ?
4. La longueur est-elle tenue (plus court que l'original s'il était long, sinon 6 phrases
   et 110 mots au plus) ? Sinon, couper :
   d'abord les précisions, jamais le verdict ni l'objet réel.

## Si ça rate deux fois

Ne pas tenter une troisième formulation. **Demander** : « Dis-moi où ça décroche —
le mot, la phrase, ou le pourquoi ? » Une question précise coûte moins cher qu'un
troisième pavé.

## Après chaque /simple : apprendre (toujours avec accord)

1. **Journal** — ajouter une ligne à `~/.config/remia-tooling/simple/journal.md` (le créer au besoin) :
   `AAAA-MM-JJ · ce qui a décroché (terme, phrase ou « le pourquoi ») · couche`.
   Jamais de secret, de donnée client ni de nom de personne. Le journal reste sur la machine.
2. **Profil qui s'enrichit** — si un terme précis a décroché, proposer en une ligne :
   « J'ajoute *X* aux termes que je définis d'office ? » Sur un oui, l'ajouter dans
   `profil.md`, ligne « Termes à définir d'office ».
3. **Récurrence** — si le même terme revient 3 fois ou plus dans le journal, le signaler :
   « *X* décroche souvent — on l'ajoute au glossaire du projet ? » (sans rien écrire d'autre
   que ce que l'utilisateur accepte).
