# skills

Skills pour Claude Code distribués en plugins de la marketplace `remia-tooling` (voir le README à la
racine du dépôt). Chacun est agnostique — aucun nom, secret ni détail de projet — et se personnalise
sur la machine, hors du plugin.

| Plugin | Rôle | Installer |
|---|---|---|
| [`simple`](simple/) | Rejouer une explication que l'utilisateur n'a pas comprise, en changeant de registre au lieu d'ajouter des détails. | `/plugin`, ou `claude plugin install simple@remia-tooling` |
| [`decode`](decode/) | Faire comprendre, paragraphe par paragraphe, un texte technique écrit par un autre (mainteneur, issue, doc, LLM), sans résumer, code à l'appui ; explications en vert dans nano (`decode.nanorc`). Lit le profil de `simple`. | `/plugin`, ou `claude plugin install decode@remia-tooling` |
| [`chatroom`](chatroom/) | Rejoindre un salon Agent Room focus et terse, écouter, travailler par le board, sortir seulement sur « au revoir » de l'hôte. | `/plugin`, ou `claude plugin install chatroom@remia-tooling` |
