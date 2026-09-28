#!/usr/bin/env bash
# Autotest de usec, sans réseau ni quota consommé (fixture). `--live` ajoute un vrai appel à usec.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
ok=0; ko=0
check() { if eval "$2"; then echo "ok  $1"; ok=$((ok+1)); else echo "KO  $1"; ko=$((ko+1)); fi; }

# 1. parsing de la fixture
"$HERE/usec" --stdin < "$HERE/fixtures/usage_sample.txt" > "$T/q.json"
check "parse : 3 quotas" \
  "python3 -c 'import json,sys; q=json.load(open(\"$T/q.json\"))[\"quotas\"]; sys.exit(len(q)!=3)'"
check "parse : session 42 %, reset ISO avec fuseau" \
  "python3 -c 'import json,sys; s=json.load(open(\"$T/q.json\"))[\"quotas\"][0]; sys.exit(not (s[\"period\"]==\"session\" and s[\"used_percent\"]==42.0 and s[\"reset_at\"].endswith(\":00\") and \"T02:20\" in s[\"reset_at\"]))'"
check "parse : sortie non reconnue → rc 1" \
  "! echo 'rien à voir' | '$HERE/usec' --stdin >/dev/null 2>&1"

# 2. porte quota, avec un faux usec qui rend la fixture
printf '#!/bin/sh\ncat "%s"\n' "$T/q.json" > "$T/fake_usec"; chmod +x "$T/fake_usec"
gate() { ( export USEC_BIN="$1" USEC_GATE_DIR="$T/gate" USEC_GATE_SESSION_MAX="$2" USEC_GATE_WEEK_MAX="$3"
           source "$HERE/quota_gate.sh"; usec_gate_reset; usec_gate ); }
check "porte : sous les seuils → ouverte"      "gate '$T/fake_usec' 70 85"
check "porte : session 42 % >= 40 → fermée"    "! gate '$T/fake_usec' 40 85"
check "porte : motif écrit dans _stop_quota"   "grep -q 'session/all models 42.0% >= 40%' '$T/gate/_stop_quota'"
check "porte : semaine 67 % >= 60 → fermée"    "! gate '$T/fake_usec' 99 60"
check "porte : usec illisible → ouverte"       "gate /bin/false 1 1"

# 3. installeur (dans un HOME jetable) et bloc CLAUDE.md idempotent
printf '# Mon CLAUDE.md\n\nRègle existante.\n' > "$T/CLAUDE.md"
for _ in 1 2; do
  HOME="$T/home" "$HERE/install.sh" --bin "$T/home/bin" --claude-md "$T/CLAUDE.md" >/dev/null 2>&1
done
check "install : script et porte copiés"      "[ -x '$T/home/bin/usec' ] && [ -f '$T/home/.local/share/usec/quota_gate.sh' ]"
check "install : un seul bloc après 2 passes" "[ \$(grep -c 'usec:start' '$T/CLAUDE.md') -eq 1 ]"
check "install : contenu existant conservé"   "grep -q 'Règle existante.' '$T/CLAUDE.md'"

# 4. appel réel (optionnel : consomme un appel)
if [ "${1:-}" = "--live" ]; then
  check "live : usec rend du JSON" "usec | python3 -c 'import json,sys; json.load(sys.stdin)[\"quotas\"][0]'"
fi

echo "$ok ok, $ko KO"
[ "$ko" -eq 0 ]
