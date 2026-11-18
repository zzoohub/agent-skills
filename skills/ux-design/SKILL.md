---
name: ux-design
description: |
  App-level UX derived from the product's core value: the journey from
  arrival to first and repeated value, who does each step (person, code or
  AI), navigation, critical flows, app-wide conventions and each bet's test.
  Covers AI chat and agent products and all 3D/XR UX. Writes
  docs/ux/ux-design.md plus the first screen specs. Use for "user journey",
  "information architecture", "user flows", "onboarding", "redo our
  navigation", "UX audit", "chatbot UX", "agent UX", a new product's UX or a
  new multi-screen flow. Do NOT use for: one screen on an existing app
  (screen-design); what a model may do (ai-architecture); tokens or motion
  (design-system); live-funnel conversion fixes (cro).
---

# UX Design

## Premise

**UX is the price a person pays for the product's value.** They pay in time, attention, effort, risk and waiting, and they stay while what they get is worth more. The business lasts when that keeps happening and it earns from it. So the design does not start from screens or features. It starts from the value, decides what the person must do, know and trust to reach it, and removes everything else.

Two things hold whatever the technology. People do not change: attention is narrow, memory short, reading partial, mistakes routine, and they arrive in the middle of something else. Systems fail: data is empty or late, networks drop, messages arrive twice, models are sometimes wrong. What changed is who can do the work. A model can now take steps only a person could take before, which removes effort and adds three costs of its own: saying what you want, checking what you got, and keeping control of what is done in your name. A chat window or an agent is one answer to that trade, chosen step by step. It is never where the design starts.

Six rules follow:

1. **Start from the value exchange.** Name what the person gets, what the business earns and the loop that repeats both. Every flow, navigation slot and screen is judged by what it does for that loop. Where the two sides pull apart, design for the person and say what it costs.
2. **Leave the person only what only they can supply:** intent, facts only they hold, preference, judgment and consent. Remembering, looking up, computing, re-entering and finding the way are the product's work, done by a default, by code, or by a model where the input is open-ended.
3. **Design for people and systems as they are.** The empty, late, failed, interrupted and wrong cases are most of real use, so the states and recoveries are the design, not its edge cases.
4. **Delegation is a hand-off, and trust has to track reliability.** Work handed to a colleague or to an agent needs a brief, an acknowledgement, visible progress, a stop, a result with evidence and a way back. People are poor monitors, so safety comes from narrow scope, reversible actions and consent at the irreversible step, never from watching or from approving everything.
5. **Every design choice is a prediction.** Say what will change for whom, by how much and why; test it the cheapest way first; measure it after ship. A law's name, a competitor's screen and "best practice" are not reasons.
6. **Write down what is hard to change.** Once people have learned them, names, navigation, routes, conventions and autonomy levels are one-way doors, and they go in the app doc. A screen is cheap to change and goes in its spec.

Done means a newcomer, person or model, can design any new screen consistently from the doc; the owner can see how the design serves the bet; the analyst knows which events to instrument; and none of them needs the conversation that produced it. Budgets size the record, never the analysis: run every check at any size.

## Route

Route by the request and by what exists: the app doc (default `docs/ux/ux-design.md`; the caller may redirect the `docs/ux/` root) and a shipped product. Sibling skills named here are used if available.

