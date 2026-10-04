#!/usr/bin/env bash
# Installe (ou met à jour) usec : idempotent, relançable à volonté.
#
#   ./install.sh                         usec, usec-watch, porte quota ; rien d'autre
#   ./install.sh --hooks [SETTINGS]      + hooks usec-watch (UserPromptSubmit, PostToolUse) dans
#                                          ce settings.json (défaut ~/.claude/settings.json)
#   ./install.sh --claude-md FICHIER     + insère/remplace le bloc usec dans ce CLAUDE.md
#   ./install.sh --check                 constate seulement : version installée vs dépôt, fichiers, hooks
#   ./install.sh --uninstall             retire scripts, porte, état, et ce qui avait été branché à la main
#                                          (hooks usec-watch du settings.json, bloc usec du CLAUDE.md)
#   options : --bin DIR (défaut ~/.local/bin)  --lib DIR (défaut ~/.local/share/usec)
#             --lang fr|en (bloc CLAUDE.md et alertes, défaut fr)
#
# N'écrit que dans --bin, --lib et, si demandé : le settings.json (copie .bak-usec avant ; seules
# les entrées usec-watch sont ajoutées ou remplacées) et le CLAUDE.md nommé (entre les marqueurs
# <!-- usec:start --> / <!-- usec:end -->, le reste du fichier intact).
#
# Avec le plugin Claude Code « usec » (marketplace remia-tooling), ce script est lancé sans option au
# démarrage de session ; les hooks et la règle viennent alors du plugin, pas de --hooks ni --claude-md.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
BIN="$HOME/.local/bin"
LIB="$HOME/.local/share/usec"
CLAUDE_MD=""
SETTINGS=""
LANG_MD=fr
MODE=install

while [ $# -gt 0 ]; do
  case "$1" in
    --bin)       BIN=$2; shift 2 ;;
    --lib)       LIB=$2; shift 2 ;;
    --claude-md) CLAUDE_MD=$2; shift 2 ;;
    --hooks)     if [ $# -ge 2 ] && [ "${2#--}" = "$2" ]; then SETTINGS=$2; shift 2
                 else SETTINGS="$HOME/.claude/settings.json"; shift; fi ;;
    --lang)      LANG_MD=$2; shift 2 ;;
    --check)     MODE=check; shift ;;
    --uninstall) MODE=uninstall; shift ;;
    -h|--help)   sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "argument inconnu : $1 (voir --help)" >&2; exit 2 ;;
  esac
done
case "$LANG_MD" in fr|en) ;; *) echo "--lang : fr ou en" >&2; exit 2 ;; esac

if [ "$MODE" = check ]; then
  rc=0; ok() { echo "[ok] $*"; }; ko() { echo "[!!] $*"; rc=1; }
  repo_v=$(sed -n 's/^USEC_VERSION=//p' "$HERE/usec")
  inst_v=$(sed -n 's/^USEC_VERSION=//p' "$BIN/usec" 2>/dev/null)
  if [ ! -x "$BIN/usec" ]; then ko "$BIN/usec absent"
  elif [ "$inst_v" = "$repo_v" ]; then ok "version $inst_v (= dépôt)"
  else ko "version installée ${inst_v:-<1.0.0} != dépôt $repo_v (relancer ./install.sh, avec les mêmes options qu'à l'installation)"; fi
  for f in "$BIN/usec:$HERE/usec" "$BIN/usec-watch:$HERE/usec-watch" "$LIB/quota_gate.sh:$HERE/quota_gate.sh"; do
    cmp -s "${f%%:*}" "${f#*:}" && ok "${f%%:*} identique au dépôt" || ko "${f%%:*} absent ou différent du dépôt"
  done
  grep -qs usec-watch "$HOME/.claude/settings.json" && ok "hooks usec-watch présents dans ~/.claude/settings.json" \
    || echo "[--] hooks usec-watch absents de ~/.claude/settings.json (optionnels : --hooks)"
  exit $rc
fi

if [ "$MODE" = uninstall ]; then
  rm -f "$BIN/usec" "$BIN/usec-watch" "$LIB/quota_gate.sh" "$HOME/.config/remia-tooling/usec/installed-version"
  rmdir "$LIB" 2>/dev/null || true
  rm -rf "$HOME/.local/state/usec"
  python3 - "${SETTINGS:-$HOME/.claude/settings.json}" "${CLAUDE_MD:-$HOME/.claude/CLAUDE.md}" <<'EOF_UN'
