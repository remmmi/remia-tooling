# modele-agents

Un bandeau au-dessus de la saisie de Claude Code liste les sous-agents en cours et le modèle sur
lequel chacun tourne :

    general-purpose·Haiku 5.5 | Explore·Sonnet 5.5

Le nom du modèle s'écrit comme dans la status line (`claude-haiku-5-5` donne `Haiku 5.5`), en cyan.
Le bandeau disparaît quand aucun sous-agent ne tourne. Il ne coûte aucun token : le mod tourne dans
Claude Code et n'appelle jamais le modèle.

## Comment il suit les agents

- Au lancement d'un sous-agent, il note son type et le modèle retenu.
- Quand l'agent rend la main, il sort du bandeau.
- S'il repart plus tard (fin d'une commande lancée en arrière-plan, message reçu), il y revient avec
  le modèle noté au lancement.

## Limites

- Après une installation ou un `/reload-plugins`, les agents déjà en cours n'apparaissent pas : le
  mod n'a pas vu leur lancement, et Claude Code ne donne pas le modèle d'un agent après coup.
- Un agent tué sans fin de tour pourrait rester affiché jusqu'à la fin de la session (non vérifié).

## Installer

    /plugin install modele-agents@remia-tooling

puis `/reload-plugins` dans une session ouverte, ou rien dans les suivantes.

## Tester

    claude plugin test modele_agents

## Versions

| Version | Changement |
|---|---|
| 1.0.0 | Première version : bandeau des sous-agents en cours avec leur modèle, retour d'un agent qui se réveille. |
