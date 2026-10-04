#!/usr/bin/env bash
# Met une machine sur la marketplace remia-tooling. Idempotent, relançable à volonté.
#
#   ./bootstrap.sh              marketplace + mise à jour automatique + plugin « remia »
#   ./bootstrap.sh --check      constate seulement, ne modifie rien
#   options : --url URL         dépôt de la marketplace (défaut git@github.com:remmmi/remia-tooling.git)
#
# Ne pose aucun outil : les plugins s'installent ensuite par /plugin, ou sur proposition du plugin
# « remia » au démarrage de session suivant. Écrit seulement, par `claude plugin …` et pour la mise à
# jour automatique : ~/.claude/settings.json (copie .bak-remia avant) et ~/.claude/plugins/.
set -euo pipefail

URL=git@github.com:remmmi/remia-tooling.git
MARKET=remia-tooling
MODE=install
while [ $# -gt 0 ]; do
  case "$1" in
    --url)     URL=$2; shift 2 ;;
    --check)   MODE=check; shift ;;
    -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "argument inconnu : $1 (voir --help)" >&2; exit 2 ;;
  esac
done
CLAUDE_DIR=${CLAUDE_CONFIG_DIR:-$HOME/.claude}
ok() { echo "[ok] $*"; }
ko() { echo "[!!] $*"; }

# ── prérequis : s'arrêter en le disant si l'un manque
missing=0
for c in claude git python3; do
  command -v "$c" >/dev/null && ok "$c" || { ko "$c introuvable"; missing=1; }
done
[ "$missing" = 0 ] || { echo "prérequis manquants : rien n'a été modifié" >&2; exit 1; }
systemctl --user is-system-running >/dev/null 2>&1 && ok "systemd utilisateur joignable" \
  || ko "systemd utilisateur injoignable : rename-herdr ne pourra pas se mettre en place (sudo loginctl enable-linger $USER)"
case "$URL" in
  /*|./*|../*) [ -f "$URL/.claude-plugin/marketplace.json" ] && ok "marketplace locale : $URL" \
                 || { ko "pas de marketplace dans $URL"; exit 1; } ;;
  *) # les mises à jour se font sans terminal : l'accès au dépôt doit marcher sans mot de passe
     if GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=10" git ls-remote "$URL" HEAD >/dev/null 2>&1
     then ok "accès au dépôt sans mot de passe"
     else ko "dépôt inaccessible sans mot de passe : $URL"
          echo "il faut une clé SSH autorisée sur le dépôt (ssh -T git@github.com) : rien n'a été modifié" >&2; exit 1
     fi ;;
esac

state() {  # affiche : marketplace connue ? mise à jour automatique ? remia installé ?
  python3 - "$CLAUDE_DIR" "$MARKET" <<'PY'
import json, os, sys
d, m = sys.argv[1:]
def load(p):
    try:
        return json.load(open(p, encoding="utf-8"))
    except Exception:
        return {}
known = load(os.path.join(d, "plugins", "known_marketplaces.json")).get(m)
declared = (load(os.path.join(d, "settings.json")).get("extraKnownMarketplaces") or {}).get(m) or {}
auto = declared.get("autoUpdate", (known or {}).get("autoUpdate"))
remia = f"remia@{m}" in load(os.path.join(d, "plugins", "installed_plugins.json")).get("plugins", {})
print(f"{int(bool(known))} {int(bool(auto))} {int(remia)}")
PY
}
read -r has_market has_auto has_remia <<<"$(state)"

if [ "$MODE" = check ]; then
  rc=0
  [ "$has_market" = 1 ] && ok "marketplace $MARKET connue" || { ko "marketplace $MARKET absente"; rc=1; }
  [ "$has_auto" = 1 ] && ok "mise à jour automatique activée" || { ko "mise à jour automatique coupée"; rc=1; }
  [ "$has_remia" = 1 ] && ok "plugin remia installé" || { ko "plugin remia absent"; rc=1; }
  exit $rc
fi

# ── marketplace
if [ "$has_market" = 1 ]; then
  claude plugin marketplace update "$MARKET" >/dev/null && ok "marketplace $MARKET mise à jour"
else
  claude plugin marketplace add "$URL" >/dev/null && ok "marketplace $MARKET ajoutée"
fi

# ── mise à jour automatique (coupée par défaut pour une marketplace tierce) : même écriture que
#    /plugin → Marketplaces → Enable auto-update
python3 - "$CLAUDE_DIR" "$MARKET" <<'PY'
import json, os, shutil, sys
d, m = sys.argv[1:]
def patch(path, get, backup):
    try:
        data = json.load(open(path, encoding="utf-8"))
    except Exception:
        return
    entry = get(data)
    if entry is None or entry.get("autoUpdate") is True:
        return
    entry["autoUpdate"] = True
    if backup:
        shutil.copy2(path, path + ".bak-remia")
    tmp = path + ".tmp-remia"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2, ensure_ascii=False)
        fh.write("\n")
    os.replace(tmp, path)
patch(os.path.join(d, "settings.json"), lambda s: (s.get("extraKnownMarketplaces") or {}).get(m), True)
patch(os.path.join(d, "plugins", "known_marketplaces.json"), lambda k: k.get(m), False)
PY
read -r _ has_auto _ <<<"$(state)"
[ "$has_auto" = 1 ] && ok "mise à jour automatique activée" \
  || ko "mise à jour automatique non activée : /plugin → Marketplaces → $MARKET → Enable auto-update"

# ── plugin remia
if [ "$has_remia" = 1 ]; then
  claude plugin update "remia@$MARKET" >/dev/null 2>&1 || true
  ok "plugin remia déjà installé"
else
  claude plugin install "remia@$MARKET" >/dev/null && ok "plugin remia installé"
fi

# ── la suite
R=$(python3 -c 'import json,os,sys; print(json.load(open(os.path.join(sys.argv[1],"plugins","known_marketplaces.json")))[sys.argv[2]]["installLocation"])' "$CLAUDE_DIR" "$MARKET")/remia/bin/remia-tooling
echo
"$R" status || true
cat <<TXT

Suite :
  1. installations à la main en doublon (lignes « à la main » ci-dessus) :
       $R migrate --dry-run     puis, si la liste convient :     $R migrate
     La commande affiche ensuite les « claude plugin install … » à lancer, avec les réglages d'avant.
  2. autres plugins voulus :  claude plugin install <plugin>@$MARKET     (ou /plugin dans Claude Code)
  3. ouvrir une nouvelle session Claude : c'est le démarrage de session qui met les outils en place.
TXT
