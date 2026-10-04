#!/usr/bin/env bash
# Autotest du skill `simple` : soumet une explication jargonneuse + « je n'ai rien compris » à
# `claude -p` avec le skill en contexte, puis vérifie la réponse par des contrôles déterministes.
#
#   ./selftest.sh [--skill <chemin SKILL.md>]
#   CLAUDE_BIN=claude  SIMPLE_MODEL=<modèle optionnel>
#
# Contrôles : longueur (pas plus que l'original, 110 mots au plus pour un original court) ; première phrase courte (verdict) ;
# jargon interne absent (PermError, MTA) ; objet réel repris (exemple.fr) ; aucun marqueur de
# re-explication. Code retour 0 = tout vert. N'écrit rien, ne touche pas au journal ni au profil.
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

AVANT="Vos mails de contact@exemple.fr tombent en spam parce que la zone publie deux enregistrements v=spf1 concurrents, ce qui produit un PermError chez le MTA destinataire, donc SPF s'évalue à none et DMARC échoue en alignement alors même que la signature DKIM est valide ; fusionner les deux include dans un seul enregistrement corrige l'évaluation."
USER="J'ai rien compris."
MARQUEURS='comme je disais|en fait|pour être précis'

PROMPT="Tu appliques le skill ci-dessous, à la lettre.
=== SKILL ===
$(cat "$SKILL")
=== FIN DU SKILL ===
Pas de profil : ne lis aucun fichier, ne propose PAS de le remplir, ne tiens pas de journal (autotest).
Ton message précédent était :
« $AVANT »
L'utilisateur répond : « $USER »
Écris uniquement ta réponse à l'utilisateur."

ARGS=(-p "$PROMPT" --output-format text --max-turns 1)
[ -n "${SIMPLE_MODEL:-}" ] && ARGS+=(--model "$SIMPLE_MODEL")
REPONSE=$("$BIN" "${ARGS[@]}" 2>/dev/null)
[ -n "$REPONSE" ] || { echo "KO  aucune réponse de $BIN"; exit 1; }

echo "----- réponse -----"; echo "$REPONSE"; echo "-------------------"
ko=0
ok() { echo "OK  $1"; }
kofn() { echo "KO  $1"; ko=$((ko + 1)); }

mots() { printf '%s' "$1" | wc -w; }
# Règle du skill : jamais plus long que l'original ; un original d'une ou deux phrases denses
# se rejoue en 110 mots au plus.
PLAFOND=$(mots "$AVANT"); [ "$PLAFOND" -lt 110 ] && PLAFOND=110
[ "$(mots "$REPONSE")" -le "$PLAFOND" ] && ok "longueur tenue ($(mots "$REPONSE") mots, plafond $PLAFOND)" || kofn "trop longue ($(mots "$REPONSE") mots, plafond $PLAFOND)"

PREMIERE=$(printf '%s' "$REPONSE" | tr '\n' ' ' | sed -E 's/^[[:space:]]*//; s/([.!?])[[:space:]].*/\1/')
[ "$(mots "$PREMIERE")" -le 25 ] && ok "première phrase courte (verdict) : $PREMIERE" || kofn "première phrase trop longue : $PREMIERE"

printf '%s' "$REPONSE" | grep -qE 'PermError|MTA' && kofn "jargon interne resté (PermError / MTA)" || ok "jargon interne absent"
printf '%s' "$REPONSE" | grep -q 'exemple.fr' && ok "objet réel repris (exemple.fr)" || kofn "objet réel absent (exemple.fr)"
printf '%s' "$REPONSE" | grep -qiE "$MARQUEURS" && kofn "marqueur de re-explication présent" || ok "aucun marqueur de re-explication"

[ "$ko" -eq 0 ] && echo "TOUT VERT" || echo "$ko contrôle(s) en échec"
exit $((ko > 0))
