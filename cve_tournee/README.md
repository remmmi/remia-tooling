# cve-tournee — une alerte de sécurité, tous les VPS audités d'un coup

Quand une CVE sort, on ne se connecte plus à chaque VPS pour coller la même question au Claude du
serveur. On donne le lien (ou l'identifiant CVE) une fois, depuis le poste : chaque VPS est audité par
son propre Claude, en parallèle, et seuls les VPS à traiter ouvrent un onglet herdr.

## Avant / après

> **Avant** — cinq connexions, cinq fois « <lien> on est comment ici ? », cinq fenêtres à surveiller
> puis à fermer, dont quatre pour apprendre que tout va bien.
>
> **Après** — « <lien> on est comment partout ? ». Le lien est lu une fois, un brief est écrit, cinq
> `claude -p` tournent en parallèle. Un tableau arrive : quatre OK, un VULNERABLE. Un seul onglet
> s'ouvre, sur le VPS vulnérable, avec un Claude qui a déjà lu le brief et l'audit.

## Déroulé

1. **Brief** : l'agent du poste lit la source et le Debian Security Tracker, et écrit un brief (produit,
   versions vulnérables, versions corrigées en bookworm et trixie, condition d'exploitation).
2. **Recensement** : `cve-tournee hosts` sonde tous les `Host` de `~/.ssh/config` et les cibles des
   raccourcis du shell. Un hôte sans `claude` ou injoignable est ignoré, sans liste à maintenir.
3. **Audit** : `cve-tournee audit <brief>` lance sur chaque VPS `claude -p --model opus --effort medium`,
   en lecture seule. Le Claude distant doit refaire l'inventaire complet du serveur à chaque fois
   (paquets, services, tous les serveurs web, chaque conteneur, runtimes, binaires hors apt) et finir
   par une ligne `VERDICT:`.
4. **Tableau** : une ligne par hôte, VULNERABLE et INCERTAIN d'abord.
5. **Onglets** : `cve-tournee ouvrir <run>` ouvre un onglet herdr par VPS à traiter, avec une session
   Claude neuve dans `~` sur le VPS.

## La veille : sans attendre de lire un article

La tournée part d'une alerte qu'on a vue. La veille part de ce qui est installé, et n'appelle aucun
modèle : `cve-tournee veille` relève l'inventaire de chaque VPS et du poste, puis le croise avec deux
sources.

| Source | Ce qu'elle dit |
|---|---|
| Debian Security Tracker | les paquets installés en dessous de la version corrigée de leur distribution (bookworm, trixie) |
| OSV.dev | les dépendances des projets (lockfiles Composer, npm, Python), les paquets npm globaux et `claude` dont la version exacte est touchée par une faille connue |

S'y ajoute l'état d'apt de chaque hôte : mises à jour de sécurité en attente, `unattended-upgrades`
inactif, listes périmées, redémarrage demandé. Le rapport marque **nouveau** ce qui n'était pas là à la
veille précédente. `cve-tournee timer installer` la lance chaque jour à 08:30 (rattrapée au démarrage si
le poste était éteint) et envoie une notification herdr quand un constat Debian, critique ou haut est
nouveau. La veille ne lance jamais d'audit toute seule : elle dit « cette version est installée »,
l'audit par le Claude du VPS dit « et elle est exposée ici ».

`cve-tournee trier` fait le lien entre les deux : il envoie à chaque hôte ses propres constats Debian,
critiques et hauts, et le Claude de l'hôte les classe en lecture seule, `EXPOSE` (chargé par quelque
chose de joignable), `HORS_PROD` (tests, build, dépendance de dev, copie non servie) ou `A_VERIFIER`.
Un constat classé n'est pas retrié ; le rapport suivant porte l'étiquette et met les exposés en tête.

Limites : les images Docker sont listées, pas analysées ; `yarn.lock` et `pnpm-lock.yaml` ne sont pas
lus ; les failles sans correctif Debian ne sont pas listées. OSV reçoit les noms et versions des paquets
des lockfiles (préfixes à taire : `~/.config/cve-tournee/osv-ignore`).

## La commande `cve-tournee`

| Sous-commande | Rôle |
|---|---|
| `cve-tournee hosts [--json]` | recense et sonde les hôtes : audité (OS, version de Claude) ou ignoré (raison) |
| `cve-tournee audit <brief.md> [--hosts a,b] [--model M] [--effort E] [--timeout S] [--dry]` | audit en parallèle, tableau, rapports dans `~/.cache/cve-tournee/<run>/` |
| `cve-tournee tableau <run>` | réaffiche le tableau d'une tournée |
| `cve-tournee ouvrir <run> [hote…] [--tous] [--dry]` | onglet herdr « cve <hote> » par VPS VULNERABLE, INCERTAIN ou ERREUR |
| `cve-tournee inventaire [--hosts a,b]` | relevé sans modèle : paquets Debian, état d'apt, images Docker, dépendances |
| `cve-tournee veille [--hosts a,b] [--sans-inventaire] [--notifier]` | inventaire, croisement Debian et OSV, rapport, nouveautés |
| `cve-tournee rapport` | chemin du dernier rapport de veille |
| `cve-tournee trier [--hosts a,b] [--tout] [--model M] [--effort E] [--dry]` | le Claude de chaque hôte classe ses constats : `EXPOSE`, `HORS_PROD`, `A_VERIFIER` |
| `cve-tournee timer installer\|etat\|retirer` | veille quotidienne par un timer systemd utilisateur |

