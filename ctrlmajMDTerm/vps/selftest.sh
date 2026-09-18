#!/usr/bin/env bash
# Autotest VPS : cree un tab mdterm sur un .md temporaire, verifie, ferme. Necessite un serveur herdr actif.
set -euo pipefail
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
f="$(mktemp --suffix=.md)"; trap 'rm -f "$f"' EXIT
printf '# selftest herdr-mdterm\n' > "$f"
tab="$(herdr-open-md "$f")"
sleep 1
pane="$(herdr pane list | jq -r --arg t "$tab" '.result.panes[] | select(.tab_id==$t) | .pane_id' | head -1)"
if herdr pane read "$pane" | grep -q "selftest herdr-mdterm"; then
  echo "[OK] tab $tab cree, mdterm affiche le fichier"; rc=0
else
  echo "[FAIL] tab $tab cree mais mdterm n'affiche pas le fichier"; rc=1
fi
herdr tab close "$tab" >/dev/null 2>&1 || true
exit $rc
