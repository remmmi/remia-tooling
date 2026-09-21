#!/usr/bin/env bash
# herdr-mdterm-pack : point d'entree unique, a lancer sur le poste de travail OU sur le VPS.
#
#   ./setup.sh            pose les questions, constate l'etat, ne fait que ce qui manque
#   ./setup.sh --check    constate seulement, ne modifie rien (diagnostic)
#   ./setup.sh --yes      accepte les actions sans sudo sans demander (le sudo est toujours demande)
#   sans option : demande quels sont les protagonistes (machines + role), puis sur lequel on est.
#   raccourcis sans question : --role vps   |   --role poste --host ALIAS [--port N] [--prefix /home/u/]
#                                --role poste seul = tous les vps de ~/.config/herdr-mdterm/protagonistes.conf
#
# Principe : une liste d'OBJECTIFS par role. Chaque objectif est verifie pour de vrai ;
# s'il est deja atteint on ne touche a rien, sinon on propose l'action et on re-verifie.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
lib="$here/lib"

MDTERM_VER="v2.0.0"
MDTERM_SHA_x86_64="b38feb69faff9e64ac105d7235979e73d5de91d931d7df779a2abb15d1350b64"
MDTERM_SHA_aarch64="d827f2662c55e1354d382ef00af7bdb865e1eaa136f62cefa55e975855896ef4"

role=""; host=""; port=""; prefix=""; check=0; yes=0
while [ $# -gt 0 ]; do case "$1" in
  --role) role="$2"; shift 2;; --host) host="$2"; shift 2;; --port) port="$2"; shift 2;;
  --prefix) prefix="$2"; shift 2;; --check) check=1; shift;; --yes) yes=1; shift;;
  -h|--help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
  *) echo "option inconnue: $1 (voir --help)" >&2; exit 2;; esac; done

export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
todo=0   # objectifs non atteints en fin de course

ok()   { echo "[ok] $*"; }
ko()   { echo "[!!] $*"; todo=$((todo+1)); }
info() { echo "     $*"; }
has_tty() { { : </dev/tty; } 2>/dev/null; }
ask()  { local a=""; if has_tty; then read -r -p "$1 " a </dev/tty || a=""; fi; echo "${a:-${2:-}}"; }
# confirm <question> [sudo] : en --check toujours non ; --yes ne vaut pas pour sudo.
confirm() {
  [ "$check" -eq 1 ] && return 1
  [ "$yes" -eq 1 ] && [ "${2:-}" != sudo ] && return 0
  case "$(ask "     $1 [o/N]" n)" in o|O|y|Y|oui) return 0;; *) return 1;; esac
}
# goal <libelle> <fn_test> <fn_action> [sudo] : le coeur. Test, action si besoin, re-test.
goal() {
  local label="$1" t="$2" act="$3" su="${4:-}"
  if "$t"; then ok "$label"; return 0; fi
  if [ "$check" -eq 1 ]; then ko "$label"; "$act" --describe; return 1; fi
  echo "[..] $label : a faire"; "$act" --describe
  if confirm "Le faire maintenant ?" "$su"; then
    "$act" || true
    if "$t"; then ok "$label"; return 0; fi
  fi
  ko "$label"; return 1
}

# ------------------------------------------------------------------ role VPS
t_herdr() { command -v herdr >/dev/null; }
a_herdr() { info "herdr >= 0.8 doit etre installe sur ce VPS (hors perimetre du pack)."; }

t_jq() { command -v jq >/dev/null; }
a_jq() {
  local cmd=""
  if   command -v apt-get >/dev/null; then cmd="sudo apt-get install -y jq"
  elif command -v dnf     >/dev/null; then cmd="sudo dnf install -y jq"
  elif command -v pacman  >/dev/null; then cmd="sudo pacman -S --noconfirm jq"
  elif command -v apk     >/dev/null; then cmd="sudo apk add jq"; fi
  if [ "${1:-}" = --describe ]; then info "jq manque. Commande : ${cmd:-installer jq avec le gestionnaire de paquets}"; return; fi
  [ -n "$cmd" ] && $cmd
}

