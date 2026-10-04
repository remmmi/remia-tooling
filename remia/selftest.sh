#!/usr/bin/env bash
# Autotest de remia dans un HOME jetable : fausse marketplace, faux installed_plugins.json,
# fausses installations à la main. Ne touche à rien de réel.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
ok=0; ko=0
check() { if eval "$2" >/dev/null 2>&1; then echo "ok  $1"; ok=$((ok+1)); else echo "KO  $1"; ko=$((ko+1)); fi; }
export HOME="$T/home"; unset CLAUDE_CONFIG_DIR
C="$HOME/.claude"; P="$C/plugins"; M="$P/marketplaces/remia-tooling"
export REMIA_MARKETPLACE_DIR="$M"
R="$HERE/bin/remia-tooling"

# fausse marketplace : remia, alpha, usec, simple, rename-herdr en chemins relatifs + un plugin d'un autre dépôt
mkdir -p "$M/.claude-plugin" "$HOME/.local/bin" "$C/skills"
plugins=""
for p in remia alpha usec simple rename-herdr; do
  mkdir -p "$M/$p/.claude-plugin"
  printf '{"name": "%s", "version": "1.0.0"}\n' "$p" > "$M/$p/.claude-plugin/plugin.json"
  plugins="$plugins{\"name\": \"$p\", \"source\": \"./$p\", \"description\": \"outil $p\"},"
done
echo "{\"name\": \"remia-tooling\", \"plugins\": [$plugins {\"name\": \"ext\", \"description\": \"ailleurs\", \"source\": {\"source\": \"git-subdir\", \"url\": \"https://exemple.invalid/x.git\", \"path\": \"p\"}}]}" > "$M/.claude-plugin/marketplace.json"
known() { echo "{\"remia-tooling\": {\"source\": {\"source\": \"git\", \"url\": \"x\"}, \"installLocation\": \"$M\", \"lastUpdated\": \"2026-01-01T00:00:00.000Z\"$1}}" > "$P/known_marketplaces.json"; }
installed() {  # installed nom=version …
  local body=""
  for kv in "$@"; do body="$body\"${kv%%=*}@remia-tooling\": [{\"scope\": \"user\", \"version\": \"${kv#*=}\"}],"; done
  echo "{\"version\": 2, \"plugins\": {${body%,}}}" > "$P/installed_plugins.json"
}
known ', "autoUpdate": true'; installed remia=1.0.0
echo '{"model": "x"}' > "$C/settings.json"
st() { "$R" status --json | python3 -c "import json,sys; d=json.load(sys.stdin); r={x['plugin']:x for x in d['plugins']}; sys.exit(not ($1))"; }
hk() { printf '{"hook_event_name":"%s","session_id":"%s","prompt":"%s"}' "$1" "${2:-s1}" "${3:-}" | "$R" hook; }

check "status : remia à jour, les autres non installés" "st \"r['remia']['state']=='à jour' and r['alpha']['state']=='non installé' and r['ext']['state']=='non installé' and r['ext']['repo']==''\""
check "hook session : propose les plugins jamais proposés" "hk SessionStart | grep -q 'jamais proposés sur cette machine : alpha (outil alpha)' && hk SessionStart | grep -q 'ext (ailleurs)'"
for p in alpha usec simple rename-herdr ext; do "$R" decide "$p" non >/dev/null; done
check "refus mémorisés → silence"                 "[ -z \"\$(hk SessionStart)\" ]"
check "decide : plugin inconnu refusé, choix inconnu refusé" "! '$R' decide nimporte oui && ! '$R' decide alpha peut-etre"
"$R" decide alpha oubli >/dev/null
check "decide oubli : la proposition revient"     "hk SessionStart | grep -q 'alpha (outil alpha)'"
"$R" decide alpha oui >/dev/null; installed remia=1.0.0 alpha=1.0.0
check "installé et à jour → silence"              "[ -z \"\$(hk SessionStart)\" ] && st \"r['alpha']['state']=='à jour' and r['alpha']['decision']=='oui'\""
printf '{"name": "alpha", "version": "1.1.0"}\n' > "$M/alpha/.claude-plugin/plugin.json"
check "status : alpha en retard (mise à jour laissée à Claude Code : hook muet)" "st \"r['alpha']['state']=='en retard' and r['alpha']['repo']=='1.1.0'\" && [ -z \"\$(hk SessionStart)\" ]"
echo '{"model": "x", "enabledPlugins": {"alpha@remia-tooling": false}}' > "$C/settings.json"
check "status : plugin désactivé"                 "st \"r['alpha']['state']=='désactivé'\""
known ''
check "mise à jour automatique coupée → signalée" "hk SessionStart | grep -q 'mise à jour automatique de la marketplace remia-tooling est coupée'"
echo '{"extraKnownMarketplaces": {"remia-tooling": {"source": {"source": "git", "url": "x"}, "autoUpdate": true}}}' > "$C/settings.json"
check "mise à jour automatique déclarée dans settings.json → silence" "[ -z \"\$(hk SessionStart)\" ]"
known ', "autoUpdate": true'

# installations à la main : usec (hooks + bloc + script), simple (profil rempli + journal), rename-herdr (skill + unité both)
for p in usec simple rename-herdr; do "$R" decide "$p" oubli >/dev/null; done
cat > "$C/settings.json" <<'JSON'
{"model": "x", "hooks": {
  "SessionStart": [{"hooks": [{"type": "command", "command": "autre"}, {"type": "command", "command": "/h/.claude/hooks/rename-herdr-version-check"}]}],
  "UserPromptSubmit": [{"hooks": [{"type": "command", "command": "USEC_BIN='/h/usec' '/h/usec-watch' hook --lang en"}]}],
  "PostToolUse": [{"hooks": [{"type": "command", "command": "USEC_BIN='/h/usec' '/h/usec-watch' hook --lang en"}]}]}}
