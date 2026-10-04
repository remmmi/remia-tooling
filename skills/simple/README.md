# simple — rejouer une explication ratée

Quand l'utilisateur dit « j'ai rien compris », l'agent ne re-explique pas plus longuement : il
**ré-ancre**. Verdict en une phrase, un objet réel nommé, le mécanisme vu depuis l'écran, le
vocabulaire de l'utilisateur. Déclenché par `/simple` ou par toute formulation d'incompréhension.

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

## Fichiers

| Fichier | Rôle |
|---|---|
| `SKILL.md` | le skill (français), avec un bloc **Profil** vide |
| `en/SKILL.md` | le même en anglais |
| `INSTALL.md` | procédure pour l'agent qui installe ou met à jour : langue, profil déduit des conversations et du projet (proposé, écrit seulement avec accord), profil et journal conservés à la mise à jour |
| `selftest.sh` | autotest : soumet une explication jargonneuse à `claude -p` et vérifie longueur, verdict, jargon, objet réel |

## Ce que le skill apprend (toujours avec accord)

- **Profil** : niveau, termes à définir d'office, stack, couches de l'utilisateur — rempli à l'installation.
- **Profil qui s'enrichit** : un terme qui a décroché est proposé à l'ajout aux termes à définir d'office.
- **Journal** (`journal.md`, local) : ce qui a décroché, à chaque `/simple` ; un terme qui revient 3 fois est signalé pour le glossaire du projet.

Profil et journal restent sur la machine de l'utilisateur : ne jamais les commiter ici.

## Versions

`version:` dans le frontmatter de `SKILL.md` et `en/SKILL.md`, montées ensemble ; mineure = retouche
de formulation ou de règle, majeure = changement de comportement visible. `INSTALL.md` § 0 compare
l'installé au dépôt.

| Version | Changements |
|---|---|
| 1.0.0 | Première version numérotée. |

## Tester

`./selftest.sh --lang fr` (ou `en`) — nécessite `claude` ; `SIMPLE_MODEL=` pour choisir le modèle.
