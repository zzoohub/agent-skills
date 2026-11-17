# ADR Template — one file per contested decision

`docs/arch/adr/ADR-NNN-{slug}.md` (NNN zero-padded, e.g. `ADR-001-relational-store-over-document-store.md`). The next number is the highest existing ADR plus one. Write it when the decision is made, not at the end.

An ADR is for a one-way door with a live alternative, a departure from the default or the technology baseline, or a trade between two drivers. A default taken for a stated reason is one row in `system.md` §1 Decisions.

---

## ADR-NNN: [the decision, stated as a choice] — YYYY-MM-DD

- **Status**: Accepted | Proposed — settled by [the spike, the vendor fact to verify, or the answer owed and by whom] | Superseded by ADR-NNN
- **Drivers**: [D / C ids this decision serves]
- **Door**: One-way — [what undoing touches] | Two-way — [how it is undone]
- **Context**: [the situation and forces; the number that triggers it]
- **Decision**: [what was chosen, for what scope]
- **Why**: [the deciding driver, with its number]
- **Rejected**: [one line each: the driver it fails or the cost it adds]
- **Tradeoff**: [what gets worse, and who pays]
- **Confirmation**: [the guard or metric that shows the decision holds]
- **Revisit when**: [a variable and its threshold, or a dated event]

<!-- ~250 words: the decision and its price. Link the design, never restate it.
     When the reasoning lives in an AI feature doc, keep Status, Drivers, Door, Decision and Revisit when, and point to the section for the rest.
     When superseded, change only Status; keep the file. -->
