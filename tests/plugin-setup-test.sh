#!/usr/bin/env bash
# Autotest de lib/plugin-setup.sh dans un HOME jetable, avec un faux plugin et un faux install.sh.
set -uo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
ok=0; ko=0
check() { if eval "$2" >/dev/null 2>&1; then echo "ok  $1"; ok=$((ok+1)); else echo "KO  $1"; ko=$((ko+1)); fi; }
export HOME="$T/home"; mkdir -p "$HOME"
unset CLAUDE_PLUGIN_ROOT

P="$T/plugin"; mkdir -p "$P/.claude-plugin" "$P/hooks"
cp "$HERE/lib/plugin-setup.sh" "$P/hooks/"
setver() { printf '{\n  "name": "demo",\n  "version": "%s"\n}\n' "$1" > "$P/.claude-plugin/plugin.json"; }
# faux install.sh : note chaque appel, échoue si le fichier "casse" existe
cat > "$P/install.sh" <<'SH'
#!/usr/bin/env bash
echo "appel $*" >> "$HOME/appels"
[ -e "$HOME/casse" ] && { echo "ligne d'erreur de l'installeur"; exit 1; }
exit 0
SH
run() { bash "$P/hooks/plugin-setup.sh" demo "$@"; }
appels() { wc -l < "$HOME/appels" 2>/dev/null || echo 0; }
STAMP="$HOME/.config/remia-tooling/demo/installed-version"

setver 1.0.0
out=$(run --target tab)
check "première mise en place : install.sh lancé avec les arguments" "grep -qx 'appel --target tab' '$HOME/appels'"
check "première mise en place : témoin écrit, une ligne dite"        "[ \"\$(cat '$STAMP')\" = '1.0.0 --target tab' ] && grep -q 'demo 1.0.0 mis en place' <<<'$out'"
out=$(run --target tab)
check "rien à faire : pas de nouvel appel, aucune sortie"            "[ \"\$(appels)\" = 1 ] && [ -z '$out' ]"
setver 1.1.0; run --target tab >/dev/null
check "changement de version : relancé"                              "[ \"\$(appels)\" = 2 ] && [ \"\$(cat '$STAMP')\" = '1.1.0 --target tab' ]"
run --target both >/dev/null
check "changement de réglage : relancé"                              "[ \"\$(appels)\" = 3 ] && [ \"\$(cat '$STAMP')\" = '1.1.0 --target both' ]"
setver 1.2.0; touch "$HOME/casse"; run --target both > "$T/out"; rc=$?
check "échec : code 0, raison dite, aussi dans le contexte de Claude" "[ $rc = 0 ] && grep -q 'en échec' '$T/out' && grep -q 'erreur de l.installeur' '$T/out' && grep -q additionalContext '$T/out'"
check "échec : témoin inchangé"                                      "[ \"\$(cat '$STAMP')\" = '1.1.0 --target both' ]"
rm "$HOME/casse"; run --target both >/dev/null
check "nouvel essai à la session suivante : réussi"                  "[ \"\$(appels)\" = 5 ] && [ \"\$(cat '$STAMP')\" = '1.2.0 --target both' ]"
rm "$P/.claude-plugin/plugin.json"; out=$(run); rc=$?
check "plugin.json illisible : code 0, silence, pas d'appel"         "[ $rc = 0 ] && [ -z '$out' ] && [ \"\$(appels)\" = 5 ]"
setver 2.0.0; out=$(run)
check "sans argument : témoin = version seule"                       "[ \"\$(cat '$STAMP')\" = '2.0.0' ]"
echo "$ok ok, $ko KO"; [ "$ko" -eq 0 ]