t_mdterm() { command -v mdterm >/dev/null && mdterm --version >/dev/null 2>&1; }
a_mdterm() {
  local arch sha url tmp avail; arch="$(uname -m)"
  case "$arch" in x86_64) sha="$MDTERM_SHA_x86_64";; aarch64) sha="$MDTERM_SHA_aarch64";; *) sha="";; esac
  if [ "${1:-}" = --describe ]; then
    if [ -n "$sha" ]; then info "mdterm manque. Binaire officiel $MDTERM_VER precompile ($arch, statique musl), sha256 verifie -> ~/.local/bin. Ni Rust ni build-essential."
    else info "mdterm manque et aucun binaire n'est publie pour $arch : compilation (rustup + cargo install), ~1,5 Go de RAM."; fi
    return
  fi
  mkdir -p "$HOME/.local/bin"
  if [ -n "$sha" ]; then
    url="https://github.com/bahdotsh/mdterm/releases/download/$MDTERM_VER/mdterm-$arch-unknown-linux-musl.tar.gz"
    tmp="$(mktemp -d)"
    curl --proto '=https' --tlsv1.2 -sSfL -o "$tmp/m.tgz" "$url" \
      && echo "$sha  $tmp/m.tgz" | sha256sum -c --quiet \
      && tar xzf "$tmp/m.tgz" -C "$tmp" \
      && install -m 755 "$(find "$tmp" -type f -name mdterm | head -1)" "$HOME/.local/bin/mdterm" \
      || info "telechargement ou sha256 en echec : rien n'a ete installe"
    rm -rf "$tmp"
  else
    avail="$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)"
    if [ "$avail" -lt 1500 ]; then
      info "seulement ${avail} Mo de RAM disponible : compiler ici risque de declencher l'OOM killer."
      confirm "Compiler quand meme ?" sudo || return 1
    fi
    command -v cc >/dev/null || { info "compilateur C absent : installer build-essential (ou equivalent) puis relancer"; return 1; }
    command -v cargo >/dev/null || { curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal; . "$HOME/.cargo/env"; }
    nice -n 19 cargo install mdterm
  fi
}

t_vps_scripts() { for f in herdr-open-md mdlink; do cmp -s "$lib/$f" "$HOME/.local/bin/$f" || return 1; done; }
a_vps_scripts() {
  if [ "${1:-}" = --describe ]; then info "copier herdr-open-md et mdlink dans ~/.local/bin"; return; fi
  mkdir -p "$HOME/.local/bin" && install -m 755 "$lib/herdr-open-md" "$lib/mdlink" "$HOME/.local/bin/"
}

# Le poste appelle : ssh HOST "bash -lc 'herdr-open-md ...'" -> environnement quasi vide. On le reproduit.
t_loginpath() { env -i HOME="$HOME" bash -lc 'command -v herdr-open-md && command -v mdterm && command -v herdr && command -v jq' >/dev/null 2>&1; }
a_loginpath() {
  if [ "${1:-}" = --describe ]; then
    info "un shell de login a environnement vide (ce que fera le ssh du poste) ne trouve pas toutes les commandes."
    info "action : ajouter ~/.local/bin et ~/.cargo/bin au PATH a la fin de ~/.profile"; return
  fi
  if grep -qF '# herdr-mdterm-pack :' "$HOME/.profile" 2>/dev/null; then
    info "le bloc PATH est deja dans ~/.profile et ne suffit pas : un ~/.bash_profile ou ~/.bash_login le masque sans doute"
    info "(bash -l ne lit ~/.profile que si ces deux fichiers sont absents). Y ajouter : . ~/.profile"
    return 1
  fi
  cat >> "$HOME/.profile" <<'EOF'

# herdr-mdterm-pack : commandes visibles par un ssh non interactif (bash -lc)
for d in "$HOME/.local/bin" "$HOME/.cargo/bin"; do
  [ -d "$d" ] && case ":$PATH:" in *":$d:"*) ;; *) PATH="$d:$PATH";; esac
done
EOF
}

