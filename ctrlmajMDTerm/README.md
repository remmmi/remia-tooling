# herdr-mdterm-pack : Ctrl+Maj+clic sur un .md -> tab herdr avec mdterm

Depuis un poste de travail Linux attache a un serveur via `herdr --remote <host>`, un Ctrl+Maj+clic sur
un chemin `.md` (texte brut, y compris dans la sortie de Claude Code) ouvre un nouveau tab herdr sur le
serveur avec `mdterm <fichier>`. mdterm est une visionneuse : lecture seule.

Le pack ne suppose aucun nom de machine, d'utilisateur, de port ni de distribution : tout est demande ou detecte.

## Utilisation

Un seul point d'entree, le meme sur toutes les machines :

```
tar xzf herdr-mdterm-pack.tar.gz && cd herdr-mdterm-pack
./setup.sh
```

Il demande :
1. **les protagonistes** : chaque machine en jeu, avec son role.
   `poste` = la machine devant toi, ou tu cliques. `vps` = le serveur ou tournent herdr et les `.md`
   (pour un vps : son acces SSH vu du poste, alias ou `user@adresse`, et le port si non standard).
   La liste est ecrite dans `~/.config/herdr-mdterm/protagonistes.conf`, sur la machine : le dossier du pack ne
   recoit aucun nom de machine, il reste diffusable tel quel.
2. **sur laquelle de ces machines il tourne en ce moment.**

Ensuite il ne suit pas une recette : il a une liste d'**objectifs** par role, verifie chacun pour de vrai,
ne fait que ce qui manque (apres accord), et re-verifie. Le relancer ne casse rien.
Sans terminal (lance par un agent, un cron) il ne pose aucune question : reponses par defaut, et seul `--yes` fait agir.

Le plus court : lancer `./setup.sh` **sur le poste seulement**. Si un vps n'est pas pret, il propose d'y copier
le pack et d'y lancer la partie vps a travers ssh. Tout ce qui est detectable l'est (port via `ssh -G`,
prefixe des chemins = `$HOME` distant, architecture, gestionnaire de paquets, terminal graphique).

| Commande | Effet |
|---|---|
| `./setup.sh` | questions, constat, actions proposees une par une |
| `./setup.sh --check` | constat seul, ne modifie rien : c'est le diagnostic quand "ca ne marche pas" |
| `./setup.sh --yes` | accepte sans demander les actions sans sudo (tout sudo reste demande) |
| `./setup.sh --role vps` | sans question, partie vps sur la machine courante |
| `./setup.sh --role poste --host H [--port N] [--prefix /home/u/]` | sans question, un seul vps |
| `./setup.sh --role poste` | sans question, tous les vps de `~/.config/herdr-mdterm/protagonistes.conf` |

## Objectifs verifies

Sur un **vps** : herdr present ; jq present ; mdterm present ; `herdr-open-md` + `mdlink` a jour dans `~/.local/bin` ;
ces commandes visibles par un shell de login a environnement vide (ce que fera le ssh du poste) ; essai reel
(tab de test ouvert puis referme).

Sur un **poste**, pour chaque vps declare : ssh sans mot de passe ; vps pret, avec `herdr-open-md` et `mdlink`
identiques a ceux du pack (sinon le pack est copie dans `~/.cache/herdr-mdterm/pack` du vps et sa partie vps y est lancee) ; `mdterm-open` + shim `xdg-open` a jour ;
ligne du vps dans `~/.config/herdr-mdterm/remotes` ; scheme `mdterm://` declare ; le terminal graphique resout bien
`xdg-open` vers le shim ; essai reel (clic simule au format du terminal, chemin complete d'espaces, tab referme
ensuite) ; le dernier vrai clic recu par le shim pour ce vps a ete relaye.

## Plusieurs VPS : ne rien effacer

Le shim `~/.local/bin/xdg-open`, `~/.local/bin/mdterm-open` et le fichier `~/.config/herdr-mdterm/remotes` sont
**partages par tous les VPS** deja configures sur le poste. Ajouter un VPS = ajouter une ligne a `remotes`.
`setup.sh` affiche les VPS deja beneficiaires, n'en retire et n'en modifie aucun.
A la main : ne jamais recreer `remotes` ni supprimer le shim pour "repartir propre", cela coupe les autres VPS.
Retirer un seul VPS = supprimer sa ligne dans `remotes`, rien d'autre.

Le poste choisit le VPS d'apres le **debut du chemin clique** (`/home/<user>/`). Deux VPS avec le meme nom
d'utilisateur ont le meme prefixe : la premiere ligne de `remotes` gagne. `setup.sh` detecte ce conflit et
s'arrete dessus ; la solution simple est un nom d'utilisateur distinct par VPS.

## Comment ca marche

