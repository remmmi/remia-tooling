<!-- usec:start — bloc géré par remia-tooling/usec, remplacé à chaque mise à jour -->
## Quotas de l'abonnement : surveillance silencieuse

Un hook (`usec-watch`) relève les quotas Claude en arrière-plan (~toutes les 20 min d'activité) et
projette la consommation au rythme actuel. Il ne dit rien tant que tout va bien.

- **Alerte `[usec-watch]` reçue** : prévenir l'utilisateur tout de suite, en une phrase avec les
  chiffres, et proposer : différer les tâches lourdes, un modèle moins cher, moins de parallélisme.
- **Sinon, à ton jugement** : après une étape lourde, ou avant d'en lancer une (chaîne de
  `claude -p`, sous-agents en nombre, lot), lire `usec-watch status` — gratuit, dernier relevé +
  projection. `usec` force un relevé frais (coûte un appel). Ne pas en parler si rien n'est critique.
- **Critique** = session ou semaine ≥ 85 %, ou 100 % atteint avant le reset au rythme actuel
  (une session qui se réinitialise dans moins de 30 min ne compte pas).
- **Scripts automatiques** : sourcer `~/.local/share/usec/quota_gate.sh` et appeler `usec_gate`
  avant chaque `claude -p` (pause propre au seuil, reprise à l'identique après le reset).
- Un échec de quota ressemble à un échec de modèle (rc 1) : regarder la durée de l'appel —
  3 échecs de suite en quelques secondes = quota ou auth, arrêter le lot.
<!-- usec:end -->
