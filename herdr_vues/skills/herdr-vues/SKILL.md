---
name: herdr-vues
description: >
  Ouvrir à côté de la session, dans un pane herdr (ou tmux), ce que l'utilisateur doit SAISIR, LIRE ou
  VOIR VIVRE, au lieu de le mettre dans le chat. Invoquer SANS attendre qu'on le demande dès que :
  il faut un secret (mot de passe, jeton, clé, htpasswd) → jamais dans le chat ; l'utilisateur doit
  coller un résultat venu d'ailleurs (relevé d'un autre outil, export) ; un texte de plus de ~15 lignes
  est à relire ou corriger (brouillon de mail, d'issue, de PR, réponse à envoyer, doc, texte et son
  décodage) ; une commande longue ou un log à suivre (deploy, import, tests, tail -f, watch, sous-agent).
  Aussi sur « montre-moi en entier », « affiche », « ouvre dans nano », « ouvre en pane », « pane
  token », « je veux voir », « surveille », « ferme les panes ». Outil : commande `vue`.
version: 1.0.0
---

# Vues : saisir, lire, montrer

Le chat est linéaire et périssable : il défile, et il est écrit après coup. Un pane reste sous les
yeux, on y écrit, il se met à jour tout seul. Trois verbes couvrent tout ce qui s'est présenté en deux
semaines d'usage. Chacun correspond à une sous-commande de `vue` (dans le PATH ; sinon
`~/.claude/plugins/cache/remia-tooling/herdr-vues/*/bin/vue`) :

| Verbe | Quand | Commande | Focus |
|---|---|---|---|
| **saisir** | l'utilisateur doit **fournir** un contenu : secret, collage d'un résultat obtenu ailleurs, ligne à ajouter dans un fichier | `vue saisir <fichier> "<quoi coller>" [--secret]` | oui : il doit agir |
| **lire** | l'utilisateur doit **lire ou corriger** un texte long : brouillon, issue, PR, réponse à envoyer, texte + son décodage | `vue lire <fichier> [+N] [--numeros] [--sous <fichier2>]` | oui |
| **montrer** | quelque chose **vit dans le temps** : commande longue, log, `watch`, sous-agent | `vue montrer "<nom>" <commande…>` | **non**, jamais |

`vue` choisit seul la géométrie (à droite au-dessus de 120 colonnes, en dessous sinon), nomme le pane,
le lance dans le bon répertoire, et rend son identifiant. Sans herdr ni tmux, elle imprime la ligne
`! nano …` à proposer à l'utilisateur (code 3).

## 1. Le réflexe : ce qui n'a rien à faire dans le chat

Ce sont les ratés constatés, pas une théorie : à chaque fois, l'utilisateur a dû réclamer le pane.

- **Un secret ne passe jamais par le chat**, ni dans un sens ni dans l'autre. Ne pas demander de le
  coller, ne pas proposer `! cat <fichier de secret>` pour vérifier : ce qui s'affiche entre dans le
  transcript (un hash bcrypt de htpasswd y est entré ainsi).
- **« Montre-moi en entier », « affiche la réponse qu'on lui fait »** sur un texte long → `vue lire`,
  pas un bloc collé dans le chat.
- **Un résultat produit ailleurs** (prompt lancé dans un autre outil, export) → `vue saisir` sur le
  fichier à son **emplacement final** dans le projet, pas un collage dans la conversation.

À l'inverse, pas de vue pour ce qui se lit en une fois et tient en quelques lignes, ni pour ce que
l'utilisateur a dit ne pas vouloir voir (un « inutile de me montrer X » vaut pour les sessions
suivantes : le noter en mémoire). Un pane mange la moitié de son écran.

## 2. Saisir

```bash
vue saisir ~/.secrets/gandi_token "Colle le jeton API Gandi (ligne 2)" --secret
vue saisir docs/ref/releve_2026-10-17.md "Colle ici le relevé de Claude in Chrome"
```

- Fichier vide : `vue` pose une ligne de consigne `# vue: … — puis Ctrl+O, Entrée, Ctrl+X` (ou
  `<!-- vue: … -->` en Markdown/HTML) et place le curseur dessous. Fichier déjà rempli (htpasswd, `.env`
  existant) : ouvert tel quel, rien n'est écrasé.
- `--secret` : répertoire `700`, fichier `600` **avant** l'ouverture ; refusé si le fichier est dans un
  dépôt git sans y être ignoré. Lieu par défaut : `~/.secrets/<nom>`.
- Une variable à remplir : préparer `NOM=` sur la ligne 2 avant d'appeler `vue`, le fichier n'est alors
  plus vide et l'utilisateur complète.
- Plusieurs secrets d'un coup : un `vue saisir` par fichier, chacun dans son pane.

**Annoncer en une ligne** : quoi, où, comment finir. « Le pane de droite attend le jeton Gandi :
colle-le ligne 2, puis Ctrl+O, Entrée, Ctrl+X ; le pane se ferme tout seul. »

