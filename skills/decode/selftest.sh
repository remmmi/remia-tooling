#!/usr/bin/env bash
# Autotest du skill `decode` : soumet un court texte de mainteneur (3 paragraphes, idiomes de
# développeur) à `claude -p` avec le skill en contexte, puis vérifie la réponse par des contrôles
# déterministes.
#
#   ./selftest.sh [--skill <chemin SKILL.md>]
#   CLAUDE_BIN=claude  DECODE_MODEL=<modèle optionnel>
#
# Contrôles : trois sections (aucun paragraphe sauté) ; idiomes repris et suivis d'une définition ;
# pas plus court que la source (on décode, on ne résume pas) ; fin « ce qu'il attend ». Code retour 0
# = tout vert. N'écrit rien, ne touche ni au profil ni au glossaire.
set -uo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL="$DIR/SKILL.md"
while [ "$#" -gt 0 ]; do
    case "$1" in
        --skill) SKILL="$2"; shift 2 ;;
        *) echo "usage: $0 [--skill SKILL.md]" >&2; exit 2 ;;
    esac
done
BIN="${CLAUDE_BIN:-claude}"
command -v "$BIN" >/dev/null || { echo "claude introuvable ($BIN) : autotest sauté"; exit 0; }
[ -r "$SKILL" ] || { echo "skill illisible : $SKILL" >&2; exit 2; }

SOURCE="Thanks for the patch, but I would rather not merge it as is: it papers over the race instead of fixing it.

The cache key is built before the lock is taken, so two workers can both miss and both write. That is a sharp edge rather than a hole, since the second write is identical, but it doubles the load on a cold start.

If you move the key computation inside the critical section and add a test that runs two workers, I will happily take it. Could you also tell me whether you saw this in production or only in the benchmark?"

PROMPT="Tu appliques le skill ci-dessous, à la lettre.
=== SKILL ===
$(cat "$SKILL")
=== FIN DU SKILL ===
Autotest : pas de profil, pas de glossaire, pas de code à lire, aucun fichier à écrire ni à ouvrir,
rien à proposer à la fin. Rends le décodage directement dans ta réponse, au format du skill.
Le texte à décoder, reçu d'un mainteneur en réponse à notre patch :
=== SOURCE ===
$SOURCE
=== FIN ==="

ARGS=(-p "$PROMPT" --output-format text --max-turns 1)
[ -n "${DECODE_MODEL:-}" ] && ARGS+=(--model "$DECODE_MODEL")
REPONSE=$("$BIN" "${ARGS[@]}" 2>/dev/null)
[ -n "$REPONSE" ] || { echo "KO  aucune réponse de $BIN"; exit 1; }

echo "----- réponse -----"; echo "$REPONSE"; echo "-------------------"
ko=0
ok() { echo "OK  $1"; }
kofn() { echo "KO  $1"; ko=$((ko + 1)); }
mots() { printf '%s' "$1" | wc -w; }

n=$(printf '%s\n' "$REPONSE" | grep -cE '^#{2,3} ')
[ "$n" -ge 3 ] && ok "$n sections (3 paragraphes source)" || kofn "seulement $n sections pour 3 paragraphes"

for idiome in "papers over" "sharp edge" "critical section" "cold start"; do
    # hors titres : le titre cite la phrase source, la définition vient dans le corps
    corps=$(printf '%s\n' "$REPONSE" | grep -vE '^#{2,3} ')
    if ! printf '%s' "$REPONSE" | grep -qi "$idiome"; then kofn "idiome absent : $idiome"
    elif printf '%s' "$corps" | grep -qiE "$idiome[^.]{0,40}(\(|⟦|=| — | - |:|, c'est|, soit|veut dire)"; then ok "idiome défini : $idiome"
    else kofn "idiome cité sans définition : $idiome"; fi
done

[ "$(mots "$REPONSE")" -ge "$(mots "$SOURCE")" ] && ok "pas résumé ($(mots "$REPONSE") mots ≥ $(mots "$SOURCE"))" || kofn "plus court que la source : résumé"
printf '%s' "$REPONSE" | grep -q "⟦" && printf '%s' "$REPONSE" | grep -q "⟧" && ok "explications marquées ⟦ ⟧" || kofn "aucune explication marquée ⟦ ⟧"
printf '%s' "$REPONSE" | grep -qi "attend" && ok "fin « ce qu'il attend »" || kofn "pas de « ce qu'il attend »"
printf '%s' "$REPONSE" | grep -qiE "production|benchmark" && ok "sa question finale est rendue" || kofn "sa question finale (production / benchmark) est perdue"

[ "$ko" -eq 0 ] && echo "TOUT VERT" || echo "$ko contrôle(s) en échec"
exit $((ko > 0))
