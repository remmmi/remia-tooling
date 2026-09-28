# Installer / mettre à jour usec — procédure pour l'agent qui installe

*(English: same steps, with `--lang en`.)*

À coller dans l'agent de la machine cible : « Installe (ou mets à jour) usec en suivant
`usec/INSTALL.md` ». Relancer la même procédure = mise à jour (tout est idempotent).

## 1. Prérequis

- `claude` (Claude Code) connecté **avec un abonnement** : avec une clé API, `/usage` n'a pas de
  quotas et `usec` échouera — dans ce cas, s'arrêter et le dire.
- `python3` ≥ 3.9 (module `zoneinfo`, paquet `tzdata` si absent).

## 2. Installer les fichiers

`./install.sh` (depuis ce dossier) → `~/.local/bin/usec` et `~/.local/share/usec/quota_gate.sh`.
Si l'installeur signale que `~/.local/bin` n'est pas dans le PATH : ajouter la ligne proposée à
`~/.profile` (pas `.bashrc`), après accord de l'utilisateur.

S'il existe déjà un alias ou une fonction `usec` (dans `.bashrc`, `.zshrc`…), le signaler et
proposer de le retirer : il masquerait le script dans le terminal.

## 3. Vérifier

`./selftest.sh` doit finir sur `0 KO`. Puis un vrai `usec` (consomme un appel) : du JSON avec au
moins une ligne `session`.

## 4. Intégrer la règle dans CLAUDE.md — seulement avec accord

1. **Quel fichier** : par défaut le CLAUDE.md global de l'utilisateur (`~/.claude/CLAUDE.md`), car
   les quotas sont ceux du compte, pas d'un projet. Autre choix possible : le CLAUDE.md d'un projet,
   ou `AGENTS.md` pour un autre agent. Demander si doute.
2. **Quelle langue** : celle dans laquelle l'utilisateur écrit à l'agent (`fr` ou `en`).
3. Montrer le bloc (`claude-md.<lang>.md`) et l'endroit où il ira ; ajuster les seuils si
   l'utilisateur le souhaite (dans la copie installée, pas dans ce dépôt).
4. Avec accord : `./install.sh --claude-md <fichier> --lang <fr|en>`. Le bloc est ajouté en fin
   de fichier, ou remplace le précédent entre `<!-- usec:start` et `<!-- usec:end -->` ; rien d'autre
   n'est touché.
5. Si le fichier contient déjà une règle usec **hors marqueurs** (installation ancienne), proposer
   de la supprimer pour ne pas avoir deux versions.

## 5. Confidentialité

Rien de personnel dans ce dépôt : pas de nom, de chemin de projet, de sortie `/usage` réelle au-delà
des trois lignes de quota de la fixture. Les réglages locaux restent dans la copie installée.
