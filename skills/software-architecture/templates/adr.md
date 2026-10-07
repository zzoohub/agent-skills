# ADR Template — one file per decision

One Architecture Decision Record per file: `docs/arch/adr/ADR-NNN-{slug}.md`
(NNN zero-padded to 3 digits — e.g. `ADR-001-relational-store-over-document-store.md`). The next number is
the highest existing ADR in `docs/arch/adr/` plus one. ADRs are written immediately when a
decision occurs, not batched at the end.

**Context**: See `docs/arch/context.md` for problem definition and ASRs, `docs/arch/system.md` for architecture.

---

## ADR-NNN: [Title] — YYYY-MM-DD

- **Status**: Accepted | Proposed | Superseded by ADR-NNN
- **Stage**: [which design stage produced this decision]
- **Drivers**: [QA / C ids this decision serves]
- **Door**: One-way (irreversible) | Two-way (reversible)
- **Context**: [the situation and forces at play]
- **Decision**: [what was chosen]
- **Why**: [reasoning — the quality attributes it optimizes]
- **Rejected**: [alternatives — the driver each fails or the cost it adds]
- **Tradeoff**: [positive and negative consequences]
- **Confirmation**: [the guard or metric that shows the decision holds]
- **Revisit when**: [trigger — a variable and its threshold]

<!-- When this decision is later superseded, set its Status to `Superseded by ADR-NNN`
     in place — keep the file, don't delete it. -->

<!-- ~300 words: the decision and its price — link the design, never restate it. -->

<!-- Minimum ADRs: references/design-flow.md § Minimum ADRs (single source). -->
