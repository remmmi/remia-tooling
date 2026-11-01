<!-- usec:start — block managed by remia-tooling/usec, replaced on every update -->
## Subscription quotas: silent watch

A hook (`usec-watch`) reads Claude quotas in the background (~every 20 min of activity) and
projects consumption at the current pace. It stays silent while everything is fine.

- **`[usec-watch]` alert received**: tell the user right away, in one sentence with the numbers,
  and suggest: postpone heavy tasks, a cheaper model, less parallelism.
- **Otherwise, at your judgment**: after a heavy step, or before starting one (chain of
  `claude -p`, many subagents, batch), read `usec-watch status` — free, last reading + projection.
  `usec` forces a fresh reading (costs a call). Say nothing if nothing is critical.
- **Critical** = a weekly quota ≥ 85 %, or 100 % reached before the reset at the week's average
  pace (there is no 5-hour session window any more).
- **Automated scripts**: source `~/.local/share/usec/quota_gate.sh` and call `usec_gate` before
  each `claude -p` (clean pause at the threshold, identical restart after the reset).
- A quota failure looks like a model failure (rc 1): check the call duration — 3 failures in a
  row within seconds = quota or auth, stop the batch.
<!-- usec:end -->