vps_selftest() {
  local f tab pane i rc=1
  herdr workspace list 2>/dev/null | jq -e '.result.workspaces[] | select(.focused==true)' >/dev/null 2>&1 \
    || { info "essai reel saute : aucun workspace herdr focus (attacher un client herdr, puis relancer --check)"; return 0; }
  confirm "Essai reel : ouvrir 2 s un tab mdterm de test dans herdr puis le fermer ?" || { info "essai reel saute"; return 0; }
  f="$(mktemp --suffix=.md)"; printf '# selftest herdr-mdterm\n' > "$f"
  if tab="$(env -i HOME="$HOME" bash -lc "herdr-open-md $(printf '%q' "$f")")"; then
    pane="$(herdr pane list | jq -r --arg t "$tab" '.result.panes[] | select(.tab_id==$t) | .pane_id' | head -1)"
    for i in 1 2 3 4 5 6; do sleep 0.5; herdr pane read "$pane" 2>/dev/null | grep -q "selftest herdr-mdterm" && { rc=0; break; }; done
    [ "$rc" -eq 0 ] || { info "contenu du pane :"; herdr pane read "$pane" 2>/dev/null | grep . | head -4 | sed 's/^/       /'; }
    herdr tab close "$tab" >/dev/null 2>&1 || true
  fi
  rm -f "$f"
  if [ "$rc" -eq 0 ]; then ok "essai reel : tab cree, mdterm affiche le fichier, tab referme"; else ko "essai reel : mdterm n'a pas affiche le fichier"; fi
}

run_vps() {
  echo "== Role : VPS ($(hostname), user $USER) =="
  goal "herdr present"                                   t_herdr       a_herdr
  goal "jq present"                                      t_jq          a_jq sudo
  goal "mdterm present"                                  t_mdterm      a_mdterm
  goal "herdr-open-md + mdlink a jour dans ~/.local/bin" t_vps_scripts a_vps_scripts
  goal "commandes visibles par un ssh non interactif"    t_loginpath   a_loginpath
  [ "$todo" -eq 0 ] && vps_selftest
  local p; p="$( { sudo -n sshd -T 2>/dev/null || true; } | awk '$1=="port"{print $2; exit}')"
  [ -n "$p" ] || p="$(grep -rihE '^[[:space:]]*Port[[:space:]]' /etc/ssh/sshd_config /etc/ssh/sshd_config.d/ 2>/dev/null | awk '{print $2; exit}' || true)"
  echo
  echo "Pour le poste de travail : ./setup.sh --role poste --host <alias-ssh-de-ce-vps>"
  info "(port sshd ici : ${p:-22} ; prefixe des chemins : $HOME/ ; le poste les detecte seul via ssh)"
}

# ------------------------------------------------------------------ role poste de travail
conf="$HOME/.config/herdr-mdterm/remotes"
desktop="$HOME/.local/share/applications/mdterm-handler.desktop"
sshq() { ssh -o BatchMode=yes -o ConnectTimeout=8 -p "$port" "$host" "$@"; }

t_ssh() { sshq true 2>/dev/null; }
a_ssh() {
  info "'ssh -o BatchMode=yes -p $port $host true' echoue. Causes habituelles :"
  info "- l'alias '$host' n'existe que dans la config herdr, pas dans ~/.ssh/config"
  info "- cle publique non installee (ssh-copy-id -p $port $host), ou cle protegee sans agent"
  info "- mauvais port"
}

