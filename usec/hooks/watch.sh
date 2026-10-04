#!/usr/bin/env bash
# Hooks UserPromptSubmit et PostToolUse du plugin usec : usec-watch lancé depuis le dossier du
# plugin (le PATH d'un hook ne contient pas forcément ~/.local/bin).
root=$(cd "$(dirname "$0")/.." && pwd)
case "${CLAUDE_PLUGIN_OPTION_LANG:-fr}" in en) lang=en ;; *) lang=fr ;; esac
USEC_BIN="${USEC_BIN:-$root/usec}" exec "$root/usec-watch" hook --lang "$lang"
