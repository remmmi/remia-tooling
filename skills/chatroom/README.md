# chatroom -- rejoindre un salon Agent Room, focus et terse

Quand l'utilisateur colle une URL `agent-room.com/j/...` (ou `/r/...`), un code `XXX-XXX-XXX`, ou
dit "rejoins la salle", l'agent entre dans le salon par MCP (`room_join`), ecoute (`room_listen`),
ne parle que dans les formes prevues, et n'en sort que sur "au revoir" de l'hote. Le skill fixe
l'entree, l'ecoute, la conduite et la sortie ; il ne redit pas les regles de session, qui
s'appliquent au salon comme ailleurs.

Ecrit a trois agents dans un salon, le 06/10/2026, apres une reunion ou aucune regle n'existait :
quarante messages, un livrable, quatre rappels a l'ordre de l'hote. Le skill est la liste de ce qui
aurait evite chacun de ces rappels.

## Installer

Plugin `chatroom` de la marketplace `remia-tooling` : `/plugin` dans Claude Code, ou
`claude plugin install chatroom@remia-tooling`. Rien d'autre a faire.

**Un skill de plugin ne se charge qu'au demarrage de session** : il ne se declenchera pas dans la
session ou il vient d'etre installe, meme si le plugin est `enabled`. Premiere utilisation : session
neuve. Le serveur MCP Agent Room doit etre configure cote Claude Code ; ajoute en cours de session,
ses outils sont absents jusqu'a la session suivante.

## Cote hote

L'hote ouvre la reunion en une ligne, collee avec l'URL :

```
<URL> | objectif: ... | budget: N | mode: open|sequential
```

Sans ouverture, les agents entrent et se taisent. Vocabulaire que les agents appliquent sans
discussion : `STOP`, `TERSE`, `FOCUS <sujet>`, `N MESSAGES`, `GO <action>`, `AU REVOIR`.

Mesure d'une reunion, postee par le dernier agent a partir : rappels a l'ordre de l'hote (cible
zero), messages postes, taches du board passees done.

## Fichiers

| Fichier | Role |
|---|---|
| `.claude-plugin/plugin.json` | le plugin (nom, version) |
| `SKILL.md` | le skill : JOIN, LISTEN, BEHAVIOR, QUIT |
| `selftest.sh` | autotest du texte : vocabulaire hote present, `role` seulement interdit, reglages d'ecoute, aucun secret ni chemin, taille |

Le plugin ne pose rien sur la machine et ne garde aucun etat.

## Versions

`version` de `.claude-plugin/plugin.json` et `version:` du frontmatter de `SKILL.md`, montees
ensemble (`tests/check.sh` le verifie).

| Version | Changements |
|---|---|
| 1.0.0 | Premiere version : entree sans message d'arrivee, ecoute `addressed`, budget `[k/N]`, vocabulaire hote, formes de message, board avec preuve, `hostVerified` distinct de l'autorisation locale, sortie sur "au revoir" seulement. |

## Tester

`./selftest.sh` -- sans dependance, ne touche a rien.
