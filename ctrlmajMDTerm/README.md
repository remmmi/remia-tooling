# herdr-mdterm-pack : Ctrl+Maj+clic sur un .md -> tab herdr avec mdterm

Depuis un laptop Linux attache a un VPS via `herdr --remote <host>`, un Ctrl+Maj+clic sur
un chemin `.md` (texte brut, y compris dans la sortie de Claude Code) ouvre un nouveau
tab herdr sur le VPS avec `mdterm <fichier>`.

## Comment ca marche

```
Ghostty (laptop)  --Ctrl+Maj+clic sur /home/u/x.md-->  xdg-open /home/u/x.md
   Maj = Ghostty garde la souris (herdr/Claude Code la captent sinon)
xdg-open (shim ~/.local/bin, prioritaire dans le PATH de Ghostty)
   .md absolu, absent en local, prefixe connu ? --> mdterm-open   (sinon vrai xdg-open)
mdterm-open  --ssh -p PORT HOST "bash -lc 'herdr-open-md <chemin>'"-->  VPS
herdr-open-md (VPS) : herdr tab create + herdr pane run "mdterm <chemin>"  -> tab visible dans le client remote
```
Le scheme `mdterm://` (sortie de `mdlink`, lien OSC8) passe par le meme relais via un `.desktop`.

## Contenu
- `vps/`    `herdr-open-md`, `mdlink`, `install.sh [--install-mdterm]`, `selftest.sh`
- `laptop/` `mdterm-open`, `xdg-open-shim`, `install.sh --host H --port P --prefix /home/u/`, `selftest.sh`
- `prompts/` `vps-claude.md`, `laptop-claude.md` : a coller dans chaque Claude
- `bridge/` skill `claude-bridge` (canal texte Claude<->Claude via fichier sur le VPS)

## Prerequis
VPS : herdr >= 0.8, `jq`, `mdterm` (Rust ; `--install-mdterm` gere rustup, il faut `build-essential`).
Laptop : Linux, Ghostty (le contournement souris par Maj est le comportement Ghostty), cle SSH sans mot de passe
vers le VPS, `client herdr --remote` deja fonctionnel.

## Pieges (tous rencontres pour de vrai)
1. **PATH de Ghostty** : lance par la session graphique, il n'a pas `~/.local/bin` -> le shim n'est jamais appele.
   Correctif : `sudo ln -sf ~/.local/bin/xdg-open /usr/local/bin/xdg-open` (annuler : `sudo rm`). `--system-link` le fait.
2. **PATH ssh non interactif** sur le VPS n'a pas `~/.local/bin` -> `command not found` (rc=127). D'ou `bash -lc`.
   Verifier que `~/.profile` du VPS ajoute `~/.local/bin` et `~/.cargo/bin`.
3. **Ctrl+clic seul ne marche pas** : herdr/Claude Code captent la souris. Ce qui marche : **Ctrl+Maj+clic** (Ghostty).
   Un plugin herdr `[[link_handlers]]` (Ctrl+clic) ne s'est pas declenche en 0.8.0 : ne pas perdre de temps dessus.
4. **Chemins absolus uniquement** (`/home/u/...`). Relatifs et `~/` non geres. Suffixe `:ligne:col` tolere.
5. Un texte brut non lie n'est pas cliquable en OSC8 : le clic sur chemin brut repose sur la detection Ghostty.
6. Un fichier qui existe aussi en local est ouvert localement (choix delibere : pas de detournement).
7. L'ouverture cible le workspace herdr **focus** du VPS.

## Diagnostic rapide
- Laptop : `~/.cache/xdg-open-shim.log` (le clic arrive-t-il ? format exact), `~/.cache/herdr-mdterm.log` (ssh).
- Log shim vide apres un clic -> pas d'appel : piege 1 (ou chemin non detecte comme lien par Ghostty).
- VPS : `herdr-open-md /chemin.md` a la main ; `vps/selftest.sh`.

## Ajouter un autre VPS
Relancer `laptop/install.sh --host autre --port N --prefix /home/autre/` (une ligne par VPS dans
`~/.config/herdr-mdterm/remotes`). Deux VPS avec le meme prefixe : le premier gagne.

## Desinstaller
Laptop : `rm ~/.local/bin/{xdg-open,mdterm-open} ~/.local/share/applications/mdterm-handler.desktop`,
`sudo rm /usr/local/bin/xdg-open` si cree, `rm -r ~/.config/herdr-mdterm`.
VPS : `rm ~/.local/bin/{herdr-open-md,mdlink}`.
