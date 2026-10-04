#!/usr/bin/env bash
# Mise en place automatique d'un outil de remia-tooling dont le plugin Claude Code est actif.
# Appelé au démarrage de session (hook SessionStart du plugin) :
#
#   plugin-setup.sh <plugin> [arguments passés à install.sh…]
#
# Compare « <version du plugin> <arguments> » au témoin ~/.config/remia-tooling/<plugin>/installed-version.
#   identique : sort sans rien faire (une lecture de fichier) ;
#   différent : lance l'install.sh du plugin avec ces arguments, écrit le témoin, le dit en une ligne ;
#   échec     : le dit avec la fin de la sortie d'install.sh, n'écrit pas le témoin
#               (nouvel essai à la session suivante).
# Toujours code 0 : un hook en échec ne doit pas gêner la session.
#
# Source : lib/plugin-setup.sh. Les copies dans <plugin>/hooks/ doivent lui rester identiques
# (un plugin installé ne peut pas lire hors de son dossier) ; tests/check.sh le vérifie.
set -u

plugin=${1:-}
[ -n "$plugin" ] || exit 0
shift

root=${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
version=$(sed -n 's/^ *"version": *"\([^"]*\)".*/\1/p' "$root/.claude-plugin/plugin.json" 2>/dev/null | head -n 1)
[ -n "$version" ] || exit 0

dir="$HOME/.config/remia-tooling/$plugin"
stamp="$dir/installed-version"
want="$version${*:+ $*}"
[ -f "$stamp" ] && [ "$(cat "$stamp" 2>/dev/null)" = "$want" ] && exit 0

# $1 = message pour l'utilisateur ; $2 = "contexte" pour l'ajouter aussi au contexte de Claude
say() {
  python3 - "$1" "${2:-}" <<'PY' 2>/dev/null || printf '%s\n' "$1"
import json, sys
out = {"systemMessage": sys.argv[1]}
if sys.argv[2]:
    out["hookSpecificOutput"] = {"hookEventName": "SessionStart", "additionalContext": sys.argv[1]}
print(json.dumps(out, ensure_ascii=False))
PY
}

if out=$(bash "$root/install.sh" "$@" 2>&1); then
  mkdir -p "$dir" && printf '%s\n' "$want" > "$stamp"
  say "[remia-tooling] $plugin $version mis en place"
else
  say "[remia-tooling] $plugin $version : mise en place en échec, nouvel essai à la prochaine session. Fin de la sortie d'install.sh : $(printf '%s' "$out" | tail -n 3 | tr '\n' ' ')" contexte
fi
exit 0
