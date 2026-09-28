#!/usr/bin/env bash
# Installe (ou met à jour) usec : idempotent, relançable à volonté.
#
#   ./install.sh                         script + porte quota, rien d'autre
#   ./install.sh --claude-md FICHIER     + insère/remplace le bloc usec dans ce CLAUDE.md
#   options : --bin DIR (défaut ~/.local/bin)  --lib DIR (défaut ~/.local/share/usec)
#             --lang fr|en (bloc CLAUDE.md, défaut fr)
#
# N'écrit que dans --bin, --lib et, si demandé, le CLAUDE.md nommé (entre les marqueurs
# <!-- usec:start --> / <!-- usec:end -->, le reste du fichier intact).
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
BIN="$HOME/.local/bin"
LIB="$HOME/.local/share/usec"
CLAUDE_MD=""
LANG_MD=fr

while [ $# -gt 0 ]; do
  case "$1" in
    --bin)       BIN=$2; shift 2 ;;
    --lib)       LIB=$2; shift 2 ;;
    --claude-md) CLAUDE_MD=$2; shift 2 ;;
    --lang)      LANG_MD=$2; shift 2 ;;
    -h|--help)   sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "argument inconnu : $1 (voir --help)" >&2; exit 2 ;;
  esac
done
case "$LANG_MD" in fr|en) ;; *) echo "--lang : fr ou en" >&2; exit 2 ;; esac

# ── prérequis
python3 -c 'import sys, zoneinfo; zoneinfo.ZoneInfo("UTC"); sys.exit(sys.version_info < (3, 9))' \
  || { echo "python3 >= 3.9 avec zoneinfo (et tzdata) requis" >&2; exit 1; }
command -v claude >/dev/null || echo "attention : 'claude' introuvable dans le PATH — usec en a besoin pour tourner" >&2

# ── fichiers
mkdir -p "$BIN" "$LIB"
install -m 0755 "$HERE/usec" "$BIN/usec"
install -m 0644 "$HERE/quota_gate.sh" "$LIB/quota_gate.sh"
echo "installé : $BIN/usec"
echo "installé : $LIB/quota_gate.sh"

case ":$PATH:" in
  *":$BIN:"*) ;;
  *) echo "attention : $BIN n'est pas dans le PATH. Ajouter à ~/.profile (pas .bashrc : il s'arrête" \
          "pour les shells non interactifs) : export PATH=\"$BIN:\$PATH\"" >&2 ;;
esac

# ── bloc CLAUDE.md
if [ -n "$CLAUDE_MD" ]; then
  mkdir -p "$(dirname "$CLAUDE_MD")"
  touch "$CLAUDE_MD"
  python3 - "$CLAUDE_MD" "$HERE/claude-md.$LANG_MD.md" "$LIB/quota_gate.sh" <<'PY'
import re, sys
target, snippet_path, gate = sys.argv[1:]
block = open(snippet_path, encoding="utf-8").read().strip()
block = block.replace("~/.local/share/usec/quota_gate.sh", gate.replace(__import__("os").path.expanduser("~"), "~"))
text = open(target, encoding="utf-8").read()
pattern = re.compile(r"<!-- usec:start.*?<!-- usec:end -->", re.DOTALL)
if pattern.search(text):
    text = pattern.sub(lambda _: block, text, count=1)
    action = "remplacé"
else:
    text = (text.rstrip() + "\n\n" if text.strip() else "") + block + "\n"
    action = "ajouté"
open(target, "w", encoding="utf-8").write(text)
print(f"bloc usec {action} dans {target}")
PY
fi
