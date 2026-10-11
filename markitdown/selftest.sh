#!/usr/bin/env bash
# Autotest de markitdown dans un HOME jetable. Ne touche à rien de réel.
#
#   ./selftest.sh          sans réseau : install.sh et to-md contre un faux environnement Python
#   ./selftest.sh --full   + une vraie installation (pip, réseau, une à deux minutes) et de vraies
#                            conversions : CSV, HTML, classeur Excel fabriqué sur place
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
FULL=0; [ "${1:-}" = --full ] && FULL=1
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
ok=0; ko=0
check() { if eval "$2" >/dev/null 2>&1; then echo "ok  $1"; ok=$((ok+1)); else echo "KO  $1"; ko=$((ko+1)); fi; }
export HOME="$T/home"; mkdir -p "$HOME"
export TMPDIR="$T/tmp"; mkdir -p "$TMPDIR"
unset XDG_DATA_HOME MARKITDOWN_VENV MARKITDOWN_SPEC MARKITDOWN_PYTHON
V="$HOME/.local/share/markitdown/venv"; B="$HOME/.local/bin"
I="$HERE/install.sh"; M="$HERE/bin/to-md"
SPEC=$(sed -n 's/^SPEC=\${MARKITDOWN_SPEC:-\(.*\)}$/\1/p' "$I")

check "to-md sans environnement : code 3, dit quoi lancer"  "echo x > '$T/a.csv'; '$M' '$T/a.csv' 2> '$T/err'; [ \$? = 3 ] && grep -q install.sh '$T/err'"
check "install.sh --check sans rien : en échec"             "! '$I' --check"

# faux environnement : un « python » qui importe tout, et dont « -m markitdown F » rend un titre puis F
mkdir -p "$V/bin"
cat > "$V/bin/python" <<'SH'
#!/usr/bin/env bash
case "$1" in
  -c) case "$2" in *importlib*) echo 9.9.9 ;; esac; exit 0 ;;
  -m) [ "$2" = markitdown ] || exit 1
      [ "$(basename "$3")" = casse.pdf ] && { echo "début de sortie"; exit 1; }
      echo "# converti"; cat "$3" ;;
  *) exit 1 ;;
esac
SH
chmod +x "$V/bin/python"; printf '%s\n' "$SPEC" > "$V/.spec"

"$I" > "$T/inst" 2>&1
check "install.sh : environnement déjà bon, pas de réinstallation" "grep -q 'déjà en place' '$T/inst'"
check "install.sh : to-md posé, identique au dépôt"         "cmp -s '$B/to-md' '$M' && [ -x '$B/to-md' ]"
check "install.sh --check : tout bon"                       "'$I' --check"
check "to-md --version : to-md et markitdown"               "'$B/to-md' --version | grep -q \"^to-md \$(sed -n 's/^VERSION=\\\"\\(.*\\)\\\"\$/\\1/p' '$M'), markitdown 9.9.9\$\""

printf 'a,b\n1,2\n' > "$T/mon tableau.csv"
"$B/to-md" "$T/mon tableau.csv" > "$T/out"
check "to-md : sortie par défaut dans le dossier temporaire, chemin et taille dits" "grep -qx 'converti : $TMPDIR/mon tableau.md' '$T/out' && grep -qx '3 lignes, 4 mots' '$T/out' && grep -q '^# converti' '$TMPDIR/mon tableau.md'"
check "to-md : sortie nommée"                               "'$B/to-md' '$T/mon tableau.csv' '$T/choisi.md' && grep -q '^1,2' '$T/choisi.md'"
check "to-md --stdout : Markdown sur la sortie, aucun fichier" "rm -f '$TMPDIR'/*.md; '$B/to-md' --stdout '$T/mon tableau.csv' | grep '^# converti' && [ -z \"\$(ls '$TMPDIR')\" ]"
echo x > "$T/casse.pdf"; echo ancien > "$T/garde.md"
check "to-md : conversion en échec → code 1, sortie précédente intacte, rien de provisoire" "'$B/to-md' '$T/casse.pdf' '$T/garde.md'; [ \$? = 1 ] && grep -qx ancien '$T/garde.md' && [ -z \"\$(ls '$T' | grep tmp-to-md)\" ]"
check "to-md : fichier introuvable → code 1"                "'$B/to-md' '$T/absent.pdf'; [ \$? = 1 ]"
check "to-md : mauvais usage → code 2"                      "'$B/to-md'; [ \$? = 2 ] && { '$B/to-md' --nimporte x; [ \$? = 2 ]; } && { '$B/to-md' --stdout a b; [ \$? = 2 ]; }"
check "to-md : refuse d'écraser la source"                  "'$B/to-md' '$T/a.csv' '$T/a.csv'; [ \$? = 2 ] && grep -qx x '$T/a.csv'"