# Pret = les 4 commandes repondent via bash -lc ET les scripts du vps sont ceux de ce pack
# (un herdr-open-md d'une version anterieure passe le test de presence et garde ses defauts).
remote_stale=""
t_remote() {
  local want got
  [ "$(sshq "bash -lc 'command -v herdr-open-md mdterm herdr jq | wc -l'" 2>/dev/null)" = 4 ] || { remote_stale=""; return 1; }
  want="$(cat "$lib/herdr-open-md" "$lib/mdlink" | sha256sum | cut -d' ' -f1)"
  got="$(sshq "bash -lc 'cat \$(command -v herdr-open-md) \$(command -v mdlink) | sha256sum'" 2>/dev/null | cut -d' ' -f1)"
  [ "$want" = "$got" ] || { remote_stale=1; return 1; }
}
a_remote() {
  if [ "${1:-}" = --describe ]; then
    if [ -n "$remote_stale" ]; then info "le VPS a herdr-open-md/mdlink d'une autre version que ce pack."
    else info "le VPS n'est pas pret (herdr-open-md, mdterm, herdr ou jq introuvable via bash -lc)."; fi
    info "action : y copier ce pack (dans ~/.cache/herdr-mdterm/pack) et y lancer './setup.sh --role vps' a travers ssh"; return
  fi
  # Copie dans un dossier reserve du vps, jamais dans ~/herdr-mdterm-pack : sur le vps ou le pack est
  # developpe, ce dossier est une copie de travail et un rm -rf la detruirait.
  local rdir='.cache/herdr-mdterm/pack'
  tar czf - -C "$here" . | sshq "rm -rf ~/$rdir && mkdir -p ~/$rdir && tar xzf - -C ~/$rdir && ls ~/$rdir/setup.sh" >/dev/null || return 1
  if has_tty; then ssh -t -p "$port" "$host" "~/$rdir/setup.sh --role vps" </dev/tty
  elif [ "$yes" -eq 1 ]; then sshq "~/$rdir/setup.sh --role vps --yes"
  else info "pas de terminal pour repondre aux questions : constat seul cote vps (relancer avec --yes pour agir)"
       sshq "~/$rdir/setup.sh --role vps --check"; fi
}

t_poste_scripts() { cmp -s "$lib/mdterm-open" "$HOME/.local/bin/mdterm-open" && cmp -s "$lib/xdg-open-shim" "$HOME/.local/bin/xdg-open"; }
a_poste_scripts() {
  if [ "${1:-}" = --describe ]; then info "copier mdterm-open et le shim xdg-open dans ~/.local/bin"; return; fi
  if [ -e "$HOME/.local/bin/xdg-open" ] && ! grep -q 'herdr-mdterm\|mdterm-open' "$HOME/.local/bin/xdg-open"; then
    info "~/.local/bin/xdg-open existe deja et n'est pas notre shim : sauvegarde en xdg-open.avant-mdterm"
    cp -a "$HOME/.local/bin/xdg-open" "$HOME/.local/bin/xdg-open.avant-mdterm"
  fi
  mkdir -p "$HOME/.local/bin"
  install -m 755 "$lib/mdterm-open" "$HOME/.local/bin/mdterm-open"
  install -m 755 "$lib/xdg-open-shim" "$HOME/.local/bin/xdg-open"
}

# Premiere ligne dont le prefixe couvre $prefix : c'est elle que le shim choisira.
remote_winner() { [ -r "$conf" ] && awk -v a="$prefix" '$1 !~ /^#/ && NF>=2 && index(a,$1)==1 {print $2" "($3?$3:22); exit}' "$conf"; }
t_remotes() { [ "$(remote_winner)" = "$host $port" ]; }
a_remotes() {
  local w; w="$(remote_winner)"
  if [ -n "$w" ]; then
    info "CONFLIT : dans $conf le prefixe $prefix mene deja a '$w' (la premiere ligne gagne)."
    info "Deux VPS avec le meme nom d'utilisateur ne sont pas distinguables par le chemin."
    info "A regler a la main : changer l'ordre des lignes, ou utiliser des noms d'utilisateur distincts."
    return 1
  fi
  if [ "${1:-}" = --describe ]; then info "AJOUTER la ligne '$prefix $host $port' a $conf (ajout seul : les lignes des autres VPS restent en place)"; return; fi
  mkdir -p "$(dirname "$conf")" && echo "$prefix $host $port" >> "$conf"
}

t_scheme() { [ -f "$desktop" ] && [ "$(xdg-mime query default x-scheme-handler/mdterm 2>/dev/null)" = mdterm-handler.desktop ]; }
a_scheme() {
  if [ "${1:-}" = --describe ]; then info "declarer le scheme mdterm:// (liens OSC8 produits par 'mdlink' sur le VPS)"; return; fi
  command -v xdg-mime >/dev/null || { info "xdg-mime absent (paquet xdg-utils) : le clic sur chemin brut marche sans, seuls les liens mdterm:// en ont besoin"; return 1; }
  mkdir -p "$(dirname "$desktop")"
  printf '[Desktop Entry]\nType=Application\nName=mdterm handler\nExec=%s %%u\nNoDisplay=true\nMimeType=x-scheme-handler/mdterm;\n' "$HOME/.local/bin/mdterm-open" > "$desktop"
  update-desktop-database "$(dirname "$desktop")" 2>/dev/null || true
  xdg-mime default mdterm-handler.desktop x-scheme-handler/mdterm
}

