# Risks & Open Questions

**Context**: See `docs/arch/context.md` (problem, ASRs), `docs/arch/system.md` (architecture) and `docs/arch/adr/` (decisions).

---

# Risk Register

<!-- Seeds mirror the highest-leverage non-AI risks; replace with this system's real ones. ATAM rows marked risk land here. -->

| Risk | Threatens (QA/C ids) | Impact | Probability | Owner | Signal | Mitigation |
|---|---|---|---|---|---|---|
| Security: tenant data leak across a trust boundary | | | | | cross-tenant test failures | STRIDE-surfaced ASR (filter #8) + ≥ 2 enforcement points + cross-tenant tests |
| Data: replica lag breaks read-your-writes | | | | | replica lag | Read-path choice (Stage 6); leader reads on critical paths |
| Capacity: load beyond the envelope | | | | | peak vs modeled load | Load test to the driver's measure; admission control, backpressure |
| Dependency slow or down | | | | | dependency p99, error rate | Deadline, one budgeted retry layer, exercised degradation (Stage 8) |
| Write hazard: lost update / double-process | | | | | duplicates, version conflicts | Outbox, idempotency keys, optimistic concurrency |

**Risk themes**: [theme → risks]

<!-- AI: add rows from each feature doc's failure path and envelope, never pre-rated (e.g. provider lock-in → model port + eval-qualified alternate).
     Transition: seed from references/evolution.md § Transition Plan (cutover data loss, store features that do not port, knowledge held by few people, old and new drifting apart). -->

---

# Tech Debt

| Item | When | Priority | Resolution Condition |
|---|---|---|---|

---

# Open Questions

| Question | Options | Info needed | Decide-by | Blocking? |
|---|---|---|---|---|
| ... | ... | ... | [date or stage] | yes / no |
