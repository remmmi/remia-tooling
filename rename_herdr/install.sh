#!/usr/bin/env bash
# Installe (ou met à jour) rename_herdr : idempotent, relançable à volonté.
#
#   ./install.sh              script -> ~/.local/bin, unités -> ~/.config/systemd/user, activation, 1er passage
#   ./install.sh --check      constate seulement (fichiers, unités, herdr joignable), ne modifie rien
#   ./install.sh --uninstall  désactive les unités et retire les fichiers posés (état ~/.cache aussi)
#   options : --bin DIR (défaut ~/.local/bin)   --target tab|pane|both (défaut tab, écrit dans l'unité)
#
# N'écrit que dans --bin et ~/.config/systemd/user/rename-herdr.{path,service}.
#
# Avec le plugin Claude Code « rename-herdr » (marketplace remia-tooling), ce script est lancé au
# démarrage de session quand la version ou le réglage « target » change.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
BIN="$HOME/.local/bin"
UNITS="$HOME/.config/systemd/user"
MODE=install
TARGET=tab

while [ $# -gt 0 ]; do
  case "$1" in
    --bin)       BIN=$2; shift 2 ;;
    --target)    TARGET=$2; shift 2 ;;
    --check)     MODE=check; shift ;;
    --uninstall) MODE=uninstall; shift ;;
    -h|--help)   sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "argument inconnu : $1 (voir --help)" >&2; exit 2 ;;
  esac
done
case "$TARGET" in tab|pane|both) ;; *) echo "--target : tab, pane ou both" >&2; exit 2 ;; esac

# Hook de version propre à rename_herdr (1.2.0 seulement), remplacé par le plugin : le retirer s'il traîne.
legacy_hook_cleanup() {
  local legacy="$HOME/.claude/hooks/rename-herdr-version-check" settings="$HOME/.claude/settings.json"
  [ -e "$legacy" ] || grep -qs rename-herdr-version-check "$settings" || return 0
  python3 - "$settings" <<'PY' || true
import json, os, sys
path = sys.argv[1]
data = json.load(open(path, encoding="utf-8"))
groups = data.get("hooks", {}).get("SessionStart", [])
for g in groups:
    g["hooks"] = [h for h in g.get("hooks", []) if "rename-herdr-version-check" not in h.get("command", "")]
groups[:] = [g for g in groups if g.get("hooks")]
tmp = path + ".rename-herdr.tmp"
with open(tmp, "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=2, ensure_ascii=False); fh.write("\n")
os.replace(tmp, path)
PY
  rm -rf "$legacy" "$HOME/.cache/rename-herdr/remote.git" "$HOME/.cache/rename-herdr/remote-version" "$HOME/.config/rename-herdr"
  echo "retiré : ancien hook de version (1.2.0), remplacé par le plugin"
}

ok()  { echo "[ok] $*"; }
ko()  { echo "[!!] $*"; }

if [ "$MODE" = uninstall ]; then
  systemctl --user disable --now rename-herdr.path 2>/dev/null || true
  rm -f "$UNITS/rename-herdr.path" "$UNITS/rename-herdr.service" "$BIN/herdr-session-name-sync"
  rm -rf "$HOME/.cache/rename-herdr"
  rm -f "$HOME/.config/remia-tooling/rename-herdr/installed-version"
  legacy_hook_cleanup
  systemctl --user daemon-reload
  echo "rename_herdr retiré"; exit 0
fi

if [ "$MODE" = check ]; then
  rc=0
  command -v python3 >/dev/null && ok "python3" || { ko "python3 absent"; rc=1; }
  systemctl --user is-system-running >/dev/null 2>&1 && ok "systemd --user joignable" || { ko "systemd --user injoignable (pas de session utilisateur ? voir INSTALL.md § Debian)"; rc=1; }
  [ -x "$BIN/herdr-session-name-sync" ] && ok "$BIN/herdr-session-name-sync" || { ko "script absent"; rc=1; }
  repo_v=$(sed -n 's/^VERSION = "\(.*\)"$/\1/p' "$HERE/herdr-session-name-sync")
  inst_v=$(sed -n 's/^VERSION = "\(.*\)"$/\1/p' "$BIN/herdr-session-name-sync" 2>/dev/null)
  if [ "${inst_v:-}" = "$repo_v" ]; then ok "version $inst_v (= dépôt)"
  else ko "version installée ${inst_v:-<1.1.0} != dépôt $repo_v (relancer ./install.sh après git pull)"; rc=1; fi
  cmp -s "$HERE/herdr-session-name-sync" "$BIN/herdr-session-name-sync" 2>/dev/null && ok "script identique au dépôt" || ko "script différent du dépôt (relancer ./install.sh)"
  [ "$(systemctl --user is-active rename-herdr.path 2>/dev/null)" = active ] && ok "rename-herdr.path actif" || { ko "rename-herdr.path inactif"; rc=1; }
  [ "$(systemctl --user is-enabled rename-herdr.path 2>/dev/null)" = enabled ] && ok "rename-herdr.path activé au login" || ko "rename-herdr.path non activé au login"
  [ -d "$HOME/.claude/sessions" ] && ok "~/.claude/sessions présent" || ko "~/.claude/sessions absent (aucune session Claude Code lancée encore ?)"
  H=$(command -v herdr || ls "$HOME/.local/bin/herdr" "$HOME/.cargo/bin/herdr" 2>/dev/null | head -1 || true)
  if [ -n "$H" ] && "$H" agent list >/dev/null 2>&1; then ok "herdr joignable ($H)"; else ko "herdr injoignable (pas lancé, ou socket ailleurs : HERDR_SOCKET_PATH)"; fi
  exit $rc
fi

# ── prérequis
command -v python3 >/dev/null || { echo "python3 requis (Debian : apt install python3)" >&2; exit 1; }
systemctl --user is-system-running >/dev/null 2>&1 || {
  echo "systemd --user injoignable : il faut une session utilisateur (login, ou 'loginctl enable-linger $USER'), voir INSTALL.md" >&2; exit 1; }

# ── fichiers
mkdir -p "$BIN" "$UNITS"
install -m 0755 "$HERE/herdr-session-name-sync" "$BIN/herdr-session-name-sync"
install -m 0644 "$HERE/units/rename-herdr.path" "$UNITS/rename-herdr.path"
{
  cat "$HERE/units/rename-herdr.service"
  [ "$TARGET" != tab ] && echo "Environment=RENAME_HERDR_TARGET=$TARGET"
  [ "$BIN" != "$HOME/.local/bin" ] && echo "ExecStart=" && echo "ExecStart=$BIN/herdr-session-name-sync"
  true
} > "$UNITS/rename-herdr.service"
echo "installé : $BIN/herdr-session-name-sync"
echo "installé : $UNITS/rename-herdr.path, $UNITS/rename-herdr.service"
legacy_hook_cleanup

# ── activation (idempotent) + premier passage
systemctl --user daemon-reload
systemctl --user enable --now rename-herdr.path >/dev/null
systemctl --user restart rename-herdr.path
echo "unité rename-herdr.path : $(systemctl --user is-active rename-herdr.path)"
RENAME_HERDR_TARGET=$TARGET "$BIN/herdr-session-name-sync" --verbose || true
echo "vérifier : ./selftest.sh ; diagnostic : ./install.sh --check ; journal : journalctl --user -u rename-herdr.service -n 20"
