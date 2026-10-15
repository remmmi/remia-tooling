# simple — rejouer une explication ratée

Quand l'utilisateur dit « j'ai rien compris », l'agent ne re-explique pas plus longuement : il
**ré-ancre**. Verdict en une phrase, un objet réel nommé, le mécanisme vu depuis l'écran, le
vocabulaire de l'utilisateur. Déclenché par `/simple:simple` (taper `/simple` suffit, la complétion
le propose) ou, sans commande, par toute formulation d'incompréhension.

## Avant / après

> **Avant** — « Vos mails tombent en spam parce que la zone publie deux enregistrements v=spf1
> concurrents, ce qui produit un PermError chez le MTA destinataire, donc DMARC échoue en alignement. »
>
> *« J'ai rien compris. »*
>
> **Après** — « Il faut fusionner deux lignes en une seule dans les réglages de votre domaine, et vos
> mails de contact@exemple.fr ne tomberont plus en spam. Aujourd'hui ils arrivent dans les indésirables
> du destinataire. La cause : votre domaine publie deux fois la liste des serveurs autorisés à envoyer
> en son nom (le « SPF ») ; face au doublon, la messagerie qui reçoit n'en croit aucune. Ça se corrige
> dans la zone DNS, chez l'hébergeur du domaine — ni votre site ni votre boîte mail ne sont en cause. »

## Installer

Plugin `simple` de la marketplace `remia-tooling` : `/plugin` dans Claude Code, ou
`claude plugin install simple@remia-tooling`. Rien d'autre à faire ; le skill propose de remplir le
profil à son premier usage.

## Fichiers

| Fichier | Rôle |
|---|---|
| `.claude-plugin/plugin.json` | le plugin (nom, version) |
| `SKILL.md` | le skill |
| `INSTALL.md` | procédure pour l'agent qui remplit le profil : déduit des conversations et du projet, proposé, écrit seulement avec accord |
| `selftest.sh` | autotest : soumet une explication jargonneuse à `claude -p` et vérifie longueur, verdict, jargon, objet réel |

## Ce que le skill apprend (toujours avec accord)

- **Profil** (`~/.config/remia-tooling/simple/profil.md`) : niveau, termes à définir d'office, stack, couches de l'utilisateur.
- **Profil qui s'enrichit** : un terme qui a décroché est proposé à l'ajout aux termes à définir d'office.
- **Journal** (`~/.config/remia-tooling/simple/journal.md`) : ce qui a décroché, à chaque `/simple` ; un terme qui revient 3 fois est signalé pour le glossaire du projet.

Profil et journal restent sur la machine de l'utilisateur, hors du plugin : une mise à jour ne les touche pas.

## Versions

`version` de `.claude-plugin/plugin.json` et `version:` du frontmatter de `SKILL.md`, montées ensemble
(`tests/check.sh` le vérifie) ; mineure = retouche de formulation ou de règle, majeure = changement de
comportement visible.

| Version | Changements |
|---|---|
| 1.1.2 | Renvoi vers `decode` quand le texte à comprendre est celui d'un autre. |
| 1.1.1 | La commande est `/simple:simple` (un skill de plugin porte le nom du plugin en préfixe) : description et docs corrigées. |
| 1.1.0 | Plugin de la marketplace `remia-tooling`. Le profil et le journal sortent du `SKILL.md` : `~/.config/remia-tooling/simple/` (`remia-tooling migrate simple` reprend ceux d'une installation à la main). Version anglaise retirée. |
| 1.0.0 | Première version numérotée. |

## Tester

`./selftest.sh` — nécessite `claude` ; `SIMPLE_MODEL=` pour choisir le modèle.
