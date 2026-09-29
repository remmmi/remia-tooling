# Écrire un adaptateur

Un adaptateur relie une source réelle (fichiers d'un site, CMS, API) au contrat PrismText. Il ne
réécrit jamais rien lui-même. Il vit dans le projet hôte (`.prismtext/adapters/<nom>/`), jamais
dans ce dépôt, et se déclare dans `.prismtext/config.json` (`contract/config.schema.json`).

## Commandes

| Commande | Variables | Obligatoire | Fait |
|---|---|---|---|
| `list` | | non (oui pour un lot) | affiche une ref par ligne : tout ce qui est transformable |
| `extract` | `{ref}` `{input}` | oui | écrit un input valide pour un item entier |
| `preview` | `{result}` `{ref}` | non | écrit la source recomposée à côté, sans toucher la source ; affiche un chemin ou une URL |
| `apply` | `{result}` `{ref}` | oui | réécrit la source ; refuse un result auquel il manque un segment |
| `verify` | `{ref}` | non | exit 0 si la source se relit correctement |
| `before_batch` | `{lot}` | non | avant un lot (build, tag « avant ») ; rien de sortant |
| `after_batch` | `{lot}` `{lotdir}` | non | après les apply (inventaire, build, commit, tag « après ») ; rien de sortant |
| `publish` | `{lot}` `{ref}` | non | la seule action sortante (push, déploiement), sur accord explicite |

`adapters.<nom>.context` porte le contexte du projet (public, support, objectif, voix).
L'adaptateur le fusionne lui-même dans `input.context` : le pilote n'ouvre jamais un input.

## Règles

1. **Un input = un item entier.** Une page, pas un paragraphe : un seul rédacteur écrit toute la
   page, c'est ce qui garantit sa cohérence.
2. **Ids stables.** Chemin de clé (`offre.cartes.2.texte`) ou numéro de paragraphe (`body.p003`).
3. **Geler plutôt qu'omettre.** Titres imposés, SEO, libellés d'interface, ancres de maillage
   prescrites, valeurs qui ressemblent à une clé, un chemin ou une URL : segments `freeze`.
   Les omettre priverait le rédacteur du sens de la page.
4. **Page rendue.** `context.rendu` = texte visible de l'item entier, dans l'ordre de lecture,
   gabarit compris (intertitres, libellés codés dans les gabarits). Lire le rendu construit
   (build, HTML publié) ; refuser d'extraire si le rendu est plus ancien que la source.
5. **Tout texte visible est soit un segment, soit dans le rendu.** Avant d'écrire l'adaptateur,
   inventorier le texte codé en dur (gabarits, composants, scripts) et proposer à l'utilisateur
   de sortir du code celui qui doit pouvoir être réécrit.
6. **Écriture chirurgicale.** Ne réécrire que les champs modifiés, à leur place, dans leur style
   d'origine. Après écriture : relire le fichier produit et comparer chaque valeur à l'attendu ;
   au moindre écart, ne rien écrire.
7. **Aucune logique de réécriture** dans un adaptateur.

## Prouver le branchement

Pour chaque ref de `list` : `extract`, `prismtext validate`, puis un result identité (chaque
segment recopié) passé à `preview` : le fichier produit doit être identique octet pour octet à la
source. C'est ce qui prouve que l'aller-retour ne perd rien.

## Ce qu'on a appris sur un site Astro (adaptateur `pages-astro`)

- Re-sérialiser un fichier YAML entier pour changer un champ a modifié la mise en forme de 9 pages
  sur 12 (guillemets, repli des lignes). Remplacer seulement le scalaire modifié, via sa position
  dans le fichier (`node.range` de la bibliothèque `yaml`), a rendu les 23 fichiers identiques
  à l'aller-retour.
- Bloc replié YAML (`>-`) : une ligne vide dans le fichier = un saut de ligne dans la valeur. Les
  valeurs avec espaces de tête, doubles espaces ou tabulations passent en chaîne entre
  guillemets doubles (le JSON est un sous-ensemble valide du YAML double-quoted).
- Sortir un texte codé en dur d'un gabarit vers un fichier de contenu doit rester neutre au rendu :
  comparer le HTML construit avant et après, page par page. Les écarts rencontrés venaient de
  l'échappement : dans une expression, Astro écrit l'apostrophe `&#39;` ; dans un attribut, `&`
  devient `&#38;`. Les valeurs calculées par la page doivent recevoir le même échappement.
- Texte généré par un script (phrases de résultat d'un calculateur) : le passer en données
  (attribut `data-*`) et prouver l'équivalence en exécutant l'ancien et le nouveau script sur les
  mêmes saisies, toutes branches couvertes.
- Un fichier qui ne contient que des libellés gelés (navigation, pied de page) n'a rien à
  réécrire : l'exclure de `list` pour qu'un lot n'y lance pas d'agent.