echo autre > "$V/.spec"
check "install.sh --check : demande différente → en échec"  "! '$I' --check"
printf '%s\n' "$SPEC" > "$V/.spec"

# skill copié et règle pour un agent sans plugins
printf '# Mes règles\n\nRègle existante.\n' > "$T/AGENTS.md"
"$I" --skill-dir "$T/skills" --agents-md "$T/AGENTS.md" > /dev/null 2>&1
check "--skill-dir : skill copié"                           "cmp -s '$T/skills/markitdown/SKILL.md' '$HERE/skills/markitdown/SKILL.md'"
check "--agents-md : règle ajoutée, le reste gardé, copie faite" "grep -q 'markitdown:start' '$T/AGENTS.md' && grep -q 'Règle existante.' '$T/AGENTS.md' && grep -q 'Règle existante.' '$T/AGENTS.md.bak-markitdown'"
"$I" --agents-md "$T/AGENTS.md" > /dev/null 2>&1
check "--agents-md relancé : un seul bloc"                  "[ \"\$(grep -c 'markitdown:start' '$T/AGENTS.md')\" = 1 ]"
"$I" --agents-md "$T/neuf/AGENTS.md" > /dev/null 2>&1
check "--agents-md : fichier absent → créé avec le bloc seul" "head -n 1 '$T/neuf/AGENTS.md' | grep -q 'markitdown:start'"
check "règle du plugin (hooks/rule.sh) : texte sans les marqueurs" "bash '$HERE/hooks/rule.sh' | grep 'skill .markitdown.' && ! bash '$HERE/hooks/rule.sh' | grep 'markitdown:start'"

mkdir -p "$HOME/.config/remia-tooling/markitdown"; echo 1.0.0 > "$HOME/.config/remia-tooling/markitdown/installed-version"
"$I" --uninstall --skill-dir "$T/skills" --agents-md "$T/AGENTS.md" > /dev/null 2>&1
check "--uninstall : environnement, to-md et témoin retirés" "[ ! -e '$V' ] && [ ! -e '$B/to-md' ] && [ ! -e '$HOME/.config/remia-tooling/markitdown' ]"
check "--uninstall : skill copié et règle retirés, le reste gardé" "[ ! -e '$T/skills/markitdown' ] && ! grep -q 'markitdown:' '$T/AGENTS.md' && grep -q 'Règle existante.' '$T/AGENTS.md'"
check "--uninstall relancé : sans erreur"                   "'$I' --uninstall"
check "argument inconnu → code 2"                           "'$I' --nimporte; [ \$? = 2 ]"

if [ "$FULL" = 1 ]; then
  "$I" > "$T/vrai" 2>&1; rc=$?
  check "vraie installation : réussie"                      "[ $rc = 0 ] && grep -q '^installé : $V (markitdown 0\.' '$T/vrai'"
  [ "$rc" = 0 ] || sed 's/^/    /' "$T/vrai"
  check "vraie installation : --check tout bon"             "'$I' --check"
  "$I" > "$T/vrai2" 2>&1
  check "vraie installation relancée : rien de refait"      "grep -q 'déjà en place' '$T/vrai2'"
  printf 'ville,habitants\nLyon,522000\n' > "$T/villes.csv"
  check "CSV → tableau Markdown"                            "'$B/to-md' --stdout '$T/villes.csv' | grep '| Lyon | 522000 |'"
  printf '<html><body><h1>Titre du document</h1><p>Un <b>mot</b> important.</p></body></html>' > "$T/page.html"
  check "HTML → titre et gras Markdown"                     "'$B/to-md' --stdout '$T/page.html' | grep '^# Titre du document' && '$B/to-md' --stdout '$T/page.html' | grep '\*\*mot\*\*'"
  "$V/bin/python" - "$T/classeur.xlsx" <<'PY'
import sys, openpyxl
wb = openpyxl.Workbook(); ws = wb.active; ws.title = "Ventes"
ws.append(["mois", "montant"]); ws.append(["janvier", 1200])
wb.create_sheet("Stocks").append(["article", "quantité"])
wb.save(sys.argv[1])
PY
  "$B/to-md" "$T/classeur.xlsx" > /dev/null 2>&1
  check "Excel → une section par feuille"                   "grep -q '^## Ventes' '$TMPDIR/classeur.md' && grep -q '^## Stocks' '$TMPDIR/classeur.md' && grep -q '| janvier | 1200 |' '$TMPDIR/classeur.md'"
  check "extras bureautiques présents (PDF, Word, PowerPoint, Outlook, xls)" "'$V/bin/python' -c 'import pdfminer, mammoth, pptx, olefile, xlrd'"
fi
echo "$ok ok, $ko KO"; [ "$ko" -eq 0 ]
