# Onboarding CRO

Activation of new users in an existing product, from the first session to the activation event. A new product's onboarding → ux-design; email cadence and copy → copywriting (triggers only here); cancellations and save offers → churn-prevention (each via that capability, if available).

## The activation event

Take it from the tracking plan (default `biz/analytics/tracking-plan.md`). The discovery method is in `product-analytics/references/aha-moment-discovery.md`, via that capability if available. With no Aha defined, use a provisional activation event, the first completion of the product's core job, flagged as provisional. A provisional Aha is correlational: before building onboarding around it, check that the retention lift holds at equal early activity, and validate it with an encouragement test (randomly nudge users toward the action; retention should follow).

**Judge onboarding on activation plus D30 retention**, never on checklist or tour completion, which can rise while activation stays flat. Time to activation (median and p90) is the diagnostic.

## Leak signatures

- **Drop at a setup dependency** (an integration, a data import, a teammate invite) → value waits on work. Confirm: step-level drop and time to activation. Start with sample data or a template. Break when sample data can't feel real (finance, health): guide the real setup instead.
- **Activation differs by acquisition source** → the first run ignores the promise that brought them. Confirm: activation by source and stated goal. Route the first run by source or by one goal question.
- **Checklist completed, no retention** → the checklist rewards setup, not the core job. Confirm: retention of completers vs activators. Rebuild it around the activation event.
- **Tours started, then skipped** → forced tours interrupt. Confirm: the skip step and later activation. Prefer short tours the user triggers, and in-context hints at the moment of need.
- **Stalled users** (no core action within one natural usage interval) → the next step is unclear or blocked. Confirm: their last completed step. Resume where they left off, in-product; email triggers go to copywriting.

## Judgment calls

- **One goal for the first session**: the first screen offers a single next action toward the activation event; advanced features wait.
- **Ask a setup question only when its answer changes what the user sees next.**
