#!/usr/bin/env bash
# Installe (ou met à jour) markitdown pour un agent : idempotent, relançable à volonté.
#
#   ./install.sh                       environnement Python de markitdown + commande to-md ; rien d'autre
#   ./install.sh --skill-dir DIR       + copie le skill dans DIR/markitdown/ (dossier de skills d'un agent
#                                        qui n'a pas de plugins)
#   ./install.sh --agents-md FICHIER   + insère/remplace la règle d'aiguillage dans ce fichier
#                                        d'instructions (AGENTS.md, CLAUDE.md, GEMINI.md…)
#   ./install.sh --check               constate seulement : environnement, version, to-md
#   ./install.sh --uninstall           retire l'environnement et to-md ; avec --skill-dir / --agents-md,
#                                        retire aussi le skill copié et le bloc de règle
#   options : --bin DIR (défaut ~/.local/bin)
#   variables : MARKITDOWN_VENV    l'environnement (défaut ${XDG_DATA_HOME:-~/.local/share}/markitdown/venv)
#               MARKITDOWN_SPEC    ce que pip installe (défaut : formats bureautiques, voir SPEC plus bas ;
#                                  tout, audio et YouTube compris : 'markitdown[all]')
#               MARKITDOWN_PYTHON  l'interpréteur qui crée l'environnement (défaut python3, sinon python)
#
# N'écrit que dans l'environnement, --bin et, si demandé, DIR/markitdown/ et le fichier nommé (entre
# les marqueurs <!-- markitdown:start --> / <!-- markitdown:end -->, le reste du fichier intact).
# Ni sudo ni paquet système : tout tient dans le compte de l'utilisateur.
#
# Avec le plugin Claude Code « markitdown » (marketplace remia-tooling), ce script est lancé sans option
# au démarrage de session ; le skill et la règle viennent alors du plugin.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
BIN="$HOME/.local/bin"
VENV=${MARKITDOWN_VENV:-${XDG_DATA_HOME:-$HOME/.local/share}/markitdown/venv}
# PDF, Word, PowerPoint, Excel (xlsx et xls), Outlook ; HTML, CSV, JSON, XML, EPUB et ZIP sont dans la base.
# Borné à la série 0.1 : une série suivante se valide ici avant d'arriver sur les machines.
SPEC=${MARKITDOWN_SPEC:-markitdown[pdf,docx,pptx,xlsx,xls,outlook]>=0.1.6,<0.2}
SKILL_DIR=""
AGENTS_MD=""
MODE=install

while [ $# -gt 0 ]; do
  case "$1" in
    --bin)       BIN=$2; shift 2 ;;
    --skill-dir) SKILL_DIR=$2; shift 2 ;;
    --agents-md) AGENTS_MD=$2; shift 2 ;;
    --check)     MODE=check; shift ;;
    --uninstall) MODE=uninstall; shift ;;
    -h|--help)   sed -n '2,23p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "argument inconnu : $1 (voir --help)" >&2; exit 2 ;;
  esac
done

venv_python() {
  if [ -x "$VENV/bin/python" ]; then echo "$VENV/bin/python"
  elif [ -x "$VENV/Scripts/python.exe" ]; then echo "$VENV/Scripts/python.exe"
  fi
}
# l'environnement est bon s'il importe markitdown et a été rempli avec la même demande
venv_ready() {
  local py; py=$(venv_python)
  [ -n "$py" ] && "$py" -c 'import markitdown' 2>/dev/null && [ "$(cat "$VENV/.spec" 2>/dev/null)" = "$SPEC" ]
}
md_version() { "$(venv_python)" -c 'from importlib.metadata import version; print(version("markitdown"))' 2>/dev/null || echo "?"; }

if [ "$MODE" = check ]; then
  rc=0; ok() { echo "[ok] $*"; }; ko() { echo "[!!] $*"; rc=1; }
  if [ -z "$(venv_python)" ]; then ko "environnement absent : $VENV (lancer ./install.sh)"
  elif venv_ready; then ok "environnement $VENV : markitdown $(md_version)"
  else ko "environnement $VENV incomplet ou rempli avec une autre demande que « $SPEC » (relancer ./install.sh)"; fi
  if [ ! -x "$BIN/to-md" ]; then ko "$BIN/to-md absent"
  elif cmp -s "$BIN/to-md" "$HERE/bin/to-md"; then ok "$BIN/to-md identique au dépôt ($(sed -n 's/^VERSION="\(.*\)"$/\1/p' "$HERE/bin/to-md"))"
  else ko "$BIN/to-md différent du dépôt (relancer ./install.sh)"; fi
  case ":$PATH:" in *":$BIN:"*) ok "$BIN est dans le PATH" ;; *) echo "[--] $BIN n'est pas dans le PATH : appeler $BIN/to-md par son chemin" ;; esac
  exit $rc
fi

