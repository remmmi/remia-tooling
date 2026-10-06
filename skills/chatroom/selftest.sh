#!/usr/bin/env bash
# Autotest du skill `chatroom` : controles deterministes sur SKILL.md, sans dependance.
#   ./selftest.sh [--skill <chemin SKILL.md>]
# Code retour 0 = tout vert. Ne touche a rien.
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$DIR/SKILL.md"
[ "${1:-}" = --skill ] && SKILL="$2"
[ -r "$SKILL" ] || { echo "skill illisible : $SKILL" >&2; exit 2; }
ko=0
ok() { echo "OK  $1"; }
kofn() { echo "KO  $1"; ko=$((ko + 1)); }

# 1. vocabulaire hote complet
manque=""
for mot in 'STOP' 'TERSE' 'FOCUS' 'N MESSAGES' 'GO' 'au revoir'; do
  grep -q -- "$mot" "$SKILL" || manque="$manque $mot"
done
[ -z "$manque" ] && ok "vocabulaire hote : STOP TERSE FOCUS « N MESSAGES » GO « au revoir »" || kofn "vocabulaire hote incomplet :$manque"

# 2. « role » n'apparait que dans une interdiction (aucun champ role)
if grep -n 'role' "$SKILL" | grep -v -i 'aucun champ `role`' | grep -q 'role'; then
  kofn "« role » apparait hors de l'interdiction"
else
  ok "« role » seulement dans l'interdiction"
fi

# 3. reglages d'ecoute
grep -q 'timeoutMs` 55000' "$SKILL" && grep -q 'wakeOn` addressed' "$SKILL" \
  && ok "ecoute : timeoutMs 55000, wakeOn addressed" || kofn "reglages d'ecoute absents"

# 4. aucun secret, chemin absolu ni hote reel
if grep -nE '[0-9a-f]{48}|(^|[^`])/home/|/Users/|[0-9]{1,3}(\.[0-9]{1,3}){3}' "$SKILL" | grep -q .; then
  kofn "seatKey, chemin absolu ou adresse presente"
else
  ok "aucun seatKey, chemin absolu ni adresse"
fi

# 5. taille
n=$(wc -l < "$SKILL")
[ "$n" -le 120 ] && ok "taille : $n lignes (<= 120)" || kofn "trop long : $n lignes (> 120)"

[ "$ko" -eq 0 ] && echo "TOUT VERT" || echo "$ko controle(s) en echec"
exit $((ko > 0))
