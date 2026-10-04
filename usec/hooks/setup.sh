#!/usr/bin/env bash
# Hook SessionStart du plugin usec : pose usec, usec-watch et quota_gate.sh dans ~/.local
# (ils servent aussi hors de Claude : terminal, cron, lots). Ni --hooks ni --claude-md : les hooks
# et la règle viennent du plugin.
exec bash "$(dirname "$0")/plugin-setup.sh" usec
