---
name: prismtext
description: Transformer un texte existant (page web, fiche, email, doc) par un ou plusieurs prompts versionnes (prismes) en garantissant une bijection de concepts avec la source, produire des variantes comparables, les faire valider par un humain puis les publier via l'adaptateur du projet. Une page seule ou tout un lot. Utiliser des que l'utilisateur veut reecrire, reformuler, "passer un prompt sur", "prismer", decliner en variantes, comparer plusieurs versions d'un texte deja en place, ou lance /prismtext. Ne pas utiliser pour rediger un texte ex nihilo.
---

# PrismText : piloter une transformation

## Le principe qui commande tout le reste

Tu es le **pilote**. Tu ne lis, n'ecris ni ne corriges jamais un texte a transformer : ta conversation contient de la gestion (choix, decisions, reglages), et ce contexte ne doit pas deteindre sur une page. Tout le travail sur le texte est fait par des **agents isoles** :

- un **redacteur** par item et par variante : il recoit un seul fichier de consigne autonome (`brief`) qui contient le prisme, le contexte du projet, la page entiere telle que le visiteur la lit, tous les segments de l'item et le chemin du fichier a ecrire ;
- un **verificateur**, different du redacteur : il recoit la consigne de passe inverse (`inverse-brief`), qui ne montre que la source et la cible, jamais la carte du redacteur ;
- une **correction** est une nouvelle consigne (`brief` la produit tout seul quand la variante echoue au controle) confiee a un nouvel agent isole.

Lancement d'un agent isole, toujours avec ce texte et rien d'autre (outil Agent, type general-purpose, jamais un fork de toi-meme) :

> Lis le fichier `<chemin de la consigne>` et applique-le a la lettre. N'ouvre aucun autre fichier. Reponds seulement "fait".

Toi, tu ne lis que des verdicts courts : sortie de `check`, `lot-status`, tableau de `lot-report`. Les rapports detailles sont pour l'humain : donne-lui leur chemin.

**Coherence de l'item.** L'unite de travail est l'item entier (une page, pas un paragraphe) : un seul redacteur ecrit tous les segments d'une page d'un coup, en voyant les segments geles et le texte fixe du gabarit. Ne decoupe jamais un item entre plusieurs agents.

## 0. Prealables

```bash
PT="$(command -v prismtext || echo "node $(cat ~/.config/prismtext/home)/engine/cli.mjs")"
$PT describe
cat .prismtext/config.json
```

Pas de `.prismtext/config.json` : PrismText n'est pas branche sur ce projet. Lance le skill `prismtext-install` et arrete-toi la.

## 1. Cadrer

Il te faut : l'adaptateur, les refs (une ou plusieurs), le ou les prismes (ou une chaine de `config.chains`), le nombre de variantes. Deduis ce qui est evident ; pour le reste, un seul AskUserQuestion. Prismes : `prisms_dirs` de la config, puis `<PRISMTEXT_HOME>/prisms`. Un nouveau prompt fourni par l'utilisateur devient d'abord un prisme versionne (`prisms/_modele.md`) dans `.prismtext/prisms/`.

Une seule ref = un lot d'un item : meme deroule.

## 2. Deroule (un item ou un lot)

1. **Perimetre.** `<list>` de l'adaptateur donne toutes les refs. Reformule le perimetre en une ligne (inclus, exclus) ; AskUserQuestion s'il reste un doute.
2. **Avant.** `<before_batch>` avec `{lot}` = nom court du lot. En echec : arret.
3. **Lot.**
   ```bash
   LOT=$($PT lot .prismtext/runs <nom> <ref>...)
   ```
   Chaque item a son dossier de run `$LOT/<slug>/`. `$PT lot-status $LOT` dit a tout moment ou en est chaque item : c'est aussi le point de reprise d'un lot interrompu.
4. **Extraire** chaque item : `<extract>` avec `{input}` = `$LOT/<slug>/input.json`. L adaptateur y met le contexte du projet (`adapters.<nom>.context`) et la page rendue ; le pilote n ouvre pas l input.
5. **Rediger.** Pour chaque item et chaque variante :
   ```bash
   $PT brief <prisme.md> $LOT/<slug> --variant a
   ```
   puis un agent isole sur la consigne affichee. Items en parallele, par vagues de 5 agents.
6. **Verifier.** Pour chaque variante ecrite :
   ```bash
   $PT inverse-brief $LOT/<slug> --variant a
   ```
   puis un **autre** agent isole sur cette consigne.
7. **Controler.**
   ```bash
   $PT check $LOT/<slug> --variant a --prism <prisme.md>
   ```
   Exit 1 : `$PT brief <prisme.md> $LOT/<slug> --variant a` archive la variante et ecrit une consigne de correction (erreurs et regles de correction incluses) ; nouvel agent redacteur, puis nouvel agent verificateur (etape 6), puis controle. Au plus `gates.max_fix_rounds` corrections (defaut 2) ; au-dela, la variante reste en echec et tu le dis. Le controle compare automatiquement a la version precedente : une idee retiree par le prisme puis reintroduite par une correction bloque (`retrait-annule`).
   Chaine de prismes : `$PT chain $LOT/<slug> a $LOT/<slug>/etape-2`, puis etapes 5 a 7 sur ce nouveau dossier avec le prisme suivant.
8. **Rapports.**
   ```bash
   for d in $LOT/*/; do $PT report $d --out $d/rapport.md; done
   $PT lot-report $LOT --out $LOT/rapport-lot.md
   ```
   `<preview>` pour chaque variante si l'adaptateur en a une.
9. **Validation humaine.** Montre le tableau de `lot-report` (pas les textes), le chemin de `rapport-lot.md` et des rapports par item, et les chemins de preview. AskUserQuestion : "Appliquer tous les items conformes", "Je choisis item par item" (l'utilisateur repond dans le chat), "Ne rien appliquer". Enregistre chaque choix : `$PT decide $LOT/<slug> <a|aucune>`. `decide` refuse une variante non conforme ; `--force` seulement si l'humain le demande explicitement pour cet item.
10. **Appliquer** chaque item decide : `<apply>`, `<verify>`, puis `$PT applied $LOT/<slug> a` (refuse sans decision humaine).
11. **Apres.** `<after_batch>` avec `{lot}` et `{lotdir}` : rien de sortant.
12. **Publier** seulement sur accord explicite (AskUserQuestion) : `<publish>`.

Termine par : le tableau de `lot-status`, la preuve de `verify` et de `after_batch`, le chemin du rapport de lot. Le dossier du lot est la trace d'audit (consignes, versions, cartes inverses, controles, decisions) : ne le supprime pas.
