<!-- usec:start — block managed by remia-tooling/usec, replaced on every update -->
## Subscription quotas: `usec`

`usec` (shell, ~5-20 s) prints Claude quotas as JSON: `quotas[]` with `period` (`session` =
rolling 5-hour window, `week`), `models`, `used_percent`, `reset_at`.

- **When to read it**: at task boundaries, before starting a heavy task (chain of `claude -p`,
  many subagents, batch/drain), and every ~20 units during a long batch. Not in a loop, not on
  every message: each read costs a call.
- **Thresholds**: above ~85 % on the relevant period, postpone or switch to a cheaper model.
  Big batch ahead and session > ~60 %: wait for the session `reset_at` rather than starting.
  Tell the user, with the numbers; do not decide silently.
- **Automated scripts**: source `~/.local/share/usec/quota_gate.sh` and call `usec_gate` before
  each `claude -p` (clean pause at the threshold, identical restart after the reset).
- A quota failure looks like a model failure (rc 1): check the call duration — 3 failures in a
  row within seconds = quota or auth, stop the batch.
<!-- usec:end -->
