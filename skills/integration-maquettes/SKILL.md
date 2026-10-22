---
name: integration-maquettes
description: >
  Vérifier qu'une intégration (site, thème, page, écran) correspond à sa maquette, section par
  section, par mesure et superposition, puis corriger ce qui compte. Déclenche sur « compare le site
  à la maquette », « écarts maquette / intégration », « c'est fidèle à la maquette ? », « audit
  visuel », « pixel perfect », et en fin d'intégration d'une maquette (phase finale de newWP). Pas
  pour concevoir une maquette, ni pour une non-régression entre deux versions du même site.
version: 1.0.0
---

# Intégration de maquettes : vérifier par la mesure, pas à l'œil

L'œil compare des impressions : il laisse passer un logo coupé, un paragraphe absent, des titres 15 %
trop grands, et il se disperse sur sept pages. Ce qui tient l'attention sur les détails, c'est une
boucle courte et bornée : **mesurer** la maquette et le site aux mêmes coordonnées, **superposer**,
**regarder** l'image, **rapporter** en chiffres, **corriger**, **re-mesurer**. Section par section.

## 1. Cadrer avant de mesurer

- **La source, à l'échelle 1:1.** Rendre la maquette à la largeur de référence, en 1x : `.ai`/`.pdf` →
  `pdftoppm -png -scale-to-x <largeur> -scale-to-y -1` ; Figma → export 1x ; image → largeur ÷ facteur.
  Un rendu réduit puis remis à l'échelle fausse toutes les tailles (un logo mesuré 225 px pour 188).
  Extraire aussi le **texte** de la maquette (`pdftotext -layout`, calque texte) : c'est lui qui dira
  ce qui manque.
- **La cible, à la même largeur**, pleine page, images différées chargées (défiler avant la capture,
  ou capturer par tuiles de fenêtre). Le projet a souvent déjà un outil de capture : l'utiliser.
- **Le seuil**, demandé à l'utilisateur s'il ne l'a pas dit : pixel perfect (≤ 1 px) ou « au mieux »
  (écart ≤ 3 px ou ≤ 3 % non signalé).
- **Les exclusions**, écrites avant de commencer : décisions déjà prises (hauteur d'un hero, un texte
  changé exprès). Une erreur manifeste de la maquette (élément collé, doublon de texte) se signale et
  se tranche avec l'utilisateur, elle ne se copie pas.
- **Les largeurs.** La maquette n'existe souvent qu'à une largeur. Les autres (mobile, intermédiaire)
  se vérifient après correction sur un critère de cohérence : rien de cassé, rien de coupé.

## 2. Mesurer, section par section

Découper la page de haut en bas (en-tête, hero, chaque bloc, pied). **Aligner chaque section sur son
propre haut** : dès la première hauteur différente, tout ce qui suit dérive, et une superposition
pleine page ne montre plus rien.

Par section, dans cet ordre : hauteur ; marges gauche/droite du contenu ; tailles de texte ;
interlignes ; espacements verticaux ; dimensions des images, boutons, pictos ; couleurs ; présence de
chaque texte (contre le texte extrait) ; alignements ; casse et graisse.

- Côté **site** : styles calculés et boîtes (`getComputedStyle`, `getBoundingClientRect`) via le
  navigateur piloté, jamais une lecture du CSS (une règle lue n'est pas une règle appliquée).
- Côté **maquette** : pixels (Pillow + numpy). Taille d'une police : rapport des largeurs d'une même
  ligne rendue avec la même police, précis à 1 % ; sinon hauteur des capitales. Un bouton se trouve
  par sa couleur, une ligne de texte par ses rangées de pixels non blancs, un bloc par sa rupture de
  fond.
- **Superposer et regarder** :
  `python3 superposer.py maquette.png site.png --y-maquette 1004 --y-site 1000 --hauteur 900 -o section.png`
  empile maquette / site / différence. Noir = identique, clair = décalé. L'image se regarde ; le script
  ne juge pas.

## 3. Rapporter avant de corriger

Un fichier, pas le chat. Par page, un tableau par section :
`Élément | Maquette | Site | Écart | Gravité (fort / moyen / faible) | Superposition`.
Une ligne = une mesure, pas une impression. Puis le top des écarts visibles toutes pages, et les
écarts de **texte** à part (mot manquant, casse, ponctuation, doublon). Chaque écart est classé :
faux (à corriger), décision (déjà tranchée, on laisse), erreur de maquette (à trancher).

## 4. Corriger, puis re-mesurer

Par gravité. Après chaque lot : recapturer, re-superposer, re-mesurer les lignes touchées. Cinq tours
par section au plus ; au-delà, noter la cause et passer. Puis les autres largeurs. Puis consigner dans
le projet ce qui est laissé et pourquoi.

## Pièges rencontrés

| Piège | Ce qui se passe | Parade |
|---|---|---|
| Rendu de maquette à mauvaise échelle | toutes les tailles fausses dans le même sens | rendre à la largeur cible, vérifier sur un élément de taille connue (logo natif) |
| Règle CSS moins spécifique que celle de la mise en page du framework | la « correction » ne s'applique pas | mesurer le style calculé, pas lire le CSS |
| Capture pleine page avec images différées | zones vides prises pour des manques | défiler avant la capture, ou tuiles |
| Attributs inline stockés dans le contenu | le CSS ne les change pas | régénérer le contenu ou surcharger explicitement |
| Maquette incohérente avec elle-même | copier une erreur | signaler, trancher avec l'utilisateur, commenter dans le code |
| Comparer à l'œil « ça a l'air bon » | détails passés | pas de verdict sans chiffre ni superposition |

## Coût

Un audit complet (7 pages, 30 sections, mesures et superpositions) a coûté 190 k tokens sur un modèle
intermédiaire en sous-agent, rapport en fichier. Les corrections se font ensuite en direct, en CSS
court, et se re-mesurent une par une.
