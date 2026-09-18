#!/usr/bin/env bash
# Cote laptop (ou toute machine non-VPS) : installe le skill claude-bridge et verifie le VPS.
# N'ecrit dans AUCUN projet. Usage: ./install.sh --vps <alias-ssh> [--target <dir>]
set -euo pipefail
here="$(cd "$(dirname "$0")/../skill" && pwd)"
target="$HOME/.claude/skills/claude-bridge"; vps=""
while [ $# -gt 0 ]; do case "$1" in
  --vps) vps="$2"; shift 2;; --target) target="$2"; shift 2;;
  *) echo "option inconnue: $1" >&2; exit 1;; esac; done
[ -n "$vps" ] || { echo "requis: --vps <alias-ssh>" >&2; exit 1; }

echo "[..] ssh sans mot de passe vers $vps"
ssh -o BatchMode=yes -o ConnectTimeout=8 "$vps" true \
  || { echo "[!!] ssh $vps echoue : installer la cle publique (le bridge utilise BatchMode)"; exit 1; }
ssh -o BatchMode=yes "$vps" 'for t in tail timeout stat awk; do command -v $t >/dev/null || { echo "manque sur le VPS: $t"; exit 1; }; done' \
  || exit 1

mkdir -p "$target"
install -m 755 "$here/bridge.sh" "$here/selftest.sh" "$target/"
install -m 640 "$here/SKILL.md" "$target/"
echo "[ok] skill installe : $target"
echo "[..] autotest via $vps"
"$target/selftest.sh" "$vps"
echo "Pseudo suggere : laptop-claude ; commande : bash $target/bridge.sh {open|send|read|watch} laptop-claude $vps ..."
