---
name: prismtext
description: Transformer un texte existant (page web, fiche, email, doc) par un ou plusieurs prompts versionnes (prismes) en garantissant une bijection de concepts avec la source, produire des variantes comparables, les faire valider par un humain puis les publier via l'adaptateur du projet. Utiliser des que l'utilisateur veut reecrire, reformuler, "passer un prompt sur", decliner en variantes, comparer plusieurs versions d'un texte deja en place, ou lance /prismtext. Ne pas utiliser pour rediger un texte ex nihilo.
---

# PrismText : executer une transformation

PrismText separe trois roles. Le **moteur** (CLI `prismtext`) est deterministe : il assemble la consigne, verifie la bijection, produit le rapport. Le **LLM** (toi) ne fait qu'une chose : ecrire les `result.json`. Les **adaptateurs** du projet hote lisent et ecrivent la source reelle. Tu n'edites jamais la source a la main : tout passe par l'adaptateur.

## 0. Prealables

```bash
PT="$(command -v prismtext || echo "node $(cat ~/.config/prismtext/home)/engine/cli.mjs")"
$PT describe          # rappel du deroule et des commandes
cat .prismtext/config.json
```

Pas de `.prismtext/config.json` dans le projet : PrismText n'y est pas installe. Lance le skill `prismtext-install` et arrete-toi la.

## 1. Cadrer (une seule question groupee si necessaire)

Il te faut : l'adaptateur et la `ref` de la source, le ou les prismes (ou une chaine de `config.chains`), le nombre de variantes. Deduis ce qui est evident de la demande. Pour le reste, un seul AskUserQuestion. Un prisme se cherche dans `prisms_dirs`, puis dans `<PRISMTEXT_HOME>/prisms`. Si l'utilisateur fournit un nouveau prompt, cree-le comme prisme (`prisms/_modele.md` du depot, version `1.0.0`) dans `.prismtext/prisms/` avant de l'utiliser : un prompt non versionne ne passe jamais dans le moteur.

## 2. Extraire

```bash
RUN=$($PT run .prismtext/runs)                       # dossier d'audit horodate
<commande extract de l'adaptateur, {ref} et {input}=$RUN/input.json>
$PT validate $RUN/input.json
```

Fusionne `adapters.<nom>.context` dans `input.context` si l'adaptateur ne l'a pas fait.

## 3. Transformer (le seul pas LLM)

Pour chaque variante (a, b, c... une par prisme, ou plusieurs tirages d'un meme prisme) :

```bash
$PT prompt <prisme.md> $RUN/input.json --variant a > $RUN/prompt-a.md
```

Lis `prompt-a.md` en entier et applique-le comme une consigne autonome. Ecris `$RUN/result-a.json`. Regles dures :
- `cible` de chaque concept = copier-coller exact d'un passage du segment cible ;
- un concept abandonne = `cible: null` plus un `motif` qui cite la regle du prisme ; jamais d'abandon silencieux ;
- le tampon `prism` est recopie tel que `prompt` l'affiche.

Si plusieurs variantes sont demandees, delegue-les a des sous-agents en parallele (un par variante, chacun recoit le chemin de son prompt et de son result).

## 4. Passe inverse (verificateur independant)

La variante est relue par un agent qui ne l'a PAS ecrite : lance un sous-agent par variante, avec pour seule consigne de lire `$RUN/inverse-prompt-a.md`, de l'appliquer et d'ecrire `$RUN/inverse-a.json`. Ne lui transmets ni la carte des concepts ni ton avis. Si aucun sous-agent n'est disponible, fais-la toi-meme dans un contexte neuf et signale-le dans le rapport final.

```bash
$PT inverse $RUN/input.json $RUN/result-a.json > $RUN/inverse-prompt-a.md
```

## 5. Controler

```bash
$PT check $RUN/input.json $RUN/result-a.json --inverse $RUN/inverse-a.json --prism <prisme.md>
```

Le controle se fait dans les deux sens : chaque idee de la source doit se retrouver dans la cible (carte des concepts), et chaque phrase de la cible doit avoir sa source (passe inverse). Un morceau sans source et non declare dans `ajouts` bloque. Pour lever ce blocage, deux voies : retirer l'ajout du texte, ou le declarer dans `ajouts` pour que l'humain tranche. Jamais en modifiant `inverse-a.json`.

Exit 1 : corrige le result (et lui seul), relance la passe inverse sur le result corrige, puis recontrole avec la version precedente en reference, au plus `gates.max_fix_rounds` fois (defaut 2). Au-dela, garde la variante en echec dans le rapport et dis-le.

```bash
cp $RUN/result-a.json $RUN/result-a.v1.json      # avant chaque correction
$PT check $RUN/input.json $RUN/result-a.json --inverse $RUN/inverse-a.json --previous $RUN/result-a.v1.json --prism <prisme.md>
```

Regles de correction, non negociables :
- **`concept-perdu`** : si le retrait est voulu par une regle du prisme, ajoute `motif` (la regle citee) et laisse le texte tel quel. Si c'est un oubli, retablis l'idee dans le texte.
- **Ne jamais retablir une idee que le prisme a retiree pour obtenir un controle vert.** Retablir est une decision humaine, prise a la relecture. `--previous` le bloque (`retrait-annule`).
- **`ajout-non-declare`** : retire l'ajout du texte, ou declare-le dans `ajouts` pour que l'humain tranche. Jamais en modifiant la carte inverse.
- Ne desactive jamais une regle de `protect` pour faire passer un controle.

Chaine de prismes : `$PT chain input.json result.json > input-2.json`, puis on reprend a l'etape 3 avec le prisme suivant. Le chainage refuse un result non conforme.

## 6. Faire valider par un humain

```bash
$PT report $RUN/input.json $RUN/result-*.json --out $RUN/rapport.md
<commande preview de l'adaptateur pour chaque variante, si elle existe>
```

Presente a l'utilisateur : le chemin du rapport, les URL ou chemins de preview, et pour chaque variante le nombre d'erreurs et d'alertes, puis les trois listes de la section Decisions du rapport, sans les melanger : retraits voulus par le prisme (a confirmer, rien n'est retabli par defaut), pertes sans motif, ajouts. Puis un AskUserQuestion : quelle variante appliquer (ou aucune). Si `gates.human_validation` est vrai (defaut), rien ne s'applique sans cette reponse.

