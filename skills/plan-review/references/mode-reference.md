# Mode Quick Reference

Loaded by `plan-review` in scope mode. Behavior matrix for the three scope modes. The per-section deltas in `references/review-sections.md` are the source of truth; this table is a lookup.

| | EXPANSION | HOLD SCOPE | REDUCTION |
|---|---|---|---|
| Scope | Push UP | Maintain | Push DOWN |
| 10x check | Mandatory | Optional | Skip |
| Platonic ideal | Yes | No | No |
| Delight opps | 5+ items | Note if seen | Skip |
| Complexity question | "Is it big enough?" | "Is it too complex?" | "Is it the bare minimum?" |
| Taste calibration | Yes | No | No |
| Temporal interrogate | Full (hr 1-6) | Key decisions only | Skip |
| Observability standard | "Joy to operate" | "Can we debug it?" | "Can we see if it's broken?" |
| Deploy standard | Infra as feature scope | Safe deploy + rollback | Simplest possible deploy |
| Error map | Full + chaos scenarios | Full | Critical paths only |
| Phase 2/3 planning | Map it | Note it | Skip |

HOLD-SCOPE note: choose HOLD SCOPE when you want maximum execution rigor on the accepted scope AND a premise/dream-state challenge alongside the rigor pass. If scope is fully locked and you only want execution rigor (no premise challenge), use execution mode (`references/execution-mode.md`) instead. Its TRIM sub-mode removes only clearly redundant work and never re-opens scope — unlike REDUCTION, which genuinely cuts scope.

Minimal-diff note: in EXPANSION, "minimal diff" constrains HOW each chosen capability is built, not WHETHER to add scope. In HOLD/REDUCTION it constrains both.

Error-map note: REDUCTION maps only critical paths, but the deterministic `RESCUED=N AND TEST=N AND Silent → CRITICAL GAP` gate still applies to whatever IS mapped — never soften it (see `references/required-outputs.md`).
