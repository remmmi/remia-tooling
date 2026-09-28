<!-- usec:start — bloc géré par remia-tooling/usec, remplacé à chaque mise à jour -->
## Quotas de l'abonnement : `usec`

`usec` (shell, ~5-20 s) rend en JSON les quotas Claude : `quotas[]` avec `period` (`session` =
fenêtre glissante de 5 h, `week`), `models`, `used_percent`, `reset_at`.

- **Quand le lire** : aux frontières de tâche, avant de lancer une tâche lourde (chaîne de
  `claude -p`, sous-agents en nombre, lot/drain), et toutes les ~20 unités pendant un lot long.
  Pas en boucle, pas à chaque message : chaque lecture coûte un appel.
- **Seuils** : au-delà de ~85 % sur la période concernée, différer ou prendre un modèle moins
  cher. Gros lot devant et session > ~60 % : attendre le `reset_at` de la session plutôt que lancer.
  Le dire à l'utilisateur avec les chiffres, ne pas trancher en silence.
- **Scripts automatiques** : sourcer `~/.local/share/usec/quota_gate.sh` et appeler `usec_gate`
  avant chaque `claude -p` (pause propre au seuil, reprise à l'identique après le reset).
- Un échec de quota ressemble à un échec de modèle (rc 1) : regarder la durée de l'appel —
  3 échecs de suite en quelques secondes = quota ou auth, arrêter le lot.
<!-- usec:end -->
