#!/usr/bin/env bash
# Installe cote VPS : herdr-open-md + mdlink (+ mdterm si --install-mdterm).
# Idempotent. Usage: ./install.sh [--install-mdterm]
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$HOME/.local/bin"
install -m 755 "$here/herdr-open-md" "$here/mdlink" "$HOME/.local/bin/"
echo "[ok] herdr-open-md + mdlink -> ~/.local/bin"

export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
miss=0
command -v herdr >/dev/null || { echo "[!!] herdr absent"; miss=1; }
command -v jq    >/dev/null || { echo "[!!] jq absent : sudo apt install jq"; miss=1; }

if ! command -v mdterm >/dev/null; then
  if [ "${1:-}" = "--install-mdterm" ]; then
    command -v cc >/dev/null || { echo "[!!] compilateur C absent : sudo apt install build-essential pkg-config"; exit 1; }
    if ! command -v cargo >/dev/null; then
      curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
      . "$HOME/.cargo/env"
    fi
    cargo install mdterm
  else
    echo "[!!] mdterm absent : relancer avec --install-mdterm (rustup + cargo install mdterm)"; miss=1
  fi
fi

# Piege : ssh non interactif n'a pas ~/.local/bin dans son PATH ; le handler laptop utilise bash -lc.
# Verifier que le shell de login le voit aussi :
if ! bash -lc 'command -v herdr-open-md && command -v mdterm' >/dev/null 2>&1; then
  echo "[!!] 'bash -lc' ne trouve pas herdr-open-md et/ou mdterm : ajouter ~/.local/bin et ~/.cargo/bin au PATH dans ~/.profile"
  miss=1
fi
[ "$miss" -eq 0 ] && echo "[ok] VPS pret. Autotest : $here/selftest.sh" || exit 1
