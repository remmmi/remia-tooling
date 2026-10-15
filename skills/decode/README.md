# decode — comprendre le texte d'un autre, paragraphe par paragraphe

Quand l'utilisateur reçoit un texte technique qu'il ne suit pas (réponse de mainteneur, issue, doc,
message rédigé par un LLM), l'agent ne le résume pas : il le **décode**. Chaque paragraphe est cité,
dit en français simple, ses raccourcis définis dans la phrase même, et le code dont il parle montré
à la bonne ligne quand c'est là que se joue l'enjeu. Déclenché par `/decode:decode` ou par « traduis-moi
ça », « décode », « je comprends pas ce qu'il veut ».

Complément de `simple` : `simple` rejoue **ma** explication ratée en plus court ; `decode` fait comprendre
celle **d'un autre**, en entier.

## Avant / après

> **Source** — « `SequenceSet` coerces every item with `intval()` unless it looks like a range, but the
> pattern had no end anchor, so `"1:2 EVIL"` was kept whole and reached the wire. »
>
> **Décodé** — `SequenceSet` est la pièce qui fabrique la liste des numéros de mails envoyée au serveur.
> Chaque élément est forcé en nombre (« coerce » = forcer le type), sauf s'il ressemble à une plage
> comme `1:2`. Le test vérifie que le texte *commence* par une plage, pas qu'il *s'arrête* là (il manque
> le `$` final, « end anchor ») : `"1:2 EVIL"` passe donc entier et part vers le serveur (« reached the
> wire »). Dans le code : `SequenceSet.php:38`, `preg_match('/^([0-9]+|\*):([0-9]+|\*)/', $id)`.

## Installer

Plugin `decode` de la marketplace `remia-tooling` : `/plugin` dans Claude Code, ou
`claude plugin install decode@remia-tooling`.

## Fichiers

| Fichier | Rôle |
|---|---|
| `.claude-plugin/plugin.json` | le plugin (nom, version) |
| `SKILL.md` | le skill |
| `decode.nanorc` | couleurs et confort de nano pour les `*-traduit.md` : explication ajoutée en vert clair |
| `selftest.sh` | autotest : soumet un court texte de mainteneur à `claude -p` et vérifie qu'aucun paragraphe n'est sauté et que les idiomes sont définis |

## Ce que le skill apprend (toujours avec accord)

- **Profil** : partagé avec `simple` (`~/.config/remia-tooling/simple/profil.md`).
- **Glossaire** (`~/.config/remia-tooling/decode/glossaire.md`) : les tournures déjà décodées ; rappelées en 3 mots ensuite.

## Versions

`version` de `.claude-plugin/plugin.json` et `version:` du frontmatter de `SKILL.md`, montées ensemble
(`tests/check.sh` le vérifie).

| Version | Changements |
|---|---|
| 1.2.0 | Un principe = un cas réel du projet ; un jugement de l'auteur = son critère (pourquoi « sharp edge » et pas « hole ») ; ce qui est annoncé comme fait est vérifié sur la forge (commit réel) ; section finale « qui a écrit » (indices d'IA, estimation). |
| 1.1.0 | Les explications ajoutées sont entre `⟦ ⟧` ; `decode.nanorc` les colore en vert clair dans nano (et porte les réglages de confort). |
| 1.0.0 | Première version. |

## Tester

`./selftest.sh` — nécessite `claude` ; `DECODE_MODEL=` pour choisir le modèle.
