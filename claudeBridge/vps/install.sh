#!/usr/bin/env bash
# Cote VPS : installe le skill claude-bridge pour l'utilisateur courant (~/.claude/skills/claude-bridge).
# N'ecrit dans AUCUN projet. Le vps du bridge est "local" ici (commandes executees sur place).
# Usage: ./install.sh [--target <dir>]     (defaut ~/.claude/skills/claude-bridge)
set -euo pipefail
here="$(cd "$(dirname "$0")/../skill" && pwd)"
target="$HOME/.claude/skills/claude-bridge"
[ "${1:-}" = "--target" ] && target="$2"

for t in tail timeout stat awk; do command -v "$t" >/dev/null || { echo "[!!] $t manquant"; exit 1; }; done
mkdir -p "$target"
install -m 755 "$here/bridge.sh" "$here/selftest.sh" "$target/"
install -m 640 "$here/SKILL.md" "$target/"
echo "[ok] skill installe : $target"
echo "[..] autotest"
"$target/selftest.sh" local
echo "Pseudo suggere : vps-claude ; commande : bash $target/bridge.sh {open|send|read|watch} vps-claude local ..."