```
terminal graphique (poste)  --Ctrl+Maj+clic sur /home/u/x.md-->  xdg-open /home/u/x.md
   Maj = le terminal garde la souris (herdr/Claude Code la captent sinon)
xdg-open (shim ~/.local/bin, prioritaire dans le PATH du terminal)
   .md absolu, absent en local, prefixe connu ? --> mdterm-open   (sinon vrai xdg-open, inchange)
mdterm-open  --ssh -p PORT HOST "bash -lc 'herdr-open-md <chemin>'"-->  vps
herdr-open-md (vps) : tab cree sans focus + "exec mdterm <chemin>" + focus  -> tab visible dans le client remote
```
Le scheme `mdterm://` (sortie de `mdlink <fichier>` sur le vps, lien OSC8) passe par le meme relais.

## mdterm : binaire precompile, pas de compilation

`setup.sh` pose le binaire officiel de la release GitHub `bahdotsh/mdterm` (statique musl, x86_64 ou aarch64),
version et sha256 epingles dans le script. Ni Rust ni chaine de compilation, quelques secondes.
La compilation (`rustup` + `cargo install`) n'est proposee que pour une architecture sans binaire publie ; elle
demande ~1,5 Go de RAM libre et peut declencher l'OOM killer sur un petit serveur de production sans swap.
Le script mesure la RAM disponible et previent.

## Pieges (tous rencontres pour de vrai)
1. **PATH du terminal graphique** : lance par la session graphique, il n'a souvent pas `~/.local/bin` -> le shim
   n'est jamais appele. Correctif propose : `sudo ln -sf ~/.local/bin/xdg-open /usr/local/bin/xdg-open` (annuler : `sudo rm`).
2. **PATH du ssh non interactif** sur le vps : pas de `~/.local/bin` -> `command not found` (rc=127). D'ou `bash -lc`,
   et le test avec `env -i` cote vps.
3. **Ctrl+clic seul ne marche pas** : herdr/Claude Code captent la souris. Ce qui marche : **Ctrl+Maj+clic**.
   Valide avec Ghostty ; avec un autre terminal le geste peut differer.
4. **Chemins absolus uniquement** (`/home/u/...`). Relatifs et `~/` non geres. Suffixe `:ligne:col` tolere.
5. **Un surlignage au survol ne prouve rien** : herdr et Claude Code surlignent aussi. Seul juge : une ligne dans
   `~/.cache/xdg-open-shim.log` a l'heure du clic.
6. Un fichier qui existe aussi sur le poste est ouvert localement (choix delibere : pas de detournement).
7. L'ouverture cible le workspace herdr **focus** du vps. Aucun client attache -> "aucun workspace herdr focus".
8. **Frappe pendant l'ouverture** : si le tab prend le focus avant que la commande soit envoyee, ce que tu tapes se
   melange a la commande (`emdterm: command not found`). `herdr-open-md` cree donc le tab sans focus et ne le donne qu'apres.
9. **ssh multiplexe (ControlMaster)** : les relais ne laissent pas de ligne `Accepted` dans les logs sshd du vps.
   L'absence de trace cote vps ne prouve pas que le clic n'est pas parti. Cote vps, le juge est le log du serveur herdr
   (`tab.create`).
10. **Le terminal complete le chemin clique avec des espaces** jusqu'au bord de la ligne (Ghostty, sortie de Claude
    Code) : `xdg-open "/home/u/x.md        "`. Le shim retire ces espaces. Un essai avec un chemin propre ne
    prouve donc rien sur le vrai clic : l'essai reel de `setup.sh` envoie le chemin complete d'espaces.
11. Un alias SSH connu seulement de la config herdr ne suffit pas : `mdterm-open` fait un `ssh` nu, il faut
    l'alias dans `~/.ssh/config` (ou donner `user@adresse`).

## Diagnostic
`./setup.sh --check` sur le poste, puis sur le vps. Journaux du poste : `~/.cache/xdg-open-shim.log` (le clic
arrive-t-il, sous quel format ; un `.md` non relaye y laisse `-- non relaye : <raison>`) et
`~/.cache/herdr-mdterm.log` (le ssh, puis l'id du tab cree). Sur le vps : `herdr-open-md /chemin.md` a la main.

## Desinstaller
Un seul VPS : supprimer sa ligne dans `~/.config/herdr-mdterm/remotes`.
Tout, et seulement si plus aucun VPS n'en depend : `rm ~/.local/bin/{xdg-open,mdterm-open}
~/.local/share/applications/mdterm-handler.desktop`, `sudo rm /usr/local/bin/xdg-open` si cree, `rm -r ~/.config/herdr-mdterm`.
Sur un vps : `rm ~/.local/bin/{herdr-open-md,mdlink,mdterm}`.
