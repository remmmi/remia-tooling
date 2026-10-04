# Le profil du skill `simple` — procédure pour l'agent

Le skill s'installe et se met à jour comme plugin (`/plugin`, marketplace `remia-tooling`) : il n'y a
rien à copier. Ce fichier ne décrit que le **profil**, qui règle le registre des explications. Il est
propre à chaque machine et ne vit pas dans le plugin :

| Fichier | Contenu |
|---|---|
| `~/.config/remia-tooling/simple/profil.md` | niveau, termes à définir d'office, stack, couches |
| `~/.config/remia-tooling/simple/journal.md` | une ligne par `/simple` : ce qui a décroché |

Une mise à jour du plugin ne touche à aucun des deux. Une installation d'avant les plugins
(`~/.claude/skills/simple/`, profil dans le `SKILL.md`) se reprend par `remia-tooling migrate simple`,
qui reporte profil et journal à cet endroit.

## 1. Forme du fichier

```markdown
## Profil de l'utilisateur

- **Niveau** : _(non renseigné)_
- **Termes à définir d'office** : _(aucun)_
- **Stack du projet** : _(non renseignée)_
- **Ses couches, avec ses mots** : _(non renseignées)_
```

## 2. Déduire le profil (lecture seule)

**Niveau de compétence** — déduit des conversations précédentes avec cet utilisateur :
mémoire de l'agent (ex. `~/.claude/projects/*/memory/`), historiques de sessions disponibles,
CLAUDE.md. Relever des indices observables, pas des impressions : les termes qu'il emploie
seul, ceux qu'il a demandé d'expliquer, ses reformulations d'incompréhension, ce qu'il fait
lui-même (lire du code, écrire du SQL, configurer un serveur). Rendre UNE phrase de niveau.

**Termes à définir d'office** — ceux qu'il a déjà demandé d'expliquer, ou qu'il n'emploie jamais
alors que la conversation les impose.

**Stack présente** — déduite du projet courant, pas supposée : fichiers de dépendances
(`composer.json`, `package.json`, `requirements.txt`, `Gemfile`, `go.mod`…), structure des
dossiers, fichiers de configuration, services en cours (`systemctl`, `docker ps`) si
accessibles. Nommer les briques et leurs versions quand elles sont lisibles.

**Ses couches, avec ses mots** — les catégories dans lesquelles il range un problème
(« c'est du template ? de la base ? de la config ? »), reprises de ses propres formulations.

Ne rien inventer : un champ sans indice reste « non renseigné » et le dit.

## 3. Proposer, puis écrire seulement avec accord

Montrer à l'utilisateur le profil rempli, avec pour chaque ligne **l'indice qui la justifie**
(ex. « a demandé ce qu'est un override le 12/03 »). Lui demander : valider tel quel, corriger,
ou laisser vide. Puis écrire `~/.config/remia-tooling/simple/profil.md` — et rien d'autre.

## 4. Confidentialité

Le profil et le journal décrivent une personne : ils restent sur la machine de l'utilisateur. Ne
jamais les commiter dans ce dépôt, ni y mettre de nom, d'adresse, de secret ou d'identifiant de
projet sensible.

## 5. Vérifier

- `selftest.sh` (à côté de ce fichier, dans un clone du dépôt) : contrôle automatique d'un
  ré-ancrage, si `claude` est installé.
- Session suivante : le skill apparaît dans la liste ; `/simple` sur une explication récente
  applique le profil.