import json, os, re, shutil, sys
settings, claude_md = sys.argv[1:]
if os.path.exists(settings) and "usec-watch" in open(settings, encoding="utf-8").read():
    data = json.load(open(settings, encoding="utf-8"))
    hooks = data.get("hooks", {})
    for event in list(hooks):
        for g in hooks[event]:
            g["hooks"] = [h for h in g.get("hooks", []) if "usec-watch" not in h.get("command", "")]
        hooks[event] = [g for g in hooks[event] if g.get("hooks")]
        if not hooks[event]:
            del hooks[event]
    shutil.copy2(settings, settings + ".bak-usec")
    tmp = settings + ".tmp-usec"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(data, fh, ensure_ascii=False, indent=2)
        fh.write("\n")
    os.replace(tmp, settings)
    print(f"hooks usec-watch retirés de {settings} (copie : {settings}.bak-usec)")
if os.path.exists(claude_md):
    text = open(claude_md, encoding="utf-8").read()
    new = re.sub(r"\n*<!-- usec:start.*?<!-- usec:end -->\n?", "\n", text, flags=re.DOTALL)
    if new != text:
        shutil.copy2(claude_md, claude_md + ".bak-usec")
        open(claude_md, "w", encoding="utf-8").write(new.rstrip("\n") + "\n")
        print(f"bloc usec retiré de {claude_md} (copie : {claude_md}.bak-usec)")
EOF_UN
  echo "usec retiré"; exit 0
fi

# ── prérequis
python3 -c 'import sys, zoneinfo; zoneinfo.ZoneInfo("UTC"); sys.exit(sys.version_info < (3, 9))' \
  || { echo "python3 >= 3.9 avec zoneinfo (et tzdata) requis" >&2; exit 1; }
command -v claude >/dev/null || echo "attention : 'claude' introuvable dans le PATH — usec en a besoin pour tourner" >&2

# ── fichiers
mkdir -p "$BIN" "$LIB"
install -m 0755 "$HERE/usec" "$BIN/usec"
install -m 0755 "$HERE/usec-watch" "$BIN/usec-watch"
install -m 0644 "$HERE/quota_gate.sh" "$LIB/quota_gate.sh"
echo "installé : $BIN/usec, $BIN/usec-watch"
echo "installé : $LIB/quota_gate.sh"

case ":$PATH:" in
  *":$BIN:"*) ;;
  *) echo "attention : $BIN n'est pas dans le PATH. Ajouter à ~/.profile (pas .bashrc : il s'arrête" \
          "pour les shells non interactifs) : export PATH=\"$BIN:\$PATH\"" >&2 ;;
esac

# ── hooks Claude Code (le hook appelle usec par son chemin absolu : le PATH d'un hook peut différer)
if [ -n "$SETTINGS" ]; then
  mkdir -p "$(dirname "$SETTINGS")"
  [ -s "$SETTINGS" ] && cp -p "$SETTINGS" "$SETTINGS.bak-usec"
  python3 - "$SETTINGS" "USEC_BIN='$BIN/usec' '$BIN/usec-watch' hook --lang $LANG_MD" <<'EOF_HOOKS'
import json, os, sys
path, command = sys.argv[1:]
data = {}
if os.path.exists(path) and os.path.getsize(path):
    data = json.load(open(path, encoding="utf-8"))  # JSON invalide : arrêt, rien n'est écrit
hooks = data.setdefault("hooks", {})
for event in ("UserPromptSubmit", "PostToolUse"):
    groups = [g for g in hooks.get(event, [])
              if not any("usec-watch" in h.get("command", "") for h in g.get("hooks", []))]
    groups.append({"hooks": [{"type": "command", "command": command, "timeout": 5}]})
    hooks[event] = groups
tmp = path + ".tmp-usec"
with open(tmp, "w", encoding="utf-8") as fh:
    json.dump(data, fh, ensure_ascii=False, indent=2)
    fh.write("\n")
os.replace(tmp, path)
print(f"hooks usec-watch posés dans {path}")
EOF_HOOKS
fi

# ── bloc CLAUDE.md
if [ -n "$CLAUDE_MD" ]; then
  mkdir -p "$(dirname "$CLAUDE_MD")"
  touch "$CLAUDE_MD"
  python3 - "$CLAUDE_MD" "$HERE/claude-md.$LANG_MD.md" "$LIB/quota_gate.sh" <<'EOF_MD'
import os, re, sys
target, snippet_path, gate = sys.argv[1:]
block = open(snippet_path, encoding="utf-8").read().strip()
block = block.replace("~/.local/share/usec/quota_gate.sh", gate.replace(os.path.expanduser("~"), "~"))
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
EOF_MD
fi
