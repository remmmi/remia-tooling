#!/usr/bin/env bash
# Installation de PrismText sur une machine (poste ou VPS). Idempotent.
#
#   ./install.sh                     skills dans ~/.claude/skills (toutes sessions)
#   ./install.sh --project <dossier> skills dans <dossier>/.claude/skills (ce projet seulement)
#   ./install.sh --uninstall         retire liens, CLI et ~/.config/prismtext
#
# Les skills et la CLI sont des liens symboliques vers ce depot : un `git pull`
# du depot met tout a jour. Le branchement a un projet (adaptateurs, config)
# est fait ensuite par le skill prismtext-install.
set -euo pipefail

HOME_PT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$HOME/.claude/skills"
BIN_DIR="$HOME/.local/bin"
CONF_DIR="$HOME/.config/prismtext"

if [[ "${1:-}" == "--uninstall" ]]; then
  for s in prismtext prismtext-install; do
    for d in "$SKILLS_DIR/$s" ./.claude/skills/$s; do
      [[ -L "$d" ]] && rm "$d" && echo "[OK] retire $d"
    done
  done
  [[ -L "$BIN_DIR/prismtext" ]] && rm "$BIN_DIR/prismtext" && echo "[OK] retire $BIN_DIR/prismtext"
  rm -rf "$CONF_DIR" && echo "[OK] retire $CONF_DIR"
  exit 0
fi

if [[ "${1:-}" == "--project" ]]; then
  [[ -d "${2:-}" ]] || { echo "[ERROR] --project demande un dossier existant"; exit 2; }
  SKILLS_DIR="$(cd "$2" && pwd)/.claude/skills"
fi

command -v node >/dev/null || { echo "[ERROR] Node.js introuvable (>= 18 requis)"; exit 1; }
NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
(( NODE_MAJOR >= 18 )) || { echo "[ERROR] Node $NODE_MAJOR detecte, >= 18 requis"; exit 1; }

node "$HOME_PT/engine/cli.mjs" selftest || { echo "[ERROR] selftest en echec : installation annulee"; exit 1; }

mkdir -p "$SKILLS_DIR" "$BIN_DIR" "$CONF_DIR"
for s in prismtext prismtext-install; do
  target="$SKILLS_DIR/$s"
  if [[ -e "$target" && ! -L "$target" ]]; then
    echo "[ERROR] $target existe et n'est pas un lien PrismText : a regarder a la main"; exit 1
  fi
  ln -sfn "$HOME_PT/skills/$s" "$target"
  echo "[OK] skill $s -> $target"
done
chmod +x "$HOME_PT/engine/cli.mjs"
ln -sfn "$HOME_PT/engine/cli.mjs" "$BIN_DIR/prismtext"
echo "$HOME_PT" > "$CONF_DIR/home"
echo "[OK] CLI $BIN_DIR/prismtext ; moteur enregistre dans $CONF_DIR/home"
case ":$PATH:" in *":$BIN_DIR:"*) ;; *) echo "[WARN] $BIN_DIR absent du PATH : les skills utiliseront le chemin enregistre" ;; esac
echo "[OK] PrismText $(node -p "require('$HOME_PT/package.json').version") installe. Suite : dans le projet cible, demander a Claude \"branche PrismText sur ce projet\"."
