#!/usr/bin/env bash
# Autotest laptop : simule le clic Ghostty (xdg-open <chemin>) et lit le log.
# Usage: ./selftest.sh /home/user/un/fichier.md    (fichier existant sur le VPS, absent en local)
set -uo pipefail
f="${1:?chemin absolu du .md sur le VPS}"
[ -e "$f" ] && { echo "[!!] $f existe en local : le shim laisserait xdg-open l ouvrir localement"; exit 1; }
before="$(wc -l < "$HOME/.cache/herdr-mdterm.log" 2>/dev/null || echo 0)"
PATH="$HOME/.local/bin:$PATH" xdg-open "$f"; rc=$?
sleep 2
if tail -n +"$((before+1))" "$HOME/.cache/herdr-mdterm.log" 2>/dev/null | grep -q -- "->"; then
  echo "[OK] shim -> mdterm-open -> ssh (rc=$rc). Verifier qu'un tab est apparu dans herdr et le fermer."
else
  echo "[FAIL] pas de relais. Voir ~/.cache/xdg-open-shim.log et ~/.cache/herdr-mdterm.log"; exit 1
fi