JSON
printf '# Mon CLAUDE.md\n\nRègle existante.\n\n<!-- usec:start — bloc -->\n## Quotas\nblabla\n<!-- usec:end -->\n' > "$C/CLAUDE.md"
touch "$HOME/.local/bin/usec" "$HOME/.local/bin/herdr-session-name-sync"
mkdir -p "$C/skills/simple" "$C/skills/rename-herdr" "$HOME/.config/systemd/user"
printf -- '---\nname: simple\n---\n<!-- PROFIL:DEBUT — rempli -->\n## Profil de l'"'"'utilisateur\n\n- **Niveau** : développeur.\n- **Termes à définir d'"'"'office** : _(aucun)_\n<!-- PROFIL:FIN -->\nsuite\n' > "$C/skills/simple/SKILL.md"
echo "2026-01-01 · cache · serveur" > "$C/skills/simple/journal.md"
echo "x" > "$C/skills/rename-herdr/SKILL.md"
printf '[Service]\nEnvironment=RENAME_HERDR_TARGET=both\n' > "$HOME/.config/systemd/user/rename-herdr.service"

check "status : restes d'installation à la main détectés" "st \"len(r['usec']['legacy'])==3 and len(r['simple']['legacy'])==1 and len(r['rename-herdr']['legacy'])==3\""
check "status : réglages repris dans la commande d'installation" "st \"r['rename-herdr']['install'].endswith('--config target=both') and r['usec']['install'].endswith('--config lang=en')\""
check "hook session : migration proposée"         "hk SessionStart | grep -q 'à migrer vers leur plugin : usec (hooks dans settings.json'"
"$R" migrate --dry-run > "$T/dry"
check "migrate --dry-run : dit tout, ne touche à rien" "grep -q 'ferait : hooks usec-watch' '$T/dry' && grep -q usec-watch '$C/settings.json' && [ -d '$C/skills/simple' ]"
check "migrate : nom inconnu refusé"              "! '$R' migrate alpha"
"$R" migrate > "$T/mig"
check "migrate : hooks usec et de version retirés, les autres et les réglages gardés" "! grep -q 'usec-watch\|version-check' '$C/settings.json' && grep -q autre '$C/settings.json' && grep -q '\"model\": \"x\"' '$C/settings.json'"
check "migrate : bloc usec retiré de CLAUDE.md, le reste gardé" "! grep -q 'usec:' '$C/CLAUDE.md' && grep -q 'Règle existante.' '$C/CLAUDE.md'"
check "migrate : profil et journal de simple conservés" "grep -q 'Niveau.* : développeur' '$HOME/.config/remia-tooling/simple/profil.md' && ! grep -q PROFIL '$HOME/.config/remia-tooling/simple/profil.md' && grep -q cache '$HOME/.config/remia-tooling/simple/journal.md'"
check "migrate : skills copiés déplacés, sauvegarde complète" "[ ! -e '$C/skills/simple' ] && [ ! -e '$C/skills/rename-herdr' ] && ls '$HOME'/.config/remia-tooling/sauvegarde/*/skills/simple/SKILL.md '$HOME'/.config/remia-tooling/sauvegarde/*/settings.json '$HOME'/.config/remia-tooling/sauvegarde/*/CLAUDE.md"
check "migrate : commandes d'installation avec les réglages d'avant" "grep -q 'claude plugin install rename-herdr@remia-tooling --config target=both' '$T/mig' && grep -q 'claude plugin install usec@remia-tooling --config lang=en' '$T/mig' && grep -q 'claude plugin install simple@remia-tooling' '$T/mig'"
check "migrate : relancé → rien à migrer"         "'$R' migrate | grep -q 'rien à migrer'"
check "hook session : scripts posés à la main sans plugin → encore proposés" "hk SessionStart | grep -q 'usec (scripts posés à la main)'"
"$R" decide usec non >/dev/null; "$R" decide rename-herdr non >/dev/null; "$R" decide simple non >/dev/null
check "refus du plugin, installation à la main gardée → silence" "[ -z \"\$(hk SessionStart)\" ]"

check "mention : prompt qui parle de remia-tooling → rappel" "hk UserPromptSubmit s2 'ou en est remia-tooling ?' | grep -q 'faire le point'"
check "mention : pas de répétition dans la session" "[ -z \"\$(hk UserPromptSubmit s2 'remia-tooling encore')\" ]"
check "mention : prompt sans rapport → silence"   "[ -z \"\$(hk UserPromptSubmit s3 'bonjour')\" ]"
check "hook : stdin invalide → rc 0, silence"     "[ -z \"\$(echo pasjson | '$R' hook)\" ]"
# marketplace absente : le script est copié hors de tout clone, pour qu'il ne retombe pas sur ce dépôt
rm -rf "$M"; unset REMIA_MARKETPLACE_DIR; mkdir -p "$T/seul/a/bin"; cp "$R" "$T/seul/a/bin/"; R="$T/seul/a/bin/remia-tooling"
for p in usec simple rename-herdr; do "$R" decide "$p" oubli >/dev/null; done
check "marketplace absente : status le dit (rc 1), hook muet" "! '$R' status 2>/dev/null && ('$R' status 2>&1 || true) | grep -q introuvable && [ -z \"\$(hk SessionStart)\" ]"
echo "$ok ok, $ko KO"; [ "$ko" -eq 0 ]
