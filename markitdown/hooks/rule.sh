#!/usr/bin/env bash
# Hook SessionStart du plugin markitdown : la règle d'aiguillage en contexte de session (au lieu
# d'un bloc dans CLAUDE.md).
grep -v '^<!-- markitdown:' "$(dirname "$0")/../rule.md" 2>/dev/null
exit 0
