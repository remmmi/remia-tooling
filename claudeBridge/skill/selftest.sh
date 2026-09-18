#!/usr/bin/env bash
# Autotest du bridge : aller-retour send/read + reveil evenementiel de watch, sur un fichier
# temporaire (BRIDGE_FILE) : ne touche ni au vrai canal, ni a un projet, n'ouvre aucun tab.
# Usage: ./selftest.sh [vps]     vps = "local" (defaut, sur le VPS) ou alias ssh du VPS (depuis le laptop)
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
vps="${1:-local}"
b="$here/bridge.sh"
export BRIDGE_FILE="/tmp/claude-bridge-selftest-$$.log"
rsh() { if [ "$vps" = "local" ]; then bash -c "$*"; else ssh -o BatchMode=yes -o ConnectTimeout=8 "$vps" "$@"; fi; }
cleanup() { rsh "rm -f '$BRIDGE_FILE'" >/dev/null 2>&1; rm -rf "$HOME/.claude/claude-bridge/state/"*selftest* 2>/dev/null; }
trap cleanup EXIT
fail=0

bash "$b" open st-a "$vps" "selftest" >/dev/null || { echo "[FAIL] open"; exit 1; }
bash "$b" send st-b "$vps" "ping-$$" >/dev/null
if bash "$b" read st-a "$vps" | grep -q "ping-$$"; then echo "[OK] send/read"; else echo "[FAIL] send/read"; fail=1; fi
if bash "$b" read st-b "$vps" | grep -q "ping-$$"; then echo "[FAIL] st-b relit son propre bloc"; fail=1; else echo "[OK] filtre pseudo (pas d'auto-lecture)"; fi

( sleep 1; bash "$b" send st-b "$vps" "pong-$$" >/dev/null ) &
start=$(date +%s)
if bash "$b" watch st-a "$vps" 15 | grep -q "pong-$$"; then
  echo "[OK] watch reveille en $(( $(date +%s) - start ))s (evenementiel)"
else echo "[FAIL] watch"; fail=1; fi
wait
exit $fail
