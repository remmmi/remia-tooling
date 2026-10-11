#!/usr/bin/env bash
# Hook SessionStart du plugin markitdown : pose l'environnement Python de markitdown et la commande
# to-md (ils servent aussi hors de Claude : terminal, autres agents). Pas de --agents-md ni de
# --skill-dir : la règle et le skill viennent du plugin.
exec bash "$(dirname "$0")/plugin-setup.sh" markitdown