**Attendre sans bloquer.** Le pane se ferme quand l'utilisateur quitte nano : c'est le signal de fin.
Lancer `vue attendre <pane>` en arrière-plan (Bash `run_in_background`) pour être réveillé à la
fermeture. Jamais de `herdr pane wait-output` au premier plan : la session est gelée pendant que
l'utilisateur tape, et ce genre d'appel a déjà été refusé. Quand il dit « c'est fait », `vue etat
<pane>` tranche : `fermé` (enregistré et quitté), `nano ouvert` (pas fini).

**Vérifier, puis seulement ranger.**

- Secret : `vue secret <fichier>` donne les droits, la date de modification, la longueur par ligne,
  et signale les espaces (un mot de passe d'application Gmail collé avec ses 3 espaces) et les
  guillemets, avec une empreinte courte. Il ne montre jamais le contenu. Puis vérifier **par l'usage** :
  un appel dont on n'affiche que le code HTTP (200/401). Retirer la consigne avant l'usage :
  `vue nettoyer <fichier>`.
- Relevé : `vue nettoyer`, puis le lire avec Read par morceaux (`limit`). Un `cat` de 70 Ko sature la
  sortie.
- **KO** (401, longueur 0, espaces) : relancer `vue saisir` sur le même fichier, qui rouvre le contenu
  tel quel, et dire en une ligne ce qui cloche. Ne jamais supprimer ni fermer quoi que ce soit dans la
  même commande que la vérification : c'est ainsi qu'un jeton vide a été jeté avec son pane.

## 3. Lire

```bash
vue lire docs/pr/reponse-140.md +29          # ouvert sur le paragraphe qui compte
vue lire issue.md --sous issue-traduit.md    # l'original en haut, le décodage en dessous
vue lire brouillon.md --numeros              # « affiche les lignes »
```

- Options de confort toujours mises : retour à la ligne aux espaces, souris, position. Un texte écrit
  pour être lu dans nano s'écrit **un paragraphe par ligne**. Un retour à la ligne dur à 80 ou 120
  colonnes coupe les phrases au milieu.
- `*-traduit.md` (skill `decode`) : les couleurs `decode.nanorc` sont prises seules.
- `--sous` : deux panes neufs empilés, le focus sur celui du bas.
- L'utilisateur peut corriger dans le pane. Quand il dit qu'il a fini, **relire le fichier** avant d'en
  reparler : sa version prime sur la mienne.

## 4. Montrer

```bash
vue montrer "import cron" tail -f var/logs/import.log
vue montrer "tests" bash tools/test_plugins.sh
```

- **Une vue nommée, réutilisée** : `vue montrer` avec un nom déjà ouvert interrompt ce qui y tourne
  (ctrl+c), attend le prompt, relance. Pas six panes anonymes.
- Pour relire ce qu'il voit : `herdr pane read <pane> --source recent-unwrapped`. La sortie est du
  **texte brut** : pas de `jq` dessus. Pas de `--lines` par défaut : il compte les lignes blanches du
  bas et rend du vide sur un pane peu rempli.
- `watch` relit son script à chaque cycle : modifier le script suffit. Un `tail -f` ou un script lancé
  une fois ne se relit pas : relancer par `vue montrer` sur le même nom.
- Quand c'est fini et commenté : `vue fermer <pane>`.

## 5. Ranger

- Les panes nano se ferment seuls. Les vues `montrer` se ferment quand leur sujet est clos ; sur
  « ferme les panes », fermer **les miens** (ceux que `vue` a nommés dans cette session).
- `vue fermer` refuse un pane où nano est encore ouvert : l'utilisateur n'a peut-être pas enregistré.
  `--force` seulement s'il le demande.
- Ne jamais fermer un pane que je n'ai pas créé. Ne jamais arrêter le serveur herdr.

## 6. Hors du périmètre de `vue`

- **Une session Claude dans un pane ou un onglet** : skill `fk`. « Pas un pane, un tab » se respecte à
  la lettre. `herdr tab create … --focus` rend le pane sous `.result.root_pane.pane_id`, pas sous
  `.result.pane.pane_id`.
- **L'utilisateur n'est pas devant herdr** (« je suis en remote, je ne vois pas le fichier ») : le pane
  ne lui sert à rien, passer par un autre canal (fichier envoyé, mail).

## 7. Pièges herdr (constatés)

| Geste | Ce qui arrive | À faire |
|---|---|---|
| `herdr pane run` sur un pane où un programme tourne encore | le texte arrive dans le programme en collage : `[200~nano: command not found` | pane neuf (ce que fait `vue`), ou attendre le prompt (`vue etat` → `shell`) |
| `send-keys <pane> C-x` | code 0, rien ne se passe | `ctrl+x`, `alt+n` : la forme longue |
| `send-keys <pane> --help` | « unsupported key --help » : tout ce qui suit l'ID est une touche | `herdr pane send-keys --help`, sans ID |
| `pane close --pane <id>` | refusé | `herdr pane close <id>` (positionnel) |
| `pane split <id>` après d'autres options | « unknown option » | `--pane <id>` ou `--current` |
| `run`/`split --pane` sur un pane que l'utilisateur a fermé | `pane_not_found` | repartir de `--current` |
| `CLAUDE_CODE_CHILD_SESSION=1` hérité | un `claude` lancé dans le pane ne sauve pas son transcript | `vue` le vide (`--env`) ; à la main, `unset` |
| syntaxe devinée par symétrie | un aller-retour perdu à chaque fois (`--help` relu 7 fois en deux semaines) | `herdr --skill` et `herdr pane <cmd> --help`, ou passer par `vue` |
