---
name: ux-design
description: |
  App-level UX: users and top tasks, navigation, multi-screen flows including
  first run, app-wide interaction and accessibility conventions, AI-feature UX
  and all 3D/XR UX. Writes docs/ux/ux-design.md plus the first screen specs.
  Use for "information architecture", "user flows", "redo our navigation",
  "UX audit", a new product's UX, a new multi-screen flow (onboarding,
  checkout), recovering a shipped app's UX, or AR, VR, MR or spatial design,
  even one screen. Do NOT use for: one screen on an existing app
  (screen-design); tokens, styling or motion (design-system); conversion
  fixes on a live funnel (cro); 3D engine code (web3d).
---

# UX Design

UX for the whole product, written so that a newcomer can design any new screen consistently from it. Budgets size the record, never the analysis: run every check at any size.

## Modes & Routing

Route by the request and what exists: the UX doc (default `docs/ux/ux-design.md`; the caller may redirect the `docs/ux/` root) and a shipped product.

| State | New product or flow | One screen | One decision | Restructure | Review | 3D/XR; a new AI feature |
|---|---|---|---|---|---|---|
| Nothing shipped, no doc | Stages 0–4 | Lite frame → that screen only | Answer inline | — | Ask what to review | Lite frame → Spatial Mode or AI pass |
| Shipped, no doc | Recover → Flow pass | screen-design | Answer inline | Recover → restructure | Recover → review | Recover what it touches → Spatial Mode or AI pass |
| Doc exists | Flow pass | screen-design | §6 row + patches | Restructure | Review | Spatial Mode or AI pass |

