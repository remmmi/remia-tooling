#!/usr/bin/env bash
# Autotest de usec, sans réseau ni quota consommé (fixture). `--live` ajoute un vrai appel à usec.
# Aucun état réel touché : usec-watch travaille dans un dossier temporaire (USEC_WATCH_DIR).
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

check "version : usec --version"              "'$HERE/usec' --version | grep -qE '^usec [0-9]+\\.[0-9]+\\.[0-9]+$'"

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

check "install --check : version égale au dépôt" "HOME='$T/home' '$HERE/install.sh' --bin '$T/home/bin' --check | grep '^\\[ok\\] version' >/dev/null"

# 4. usec-watch : état construit à la main (W = dossier d'état, mk = relevé + historique)
W="$T/watch"; export USEC_WATCH_DIR="$W"
mk() {  # mk '<quotas json>' [âge du relevé en s] ['<historique: [[il_y_a_s, used], …]>']
  rm -rf "$W"; mkdir -p "$W"
  python3 - "$W" "$1" "${2:-0}" "${3:-[]}" <<'EOF_MK'
import json, sys, time
from datetime import datetime, timedelta
w, quotas, age, hist = sys.argv[1], json.loads(sys.argv[2]), float(sys.argv[3]), json.loads(sys.argv[4])
now = time.time()
for q in quotas:  # "reset_in" (s) → reset_at ISO
    q["reset_at"] = (datetime.now().astimezone() + timedelta(seconds=q.pop("reset_in"))).isoformat(timespec="seconds")
    q.setdefault("models", "all models"); q.setdefault("timezone", "UTC")
json.dump({"at": now - age, "quotas": quotas}, open(f"{w}/last.json", "w"))
with open(f"{w}/history.jsonl", "w") as fh:
    for ago, used in hist:
        fh.write(json.dumps({"at": now - ago, "quotas": [dict(quotas[0], used_percent=used)]}) + "\n")
EOF_MK
}
hk() { printf '{"session_id":"%s","hook_event_name":"%s"}' "${1:-s1}" "${2:-UserPromptSubmit}" \
         | USEC_BIN=/bin/false "$HERE/usec-watch" hook --lang fr; }
LOW='[{"period":"session","used_percent":20,"reset_in":9000},{"period":"week","used_percent":40,"reset_in":200000}]'
WEEK90='[{"period":"week","used_percent":90,"reset_in":80000}]'

rm -rf "$W"
check "watch : status sans relevé"             "'$HERE/usec-watch' status | grep -q 'aucun relevé'"
mk "$LOW"
check "watch : tout va bien → silence"         "[ -z \"\$(hk)\" ]"
mk "$WEEK90"
check "watch : semaine 90 % → alerte"          "hk | grep -q 'week (all models) à 90 %'"
check "watch : même session → pas de répétition" "[ -z \"\$(hk)\" ]"
check "watch : autre session → alerte"         "hk s2 | grep -q 'additionalContext'"
check "watch : hookEventName suit l'événement" "hk s3 PostToolUse | grep -q '\"hookEventName\": \"PostToolUse\"'"
mk '[{"period":"session","used_percent":95,"reset_in":600}]'
check "watch : session qui se réinitialise < 30 min → silence" "[ -z \"\$(hk)\" ]"
mk "$WEEK90" 10800
check "watch : relevé de plus de 2 h → silence" "[ -z \"\$(hk)\" ]"
mk '[{"period":"session","used_percent":70,"reset_in":10800}]' 0 '[[1200, 60], [0, 70]]'
check "watch : 70 % mais 100 % avant le reset → alerte projetée" "hk | grep -q 'au rythme actuel, 100 %'"
mk '[{"period":"session","used_percent":70,"reset_in":10800}]' 0 '[[1200, 69], [0, 70]]'
check "watch : pente lente → silence"          "[ -z \"\$(hk)\" ]"
# Semaine : une rafale en début de semaine (0 → 3 % en 80 min, 12 h après le reset) ne doit pas
# se projeter 24 h/24 (fausse alerte du 30/09/2026 : « 100 % le 04/10 ») — moyenne depuis le début.
mk '[{"period":"week","used_percent":3,"reset_in":560400}]' 0 '[[4800, 0], [0, 3]]'
check "watch : rafale en début de semaine → silence" "[ -z \"\$(hk)\" ]"
# … mais 60 % en 2 jours (reset dans 5 j) atteint 100 % avant le reset → alerte projetée.
mk '[{"period":"week","used_percent":60,"reset_in":432000}]' 0 '[[4800, 59], [0, 60]]'
check "watch : semaine 60 % en 2 j → alerte projetée" "hk | grep -q 'au rythme actuel, 100 %'"
mk "$WEEK90"
check "watch : USEC_WATCH_INNER → silence"     "[ -z \"\$(printf '{}' | USEC_WATCH_INNER=1 '$HERE/usec-watch' hook)\" ]"
rm -rf "$W"
printf '{}' | USEC_BIN="$T/fake_usec" "$HERE/usec-watch" hook >/dev/null
for _ in $(seq 50); do [ -s "$W/last.json" ] && break; sleep 0.1; done
check "watch : relevé périmé → rafraîchi en arrière-plan" "[ -s '$W/last.json' ] && grep -q session '$W/history.jsonl'"
check "watch : status lit le relevé"           "'$HERE/usec-watch' status | grep -q 'session: 42 %'"
unset USEC_WATCH_DIR