# insère, remplace ou retire le bloc de règle d'un fichier d'instructions ; le reste du fichier intact
rule_block() {  # rule_block poser|retirer FICHIER
  python3 - "$1" "$2" "$HERE/rule.md" <<'EOF_MD'
import os, re, shutil, sys
action, target, snippet = sys.argv[1:]
pattern = re.compile(r"<!-- markitdown:start.*?<!-- markitdown:end -->", re.DOTALL)
text = open(target, encoding="utf-8").read() if os.path.exists(target) else ""
if action == "poser":
    block = open(snippet, encoding="utf-8").read().strip()
    if pattern.search(text):
        new, done = pattern.sub(lambda _: block, text, count=1), "remplacée"
    else:
        new, done = (text.rstrip() + "\n\n" if text.strip() else "") + block + "\n", "ajoutée"
else:
    new, done = re.sub(r"\n*<!-- markitdown:start.*?<!-- markitdown:end -->\n?", "\n", text, flags=re.DOTALL), "retirée"
    new = new.rstrip("\n") + "\n" if new.strip() else ""
if new == text:
    sys.exit(0)
if text:
    shutil.copy2(target, target + ".bak-markitdown")
os.makedirs(os.path.dirname(os.path.abspath(target)), exist_ok=True)
with open(target, "w", encoding="utf-8") as fh:
    fh.write(new)
print(f"règle markitdown {done} dans {target}" + (f" (copie : {target}.bak-markitdown)" if text else ""))
EOF_MD
}

if [ "$MODE" = uninstall ]; then
  rm -rf "$VENV"
  rmdir "$(dirname "$VENV")" 2>/dev/null || true
  rm -f "$BIN/to-md" "$HOME/.config/remia-tooling/markitdown/installed-version"
  rmdir "$HOME/.config/remia-tooling/markitdown" 2>/dev/null || true
  if [ -n "$SKILL_DIR" ] && grep -qs '^name: markitdown$' "$SKILL_DIR/markitdown/SKILL.md"; then
    rm -f "$SKILL_DIR/markitdown/SKILL.md"; rmdir "$SKILL_DIR/markitdown" 2>/dev/null || true
    echo "skill retiré de $SKILL_DIR/markitdown"
  fi
  [ -n "$AGENTS_MD" ] && [ -f "$AGENTS_MD" ] && rule_block retirer "$AGENTS_MD"
  echo "markitdown retiré"; exit 0
fi

# ── environnement Python (sauté s'il est déjà bon : un démarrage de session ne refait pas l'installation)
if venv_ready; then
  echo "environnement déjà en place : $VENV (markitdown $(md_version))"
else
  HOST_PY=${MARKITDOWN_PYTHON:-}
  [ -n "$HOST_PY" ] || HOST_PY=$(command -v python3 || command -v python || true)
  [ -n "$HOST_PY" ] || { echo "python introuvable : installer Python 3.10 ou plus récent" >&2; exit 1; }
  "$HOST_PY" -c 'import sys; sys.exit(sys.version_info < (3, 10))' \
    || { echo "Python 3.10 ou plus récent requis par markitdown ($HOST_PY est plus ancien ; en désigner un autre par MARKITDOWN_PYTHON)" >&2; exit 1; }

  mkdir -p "$(dirname "$VENV")"
  if [ -z "$(venv_python)" ]; then
    # python -m venv d'abord ; sur Debian/Ubuntu il manque parfois (paquet python3-venv) : uv, puis virtualenv
    rm -rf "$VENV"
    "$HOST_PY" -m venv "$VENV" >/dev/null 2>&1 \
      || { rm -rf "$VENV"; command -v uv >/dev/null && uv venv --quiet --python "$HOST_PY" "$VENV"; } \
      || { rm -rf "$VENV"; "$HOST_PY" -m virtualenv --quiet "$VENV" >/dev/null 2>&1; } \
      || { rm -rf "$VENV"
           echo "impossible de créer l'environnement Python : installer le module venv (Debian/Ubuntu : paquet python3-venv) ou uv (https://docs.astral.sh/uv/), puis relancer" >&2
           exit 1; }
  fi
  PY=$(venv_python)
  if "$PY" -m pip --version >/dev/null 2>&1; then
    "$PY" -m pip install --quiet --disable-pip-version-check --upgrade "$SPEC"
  elif command -v uv >/dev/null; then
    uv pip install --quiet --python "$PY" --upgrade "$SPEC"
  else
    echo "ni pip ni uv dans l'environnement $VENV : le supprimer et relancer" >&2; exit 1
  fi
  "$PY" -c 'import markitdown' || { echo "markitdown ne s'importe pas après installation" >&2; exit 1; }
  printf '%s\n' "$SPEC" > "$VENV/.spec"
  echo "installé : $VENV (markitdown $(md_version))"
fi

# ── commande to-md
mkdir -p "$BIN"
install -m 0755 "$HERE/bin/to-md" "$BIN/to-md"
echo "installé : $BIN/to-md"
case ":$PATH:" in
  *":$BIN:"*) ;;
  *) echo "attention : $BIN n'est pas dans le PATH. L'appeler par son chemin, ou ajouter à ~/.profile :" \
          "export PATH=\"$BIN:\$PATH\"" >&2 ;;
esac

# ── skill copié pour un agent sans plugins
if [ -n "$SKILL_DIR" ]; then
  mkdir -p "$SKILL_DIR/markitdown"
  install -m 0644 "$HERE/skills/markitdown/SKILL.md" "$SKILL_DIR/markitdown/SKILL.md"
  echo "installé : $SKILL_DIR/markitdown/SKILL.md"
fi

# ── règle d'aiguillage dans un fichier d'instructions
[ -n "$AGENTS_MD" ] && rule_block poser "$AGENTS_MD"
exit 0
