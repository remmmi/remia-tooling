#!/usr/bin/env bash
# Autotest du skill integration-maquettes : contrôles déterministes, sans réseau ni claude.
#   bash selftest.sh      Code retour 0 = tout vert.
set -uo pipefail
DIR=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d) || exit 2
trap 'rm -rf -- "$tmp"' EXIT
ko=0
ok() { echo "OK  $1"; }
kofn() { echo "KO  $1"; ko=$((ko + 1)); }

# 1. frontmatter : nom = dossier, description, version
nom=$(sed -n 's/^name: *//p' "$DIR/SKILL.md" | head -n 1)
[ "$nom" = "$(basename "$DIR")" ] && ok "name = $nom" || kofn "name « $nom » ≠ dossier $(basename "$DIR")"
grep -q '^description:' "$DIR/SKILL.md" && ok "description présente" || kofn "description absente"
grep -qE '^version: [0-9]+\.[0-9]+\.[0-9]+$' "$DIR/SKILL.md" && ok "version présente" || kofn "version absente ou mal formée"

# 2. le skill mentionne ses étapes clés et son outil
for mot in "superposer.py" "section" "seuil" "exclusion" "Rapporter" "re-mesurer"; do
    grep -qi "$mot" "$DIR/SKILL.md" && ok "SKILL.md parle de « $mot »" || kofn "SKILL.md ne parle pas de « $mot »"
done

# 3. superposer.py : deux images de synthèse, section décalée, sortie empilée aux bonnes dimensions
if python3 -c 'import PIL' 2>/dev/null; then
    python3 - "$tmp" <<'PY'
import sys
from PIL import Image, ImageDraw
d = sys.argv[1]
a = Image.new("RGB", (400, 600), "white"); ImageDraw.Draw(a).rectangle((50, 100, 350, 300), fill="black"); a.save(f"{d}/m.png")
b = Image.new("RGB", (400, 650), "white"); ImageDraw.Draw(b).rectangle((50, 150, 350, 350), fill="black"); b.save(f"{d}/s.png")
PY
    out=$(python3 "$DIR/superposer.py" "$tmp/m.png" "$tmp/s.png" --y-maquette 100 --y-site 150 --hauteur 200 -o "$tmp/o.png" 2>&1) \
        && ok "superposer.py : $out" || kofn "superposer.py en échec : $out"
    python3 - "$tmp/o.png" <<'PY' && ok "sortie 400 x 624 et différence noire (sections identiques)" || kofn "sortie inattendue (dimensions ou différence non nulle)"
import sys
from PIL import Image
o = Image.open(sys.argv[1]); assert o.size == (400, 200 * 3 + 24), o.size
diff = o.crop((0, 424, 400, 624)); assert diff.getextrema() == ((0, 0), (0, 0), (0, 0)), diff.getextrema()
PY
    python3 "$DIR/superposer.py" "$tmp/m.png" "$tmp/s.png" --hauteur 200 -o "$tmp/o2.png" >/dev/null 2>&1 \
        && python3 -c "import sys; from PIL import Image; d = Image.open(sys.argv[1]).crop((0, 424, 400, 624)); sys.exit(0 if d.getextrema()[0][1] > 0 else 1)" "$tmp/o2.png" \
        && ok "sans alignement, la différence est visible" || kofn "sans alignement, la différence devrait être visible"
else
    echo "--  Pillow absent : contrôle de superposer.py sauté"
fi

# 4. rien de personnel
if grep -rnE '/home/[a-z]+|srv[0-9]{4,}' "$DIR" --include='*.md' --include='*.py' --include='*.sh' | grep -v selftest.sh; then
    kofn "chemin ou nom personnel dans les fichiers"
else ok "rien de personnel"; fi

[ "$ko" -eq 0 ] && echo "TOUT VERT" || echo "$ko contrôle(s) en échec"
exit $((ko > 0))
