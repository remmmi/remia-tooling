#!/usr/bin/env bash
# Autotest de `cve-tournee` sans reseau ni herdr : un faux HOME avec ssh/config et raccourcis, les
# fonctions de lecture appelees directement, les commandes a blanc (--dry).
#
#   ./selftest.sh        code retour 0 = tout vert ; n'ecrit que dans un repertoire temporaire
set -uo pipefail
C="$(cd "$(dirname "$0")" >/dev/null && pwd)/bin/cve-tournee"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
ok=0; ko=0
check() { if eval "$2" >/dev/null 2>&1; then echo "ok  $1"; ok=$((ok+1)); else echo "KO  $1"; ko=$((ko+1)); fi; }

mkdir -p "$T/.ssh/conf.d" "$T/.config/cve-tournee" "$T/.cache"
cat > "$T/.ssh/config" <<'EOF'
Include conf.d/*
Host alpha alpha-bis
  HostName 192.0.2.1
Host *.exemple.net
  User x
Host beta
  HostName 192.0.2.2
EOF
printf 'Host gamma\n  HostName 192.0.2.3\n' > "$T/.ssh/conf.d/plus"
cat > "$T/.bashrc" <<'EOF'
alias deltar='herdr --remote delta'
alias eps='ssh -t -p 2222 epsilon "tmux a"'
_herdr_retry() { while ! herdr --remote "$1"; do sleep 2; done; }
zetar() { _herdr_retry zeta; }
# alias mort='ssh fantome'
alias m='mosh eta -- herdr'
EOF
printf 'beta\n' > "$T/.config/cve-tournee/ignore"

env_t() { HOME="$T" XDG_CONFIG_HOME="$T/.config" XDG_CACHE_HOME="$T/.cache" "$@"; }
printf 'Bash(pm2 list:*)\n' > "$T/.config/cve-tournee/outils"

# Fonctions de lecture, appelees directement : une ligne « ok/KO <nom> » par controle.
while IFS= read -r l; do
  echo "$l"; case $l in ok*) ok=$((ok+1)) ;; *) ko=$((ko+1)) ;; esac
done < <(env_t python3 - "$C" <<'EOF' 2>&1
import importlib.machinery, importlib.util, sys
l = importlib.machinery.SourceFileLoader("ct", sys.argv[1])
ct = importlib.util.module_from_spec(importlib.util.spec_from_loader("ct", l)); l.exec_module(ct)
def check(nom, f):
    try: bon = f()
    except Exception as e: bon = False; nom += " (%r)" % e
    print(("ok  " if bon else "KO  ") + nom)
check("ssh/config : Host, Include, premier alias, pas de motif",
      lambda: ct.hotes_ssh_config() == ["gamma", "alpha", "beta"])
h = ct.hotes_shell()
check("raccourcis : herdr --remote, ssh avec options, _herdr_retry, mosh ; commentaire ignore",
      lambda: sorted(h) == ["delta", "epsilon", "eta", "zeta"])
check("raccourcis : le nom du raccourci est retenu", lambda: (h["delta"], h["zeta"]) == ("deltar", "zetar"))
faux = lambda x: {"hote": x, "etat": "ok"} if x == "alpha" else {"hote": x, "etat": "ignore", "raison": "pas de claude"}
r = {x["hote"]: x for x in ct.recenser(faux)}
check("recensement : ignore respecte, hote sans claude ecarte, raccourci rattache",
      lambda: r["beta"]["raison"].startswith("liste") and r["alpha"]["etat"] == "ok"
      and r["delta"]["raccourci"] == "deltar" and r["gamma"]["etat"] == "ignore")
check("verdict : derniere ligne, pile et preuve",
      lambda: ct.lire_verdict("bla\nVERDICT: VULNERABLE | apache2 | 2.4.68 avec h2") == ("VULNERABLE", "apache2", "2.4.68 avec h2"))
check("verdict : gras markdown et accent toleres",
      lambda: ct.lire_verdict("**VERDICT: NON_CONCERNÉ | rien | absent**")[0] == "NON_CONCERNE")
check("verdict : absent ou inconnu = INCERTAIN",
      lambda: ct.lire_verdict("tout va bien")[0] == ct.lire_verdict("VERDICT: PEUT_ETRE | x | y")[0] == "INCERTAIN")
o = ct.outils()
check("outils : lecture seule (ni Edit, ni Write, ni Bash nu), regles en plus lues",
      lambda: "Bash(pm2 list:*)" in o and not {"Edit", "Write", "Bash", "Bash(*)"} & set(o)
      and not [x for x in o if "install" in x or "restart" in x or "Bash(rm" in x])
EOF
)

printf 'Produit X, versions 1.0 a 1.4 vulnerables, corrige en 1.5 (bookworm 1.5-1~deb12u1).\n' > "$T/brief.md"
out=$(env_t "$C" audit "$T/brief.md" --hosts alpha,gamma --dry 2>&1)
check "audit --dry : une commande par hote, opus medium, dans ~" \
  "[ \"\$(grep -c '^ssh ' <<<\"\$out\")\" = 2 ] && grep -q -- '--model opus --effort medium' <<<\"\$out\" && grep -q 'cd ~ && claude -p' <<<\"\$out\" && grep -q 'BatchMode=yes' <<<\"\$out\""
check "audit : brief vide refuse" \
  "printf 'x\n' > '$T/vide.md'; ! env_t '$C' audit '$T/vide.md' --hosts alpha --dry"

R="$T/.cache/cve-tournee/run1"; mkdir -p "$R"; cp "$T/brief.md" "$R/brief.md"
cat > "$R/resultats.json" <<'EOF'
[{"hote":"alpha","verdict":"OK","pile":"x","preuve":"1.5"},
 {"hote":"gamma","verdict":"VULNERABLE","pile":"x","preuve":"1.2"},
 {"hote":"delta","verdict":"ERREUR","pile":"","preuve":"delai"}]
EOF
run() { env_t "$C" "$@" 2>&1; }
check "tableau : VULNERABLE en tete, OK en dernier" \
  "[ \"\$(run tableau run1 | awk 'NR>1{print \$1}' | tr '\n' ' ')\" = 'gamma delta alpha ' ]"
out=$(run ouvrir run1 --dry)
check "ouvrir --dry : VULNERABLE et ERREUR seulement, session puis exit" \
  "[ \"\$(grep -c '_session' <<<\"\$out\")\" = 2 ] && ! grep -q 'alpha' <<<\"\$out\" && grep -q '_session gamma .cache/cve-tournee/run1.md VULNERABLE && exit' <<<\"\$out\""
check "ouvrir --dry <hote> : un hote precis, meme OK" \
  "[ \"\$(run ouvrir run1 alpha --dry | grep -c '_session alpha')\" = 1 ]"

echo "$ok ok, $ko KO"; [ "$ko" -eq 0 ]
