# ADR Template — one file per decision

One Architecture Decision Record per file: `docs/arch/adr/ADR-NNN-{slug}.md`
(NNN zero-padded to 3 digits — e.g. `ADR-001-postgres-over-dynamo.md`). The next number is
the highest existing ADR in `docs/arch/adr/` plus one. ADRs are written immediately when a
decision occurs, not batched at the end.

**Context**: See `docs/arch/context.md` for problem definition and ASRs. See `docs/arch/system.md` for architecture.

---

## ADR-NNN: [Title] — YYYY-MM-DD

- **Status**: Accepted | Proposed | Superseded by ADR-NNN
- **Stage**: [which design stage produced this decision]
- **Door**: One-way (irreversible) | Two-way (reversible)
- **Context**: [the situation and forces at play]
- **Decision**: [what was chosen]
- **Why**: [reasoning — reference quality attributes from utility tree]
- **Rejected**: [alternatives and why not]
- **Tradeoff**: [positive and negative consequences]
- **Revisit when**: [trigger for reconsideration]

<!-- When this decision is later superseded, set its Status to `Superseded by ADR-NNN`
     in place — keep the file, don't delete it. -->

---

<!-- Minimum ADRs to record (guidance — this comment is scaffolding, not document content):

Always (all software types):
1. System architecture pattern
2. Service architecture pattern
3. Primary data storage approach
4. Communication style (sync/async/event-driven)

When applicable:
- AI integration approach — when AI features exist
- Authentication/authorization — when users exist
- API design philosophy — when external consumers exist
- Offline/sync strategy — when offline capability is needed
- Distribution/packaging — for libraries, CLIs, desktop apps
- Concurrency model — for high-throughput or real-time systems
- Build-vs-buy — when a generic subdomain is bought as an external service rather than built or self-hosted
-->
