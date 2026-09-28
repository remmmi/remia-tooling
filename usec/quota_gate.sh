# quota_gate.sh — porte quota pour un script qui enchaîne des appels `claude -p` (drain, lot, cron).
# À sourcer (bash). Avant chaque appel : `usec_gate || break`. Au-delà d'un seuil, la porte se
# ferme pour tout le run : fichier STOP écrit avec le motif, le script s'arrête proprement et se
# relance à l'identique après le reset (le lot doit être idempotent).
#
#   source ~/.local/share/usec/quota_gate.sh
#   export USEC_GATE_DIR=/chemin/etat/du/lot     # cache + fichier STOP (défaut : $TMPDIR/usec_gate)
#   usec_gate_reset                              # au démarrage : purge cache et STOP d'un run précédent
#   for x in …; do usec_gate || { echo "pause : $(usec_gate_motif)"; break; }; claude -p …; done
#
# Réglages (variables d'environnement) :
#   USEC_BIN               commande usec                      (défaut : usec)
#   USEC_GATE_SESSION_MAX  seuil fenêtre de session, en %     (défaut : 70)
#   USEC_GATE_WEEK_MAX     seuil de chaque quota semaine, en % (défaut : 85)
#   USEC_GATE_TTL          durée de vie du cache, en s        (défaut : 120 — usec coûte ~4-20 s)
# Le cache est partagé entre workers parallèles qui ont le même USEC_GATE_DIR.
# usec illisible (format changé, réseau) = porte OUVERTE : garder un coupe-circuit à côté.

_usec_gate_dir() { printf '%s' "${USEC_GATE_DIR:-${TMPDIR:-/tmp}/usec_gate}"; }

usec_gate_reset() {
  local d; d=$(_usec_gate_dir)
  mkdir -p "$d" && rm -f "$d/_quota.json" "$d/_stop_quota"
}

usec_gate_motif() { cat "$(_usec_gate_dir)/_stop_quota" 2>/dev/null; }

# 0 = on peut appeler ; 1 = seuil franchi (motif dans _stop_quota).
usec_gate() {
  local d cache stop age motif
  d=$(_usec_gate_dir); cache="$d/_quota.json"; stop="$d/_stop_quota"
  mkdir -p "$d"
  [ -e "$stop" ] && return 1

  age=$(python3 -c 'import os,sys,time
try: print(int(time.time() - os.path.getmtime(sys.argv[1])))
except OSError: print(10**9)' "$cache")
  if [ ! -s "$cache" ] || [ "$age" -gt "${USEC_GATE_TTL:-120}" ]; then
    "${USEC_BIN:-usec}" > "$cache.tmp.$$" 2>/dev/null \
      && mv -f "$cache.tmp.$$" "$cache" || rm -f "$cache.tmp.$$"
  fi
  [ -s "$cache" ] || return 0

  motif=$(python3 -c '
import json, sys
try:
    quotas = json.load(open(sys.argv[1]))["quotas"]
except Exception:
    sys.exit(0)
for q in quotas:
    limit = float(sys.argv[2] if q.get("period") == "session" else sys.argv[3])
    if float(q.get("used_percent", 0)) >= limit:
        print("%s/%s %s%% >= %g%% (reset %s)" % (
            q.get("period"), q.get("models"), q.get("used_percent"), limit, q.get("reset_at", "?")))
        break
' "$cache" "${USEC_GATE_SESSION_MAX:-70}" "${USEC_GATE_WEEK_MAX:-85}")
  [ -z "$motif" ] && return 0
  printf '%s\n' "$motif" > "$stop"
  return 1
}