# Quel xdg-open le terminal graphique lancera-t-il ? On lit le PATH reel de son processus.
term_name=""; term_pid=""
find_term() {
  local t; for t in ghostty kitty wezterm-gui foot alacritty konsole gnome-terminal-server; do
    term_pid="$(pgrep -xo "$t" 2>/dev/null || true)"; [ -n "$term_pid" ] && { term_name="$t"; return 0; }
  done; return 1
}
t_termpath() {
  local p first
  find_term || return 1
  p="$(tr '\0' '\n' < "/proc/$term_pid/environ" 2>/dev/null | sed -n 's/^PATH=//p')"
  first="$(PATH="$p" command -v xdg-open 2>/dev/null)"
  [ -n "$first" ] && [ "$(readlink -f "$first")" = "$(readlink -f "$HOME/.local/bin/xdg-open")" ]
}
a_termpath() {
  if [ "${1:-}" = --describe ]; then
    if [ -z "$term_name" ]; then info "aucun terminal graphique connu en cours d'execution : lancer le terminal puis './setup.sh --check'"
    else info "$term_name (pid $term_pid) resout xdg-open ailleurs que vers le shim : son PATH n'a pas ~/.local/bin en tete."; fi
    info "action (sudo) : ln -sf ~/.local/bin/xdg-open /usr/local/bin/xdg-open   -- annulation : sudo rm /usr/local/bin/xdg-open"
    return
  fi
  sudo ln -sf "$HOME/.local/bin/xdg-open" /usr/local/bin/xdg-open
}

poste_selftest() {
  local f="" before rc new tab mlog="$HOME/.cache/herdr-mdterm.log"
  f="$(sshq "bash -lc 'ls -t ~/*.md ~/docs/*.md ~/.claude/CLAUDE.md 2>/dev/null | head -1'" 2>/dev/null)"
  [ -n "$f" ] || { info "essai reel saute : pas de .md trouve dans le HOME du VPS"; return 0; }
  [ -e "$f" ] && { info "essai reel saute : $f existe aussi ici (il serait ouvert en local, choix delibere)"; return 0; }
  confirm "Essai reel : simuler le clic sur $f (un tab mdterm s'ouvre 2 s dans herdr puis est referme) ?" || { info "essai reel saute"; return 0; }
  before="$(wc -l < "$mlog" 2>/dev/null || echo 0)"
  # Le clic reel arrive complete d'espaces jusqu'au bord de la ligne : l'essai reproduit ce format,
  # un chemin propre passerait meme avec un shim qui rate tous les vrais clics.
  "$HOME/.local/bin/xdg-open" "$f                    "; rc=$?
  new="$(tail -n +"$((before+1))" "$mlog" 2>/dev/null)"
  tab="$(printf '%s\n' "$new" | grep -E '^w[^: ]+:t[^: ]+$' | tail -1)"
  if [ "$rc" -eq 0 ] && [ -n "$tab" ]; then
    ok "essai reel : shim -> mdterm-open -> ssh -> herdr-open-md, tab $tab ouvert"
    sleep 2; sshq "bash -lc 'herdr tab close $tab'" >/dev/null 2>&1 && info "tab $tab referme" || info "tab $tab a fermer a la main (q)"
  else
    ko "essai reel : rc=$rc, aucun tab cree"
    if [ -n "$new" ]; then printf '%s\n' "$new" | sed 's/^/       /'
    else info "le shim n'a pas relaye :"; tail -2 "$HOME/.cache/xdg-open-shim.log" 2>/dev/null | sed 's/^/       /'; fi
    info "'aucun workspace herdr focus' = aucun client herdr attache au VPS"
  fi
}

