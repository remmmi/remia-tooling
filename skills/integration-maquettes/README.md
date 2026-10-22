# integration-maquettes — vérifier une intégration contre sa maquette, par la mesure

Quand une maquette (Illustrator, PDF, Figma, image) a été intégrée en site ou en thème, l'agent ne
juge pas « ça ressemble » : il **mesure** la maquette et le site aux mêmes coordonnées, section par
section, **superpose** les deux, regarde l'image, rapporte les écarts en chiffres, corrige ce qui
compte et re-mesure. Déclenché par « compare le site à la maquette », « écarts maquette /
intégration », « c'est fidèle ? », « audit visuel », « pixel perfect », et en phase finale de `newWP`.

Hors marketplace, volontairement : l'usage est ponctuel (une fin d'intégration), le skill s'installe à
la main sur la machine où il sert, et `remia` ne le propose pas.

## Avant / après

> **À l'œil** — « L'en-tête est conforme, le logo respire un peu moins que sur la maquette. »
>
> **Mesuré** — maquette 1920 : logo 188 × 108 px, marges 6 px ; site : 225 × 129 px dans un en-tête de
> 120 px, le mot du bas coupé. Cause : une mesure faite sur un rendu à 1067 px remis à l'échelle. Sur
> 30 sections, quatre paragraphes absents, des titres 17 % trop grands, un formulaire à la moitié de sa
> taille, des boutons de la mauvaise couleur : rien de tout cela n'avait été vu à l'œil.

## Installer

Depuis le clone de la marketplace (`remia-tooling path`) :

```bash
ln -s "$(remia-tooling path)/skills/integration-maquettes" ~/.claude/skills/integration-maquettes
```

Nouvelle session ensuite. `superposer.py` demande Pillow (`pip install Pillow`) ; les mesures de
pixels dans le skill utilisent Pillow et numpy ; les rendus de `.ai`/`.pdf` utilisent `pdftoppm`
(poppler-utils).

## Fichiers

| Fichier | Rôle |
|---|---|
| `SKILL.md` | le skill : cadrer, mesurer section par section, rapporter, corriger, re-mesurer ; pièges |
| `superposer.py` | empile une section de maquette, la même section du site et leur différence dans une image |
| `selftest.sh` | autotest déterministe : frontmatter, nom, `superposer.py` sur deux images de synthèse, rien de personnel |

## Origine

Réécriture de `slice-web` (dépôt `daffa09/web-slicing-skills`, MIT), dont la boucle mesure /
superposition / cinq tours a servi telle quelle pour un premier audit. Réécrit pour la vérification
d'une intégration existante (le skill d'origine construit la page), avec le cadrage préalable (seuil,
exclusions, largeurs), le rapport chiffré avant correction, et les pièges rencontrés.

## Versions

`version:` du frontmatter de `SKILL.md`.

| Version | Changements |
|---|---|
| 1.0.0 | Première version. |

## Tester

`bash selftest.sh` — sans réseau ni `claude` ; saute le contrôle de `superposer.py` si Pillow manque.