## 7. Appliquer

```bash
<commande apply de l'adaptateur avec le result choisi>
<commande verify de l'adaptateur, si elle existe>
echo '{"choix":"a","par":"humain","le":"<date ISO>"}' > $RUN/decision.json
```

Termine par : ce qui a ete applique, la preuve de `verify`, le chemin du dossier de run. Le dossier de run est la trace d'audit : input, prompts, results, passes inverses, rapport, decision. Ne le supprime pas.

## Mode lot (plusieurs sources d'un coup)

Declencheurs : "toutes les pages", "tout le site", une liste de sources, "par lots". Meme deroule que ci-dessus, avec un dossier par source et un seul rapport.

1. **Perimetre.** `<commande list de l'adaptateur>` donne toutes les sources. Reformule le perimetre en une ligne (sources incluses, exclusions demandees) et fais-le confirmer par un AskUserQuestion s'il reste un doute.
2. **Avant.** `<before_batch>` avec `{lot}` = nom court du lot (ex. `copywriter-2026-09-29`). S'il echoue, arrete tout.
3. **Creer le lot.**
   ```bash
   LOT=$($PT lot .prismtext/runs <nom> <ref1> <ref2> ...)
   $PT lot-status $LOT          # a tout moment ; sert aussi a reprendre un lot interrompu
   ```
   Chaque source a son dossier `$LOT/<slug>/` : c'est un `$RUN` ordinaire pour les etapes 2 a 5.
4. **Extraire** toutes les sources (etape 2), dans l'ordre.
5. **Transformer en parallele.** Un sous-agent redacteur par source (par vagues de 5), chacun recoit : le chemin de `prompt-a.md`, le chemin ou ecrire `result-a.json`, et les regles dures de l'etape 3. Puis un sous-agent **verificateur different** par source pour la passe inverse (etape 4). Un redacteur ne verifie jamais son propre texte.
6. **Controler** chaque source (etape 5, boucle de correction comprise), puis :
   ```bash
   for d in $LOT/*/; do $PT report $d/input.json $d/result-*.json --out $d/rapport.md; done
   $PT lot-report $LOT --out $LOT/rapport-lot.md
   ```
7. **Validation humaine.** Presente le tableau du rapport de lot et, pour chaque source, ses trois listes de decisions. AskUserQuestion : "Appliquer toutes les sources conformes", "Je choisis source par source" (l'utilisateur liste dans le chat), "Ne rien appliquer". Une source non conforme ne s'applique jamais en bloc. Enregistre chaque choix : `$PT decide $LOT/<slug> <a|aucune>`.
8. **Appliquer** chaque source decidee : `<apply>` puis `<verify>` puis `$PT applied $LOT/<slug> a` (refuse sans decision humaine).
9. **Apres.** `<after_batch>` avec `{lot}` et `{lotdir}` (build, commit, tag "apres" : rien de sortant).
10. **Publier** seulement sur accord explicite (AskUserQuestion) : `<publish>`.

Termine par le tableau de `lot-status`, les tags poses, la preuve de `verify` et de `after_batch`, et le chemin du rapport de lot.