# Le juge du vrai clic : la derniere ligne du log du shim pour ce prefixe, et ce que le shim en a fait.
t_lastclick() {
  local slog="$HOME/.cache/xdg-open-shim.log" ln
  [ -r "$slog" ] || return 0
  ln="$(grep -nF "args=[$prefix" "$slog" | tail -1 | cut -d: -f1)"; [ -n "$ln" ] || return 0
  case "$(sed -n "$((ln+1))p" "$slog")" in "  -> mdterm-open"*) return 0;; *) return 1;; esac
}
a_lastclick() {
  local slog="$HOME/.cache/xdg-open-shim.log" ln
  ln="$(grep -nF "args=[$prefix" "$slog" | tail -1 | cut -d: -f1)"
  info "le shim a bien recu ce clic mais ne l'a pas relaye :"
  sed -n "${ln},$((ln+1))p" "$slog" | sed 's/^/       /'
  info "sans ligne '-- non relaye : <raison>' dessous, le shim installe est anterieur a ce pack : le mettre a jour puis recliquer."
  [ "${1:-}" = --describe ] || return 1
}

run_poste() {
  echo; echo "== Poste de travail $(hostname) -> VPS '$host' =="
  term_name=""; term_pid=""
  [ -n "$port" ] || port="$(ssh -G "$host" 2>/dev/null | awk '$1=="port"{print $2; exit}')"; port="${port:-22}"
  info "cible : $host, port $port"

  goal "ssh sans mot de passe vers $host" t_ssh a_ssh || { echo; echo "Bloquant : rien d'autre n'est verifiable sans ssh."; return; }
  if [ -z "$prefix" ]; then prefix="$(sshq 'printf %s "$HOME"' 2>/dev/null)/"; info "prefixe detecte sur le VPS : $prefix"; fi
  [[ "$prefix" == */ ]] || prefix="$prefix/"

  goal "VPS pret (herdr-open-md, mdterm, herdr, jq via bash -lc, scripts a jour)" t_remote a_remote
  goal "mdterm-open + shim xdg-open a jour dans ~/.local/bin"     t_poste_scripts a_poste_scripts
  goal "remotes : $prefix -> $host:$port"                         t_remotes       a_remotes
  goal "scheme mdterm:// declare"                                 t_scheme        a_scheme
  goal "le terminal graphique appelle bien le shim"               t_termpath      a_termpath sudo
  [ -n "$term_name" ] && [ "$term_name" != ghostty ] && info "note : seul Ghostty a ete valide (Ctrl+Maj+clic). Avec $term_name le geste peut differer."
  [ "$todo" -eq 0 ] && poste_selftest
  goal "dernier clic recu par le shim pour $prefix : relaye"      t_lastclick     a_lastclick

  echo
  echo "Usage : Ctrl+MAJ+clic sur un chemin .md absolu affiche dans la session herdr remote."
  info "Si le clic surligne mais n'ouvre rien : cliquer puis 'tail -3 ~/.cache/xdg-open-shim.log'."
  info "Aucune ligne a l'heure du clic = le terminal n'a pas reconnu le lien (le surlignage peut venir de herdr)."
  info "Une ligne suivie de '-- non relaye : <raison>' = le shim dit lui-meme pourquoi."
}

# ------------------------------------------------------------------ protagonistes
# Fichier de la machine, hors du pack : le pack ne contient aucun nom de machine, il reste diffusable tel quel.
#   <nom> poste
#   <nom> vps <acces-ssh-vu-du-poste> [port]
pfile="$HOME/.config/herdr-mdterm/protagonistes.conf"

show_protagonists() { grep -vE '^[[:space:]]*(#|$)' "$pfile" 2>/dev/null | awk '{printf "       %-14s %-6s %s %s\n", $1, $2, $3, $4}'; }

declare_protagonists() {
  local n r a p known
  echo "Quelles machines sont en jeu ? Une par une ; nom vide pour terminer."
  info "poste = machine devant toi, ou tu cliques. vps = serveur ou tournent herdr et les .md."
  known="$(grep -ihE '^Host[[:space:]]' "$HOME/.ssh/config" 2>/dev/null | awk '{for(i=2;i<=NF;i++) if($i!~/[*?]/) printf "%s ", $i}')"
  [ -n "$known" ] && info "alias presents dans ~/.ssh/config d'ici : $known"
  mkdir -p "$(dirname "$pfile")"; : > "$pfile.tmp"
  while :; do
    n="$(ask "     Nom de la machine (libre, sans espace) :")"; [ -n "$n" ] || break
    n="${n// /-}"
    case "$(ask "       role de '$n' [poste/vps] :")" in
      p|poste|1) echo "$n poste" >> "$pfile.tmp" ;;
      v|vps|2)
        a="$(ask "       acces SSH a '$n' depuis le poste (alias ou user@adresse) [$n] :" "$n")"
        p="$(ask "       port SSH (vide = selon ~/.ssh/config, sinon 22) :")"
        echo "$n vps $a $p" >> "$pfile.tmp" ;;
      *) info "role inconnu, machine ignoree" ;;
    esac
  done
  grep -q ' vps ' "$pfile.tmp" || { rm -f "$pfile.tmp"; echo "il faut au moins un vps" >&2; exit 2; }
  { echo "# protagonistes herdr-mdterm : <nom> poste | <nom> vps <acces-ssh> [port]"; cat "$pfile.tmp"; } > "$pfile"; rm -f "$pfile.tmp"
}

