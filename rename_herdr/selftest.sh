#!/usr/bin/env bash
# Vérifie l'installation de rename_herdr, sans créer de fausse session Claude Code.
# Fin attendue : "0 KO". Un test SKIP (herdr pas lancé) n'est pas un KO.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
BIN="${BIN:-$HOME/.local/bin}"
ko=0; t() { if "$@" >/dev/null 2>&1; then echo "[ok] $*"; else echo "[KO] $*"; ko=$((ko+1)); fi; }

# 1. le script du dépôt est du python valide et tourne à vide sans herdr
t python3 -m py_compile "$HERE/herdr-session-name-sync"
t env HERDR_BIN=/nonexistent PATH=/usr/bin "$HERE/herdr-session-name-sync"

# 2. fichiers installés et identiques au dépôt
t test -x "$BIN/herdr-session-name-sync"
t cmp -s "$HERE/herdr-session-name-sync" "$BIN/herdr-session-name-sync"
t test -f "$HOME/.config/systemd/user/rename-herdr.path"

# 3. unité path active
t test "$(systemctl --user is-active rename-herdr.path 2>/dev/null)" = active

# 4. le déclencheur tire : un touch du dossier surveillé doit relancer le service
if [ -d "$HOME/.claude/sessions" ]; then
  before=$(systemctl --user show rename-herdr.service -p ExecMainStartTimestampMonotonic --value)
  touch "$HOME/.claude/sessions"; sleep 2
  after=$(systemctl --user show rename-herdr.service -p ExecMainStartTimestampMonotonic --value)
  t test "$before" != "$after"
else
  echo "[skip] ~/.claude/sessions absent : déclencheur non testé"
fi

# 5. herdr joignable → un dry-run doit parler JSON sans erreur
if command -v herdr >/dev/null 2>&1 && herdr agent list >/dev/null 2>&1; then
  t "$BIN/herdr-session-name-sync" --dry-run
else
  echo "[skip] herdr pas lancé : dry-run non testé"
fi

echo "$ko KO"; exit $((ko > 0))