- **Recover**: walk the product (browse or qa capability, if available; else screenshots or code routes) and write the app doc as shipped (`State: as-is recovered`): the whole app for a restructure, else what the request touches plus the navigation and role landings around it; a review writes no doc unless asked. Inconsistencies become findings, not fixes.
- **Flow pass**: Stage 0 for the roles and task it serves; Stage 1 for any object it introduces; Stage 2 for the flow; patch §4, routes and pending Screens entries; one screen-design run per screen.
- **One decision** (tabs or sidebar, dialog or page, an object's name, one nav item): the pick, runner-up, what it gives up and when to revisit, inline (≤300 words) or as a §6 row plus patches to the rows it touches; a new top-level destination goes through Stage 1.
- **Restructure**: decide whether it is warranted, then run Stage 1 against the as-is and migrate routes, reversals included (`references/information-architecture.md` § Restructure).
- **One screen**, AI screens included: the screen-design capability, if available; else Stage 4 for that screen, first recovering the conventions it touches if no doc records them.

**Always**: patch in place, never regenerate (an older-format doc: convert only the sections you touch; keep its headings); write only under the UX root. Upstream docs are input, not constraint: never inherit a choice that fails a role or can cause harm. Screens use the safer answer where it needs no upstream change; otherwise they use a fail-safe fallback and propose the safer answer. Log each conflict in §7 with its owner, the upstream section to change and that fallback; a harm-capable one is a blocker. Ask once, in Stage 0 (the only other stop: Stage 4's Full-tier gate); a run that cannot ask applies the defaults as `A-nn` assumptions, fail-safe wherever a wrong guess can hurt someone (a human route, narrower autonomy, the manual path), and lists its questions.

**Report back** in ≤200 words, not the docs: blockers first (harm-capable conflicts, costly paths left unspecified, a restructure or costly-to-fail flow due to ship before its test passes); then files written, pending screens, assumptions and questions, recovery findings, the validation plan, hand-offs (screen-design, design-system, web3d, if available); a review's verdict and root causes. No material finding drops to fit: one line each, overrun stated.

## Stage 0 — Frame

**Read first** (defaults; caller may redirect): the PRD (`docs/prd/prd.md` §2 segment, motion and job story, §5 features, §6 releases, §7 ⚠ arch items, §8 envelope and duties) and feature specs (`docs/prd/features/*.md`); the architecture: `docs/arch/context.md` (§2 placement, reach and hazard, §4 Ubiquitous Language, §5 C-03 and C-05), `docs/arch/system.md`, ADRs (`docs/arch/adr/`) and AI feature docs (`docs/arch/ai-features/*.md`), noting the UI they oblige (audit, admin or review tools, consent, degraded modes); funnels (`biz/analytics/funnels.md`); support themes; the live product; existing `docs/ux/`. No requirements anywhere: ask where they live, else treat the caller's words as assumptions.

**Find the problem behind the request** and solve it where it lies (another screen, a message, an upstream choice), or hand it off specified enough to act on; never trim it to fit the request; state any cut, its reason and what users do meanwhile.
- "Add onboarding" → often an empty first run or an ask before value: map each arrival path to its first-value event.
- "Redo the navigation", one role's complaint → check the organizing principle first (navigation built around the product's features, modules or teams, not each role's top tasks; a role with no home), then objects without a home and labels that don't predict. Check every role and where each lands; first-click test the top tasks.
- "Simpler", "a dashboard" → secondary tasks crowd the top one, or nothing shows what needs attention: rank roles × tasks; name each screen's decision.
- "Nobody uses X", "make it engaging" → never seen, unclear, tried and failed, or no value (`references/cognitive-principles.md`); no value is the caller's product question, not a redesign.

**Calibrate once**, asking only what the inputs leave open and the output needs. Defaults: platforms, locales, offline use and accessibility duty per the PRD §8 envelope or C-05 (else responsive web with touch and pointer, one LTR locale, online-only with a notice, WCAG 2.2 AA); roles per the PRD (B2B: admin, member, invitee); frequency from the archetype; volume per core object in a heavy account, est.; design system: the platform's own components; regulated flows per the PRD or C-03; conventions as shipped. Test each adopted value against the roles' real context: one that shuts a role out (a language its users need, the device or connectivity of its work, an accessibility need) is a conflict (Always), not a default.

**Tier** from the PRD's Reach: personal → Lite, team → Standard, external → Full (none given: Standard); one up for several roles, regulated flows or platforms. Tier sizes the doc, never a costly path's depth. Lite writes Stage 0 in a few lines, §4 for the top tasks and first run, and §5's accessibility line; the rest of Stages 1 and 3 only where the product departs from platform defaults.

**Top tasks.** List each role × task (invitees, approvers, admins, viewers and people reached only by messages included) with frequency (daily, weekly, rare) and cost of failure (money, data, health or safety, other people, legal); frequent or costly-to-fail tasks are top tasks. Frequency sets prominence (navigation slots, accelerators, defaults); cost sets depth (safeguards, recovery, validation): a rare, costly task (account recovery, restoring a backup) gets full depth and a findable home, not a nav slot. Where failure can hurt someone, its waiting, unsure and down states offer a person or a safe manual action, faster than the harm develops. *Break when* the PRD names a strategic task with no usage yet: temporary prominence, dated revisit.

**Archetype**, by the primary role's top task: occasional transaction, daily workspace, feed, marketplace or admin console, each with default navigation, density and a signature risk (`references/information-architecture.md` § Navigation model). *Break when* the product is a hybrid: the secondary role gets its own home, not an average.

**Done** is measurable per top task ("a new member shares a first project in under 3 minutes, unaided"), tagged target. Write the app doc from `templates/ux-design.md`, starting with §1 and its assumption register. §7 tests what the design bets on (`references/design-process.md` § Validation plan). A PRD feature or architecture obligation with no task behind it is an open question, never a silent cut.

## Stage 1 — Objects & IA

Per `references/information-architecture.md`: objects first, each with one home and route; top-level slots are a budget for what users switch between, never features or teams; each role lands on its top tasks and waiting items, counted on navigation; findability is tested on top tasks, never judged by counting clicks. Write §2 and §3.

## Stage 2 — Critical flows

One flow per top task, rare costly ones included, plus a first run per arrival path (self sign-up, invite, admin or SSO provisioning) ending at its own first-value event ("first invoice sent"). The PRD's motion picks the lead: self-serve, sign-up, nothing that can wait before first value; sales-led, the admin's setup, then the invitee's first day; internal rollout, the provisioned member's first day. Each goes in §4 with its release tag, mapped per `references/design-process.md` § Mapping a flow. Flows break where they leave one person's screen: hand-offs get acknowledgement, a timeout and an escalation when nobody responds; messages they depend on (email, push, SMS) are steps too, not §5 lines.

## Stage 3 — Conventions

State each convention once in §5 (the template lists them), never per screen, from `references/interaction-patterns.md`, `references/ux-writing.md` and `references/ergonomics.md`. Offline behavior per object is the architecture's contract; where it fails a role, log a conflict (Always), default fallback: readable, writes disabled with the reason. Accessibility always goes in §5, as requirements and floors for the design-system capability ("text pairs ≥4.5:1"), never as token values. A departure from a platform default, or a trade-off between roles, gets a §6 row.

## Stage 4 — Screens

**Gate (Full tier):** a caller who can answer approves the navigation model and top flows before screens are written; otherwise mark the IA unvalidated in §7. At any tier, screens that depend on a §7 prototype test stay pending until it passes.

**Coverage.** Full specs for the first release's critical-path screens, every screen on a costly-to-fail path however rare, and every screen an architecture doc or ADR obliges, plus one exemplar per screen class (collection, record, form, dashboard; AI surface where present); every other screen is a pending Screens entry naming its exemplar and how it deviates. *Break when* the app has 8 screens or fewer, or the caller asks: spec all.

**Write each** (default `docs/ux/screens/{screen}.md`, kebab-case; modals, drawers and sheets in their parent's file) via the screen-design capability, if available, one run per screen (parallel runs return patch lines; apply them); §5 conventions override its defaults. Without it, use its headings only (Job and success, Layout, Fields, States, Interactions, Accessibility, Decisions, Dependencies and open questions), its budgets (simple 600, standard 1,000, complex 1,500 words; +300 per overlay), a layout sketch (regions in task order, ASCII or a list), literal copy for every label, message and state, and the 7 base states in order (empty, loading, loaded, error, partial, refreshing, offline), each specified or `N/A — reason`.

**Element cost:** an element serving no task, role or failure (success, error prevention, trust, recovery, learning) is cut; one serving only a secondary role is demoted; cost and consequence at money, data or permission moments always stay.

## Spatial Mode

All 3D/XR UX stays here, even one screen; the web3d capability, if available, implements it.

**Job first:** what does 3D/XR do better than the 2D baseline? Nothing → recommend 2D and stop. Then frame with `templates/spatial.md` §1–2 and its defaults. Done means the job metric beats the baseline, discomfort stays under a stop threshold, and the frame rate holds on the weakest device.

Write one spec per experience from that template (default `docs/ux/screens/{experience}.md`); a 3D surface on an existing screen is a section of that screen's file; patch the route table and Screens group either way; app-wide spatial conventions go to §5. Read `references/3d-design.md` (screens, phone AR) or `references/xr-design.md` (headsets, glasses).

## AI features

**AI pass.** Read the feature's doc (default `docs/arch/ai-features/{feature}.md`) and present it with `references/ai-feature-ux.md`: AI conventions to §5, the flows autonomy creates (approvals, activity ledger, scope settings) to §4, hosting screens through Stage 4. Its harm rules (§ Frame first) override the doc's routing, as a logged conflict (Always). No doc: design the presentation and list the questions for the software-architecture capability's AI Feature Mode, if available; never invent what the model may do, its limits or the data it sees.

## Review / Diagnose Mode

**Read-only by default**: edit only when asked, as targeted patches.

1. **Scope:** the decision the review feeds (launch gate, redesign priority, one complaint) and the roles, tasks and platforms in it. A complaint sets where you start, not what you check: trace it to the structure that produces it, and check that structure for every role.
2. **Evidence, strongest first:** the live product; funnels (default `biz/analytics/funnels.md`) and support themes; routes in code; the docs. Walk each in-scope top task (tools as in Recover), covering, across walks: a new empty account; a full one (long names, lists past one page); the most restricted role; the smallest supported window; keyboard alone (a screen reader on the critical path).
3. **Sweep** the shell (navigation, header, global actions, notifications) and each in-scope screen, walked or from code and screenshots:
   - *Structure, first:* navigation follows each role's top tasks, not the product's features, modules or org chart; each role lands on its top tasks and waiting items; one home and name per object; no vague bucket holds a top task (`references/information-architecture.md` § Anti-patterns).
   - *Shell access:* location and state shown by more than color; every item keyboard-reachable and operable, focus visible; icon-only items named; nothing hover-only; targets, contrast, text scaling and reflow at the floors in `references/ergonomics.md`.
   - *Conventions:* none of: a dialog for a reversible action, a vague "Are you sure?", a placeholder as label, a custom pattern for a standard task, promotion inside a task.
4. **Tag** each finding Observed (analytics, recordings, tests, tickets), Walked (you ran the task) or Inferred (docs or code only); an Inferred 🔴/🟠 names the check that would confirm it; never claim a walk-through you did not run.
5. **Diagnose** cause-first: from each symptom through its competing causes (`references/cognitive-principles.md`, which also says what goes to cro), never from a law's name, then group symptoms under the root cause they share; 3D and XR surfaces use their references' Diagnose tables.
6. **Drift:** Screens group ↔ `docs/ux/screens/`; route rows without a screen; base states missing without `N/A — reason`; screens contradicting §5; spec vs shipped.
7. **Severity**, by task impact; a root cause takes its symptoms' combined impact (the worst of them, one level up when it spans several roles or top tasks); within a level, order by users or sessions affected (funnels, recordings), else by the task's frequency rank, labeled an estimate:
   - 🔴 blocks a top task; loses data or money; exposes data; leaves someone at risk of harm without a fast human route; locks assistive-technology users out of a top task; a spatial comfort or physical-safety hazard.
   - 🟠 a top task succeeds only with major error, delay or help; a secondary task is blocked; a device or posture can't perform a core action.
   - 🟡 friction with a workaround.
   - 🟢 polish.
8. **Propose and test:** each structural root cause gets the proposed structure (navigation model, each role's landing, route changes with their migration) as a hypothesis, with tasks per role, success and first-click targets against the as-is, and post-ship metrics with action thresholds (`references/design-process.md` § Validation plan).
9. **Report**, sized by where the cause lies, not by the request (one flow ≈500 words; the structure or whole app ≈1,500; with no doc, plus an as-is summary of at most 300; exceed only to keep a material finding, a proposed structure or its test plan, and say so): open with the answer to the scoped decision (go, go after named fixes, or no-go); then root causes, each with the symptoms it explains, severity and evidence; then the fix order as its own list (🔴 stopgaps now, cheap top-task fixes, the structural fix with its migration and test); separate taste from defects; name what works and must survive; the top ~10 findings in full (location, user impact, evidence and tag, severity, fix), the rest one line each.

## Self-Review

Against the written files (Lite: items on sections it skipped don't apply):
- The problem behind the request is solved, or handed off with a spec; each cut says why and what users do meanwhile; conflicts name owner, upstream section and fallback; harm-capable questions default fail-safe and lead Report back as blockers.
- Each top task: a measurable success criterion (§1) and a flow with entry points and failure paths (§4); first runs end at a named first-value event; hand-offs have acknowledgement, timeout and escalation; messages a flow depends on are specified.
- Nav items map to objects or frequent top tasks; each role lands on its top tasks and waiting items; one home route per object; deep links cover no access, another account, deleted and moved.
- Every PRD §5 feature and architecture or ADR UI obligation maps to a screen or "no UI"; costly-to-fail paths have full specs; the Screens group matches `docs/ux/screens/` one-to-one, entries tagged by release, pending ones with an exemplar.
- One glossary term per object and status, used everywhere; literal copy; no law names or method notes; each convention once, in §5, with a complete accessibility line; offline behavior matches the architecture or is a logged conflict.
- Decisions name runner-up, cost and revisit trigger; §7 tests the riskiest assumptions and the proposed structure (tasks per role, targets, post-ship thresholds); no invented participant data.
- Screens written here: a job, layout sketch and literal copy; one primary action per decision region (none on read-only screens); the 7 base states in order or `N/A — reason`; irreversible actions confirmed naming object and consequence, reversible ones undoable; a single-pointer alternative per drag or gesture.
- Spatial: `templates/spatial.md`'s self-check passes. AI: each failure-path branch has a state; harm-capable ones reach a person.
- Review: the answer first; root causes lead (combined impact, every role); the sweep ran; structural fixes carry a proposed structure, test and thresholds; each 🔴/🟠 has location, evidence tag, impact and fix (Inferred: its confirming check); what must survive is named.
- **Footprint:** each file within its template-header budget (screen specs: Stage 4; a review: step 9; Report back ≤200 words), or over only for a material finding, a costly path, or a review's proposed structure and test, reason given; no empty section.

## Reference files

- `references/design-process.md`: Stages 0 and 2 (flows, hand-offs, messages); validation plans.
- `references/information-architecture.md`: archetypes; Stage 1; restructures; the anti-patterns a review checks first.
- `references/interaction-patterns.md`: Stages 3–4.
- `references/ux-writing.md`: copy; the glossary; messages.
- `references/ergonomics.md`: accessibility floors; window sizes; platforms.
- `references/cognitive-principles.md`: reviews; "users struggle with X".
- `references/ai-feature-ux.md`: any AI surface.
- `references/3d-design.md`, `references/xr-design.md`: Spatial Mode.
- `templates/ux-design.md`, `templates/spatial.md`: the app doc; a spatial spec.
