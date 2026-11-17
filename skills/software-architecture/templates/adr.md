# ADR Template — one file per contested decision

`docs/arch/adr/ADR-NNN-{slug}.md` (NNN zero-padded, e.g. `ADR-001-relational-store-over-document-store.md`). The next number is the highest existing ADR plus one. Write it when the decision is made, not at the end.

An ADR is for a one-way door with a live alternative, a departure from the default or the technology baseline, or a trade between two drivers. A default taken for a stated reason is one row in `system.md` §1 Decisions.

---

# ADR-NNN: [the decision, as a rule or a choice]

- **Status**: Accepted · YYYY-MM-DD · [who decided] | Proposed · YYYY-MM-DD · settled by [the spike, the vendor fact to verify, or the answer owed and by whom] | Superseded by ADR-NNN
- **Door**: One-way — [what undoing touches] | Two-way — [how it is undone]
- **Context**: [the problem, the number that triggers it, the D / C ids it serves]
- **Decision**: [what was chosen, for what scope; the guard that enforces it]
- **Why**: [the one fact that separates it from the runner-up, with its number]
- **Rejected**: [one line each: the driver it fails or the cost it adds]
- **Tradeoff**: [what gets worse, and who pays]
- **Revisit when**: [a variable and its threshold, or a dated event]

<!-- One or two sentences per field: 150 to 200 words, 250 at most. The decision and its price.
     The title states the decision ("Pooled tenancy with row-level policies"), never the topic ("Tenancy model").
     Link the design, never restate it: rollout steps, proof and design detail live in system.md, risks.md and the code.
     When the reasoning lives in an AI feature doc, keep Status, Door, Decision and Revisit when, and point to the section for the rest.
     When superseded, change only Status; keep the file. -->
