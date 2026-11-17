# Risks & Open Questions

**Context**: `docs/arch/context.md` (problem, drivers), `docs/arch/system.md` (architecture), `docs/arch/adr/` (decisions).

<!-- Budget, tables included: Small ≈ 300 · Standard ≈ 600 · Large ≈ 1,000 words. -->

---

# Risk Register

<!-- Only risks this design carries: Driver Coverage rows marked at risk, plus a pre-mortem (assume failure a year after launch; the likeliest cause per driver). A risk with no watched signal is fiction. Highest first. -->

| Risk (condition → consequence) | Threatens (D / C ids) | Impact | Probability | Owner (role) | Watched signal | Mitigation |
|---|---|---|---|---|---|---|
| e.g. replica lag breaks read-your-writes on checkout | D-03 | H | M | backend | replica lag p99 | leader reads on the critical path |

<!-- AI: rows from each feature doc's failure path and envelope. Transition: cutover data loss, features that do not port, knowledge held by few people, old and new drifting apart. -->

---

# Spikes

<!-- What must be proven before the work it unblocks. In the order to run them. -->

| SP-nn | Question | Pass / fail (a number) | Time box | Unblocks (ADR, driver, assumption) |
|---|---|---|---|---|

---

# Tech Debt

| Item | When taken | Priority | Resolution condition |
|---|---|---|---|

---

# Open Questions

| Question | Options (default first) | Information needed | Decide-by | Blocking? |
|---|---|---|---|---|
