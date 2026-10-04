#!/usr/bin/env bash
# Installe (ou met à jour) rename_herdr : idempotent, relançable à volonté.
#
#   ./install.sh              script -> ~/.local/bin, unités -> ~/.config/systemd/user, activation, 1er passage
#   ./install.sh --check      constate seulement (fichiers, unités, herdr joignable), ne modifie rien
#   ./install.sh --uninstall  désactive les unités et retire les fichiers posés (état ~/.cache aussi)
#   options : --bin DIR (défaut ~/.local/bin)   --target tab|pane|both (défaut tab, écrit dans l'unité)
#             --no-hook (ne pose pas le hook SessionStart qui signale une version plus récente)
#
# Écrit dans --bin, ~/.config/systemd/user/rename-herdr.{path,service}, ~/.config/rename-herdr/,
# ~/.claude/hooks/rename-herdr-version-check et une entrée SessionStart de ~/.claude/settings.json.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
BIN="$HOME/.local/bin"
UNITS="$HOME/.config/systemd/user"
MODE=install
TARGET=tab
HOOK_ON=1
CONF="$HOME/.config/rename-herdr"
HOOK="$HOME/.claude/hooks/rename-herdr-version-check"
SETTINGS="$HOME/.claude/settings.json"

# Ajoute (add) ou retire (remove) l'entrée SessionStart du hook dans settings.json, sans toucher au reste.
# Fichier absent ou JSON invalide : ne rien écrire (un settings.json cassé désactive tous les réglages).
hook_entry() {
  python3 - "$1" "$SETTINGS" "$HOOK" <<'PY'
import json, os, sys
action, path, cmd = sys.argv[1:]
try:
    with open(path, encoding="utf-8") as fh:
        data = json.load(fh)
except FileNotFoundError:
    if action == "remove":
        sys.exit(0)
    data = {}
except Exception as exc:
    sys.exit(f"{path} illisible ({exc}) : hook non modifié")
if action == "has":
    groups = data.get("hooks", {}).get("SessionStart", [])
    sys.exit(0 if any(h.get("command") == cmd for g in groups for h in g.get("hooks", [])) else 1)
groups = data.setdefault("hooks", {}).setdefault("SessionStart", [])
for g in groups:
    g["hooks"] = [h for h in g.get("hooks", []) if h.get("command") != cmd]
groups[:] = [g for g in groups if g.get("hooks")]
if action == "add":
    groups.append({"hooks": [{"type": "command", "command": cmd, "timeout": 5}]})
if not groups:
    del data["hooks"]["SessionStart"]
    if not data["hooks"]:
        del data["hooks"]
tmp = path + ".rename-herdr.tmp"
with open(tmp, "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=2, ensure_ascii=False)
    fh.write("\n")
os.replace(tmp, path)
PY
}

while [ $# -gt 0 ]; do
  case "$1" in
    --bin)       BIN=$2; shift 2 ;;
    --target)    TARGET=$2; shift 2 ;;
    --check)     MODE=check; shift ;;
    --uninstall) MODE=uninstall; shift ;;
    --no-hook)   HOOK_ON=0; shift ;;
    -h|--help)   sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "argument inconnu : $1 (voir --help)" >&2; exit 2 ;;
  esac
done
case "$TARGET" in tab|pane|both) ;; *) echo "--target : tab, pane ou both" >&2; exit 2 ;; esac

ok()  { echo "[ok] $*"; }
ko()  { echo "[!!] $*"; }

if [ "$MODE" = uninstall ]; then
  systemctl --user disable --now rename-herdr.path 2>/dev/null || true
  rm -f "$UNITS/rename-herdr.path" "$UNITS/rename-herdr.service" "$BIN/herdr-session-name-sync" "$HOOK"
  hook_entry remove || true
  rm -rf "$HOME/.cache/rename-herdr" "$CONF"
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
  if hook_entry has 2>/dev/null && [ -x "$HOOK" ]; then
    cmp -s "$HERE/rename-herdr-version-check" "$HOOK" && ok "hook SessionStart de version posé" || ko "hook de version différent du dépôt (relancer ./install.sh)"
    rv=$(cat "$HOME/.cache/rename-herdr/remote-version" 2>/dev/null || true)
    ok "dernière version vue au dépôt distant : ${rv:-pas encore lue (au prochain démarrage de session)}"
  else ko "hook SessionStart de version absent (./install.sh le pose, --no-hook pour s'en passer)"; fi
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

# ── hook SessionStart : signale à l'agent une version plus récente au dépôt (fetch en arrière-plan, 1x/24 h)
mkdir -p "$CONF"
printf '%s' "$BIN" > "$CONF/bin"
url=$(git -C "$HERE" remote get-url origin 2>/dev/null || true)
if [ "$HOOK_ON" = 1 ] && [ -n "$url" ]; then
  printf '%s' "$url" > "$CONF/remote"
  mkdir -p "$(dirname "$HOOK")"
  install -m 0755 "$HERE/rename-herdr-version-check" "$HOOK"
  hook_entry add && echo "installé : $HOOK (SessionStart dans $SETTINGS ; dépôt suivi : $url)"
else
  rm -f "$HOOK" "$CONF/remote"; hook_entry remove || true
  [ "$HOOK_ON" = 1 ] && echo "hook de version non posé : $HERE n'est pas un clone git avec un remote origin"
fi

# ── activation (idempotent) + premier passage
systemctl --user daemon-reload
systemctl --user enable --now rename-herdr.path >/dev/null
systemctl --user restart rename-herdr.path
echo "unité rename-herdr.path : $(systemctl --user is-active rename-herdr.path)"
RENAME_HERDR_TARGET=$TARGET "$BIN/herdr-session-name-sync" --verbose || true
echo "vérifier : ./selftest.sh ; diagnostic : ./install.sh --check ; journal : journalctl --user -u rename-herdr.service -n 20"
