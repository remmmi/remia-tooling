#!/usr/bin/env bash
# Hook SessionStart du plugin usec : la règle quotas en contexte de session (au lieu d'un bloc
# dans CLAUDE.md). Silencieux dans le `claude -p /usage` que lance un relevé.
[ -n "${USEC_WATCH_INNER:-}" ] && exit 0
case "${CLAUDE_PLUGIN_OPTION_LANG:-fr}" in en) lang=en ;; *) lang=fr ;; esac
grep -v '^<!-- usec:' "$(dirname "$0")/../claude-md.$lang.md" 2>/dev/null
exit 0
