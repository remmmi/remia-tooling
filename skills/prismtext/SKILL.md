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

## 4. Controler

```bash
$PT check $RUN/input.json $RUN/result-a.json --prism <prisme.md>
```

Exit 1 : corrige le result (et lui seul) puis recontrole, au plus `gates.max_fix_rounds` fois (defaut 2). Au-dela, garde la variante en echec dans le rapport et dis-le. Ne desactive jamais une regle de `protect` pour faire passer un controle.

Chaine de prismes : `$PT chain input.json result.json > input-2.json`, puis on reprend a l'etape 3 avec le prisme suivant. Le chainage refuse un result non conforme.

## 5. Faire valider par un humain

```bash
$PT report $RUN/input.json $RUN/result-*.json --out $RUN/rapport.md
<commande preview de l'adaptateur pour chaque variante, si elle existe>
```

Presente a l'utilisateur : le chemin du rapport, les URL ou chemins de preview, et pour chaque variante le nombre d'erreurs, d'alertes et chaque `concept-retire` avec son motif. Puis un AskUserQuestion : quelle variante appliquer (ou aucune). Si `gates.human_validation` est vrai (defaut), rien ne s'applique sans cette reponse.

## 6. Appliquer

```bash
<commande apply de l'adaptateur avec le result choisi>
<commande verify de l'adaptateur, si elle existe>
echo '{"choix":"a","par":"humain","le":"<date ISO>"}' > $RUN/decision.json
```

Termine par : ce qui a ete applique, la preuve de `verify`, le chemin du dossier de run. Le dossier de run est la trace d'audit : input, prompts, results, rapport, decision. Ne le supprime pas.
