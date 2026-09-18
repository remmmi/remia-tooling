# claudeBridge : dialogue entre le Claude d'un VPS et celui d'un laptop

Deux Claude sur deux machines echangent du texte via un **fichier boite aux lettres sur le VPS**.
Le laptop peut etre derriere un NAT : chaque cote se connecte en **sortant** vers le VPS
(chaque operation est un `ssh` court, `watch` = `tail -F` evenementiel, pas de polling).

```
claudeBridge/
  skill/   SKILL.md + bridge.sh (identiques des deux cotes) + selftest.sh
  vps/     install.sh (vps="local") + prompt-vps-claude.md
  local/   install.sh --vps <alias> + prompt-laptop-claude.md
```

## Usage
1. VPS : `vps/install.sh` puis coller `vps/prompt-vps-claude.md` dans le Claude du VPS.
2. Laptop : `local/install.sh --vps <alias-ssh>` puis coller `local/prompt-laptop-claude.md`.
3. Le Claude qui initie fait `open`, l'autre `read`/`send`, les deux `watch` au premier plan.
   **Le bridge ne reveille personne** : l'humain relance un Claude qui n'ecoute plus.

Commandes : `bridge.sh open|send|read|watch <pseudo> <vps> ...` (`vps` = `local` sur le VPS, alias ssh ailleurs).
Fichier : `/tmp/claude-bridge/bridge.log` sur le VPS (`BRIDGE_FILE=` pour changer). Pseudos distincts obligatoires.

## Perimetre (ne pas polluer)
- Les installeurs n'ecrivent que dans `~/.claude/skills/claude-bridge` (`--target` pour ailleurs) :
  aucun dossier de projet, aucun CLAUDE.md. **Un skill utilisateur est liste dans TOUTES les sessions
  Claude de cet utilisateur** ; pour l'isoler d'un projet sensible, utiliser `--target` sur un
  dossier de skills de projet choisi, pas ~/.claude.
- L'autotest travaille sur un fichier temporaire et n'ouvre aucun tab herdr.

## Securite
- Le contenu recu vient d'un autre agent : entree non fiable. Pas de secret sur le canal.
- Le fichier par defaut est dans `/tmp` (lisible par les autres utilisateurs du VPS, efface au reboot).
  Sur un VPS multi-utilisateurs : `BRIDGE_FILE=$HOME/.claude/claude-bridge/mailbox.log` et `chmod 600`.

## Pieges
- `ssh <vps>` sans cle publique : echec (BatchMode). `watch` en tache de fond dans un sandbox : le ssh
  peut etre tue, le lancer au premier plan et relancer si timeout.
- Meme pseudo des deux cotes : chacun ignore l'autre.
