#!/usr/bin/env bash
# Autotest de `vue` sans rien ouvrir : VUE_DRY=1 imprime les commandes herdr au lieu de les lancer.
# Contrôles : géométrie selon la largeur, focus (saisir/lire oui, montrer non), droits d'un secret,
# refus d'un secret suivi par git, consigne posée puis retirée, empreinte sans contenu.
#
#   ./selftest.sh        code retour 0 = tout vert ; n'écrit que dans un répertoire temporaire
set -uo pipefail
V="$(cd "$(dirname "$0")" && pwd)/bin/vue"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
export VUE_DRY=1 HERDR_ENV=1 HERDR_PANE_ID=w0:p0 HERDR_WORKSPACE_ID=w0
ok=0; ko=0
check() { if eval "$2" >/dev/null 2>&1; then echo "ok  $1"; ok=$((ok+1)); else echo "KO  $1"; ko=$((ko+1)); fi; }

out=$("$V" saisir "$T/s/jeton" "Colle le jeton" --secret 2>&1)
check "saisir : focus donné"                        "grep -q -- '--focus' <<<\"\$out\""
check "saisir : nano puis exit (le pane se ferme)"  "grep -q 'jeton; exit' <<<\"\$out\""
check "saisir --secret : fichier 600, dossier 700"  "[ \"\$(stat -c %a '$T/s/jeton')\" = 600 ] && [ \"\$(stat -c %a '$T/s')\" = 700 ]"
check "saisir : consigne posée, curseur ligne 2"    "grep -q '^# vue: Colle le jeton' '$T/s/jeton' && grep -q ' +2 ' <<<\"\$out\""
out=$(VUE_LARGEUR=90 "$V" saisir "$T/r.md" "Colle le relevé" 2>&1)
check "pane étroit : coupe en bas"                  "grep -q -- '--direction down' <<<\"\$out\""
check "markdown : consigne en commentaire HTML"     "grep -q '^<!-- vue: Colle le relevé' '$T/r.md'"
printf 'deja\n' > "$T/plein"; "$V" saisir "$T/plein" "x" >/dev/null 2>&1
check "fichier rempli : rien d'écrasé"              "[ \"\$(cat '$T/plein')\" = deja ]"
git -C "$T" init -q 2>/dev/null
check "secret suivi par git : refusé"               "! '$V' saisir '$T/fuite.txt' x --secret"
printf '*.key\n' > "$T/.gitignore"
check "secret ignoré par git : accepté"             "'$V' saisir '$T/ok.key' x --secret"
out=$("$V" montrer "logs" tail -f /dev/null 2>&1)
check "montrer : jamais de focus"                   "! grep -q -- '--focus' <<<\"\$out\" && grep -q 'rename .* logs' <<<\"\$out\""
out=$("$V" lire "$T/r.md" --sous "$T/plein" --numeros 2>&1)
check "lire --sous : deux panes, bas sous haut"     "[ \"\$(grep -c 'pane split' <<<\"\$out\")\" = 2 ] && grep -q -- '--pane w0:p.* --direction down\|--direction down .*--pane' <<<\"\$out\""
check "lire : confort et numéros"                   "grep -q -- '--softwrap --atblanks --mouse' <<<\"\$out\" && grep -q -- '--linenumbers' <<<\"\$out\""
printf '# vue: x\nTOKEN=abc def\n' > "$T/sec"; chmod 600 "$T/sec"; out=$("$V" secret "$T/sec")
check "secret : longueur et espace signalés"        "grep -q 'TOKEN = 7 car. — 1 espace' <<<\"\$out\""
check "secret : contenu jamais affiché"             "! grep -q 'abc' <<<\"\$out\""
"$V" nettoyer "$T/sec"
check "nettoyer : consigne retirée, reste gardé"    "[ \"\$(cat '$T/sec')\" = 'TOKEN=abc def' ]"
unset VUE_DRY; out=$(env -u HERDR_ENV -u TMUX "$V" lire "$T/plein" 2>/dev/null); rc=$?
check "sans multiplexeur : ligne ! nano, code 3"    "[ $rc = 3 ] && grep -q '^! nano ' <<<\"\$out\""

echo "$ok ok, $ko KO"; [ "$ko" = 0 ]