- **A new product, nothing shipped:** steps 1–7.
- **Shipped, no doc:** recover first. Walk the product (browse or qa; else screenshots or code routes) and write the doc as shipped (`State: as-is recovered`): the whole app for a restructure, otherwise what the request touches plus the navigation and role landings around it. Inconsistencies become findings, not fixes.
- **A new multi-screen flow** (a Flow pass: onboarding, checkout, an approval chain, an agent's run): step 1 for the roles, the task and the journey stage it serves; step 2 for its work split; step 3 for any object it adds; step 4 for the flow. Patch §4, the routes and the pending Screens entries, then run screen-design once per screen.
- **One screen**, an AI surface included: screen-design. Without it, step 6 for that screen, first recovering the conventions it touches if no doc records them. With nothing shipped and no doc, frame in a few lines (step 1) and write only that screen.
- **One decision** (tabs or sidebar, dialog or page, chat or form, an object's name, one nav item): the pick, the runner-up, what it gives up and when to revisit, inline in 300 words or fewer, or as a §6 row plus patches to the rows it touches. A new top-level destination goes through step 3.
- **Restructure:** decide whether it is warranted, then run step 3 against the as-is and migrate routes, reversals included (`references/information-architecture.md` § Restructure).
- **An AI feature, assistant or agent:** steps 1–2 decide whether a model takes the work and on which surface. Read `references/ai-feature-ux.md` always, `references/conversation.md` for a chat or voice surface, `references/agents.md` for delegated, background or standing work. What the model may do belongs to ai-architecture.
- **3D, AR, VR or glasses,** even one screen: [Spatial](#spatial).
- **Review, audit, "why do people struggle with X":** `references/review.md`. Read-only unless asked.

**Always.** Patch in place, never regenerate (an older-format doc: convert only the sections you touch and keep its headings). Write only under the UX root. A solution someone asked for, in the request or in an upstream doc, is evidence of a problem, not a decision: design for the problem, record the request as the runner-up in §6 with what it would cost, and report the departure first, so its owner can overrule it knowingly. Upstream docs are input, not constraint: never inherit a choice that fails a role or can cause harm. Screens use the safer answer where it needs no upstream change; otherwise they use a fail-safe fallback and propose the safer answer. Log each conflict in §7 with its owner, the upstream section to change and that fallback; one that can hurt someone is a blocker. Ask once, in step 1 (the only other stop is step 6's gate). A run that cannot ask applies the defaults as `A-nn` assumptions, fail-safe wherever a wrong guess can hurt someone (a human route, narrower autonomy, the manual path), and lists its questions in §7 and in the report.

**Report back** in 200 words or fewer, not the docs. First each departure from what was asked. Then blockers: conflicts that can hurt someone, costly paths left unspecified, a restructure or costly-to-fail flow due to ship before its test passes. Then the files written, pending screens, assumptions and questions, recovery findings, the tests owed, and hand-offs (screen-design, design-system, ai-architecture, product-analytics, web3d). Material findings outrank the limit: none is dropped to fit, each gets one line, and the report says it ran over.

## 1. Frame

**Read first** (defaults; the caller may redirect):
- the PRD (`docs/prd/prd.md`): §2 segment, motion, price hypothesis and job story; §3 the bet; §4 metrics and counter-metrics; §5 the Now release and its features, Later items and their ⚠ arch marks, Never; §6 envelope and duties; and the feature specs (`docs/prd/features/*.md`);
- the architecture: `docs/arch/context.md` (§2 placement, reach and hazard, §4 Ubiquitous Language, §5 C-03 and C-05), `docs/arch/system.md`, ADRs (`docs/arch/adr/`) and AI feature docs (`docs/arch/ai-features/*.md`), noting the UI they oblige (audit, admin or review tools, consent, degraded modes);
- the evidence: funnels and the activation event (`biz/analytics/funnels.md`, `tracking-plan.md`), support themes, the live product, existing `docs/ux/`.

No requirements anywhere: ask where they live, else treat the caller's words as assumptions. A missing architecture doc or tracking plan is a gap to log in §7 with the default you used (online-only with a notice, people's own words for the glossary, event names marked proposed), never a reason to stop.

**Find the problem behind the request** and solve it where it lies (another screen, a message, an upstream choice), or hand it off specified enough to act on. Never trim the problem to fit the request; state any cut, its reason and what people do meanwhile.
- "Add onboarding" → usually an empty first run or an ask before value: map each arrival path to its first value event.
- "Redo the navigation", one role's complaint → check the organizing principle first (navigation built around features, modules or teams instead of each role's top tasks; a role with no home), then objects without a home and labels that don't predict. Check every role and where each lands.
- "Simpler", "a dashboard" → secondary tasks crowd the top one, or nothing shows what needs attention: rank roles × tasks and name each screen's decision.
- "Nobody uses X", "make it engaging" → never seen, unclear, tried and failed, or no value (`references/human-factors.md`). No value is the caller's product question, not a redesign.
- "Build a habit", "add streaks", "a daily push" → a wish for people to come back. Take the cadence from the job (the loop line below): a return trigger carries the value itself or work waiting for this person, on a channel they chose, and a mechanic that brings people back with nothing to do is cut (`references/journey.md` § Value).
- "Add a chatbot", "add AI", "make it agentic" → a named solution. Find the step that costs people most, and what they would have to say, check and trust if a model took it (step 2). Often the answer is a better default, a search that works or one generated field.

**Ask once**, only what the inputs leave open and the output needs. Defaults: platforms, locales, offline use and accessibility duty per the PRD §6 envelope or C-05 (else responsive web with touch and pointer, one LTR locale, online-only with a notice, WCAG 2.2 AA); roles per the PRD (B2B: admin, member, invitee); frequency from the archetype; volume per core object in a heavy account, est.; design system: the platform's own components; regulated flows per the PRD or C-03; what a model may do per its feature doc or the PRD §6 AI line (else it suggests and the person applies every result); conventions as shipped. Test each adopted value against the roles' real context: one that shuts a role out (a language its users need, the device or connectivity of its work, an accessibility need) is a conflict (Always), not a default.

**The value exchange.** Before any structure, write four lines in §1 (`references/journey.md` § Value): the *value* (the progress the person makes, and the event that shows it happened); the *business event* (what the business earns, and how it depends on the value event); the *loop* (what brings the person back, what they do and get, what carries over, at the job's own cadence); and *where they pull apart* (the point where the business could win while the person loses, with its guard). A product whose value event nobody can name has a product question for the caller, not a UX task.

**Roles and top tasks.** List each role × task (invitees, approvers, admins, viewers and people reached only by messages included) with frequency (daily, weekly, rare) and cost of failure (money, data, health or safety, other people, legal). Frequent or costly-to-fail tasks are top tasks. Frequency sets prominence (navigation slots, accelerators, defaults); cost sets depth (safeguards, recovery, validation): a rare, costly task (account recovery, restoring a backup) gets full depth and a findable home, not a nav slot. Where failure can hurt someone, its waiting, unsure and down states offer a person or a safe manual action, faster than the harm develops. *Break when* the PRD names a strategic task with no usage yet: temporary prominence, with a dated revisit.

**Journey.** One row per stage for the primary role, and for another role only the rows that differ: arrive, first value, repeat, pay or commit, return after a gap, leave. Each row gives what the person arrives with, what the product asks of them, the event that shows they got through, a target, and the likeliest loss with the design's answer (`references/journey.md` § Stages). The first three rows decide whether the product is used; the last two decide whether it is trusted.

**Archetype**, by the primary role's top task: occasional transaction, daily workspace, feed, marketplace, admin console, assistant or delegated work, each with a default navigation, density and signature risk (`references/information-architecture.md` § Navigation model). *Break when* the product is a hybrid: the secondary role gets its own home, not an average.

**Done** is measurable per top task ("a new member shares a first project in under 3 minutes, unaided"), tagged target, and tied to the value event or to one of the PRD's §4 metrics. Write the app doc from `templates/ux-design.md`, starting with §1 and its assumption register. A PRD feature or architecture obligation with no task behind it is an open question, never a silent cut.

**Size** follows the PRD's Reach: personal → small, team → standard, external → large (none given: standard); one up, to large at most, for several roles, regulated flows, several platforms or a model that acts. Size sets the doc's budget, never a costly path's depth. A small doc writes the value lines, §4 for the top tasks and first run, and §5's accessibility line; the rest only where the product departs from platform defaults.

## 2. Split the work

List what the person must supply on the path to first value and in each top task (the cost ledger, `references/journey.md`). Then ask of each line who should do it, and take the first rung that is safe, meaning a wrong result cannot happen, or is cheap to notice and undo:

1. **Nobody.** The product does not need it, or not yet: defer an ask until after the value it unlocks, or until the moment it is needed.
2. **A default or a derivation** from what the product already knows (the last answer, the device, the object in view), which the person can change.
3. **Code, by rule:** calculation, validation, sync, scheduling, a reminder. Nothing to check, so prefer it wherever a rule gives the same answer as a model would.
4. **A model,** when the input or the output is open-ended and no rule gives the answer. Something must check it: code where "done" can be checked objectively, otherwise the person. With the person checking, it pays only when saying what they want, waiting, checking the result and fixing the misses cost less than doing the step, at the reliability the model really has for these users. If checking means redoing the work, reshape the output into units that can be checked (a diff, a citation, a filled form), or leave the step with the person.
5. **The person, with help:** an example, a suggestion, completion, a template.
6. **The person alone:** intent, judgment and consent that must be theirs. Consent to anything irreversible, or that reaches other people, stays here however much else is automated.

The ledger is working material. Record its result only: the flow in §4, each step saying who does it, and the totals before and after as a §7 prediction.

**The surface follows the split**, per step, never per product:

| The step is | Surface | Fails when |
|---|---|---|
| A choice among known options, a precise value, a frequent action | Direct controls | The options outgrow what can be shown and scanned |
| An open-ended request, a search across everything, a rare command the person can describe but not find | Language, typed or spoken, with the product's reading shown back as controls the person can correct | The person cannot put it in words; a value is easier to pick than to say |
| Multi-step work with a checkable outcome the person need not watch | An agent run: brief, progress, result (`references/agents.md`) | "Done" cannot be checked; an error is costly and cannot be undone |
| Something the product can anticipate | A suggestion in place, then automation with a ledger, inside an interruption budget | Confidence is low, or it breaks the person's focus |
| News for someone who is elsewhere | A message: email, push, SMS (step 4) | It is late, doubled or never opened, and nothing else catches that |
| Hands or eyes are busy, or the content is speech | Voice (`references/conversation.md` § Voice) | A shared or noisy place; secrets; exact values |
| The decision depends on shape, scale or place | 3D or XR ([Spatial](#spatial)) | The 2D baseline does the job |

Two rules keep a model's work part of the product:
- **Results are objects, not messages.** What a model or agent produces for later use is saved as the product's own object, with a home, a name and its normal actions. The conversation points to it.
- **Language in, controls back.** After a request in words, show what was understood as editable structure (the filters, the filled form, the plan), so that correcting it is a click, not another sentence.

**With an AI feature doc** (default `docs/arch/ai-features/{feature}.md`), present it: its autonomy level per action class, its failure path and its output contract become conventions (§5), flows (approvals, the activity ledger, scope settings: §4) and screen states, per `references/ai-feature-ux.md`. Where that file's harm rules disagree with the doc's routing, they win, as a logged conflict (Always). **Without one**, design the presentation, list the questions for ai-architecture, and keep the surface a pending entry until they are answered. Never invent what the model may do, how often it is right or what data it sees.

## 3. Structure

Per `references/information-architecture.md`: objects first, each with one home and one route; top-level slots are a budget for what people switch between, never features or teams; each role lands on its top tasks and the items waiting for it, counted on navigation; findability is tested on top tasks, never judged by counting clicks. A model's work adds objects like any other (runs, approvals, standing instructions, what it remembers and may reach), and the items waiting for a person include the ones an agent is waiting on. Write §2 and §3.

## 4. Flows

One flow per top task, rare costly ones included, plus a first run per arrival path (self sign-up, invite, admin or SSO provisioning, a link from someone else's assistant) ending at its own first value event ("first invoice sent"). The PRD's motion picks the lead: self-serve, sign-up, with nothing before first value that can wait; sales-led, the admin's setup, then the invitee's first day; internal rollout, the provisioned member's first day. The journey's pay, return and leave rows get a flow where the product has them: a paywall's offer and a cancel flow's save offers belong to pricing, cro and churn-prevention, while this skill places them in the journey and specifies their exits.

Each flow goes in §4 with its release tag, mapped per `references/journey.md` § Mapping a flow, each step saying who does it. Flows break where the work leaves one person's screen: a hand-off to a colleague or to an agent gets an acknowledgement, a timeout and an escalation when nothing comes back, and a hand-back rebuilds what the person stopped following. Messages a flow depends on (email, push, SMS) are steps too, not §5 lines.

## 5. Conventions

State each convention once in §5 (the template lists them), never per screen, from `references/interaction-patterns.md`, `references/ux-writing.md` and `references/ergonomics.md`. Offline behavior per object is the architecture's contract; where it fails a role, log a conflict (Always), with the default fallback: readable, writes disabled with the reason. Accessibility always goes in §5, as requirements and floors for the design-system capability ("text pairs ≥4.5:1"), never as token values. A departure from a platform default, or a trade-off between roles, gets a §6 row.

With a model in the loop, §5 also fixes, once: how people are told it is AI; how each autonomy level looks; where approval is asked and what it shows; the ledger of what was done; stop and undo; what the model can see and remember, and where people change that; and which words are fixed copy and which are generated under rules (`references/ai-feature-ux.md`).

## 6. Screens

**Gate (large docs):** a caller who can answer approves the navigation model and top flows before screens are written; otherwise mark the IA unvalidated in §7. At any size, screens that depend on a §7 prototype test stay pending until it passes.

**Coverage.** Full specs for the first release's critical-path screens, every screen on a costly-to-fail path however rare, and every screen an architecture doc or ADR obliges, plus one exemplar per screen class (collection, record, form, dashboard; conversation, run or generated block where present). Every other screen is a pending Screens entry naming its exemplar and how it deviates. *Break when* the app has 8 screens or fewer, or the caller asks: spec all.

**Write each** (default `docs/ux/screens/{screen}.md`, kebab-case; modals, drawers and sheets in their parent's file) via the screen-design capability, if available, one run per screen (parallel runs return patch lines; apply them); §5 conventions override its defaults. Without it, use its headings only (Job and success, Layout, Fields, States, Interactions, Accessibility, Decisions, Dependencies and open questions), its budgets (simple 600, standard 1,000, complex 1,500 words; +300 per overlay), a layout sketch (regions in task order, ASCII or a list), literal copy for every label, message and state, and the 7 base states in order (empty, loading, loaded, error, partial, refreshing, offline), each specified or `N/A — reason`.

**Element cost:** an element serving no task, role or failure (success, error prevention, trust, recovery, learning) is cut; one serving only a secondary role is demoted; cost and consequence at money, data or permission moments always stay.

## 7. Proof

Each thing the design bets on becomes a §7 row: the assumption or the proposed structure, the prediction (who does what, measured how, from which baseline to which target, and why), the cheapest test that could prove it wrong, and the pass criterion fixed before the test runs (`references/validation.md`). Test the riskiest assumptions, every assumption a costly-to-fail path rests on, and any new structure. After ship, each top task and journey stage gets a signal, a baseline, a threshold and the action it triggers. Never invent participants, quotes or results: a model's guess at what people will do is an assumption.

## Spatial

All 3D/XR UX stays here, even one screen; the web3d capability, if available, implements it.

**Job first:** what does 3D/XR do better than the 2D baseline? Nothing → recommend 2D and stop. Then frame with `templates/spatial.md` §1–2 and its defaults. Done means the job metric beats the baseline, discomfort stays under a stop threshold, and the frame rate holds on the weakest device.

Write one spec per experience from that template (default `docs/ux/screens/{experience}.md`); a 3D surface on an existing screen is a section of that screen's file; patch the route table and Screens group either way; app-wide spatial conventions go to §5. Read `references/3d-design.md` (screens, phone AR) or `references/xr-design.md` (headsets, glasses).

## Self-Review

Against the written files (a small doc: items on sections it skipped don't apply):
- The problem behind the request is solved, or handed off with a spec; each cut says why and what people do meanwhile; conflicts name owner, upstream section and fallback; harm-capable questions default fail-safe and lead Report back as blockers.
- §1 names the value event, the business event, the loop and where they pull apart, with its guard; the journey has an event and a target per row; nothing is asked before the value it unlocks, or a §6 row says why; none of the temptations in `references/journey.md` § Value is in the design.
- Each top task: a measurable success criterion (§1) and a flow with entry points and failure paths (§4); first runs end at a named first value event; hand-offs, to people and to agents, have acknowledgement, timeout and escalation; messages a flow depends on are specified.
- Each step a model takes has a named check and a path without the model; no chat or agent surface where direct controls do the step; results a person will use again are objects with a home.
- Nav items map to objects or frequent top tasks; each role lands on its top tasks and waiting items; one home route per object; deep links cover no access, another account, deleted and moved.
- Every PRD §5 feature and architecture or ADR UI obligation maps to a screen or "no UI"; costly-to-fail paths have full specs; the Screens group matches `docs/ux/screens/` one-to-one, entries tagged by release, pending ones with an exemplar.
- One glossary term per object and status, used everywhere; literal copy; no law names or method notes; each convention once, in §5, with a complete accessibility line; offline behavior matches the architecture or is a logged conflict.
- AI: every failure branch of the feature doc has a state, and harm-capable ones reach a person; people are told it is AI; approval is asked only at irreversible or outward steps; the autonomy level in force is visible; nothing invented about what the model may do.
- Decisions name runner-up, cost and revisit trigger; §7 states each bet as a prediction with a test and a pass criterion (tasks per role, targets, post-ship thresholds); no invented participant data.
- Screens written here: a job, layout sketch and literal copy; one primary action per decision region (none on read-only screens); the 7 base states in order or `N/A — reason`; irreversible actions confirmed naming object and consequence, reversible ones undoable; a single-pointer alternative per drag or gesture.
- Spatial: `templates/spatial.md`'s self-check passes.
- **Footprint:** each file within its template-header budget (screen specs: step 6; Report back 200 words), or over only for a material finding or a costly path, reason given; no empty section.

## Reference files

Read the section a decision touches, not the whole file.

| File | Read when |
|---|---|
| `templates/ux-design.md`, `templates/spatial.md` | Writing or patching the app doc; a spatial spec |
| `references/journey.md` | Step 1 and step 4: value lines, journey stages, the cost ledger, flows, hand-offs, messages |
| `references/information-architecture.md` | Step 3; a restructure; the structural anti-patterns |
| `references/interaction-patterns.md` | Steps 5–6: states, containers, destructive actions, feedback, forms |
| `references/ux-writing.md` | Copy, the glossary, messages |
| `references/ergonomics.md` | Accessibility floors, window sizes, platforms |
| `references/ai-feature-ux.md` | Any model in the loop |
| `references/conversation.md` | A chat, assistant panel or voice surface; the product shown inside someone else's assistant |
| `references/agents.md` | Delegated, background or standing work; agents acting among people; agents as users of the product |
| `references/human-factors.md` | The limits designs rest on; "people struggle with X" |
| `references/validation.md` | Step 7: predictions, tests, sample sizes, post-ship signals |
| `references/review.md` | A review or audit |
| `references/examples.md` | Weak lines next to better ones, for the value lines, the journey, the work split and a prediction |
| `references/landscape.md` | Before citing a platform rule, a law or a product convention: a dated snapshot |
| `references/3d-design.md`, `references/xr-design.md` | Spatial |