# 5. installeur : hooks fusionnés sans toucher aux existants, idempotent
printf '{"model":"x","hooks":{"UserPromptSubmit":[{"hooks":[{"type":"command","command":"autre-hook"}]}]}}' > "$T/settings.json"
for _ in 1 2; do HOME="$T/home" "$HERE/install.sh" --bin "$T/home/bin" --hooks "$T/settings.json" >/dev/null 2>&1; done
check "hooks : 1 entrée usec-watch par événement, hook existant et réglages gardés" \
  "python3 -c 'import json,sys; d=json.load(open(\"$T/settings.json\")); h=d[\"hooks\"]
n=lambda e: sum(\"usec-watch\" in x[\"command\"] for g in h[e] for x in g[\"hooks\"])
sys.exit(not (n(\"UserPromptSubmit\")==1 and n(\"PostToolUse\")==1 and \"autre-hook\" in json.dumps(h) and d[\"model\"]==\"x\"))'"
check "hooks : sauvegarde .bak-usec"           "[ -s '$T/settings.json.bak-usec' ]"

# 6. appel réel (optionnel : consomme un appel)
if [ "${1:-}" = "--live" ]; then
  check "live : usec rend du JSON" "usec | python3 -c 'import json,sys; json.load(sys.stdin)[\"quotas\"][0]'"
fi

# 6. plugin Claude Code : règle en contexte, hook de surveillance
check "plugin : rule.sh rend la règle, sans les marqueurs" "bash '$HERE/hooks/rule.sh' | grep -q 'usec-watch' && ! bash '$HERE/hooks/rule.sh' | grep -q 'usec:'"
check "plugin : rule.sh en anglais (réglage lang)"    "CLAUDE_PLUGIN_OPTION_LANG=en bash '$HERE/hooks/rule.sh' | grep -q 'Subscription quotas'"
check "plugin : rule.sh muet dans un relevé"          "[ -z \"\$(USEC_WATCH_INNER=1 bash '$HERE/hooks/rule.sh')\" ]"
check "plugin : watch.sh dans un relevé → rc 0, silence" "[ -z \"\$(echo '{}' | USEC_WATCH_INNER=1 bash '$HERE/hooks/watch.sh')\" ]"

# 7. désinstallation (HOME jetable de l'étape 3) : fichiers, hooks posés à la main, bloc CLAUDE.md
mkdir -p "$T/home/.claude"
echo '{"hooks":{"PostToolUse":[{"hooks":[{"type":"command","command":"autre"}]}]}}' > "$T/home/.claude/settings.json"
HOME="$T/home" "$HERE/install.sh" --bin "$T/home/bin" --hooks >/dev/null 2>&1
HOME="$T/home" "$HERE/install.sh" --bin "$T/home/bin" --claude-md "$T/CLAUDE.md" --uninstall >/dev/null 2>&1
check "uninstall : scripts et porte retirés"       "[ ! -e '$T/home/bin/usec' ] && [ ! -e '$T/home/bin/usec-watch' ] && [ ! -e '$T/home/.local/share/usec/quota_gate.sh' ]"
check "uninstall : hooks usec-watch retirés, les autres gardés" "! grep -q usec-watch '$T/home/.claude/settings.json' && grep -q autre '$T/home/.claude/settings.json' && ! grep -q UserPromptSubmit '$T/home/.claude/settings.json'"
check "uninstall : bloc CLAUDE.md retiré, le reste gardé" "! grep -q 'usec:' '$T/CLAUDE.md' && grep -q 'Règle existante.' '$T/CLAUDE.md'"

echo "$ok ok, $ko KO"
[ "$ko" -eq 0 ]
