#!/usr/bin/env bash
# Contrôle du dépôt avant de pousser : versions cohérentes, copies de plugin-setup.sh identiques,
# manifestes valides, autotests qui tournent sans rien toucher à la machine.
#
#   tests/check.sh            tout
#   tests/check.sh --quick    sans `claude plugin validate` ni les autotests
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd); cd "$ROOT"
QUICK=0; [ "${1:-}" = --quick ] && QUICK=1
ok=0; ko=0
good() { echo "ok  $*"; ok=$((ok+1)); }
bad()  { echo "KO  $*"; ko=$((ko+1)); }
same() { if [ -n "$2" ] && [ "$2" = "$3" ]; then good "$1 : $2"; else bad "$1 : « $2 » != « $3 »"; fi; }
manifest() { python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("version",""))' "$1/.claude-plugin/plugin.json" 2>/dev/null; }
front() { sed -n 's/^version: *//p' "$1" | head -n 1; }

# ── versions : celle de plugin.json est celle que compare Claude Code ; l'outil doit dire la même
same "remia : plugin.json = bin/remia-tooling"            "$(manifest remia)" "$(sed -n 's/^VERSION = "\(.*\)"$/\1/p' remia/bin/remia-tooling)"
same "remia : plugin.json = SKILL.md"                     "$(manifest remia)" "$(front remia/skills/remia-tooling/SKILL.md)"
same "rename-herdr : plugin.json = herdr-session-name-sync" "$(manifest rename_herdr)" "$(sed -n 's/^VERSION = "\(.*\)"$/\1/p' rename_herdr/herdr-session-name-sync)"
same "rename-herdr : plugin.json = SKILL.md"              "$(manifest rename_herdr)" "$(front rename_herdr/skills/rename-herdr/SKILL.md)"
same "usec : plugin.json = USEC_VERSION"                  "$(manifest usec)" "$(sed -n 's/^USEC_VERSION=//p' usec/usec)"
same "simple : plugin.json = SKILL.md"                    "$(manifest skills/simple)" "$(front skills/simple/SKILL.md)"
same "chatroom : plugin.json = SKILL.md"                  "$(manifest skills/chatroom)" "$(front skills/chatroom/SKILL.md)"

# ── chaque version figure dans le tableau « Versions » du README de l'outil
for d in remia rename_herdr usec skills/simple skills/chatroom; do
  v=$(manifest "$d")
  grep -q "^| $v |" "$d/README.md" && good "$d/README.md : ligne $v dans Versions" || bad "$d/README.md : pas de ligne $v dans Versions"
done

# ── marketplace : sources relatives existantes, noms égaux à ceux des plugin.json, pas d'autre version déclarée
python3 - <<'PY' && good "marketplace.json : sources, noms et versions cohérents" || bad "marketplace.json incohérent (détail ci-dessus)"
import json, os, sys
m = json.load(open(".claude-plugin/marketplace.json"))
rc = 0
for p in m["plugins"]:
    src = p["source"]
    if not isinstance(src, str):
        continue  # plugin d'un autre dépôt : sa version se lit là-bas
    try:
        pj = json.load(open(os.path.join(src, ".claude-plugin", "plugin.json")))
    except Exception as e:
        print(f"    {p['name']} : {src}/.claude-plugin/plugin.json illisible ({e})"); rc = 1; continue
    if pj.get("name") != p["name"]:
        print(f"    {p['name']} : plugin.json dit « {pj.get('name')} »"); rc = 1
    if "version" in p and p["version"] != pj.get("version"):
        print(f"    {p['name']} : marketplace {p['version']} != plugin.json {pj.get('version')}"); rc = 1
sys.exit(rc)
PY

# ── copies du hook de mise en place
for d in rename_herdr usec; do
  cmp -s lib/plugin-setup.sh "$d/hooks/plugin-setup.sh" && good "$d/hooks/plugin-setup.sh identique à lib/" \
    || bad "$d/hooks/plugin-setup.sh diffère de lib/plugin-setup.sh (cp lib/plugin-setup.sh $d/hooks/)"
done

# ── hooks.json lisibles, scripts appelés présents et exécutables
for f in remia/hooks/hooks.json rename_herdr/hooks/hooks.json usec/hooks/hooks.json; do
  python3 - "$f" <<'PY' && good "$f : JSON valide, scripts présents" || bad "$f : invalide ou script manquant"
import json, os, re, sys
path = sys.argv[1]; root = os.path.dirname(os.path.dirname(path))
rc = 0
for groups in json.load(open(path))["hooks"].values():
    for g in groups:
        for h in g["hooks"]:
            for rel in re.findall(r"\$\{CLAUDE_PLUGIN_ROOT\}/([\w./-]+)", h["command"]):
                if not os.access(os.path.join(root, rel), os.X_OK):
                    print(f"    {rel} absent ou non exécutable"); rc = 1
sys.exit(rc)
PY
done

# ── rien de personnel dans ce qui est distribué (chemin absolu d'un compte, nom de machine ou de projet)
perso=$(grep -rnIP '(?<![\w$}])/home/[a-z0-9_-]+/|kilorem|kilometrack' --exclude-dir=.git \
          .claude-plugin remia rename_herdr usec skills lib bootstrap.sh README.md 2>/dev/null || true)
if [ -n "$perso" ]; then
  bad "chemin ou nom personnel dans les fichiers distribués :"; sed 's/^/    /' <<<"$perso"
else
  good "aucun chemin ni nom personnel dans les fichiers distribués"
fi

if [ "$QUICK" = 0 ]; then
  if command -v claude >/dev/null; then
    for d in . remia rename_herdr usec skills/simple; do
      claude plugin validate "$d" >/dev/null 2>&1 && good "claude plugin validate $d" || bad "claude plugin validate $d"
    done
  else
    echo "--  claude introuvable : validation des manifestes sautée"
  fi
  for t in tests/plugin-setup-test.sh remia/selftest.sh usec/selftest.sh; do
    out=$("$t" 2>&1) && good "$t : $(tail -n 1 <<<"$out")" || { bad "$t : $(tail -n 1 <<<"$out")"; grep '^KO' <<<"$out" | sed 's/^/    /'; }
  done
fi

echo "$ok ok, $ko KO"; [ "$ko" -eq 0 ]
