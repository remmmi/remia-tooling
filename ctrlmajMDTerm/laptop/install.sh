#!/usr/bin/env bash
# Installe cote laptop (Linux + Ghostty) le relais Ctrl+Maj+clic -> tab herdr sur un VPS.
# Usage: ./install.sh --host <alias-ssh> --port <port> --prefix </home/user/> [--system-link]
#   --prefix : debut des chemins VPS a intercepter (typiquement le HOME du VPS, avec / final)
#   Relancer avec d'autres --host/--prefix pour ajouter un autre VPS.
#   --system-link : sudo ln -sf le shim dans /usr/local/bin (PATH de Ghostty), sinon commande affichee.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
host=""; port="22"; prefix=""; syslink=0
while [ $# -gt 0 ]; do case "$1" in
  --host) host="$2"; shift 2;; --port) port="$2"; shift 2;;
  --prefix) prefix="$2"; shift 2;; --system-link) syslink=1; shift;;
  *) echo "option inconnue: $1" >&2; exit 1;; esac; done
[ -n "$host" ] && [ -n "$prefix" ] || { echo "requis: --host et --prefix" >&2; exit 1; }
[[ "$prefix" == */ ]] || prefix="$prefix/"

echo "[..] test ssh sans mot de passe vers $host:$port"
ssh -o BatchMode=yes -o ConnectTimeout=8 -p "$port" "$host" true \
  || { echo "[!!] ssh $host echoue : installer la cle publique d'abord"; exit 1; }
ssh -o BatchMode=yes -p "$port" "$host" "bash -lc 'command -v herdr-open-md'" >/dev/null \
  || { echo "[!!] herdr-open-md introuvable sur $host (bash -lc) : lancer vps/install.sh sur le VPS"; exit 1; }

mkdir -p "$HOME/.local/bin" "$HOME/.config/herdr-mdterm" "$HOME/.local/share/applications"
install -m 755 "$here/mdterm-open" "$HOME/.local/bin/mdterm-open"
install -m 755 "$here/xdg-open-shim" "$HOME/.local/bin/xdg-open"

conf="$HOME/.config/herdr-mdterm/remotes"; touch "$conf"
grep -qF "$prefix $host $port" "$conf" || echo "$prefix $host $port" >> "$conf"

cat > "$HOME/.local/share/applications/mdterm-handler.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=mdterm handler
Exec=$HOME/.local/bin/mdterm-open %u
NoDisplay=true
MimeType=x-scheme-handler/mdterm;
EOF
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
xdg-mime default mdterm-handler.desktop x-scheme-handler/mdterm
echo "[ok] scripts + handler mdterm:// + remotes ($conf)"

# Piege central : le shim ne sert que si le PATH de Ghostty le voit avant /usr/bin.
gpid="$(pgrep -xo ghostty || true)"
if [ -n "$gpid" ] && tr '\0' '\n' < "/proc/$gpid/environ" 2>/dev/null | grep '^PATH=' | grep -q "$HOME/.local/bin"; then
  echo "[ok] Ghostty voit ~/.local/bin dans son PATH"
elif [ "$syslink" -eq 1 ]; then
  sudo ln -sf "$HOME/.local/bin/xdg-open" /usr/local/bin/xdg-open && echo "[ok] /usr/local/bin/xdg-open -> shim (annuler: sudo rm /usr/local/bin/xdg-open)"
else
  echo "[!!] Le PATH de Ghostty n'inclut pas ~/.local/bin : le shim ne sera pas appele."
  echo "     Correctif immediat (sudo) : sudo ln -sf $HOME/.local/bin/xdg-open /usr/local/bin/xdg-open"
  echo "     Annulation               : sudo rm /usr/local/bin/xdg-open"
fi
echo "[ok] Termine. Autotest : $here/selftest.sh <chemin-absolu-d-un-.md-sur-le-VPS>"
