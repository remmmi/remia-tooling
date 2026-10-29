# bandeau-sous-agents

Un bandeau au-dessus de la saisie de Claude Code liste les sous-agents en cours, le modèle sur
lequel chacun tourne et son effort (le niveau de réflexion demandé au modèle) :

    general-purpose·Haiku 5.5 | Explore·Opus 5.5 high

Le nom du modèle s'écrit comme dans la status line (`claude-haiku-5-5` donne `Haiku 5.5`), en cyan ;
l'effort suit en gris : un niveau (`low` à `max`), ou un budget entier en tokens (`8000 tok`). Un
modèle sans réglage d'effort n'en affiche pas. Le bandeau disparaît quand aucun sous-agent ne
tourne. Il ne coûte aucun token : le mod tourne dans Claude Code et n'appelle jamais le modèle.

## Comment il suit les agents

- Au lancement d'un sous-agent, il note son type, le modèle retenu et l'effort demandé au lancement
  s'il y en a un.
- À chaque requête de l'agent au modèle, il relève l'effort réellement envoyé (réglage du type
  d'agent, de la session, ou défaut du modèle) : c'est lui qui s'affiche.
- Quand l'agent rend la main, il sort du bandeau.
- S'il repart plus tard (fin d'une commande lancée en arrière-plan, message reçu), il y revient avec
  le modèle et l'effort notés.

## Limites

- Après une installation ou un `/reload-plugins`, les agents déjà en cours n'apparaissent pas : le
  mod n'a pas vu leur lancement, et Claude Code ne donne pas le modèle d'un agent après coup.
- Entre le lancement et la première requête de l'agent, l'effort n'apparaît que s'il a été demandé
  au lancement.
- Un agent tué sans fin de tour pourrait rester affiché jusqu'à la fin de la session (non vérifié).

## Installer

    /plugin install bandeau-sous-agents@remia-tooling

puis `/reload-plugins` dans une session ouverte, ou rien dans les suivantes.

## Tester

    claude plugin test bandeau_sous_agents

## Versions

| Version | Changement |
|---|---|
| 1.0.0 | Première version, sous le nom `modele-agents` : bandeau des sous-agents en cours avec leur modèle, retour d'un agent qui se réveille. |
| 1.1.0 | Renommé `bandeau-sous-agents` ; l'effort de chaque agent suit le nom du modèle. |