# un poste s'occupe de TOUS les vps declares
run_poste_all() {
  local _n _r _a _p
  while read -r _n _r _a _p; do
    host="$_a"; port="${_p:-}"; prefix=""
    run_poste </dev/null
  done < <(awk '$2=="vps"' "$pfile")
}

if [ -n "$role" ]; then
  # raccourci non interactif : --role vps   |   --role poste --host ALIAS [--port N] [--prefix P]
  [ "$check" -eq 1 ] && echo "(mode --check : constat seul, aucune modification)"
  case "$role" in
    vps) run_vps ;;
    poste) if [ -n "$host" ]; then run_poste
           elif [ -s "$pfile" ]; then run_poste_all
           else echo "--role poste demande --host (ou un protagonistes.conf deja rempli)" >&2; exit 2; fi ;;
    *) echo "--role vps|poste" >&2; exit 2 ;;
  esac
else
  if [ -s "$pfile" ]; then
    echo "Protagonistes deja declares ($pfile) :"; show_protagonists
    case "$(ask "     Garder cette liste ? [O/n]" o)" in n|N|non) declare_protagonists;; esac
  else
    declare_protagonists
  fi
  echo "Protagonistes :"; show_protagonists
  me="$(awk -v h="$(hostname)" '$1==h {print $1; exit}' "$pfile")"
  me="$(ask "     Sur laquelle de ces machines ce script tourne-t-il en ce moment ?${me:+ [$me]}" "$me")"
  myrole="$(awk -v m="$me" '$1==m {print $2; exit}' "$pfile")"
  [ -n "$myrole" ] || { echo "'$me' n'est pas dans la liste" >&2; exit 2; }
  [ "$check" -eq 1 ] && echo "(mode --check : constat seul, aucune modification)"
  if [ "$myrole" = vps ]; then
    run_vps
  else
    # Le shim xdg-open et mdterm-open sont PARTAGES par tous les VPS du fichier remotes.
    if [ -s "$conf" ]; then
      echo "VPS deja beneficiaires du shim sur ce poste ($conf) :"
      grep -vE '^[[:space:]]*(#|$)' "$conf" | sed 's/^/       /'
      info "Ces lignes sont conservees : ce script n'en retire ni n'en modifie aucune, il ne fait qu'en ajouter."
      info "Ne pas supprimer $conf, ~/.local/bin/xdg-open ni ~/.local/bin/mdterm-open : les VPS ci-dessus en dependent."
    fi
    run_poste_all
  fi
fi

echo
if [ "$todo" -eq 0 ]; then echo "Bilan : tous les objectifs sont atteints."; else echo "Bilan : $todo objectif(s) non atteint(s), voir les [!!] ci-dessus."; exit 1; fi