L'hôte `local` est le poste lui-même : inventorié, veillé, et audité s'il a `claude`.

Verdicts : `VULNERABLE`, `INCERTAIN` (le Claude distant n'a pas pu trancher), `ERREUR` (pas de réponse),
`OK` (présent, corrigé ou non exploitable), `NON_CONCERNE` (produit absent).

## Ce qui est garanti, ce qui ne l'est pas

- **Lecture seule** : le Claude distant n'a que `Read`, `Grep`, `Glob` et une liste de commandes de
  constat (`dpkg`, `apt-cache`, `systemctl status`, `docker ps/inspect/exec`, `ss`, versions des
  binaires…). Tout le reste lui est refusé, en plus de ce que les réglages du VPS autorisent déjà. `docker
  exec` est dans la liste, pour lire une version dans un conteneur : la consigne interdit toute
  modification, la liste ne peut pas l'empêcher à elle seule. Ajouter des règles : une par ligne dans
  `~/.config/cve-tournee/outils` (format `--allowedTools`, par exemple `Bash(pm2 list:*)`).
- **Rien n'est corrigé tout seul**. Le correctif se discute dans l'onglet, avec le Claude du VPS.
- **Le verdict est celui d'un modèle**. Le rapport complet de chaque hôte est gardé pour relire la preuve.
- **Confiance dans `~`** : à la première session interactive sur un VPS, Claude demande de confirmer la
  confiance dans le dossier personnel. À valider soi-même, une fois par VPS.
- **Lien SSH coupé** : l'onglet se reconnecte et reprend la même session (`claude --resume`).

## Fichiers sur la machine

| Chemin | Rôle |
|---|---|
| `~/.config/cve-tournee/ignore` | hôtes à laisser hors tournée, un par ligne (facultatif) |
| `~/.config/cve-tournee/outils` | règles `--allowedTools` en plus (facultatif) |
| `~/.config/cve-tournee/osv-ignore` | préfixes de paquets à ne pas envoyer à OSV (facultatif) |
| `~/.config/systemd/user/cve-tournee-veille.{service,timer}` | posés par `timer installer`, retirés par `timer retirer` |
| `~/.cache/cve-tournee/inventaire/<hote>.json` | dernier inventaire de chaque hôte |
| `~/.cache/cve-tournee/veille/` | `rapport.md`, `constats.json`, `vus.json` (ce qui est déjà connu), `tri.json` (classes) et `tri-<hote>.md` (réponse du Claude de l'hôte) |
| `~/.cache/cve-tournee/debian-tracker.json`, `osv/` | caches des deux sources (tracker : 90 Mo, rafraîchi après 20 h) |
| `~/.cache/cve-tournee/briefs/` | les briefs |
| `~/.cache/cve-tournee/<run>/` | `brief.md`, `<hote>.md` (rapport), `<hote>.json` (sortie brute), `resultats.json` |
| sur chaque VPS ouvert : `~/.cache/cve-tournee/<run>.md` | brief et rapport, lus par la session de l'onglet |

## Installer

Plugin `cve-tournee` de la marketplace `remia-tooling` : `/plugin` dans Claude Code, ou
`claude plugin install cve-tournee@remia-tooling`. À installer sur le poste d'où part la tournée, pas sur
les VPS. Demande `python3`, `ssh` avec une clé qui ouvre chaque VPS sans mot de passe, `claude` connecté
sur chaque VPS, et `herdr` pour les onglets. Si le plugin `usec` est installé, la tournée n'est pas
lancée quand un quota hebdomadaire a franchi son seuil.

## Fichiers

| Fichier | Rôle |
|---|---|
| `.claude-plugin/plugin.json` | le plugin (nom, version) |
| `skills/cve-tournee/SKILL.md` | le skill : brief, recensement, audit, compte rendu, onglets |
| `bin/cve-tournee` | la commande (Python, bibliothèque standard) |
| `selftest.sh` | autotest sans réseau : lecture de `ssh/config` et des raccourcis, lecture des verdicts, commandes à blanc, lecture des lockfiles, comparaison de versions Debian, croisements Debian et OSV sur des données factices |

## Versions

| Version | Changement |
|---|---|
| 1.2.0 | `trier` : le Claude de chaque hôte classe ses constats de veille (Debian, critiques, hauts) en `EXPOSE`, `HORS_PROD` ou `A_VERIFIER`, en lecture seule ; classes mémorisées et reportées dans le rapport de veille. |
| 1.1.0 | Veille sans modèle : `inventaire`, `veille` (Debian Security Tracker et OSV.dev, nouveautés depuis la veille précédente), `rapport`, `timer` (systemd utilisateur, notification herdr). Hôte `local` : le poste est inventorié, veillé et audité comme un VPS. |
| 1.0.0 | Première version : recensement automatique, audit parallèle en lecture seule (Opus, effort medium), tableau, onglet herdr en ssh simple avec session neuve dans `~` et reprise après coupure. |
