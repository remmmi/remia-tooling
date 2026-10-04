#!/usr/bin/env bash
# Hook SessionStart du plugin rename-herdr : install.sh avec le réglage « target » du plugin.
exec bash "$(dirname "$0")/plugin-setup.sh" rename-herdr --target "${CLAUDE_PLUGIN_OPTION_TARGET:-tab}"
