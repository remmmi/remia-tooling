#!/usr/bin/env bash
# claude-bridge : canal de communication bilateral entre deux Claude via une
# boite aux lettres fichier posee sur un VPS joignable en SSH.
# Aucun NAT entrant requis cote laptop : le fichier de rendez-vous vit sur le VPS,
# les deux cotes s'y connectent en sortant.
#
# Sous-commandes :
#   open  <pseudo> <vps> "<situation+problematique>"   init + poste le bloc d'intro
#   send  <pseudo> <vps> "<message>"                   poste un bloc
#   read  <pseudo> <vps>                               affiche les nouveaux blocs des AUTRES
#   watch <pseudo> <vps> [secondes]                    bloque jusqu'a un bloc d'un AUTRE, puis rend la main
#
# pseudo : identifiant de CE Claude (ex: grofix, laptop-deb)
# vps    : alias ssh du VPS a contacter (ex: newlcm) ; doit marcher sans mot de passe.
#          "local" = ce Claude tourne SUR le VPS : les commandes s'executent sur place, sans ssh.
#
# Variables d'env optionnelles :
#   BRIDGE_FILE  chemin du fichier sur le VPS (defaut /tmp/claude-bridge/bridge.log)
set -uo pipefail

REMOTE="${BRIDGE_FILE:-/tmp/claude-bridge/bridge.log}"
STATE_DIR="$HOME/.claude/claude-bridge/state"
SSH_OPTS="-o ConnectTimeout=8 -o BatchMode=yes"

# rsh <vps> <commande> : execute sur le VPS (ssh), ou sur place si vps=local
rsh() {
  local vps="$1"; shift
  if [ "$vps" = "local" ]; then bash -c "$*"; else ssh $SSH_OPTS ${SSH_EXTRA:-} "$vps" "$@"; fi
}

usage() {
  sed -n '2,20p' "$0"
  exit 2
}

now_utc() { date -u +%Y-%m-%dT%H:%M:%SZ; }

state_file() {
  local pseudo="$1" vps="$2"
  local key
  key=$(printf '%s|%s|%s' "$vps" "$REMOTE" "$pseudo" | tr -c 'A-Za-z0-9' '_')
  echo "$STATE_DIR/$key.offset"
}

ensure_remote() {
  local vps="$1"
  rsh "$vps" "mkdir -p \"\$(dirname '$REMOTE')\" && touch '$REMOTE'" \
    || { echo "[bridge] echec init distant sur $vps ($REMOTE)" >&2; exit 1; }
}

cmd_send() {
  local pseudo="$1" vps="$2" body="$3"
  ensure_remote "$vps"
  local block
  block=$(printf '===[%s %s]===\n%s\n===END===\n' "$pseudo" "$(now_utc)" "$body")
  printf '%s\n' "$block" | rsh "$vps" "cat >> '$REMOTE'" \
    || { echo "[bridge] echec envoi" >&2; exit 1; }
  echo "[bridge] envoye vers $vps:$REMOTE (pseudo=$pseudo)"
}

cmd_open() {
  local pseudo="$1" vps="$2" sit="$3"
  ensure_remote "$vps"
  local intro
  intro=$(printf 'PSEUDO: %s\nSITUATION ET PROBLEMATIQUE:\n%s\n\n(Reponds en postant un bloc ===[ton_pseudo ...]=== dans ce meme fichier.)' "$pseudo" "$sit")
  cmd_send "$pseudo" "$vps" "$intro"
  # aligne l'offset de lecture sur la fin actuelle pour ne pas relire l'intro
  mkdir -p "$STATE_DIR"
  local sf sz
  sf=$(state_file "$pseudo" "$vps")
  sz=$(rsh "$vps" "stat -c %s '$REMOTE'" 2>/dev/null || echo 0)
  echo "$sz" > "$sf"
  cat <<EOF

[bridge] canal ouvert.
  Pour attendre la reponse de l'autre Claude :
    bash $0 watch $pseudo $vps 300
  Pour lire sans bloquer :
    bash $0 read $pseudo $vps
  Pour repondre :
    bash $0 send $pseudo $vps "ton message"
EOF
}

cmd_read() {
  local pseudo="$1" vps="$2"
  mkdir -p "$STATE_DIR"
  local sf off sz
  sf=$(state_file "$pseudo" "$vps")
  off=$(cat "$sf" 2>/dev/null || echo 0)
  sz=$(rsh "$vps" "stat -c %s '$REMOTE'" 2>/dev/null || echo "")
  if [ -z "$sz" ]; then echo "[bridge] VPS injoignable ($vps)"; exit 1; fi
  if [ "$sz" -le "$off" ]; then
    echo "[bridge] rien de nouveau (offset $off/$sz)"
    echo "$sz" > "$sf"
    return 0
  fi
  local new
  new=$(rsh "$vps" "tail -c +$((off+1)) '$REMOTE'")
  echo "$sz" > "$sf"
  # n'affiche que les blocs des AUTRES pseudos
  printf '%s\n' "$new" | awk -v me="$pseudo" '
    /^===\[/ { inblk=1; buf=$0 "\n"; mine=($0 ~ ("^===\\[" me " ")); next }
    inblk    { buf=buf $0 "\n"; if ($0 ~ /^===END===/) { if(!mine) printf "%s", buf; inblk=0 } }
  '
}

cmd_watch() {
  local pseudo="$1" vps="$2" secs="${3:-300}"
  ensure_remote "$vps"
  echo "[bridge] attente d'un bloc d'un autre Claude (tail -F evenementiel, max ${secs}s)..."
  # Boucle de lecture distante sur un tail -F : rend la main INSTANTANEMENT des
  # qu'une entete ===[...]=== d'un AUTRE pseudo arrive (et tue le tail), sinon
  # timeout. Pas de polling.
  SSH_EXTRA="-o ServerAliveInterval=15 -o ServerAliveCountMax=3" rsh "$vps" \
    "timeout $secs bash -s -- '$REMOTE' '$pseudo'" <<'RS' >/dev/null 2>&1
F="$1"; ME="$2"
exec 3< <(tail -n0 -F "$F" 2>/dev/null)
tp=$!
trap 'kill $tp 2>/dev/null; exit 3' TERM INT
while IFS= read -r line <&3; do
  case "$line" in
    "===[$ME "*) : ;;                       # mon propre bloc : ignore
    "===["*)     kill $tp 2>/dev/null; exit 0 ;;  # bloc d'un autre : reveil
  esac
done
kill $tp 2>/dev/null
exit 3
RS
  local rc=$?
  if [ $rc -eq 0 ]; then
    echo "[bridge] nouveau bloc detecte :"
    cmd_read "$pseudo" "$vps"
    return 0
  fi
  echo "[bridge] timeout, aucun nouveau bloc"
  return 1
}

[ $# -ge 1 ] || usage
sub="$1"; shift
case "$sub" in
  open)  [ $# -eq 3 ] || usage; cmd_open  "$1" "$2" "$3" ;;
  send)  [ $# -eq 3 ] || usage; cmd_send  "$1" "$2" "$3" ;;
  read)  [ $# -eq 2 ] || usage; cmd_read  "$1" "$2" ;;
  watch) [ $# -ge 2 ] || usage; cmd_watch "$1" "$2" "${3:-300}" ;;
  *) usage ;;
esac
