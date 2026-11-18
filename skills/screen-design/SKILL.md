---
name: screen-design
description: |
  Design or redesign one in-product screen (page, form, dashboard, modal,
  sheet) or one AI surface (chat panel, agent run view, generated block) on
  an existing app, with or without its UX doc: every reachable state and
  interaction, functional copy only, in docs/ux/screens/{screen}.md. Use
  for: "design the X screen", "redesign the X page", "spec the X modal",
  "fix the X form", "spec the chat panel"; one run per screen. Do NOT use
  for: a new product or new multi-screen flow, app-wide IA, UX review or
  3D/XR (ux-design); marketing-site pages (copywriting; cro to optimize);
  form completion or conversion diagnosis (cro); styling, tokens or motion
  (design-system).
---

# Screen Design

## Premise

**A screen spec is a behavior contract for its builder and tester, not a picture.** A builder can draw a screen from one sentence. What nobody can guess is what it does when the data is empty, the request fails, the person has no access, two people edit at once, or a model returns something wrong. A picture shows one state, and people spend most of their time in the others. So the spec's job is every state a person can reach and every control's result, in the words they will read, each row something a tester can trigger.

Five rules follow:

1. **One screen, one job.** Name the decision the person makes here and what follows from it. The layout serves that decision in the order the task needs, and what serves no task, role or failure is cut.
2. **Ask only for what only the person has.** Every field and choice is dropped, deferred, defaulted or derived before it is asked.
3. **The states are the design.** The seven base states, then every state the data, the writes, the roles and a model's failures make reachable, each with literal copy, a way out and a trigger.
4. **A consequence is shown before the commit, true to the record, and leaves proof after it.**
5. **Fixed words are written out; generated words are specified as behavior.** A model's output is a range, so the spec gives its shape, limits and examples, never one sample.

Done means a builder can build it and a tester can test it without asking, and the docs around it still agree.

## Route and read

- **App UX doc** (default `docs/ux/ux-design.md`; caller may redirect the `docs/ux/` root): read what this screen touches: the value event and journey stage it serves, users and frequency, objects (statuses, roles × actions), glossary, routes, flows, conventions.
- **Shipped UI, no doc**: recover only the conventions this screen must honor, each [Assumed], citing where seen.
- **Neither**: ask the caller for an app-level UX pass (e.g. `ux-design`); failing that, use §1's defaults and propose the conventions you set.

Read the brief (feature spec, default `docs/prd/features/{feature}.md`; a CRO or UX-review finding; or the caller's words), the current spec and built screen, a pending entry's exemplar, the architecture and AI feature docs (default `docs/arch/`), and all evidence offered, in full, before scoping. With no feature spec, the caller's words and the app doc's flow are the brief: say so in the header and list the acceptance criteria you had to assume as open questions. Never write a feature spec here.

**A brief that contradicts the app doc.** A convention that guards a person (consent, an action that always asks, a legal duty, a route to a human) holds: spec the safe behavior, meet the brief's goal another way where you can, and return the contradiction as a conflict for its owner. Any other convention the requester may change, on every surface it covers (§5), never on this screen alone.

**Scope is the user's job.** Where it fails or needs a control next to this screen (on arrival, in what opens here, in what follows), spec that here or in a second spec, never on an unspecced surface; any cut says why and what the user does meanwhile. A message the screen depends on (the email or push that brings the person here, or tells them the outcome) counts: give its trigger, recipient, words and landing. Top-level navigation goes to ux-design (via that capability, if available) as a proposal; causes outside the product, to their owner with evidence, change and expected effect.

## 1. Frame the problem

Run all of §1 on every request. A small change (one control or region, no new write, source or role) writes only what changes (unspecced screen: plus the 7 base rows, the rest marked not yet specified), and one line per material finding beyond it.

- **Requested solution**: design for the problem behind it and report the reframe (setting → better default; tooltip or tour → clearer label or empty state; "add AI here" → the step that costs the person most, and whether a default, a rule or a model should take it).
- **Job**: the situation, the user's decision here, the outcome, and who else it reaches (recipients, approvers, support); 1-3 success criteria, each observable or a number tagged measured, est., target or unknown.
- **First questions**, one batch, only those whose answer changes the spec; unanswered, apply the default as [Assumed] unless the app doc or PRD sets it, and list the question under Dependencies and open questions:
  - *Arrival*: each entry path, its share and the context it brings (default: the app doc's flows, navigation dominant).
  - *Device*: the PRD's platforms, laid out from the narrowest supported window (web: 320 CSS px), not a device model.
  - *Next*: where success, cancel and failure land.
  - *Users and data*: occasional, one role (daily experts: density, shortcuts, bulk actions); typical data sets the hierarchy, extremes (0, 1, max, longest translated string, missing fields) what the layout must survive.
- **Redesign: find the lever first.** What fails, for whom, with evidence ([Observed], [Said], or [Assumed] plus its test), and what must not regress. Split the outcome by entry path and step (share × loss per case: failures, delay or cost; from the given data, else est.); design for the largest lever, wherever it sits, stating the share of the outcome this screen moves. Polishing an easy segment is not a redesign.
- **Classify each region**:

| Region | Leads | Breaks on |
|---|---|---|
| Collection | Content; Create leads only when empty or the top task | Filtered to nothing; next page fails; live inserts; select-all scope; partial batch failure |
| Record | The next action its status allows | Deleted; no permission; edited elsewhere |
| Form, flow step, settings | The commit verb (none if autosaved) | Invalid input; double submit; server reject; facts changed since shown; timeout; unsaved exit; back loses input; OS permission denied |
| Dashboard | Anomalies, each metric against a baseline | Stale data; no data vs zero; one widget failing; updates mid-interaction |
| Overlay (short task returning here) | The decision verb (or undo instead) | Esc, back, scrim; focus return; double activation; reload loses it |
| Conversation (an input and its transcript) | The input and the latest result; starting points when empty | A misread request; a reply stopped, cut off or refused; a source or tool failing mid-reply; a second request while one runs; a long thread; context the model cannot see |
| Run (delegated work, in progress or finished) | What needs the person now, then status, then the result | Waiting unanswered; stopped halfway; over its limit; some steps failed; the person changed the same thing meanwhile; reopened long after |
| Generated block (a summary, draft or filled field inside another region) | The output with its source and its actions | Wrong; nothing to draw on; too long or short for its space; refused; slow; the record changed since; the person edited it |

## 2. Decide

Defaults; app UX doc conventions override them. When rules collide, protect the critical-path action.

- **Inputs**: take each field and choice down this ladder and stop at the first rung that is safe: drop it; defer it to the moment it is needed; default it to the most common safe choice; derive it from what the product knows, shown and editable; let a model fill it for the person to check; ask. What is asked says why when the reason isn't obvious.
- **Save**: autosave independent, reversible changes; explicit Save when fields validate together or have consequences, with a leave guard. *Break*: drafts autosave; Publish or Send stays explicit.
- **Commits with consequences** (money, sends, deletes, access, anything others see or can't undo). Reversible: act at once, undo outliving its toast, no confirmation. Irreversible or wide-reaching: confirm on outcome-labeled buttons naming object and consequence ("Delete 3 files" / "Keep files", focus on Keep), and:
  - *Facts from the record*: when the decision step opens, fetch from the server what the consequence and its warnings depend on, not this client's cache or device; a failed or timed-out fetch blocks the commit with the reason and Retry.
  - *Submit*: unavailable only in flight or until the facts load, never for validation; one idempotent submission; no success before the server confirms.
  - *Proof that lasts*: a reference, a history entry, a receipt through a channel the action doesn't cut (a closed account can't sign in: email it); never only a toast.
  - *Many at once*: a bulk commit confirms once for the set, never again per item: the count, each item a line that can be taken out, ordered by what most needs a look, and the consequence. Items whose facts changed since they were shown are removed and named. A failed check removes that item, not the batch, unless the items depend on each other.
- **Errors by class**: invalid → inline on leaving a typed-in field (empty required: on submit), cleared once valid; failed submit → input kept, first invalid field focused; rule rejected (card declined, slot taken) → the rule and nearest valid option; session expired → sign in again, input kept; forbidden → who grants access; not found → its own state; conflict → both versions, reload or merge; network, 5xx or timeout → content kept, retry if safe, else how to check the outcome.
- **Backend needs** (undo, live updates, offline writes, idempotency, fresh reads, history, receipts, a server-side stop for generation): read the architecture; each missing one is a Dependencies row with owner and the screen's behavior until it lands (default: only the writes needing it disabled, saying why; no undo: confirm; no live updates: refresh on return).

Depth, if available, in the ux-design skill's `references/`: `interaction-patterns.md` (save, forms, unavailable actions), `ux-writing.md` (errors, empty states, words about AI), `ergonomics.md` (accessibility floors, placement), `journey.md` (entry paths, hand-offs), `human-factors.md` (diagnosis).

## 3. A model on the screen

For a conversation, a run or a generated block. Read the feature doc (default `docs/arch/ai-features/{feature}.md`; caller may redirect) before writing states. A state it doesn't define is a Dependencies row for its owner, and until it is answered the screen shows the path without the model. Never invent what the model may do, how often it is right or what it can see.

- **States from the doc.** One row per failure branch (its §5: wrong, unsure, down, an action blocked, a limit hit, stopped halfway) and per termination reason (its §4: complete, cut off, refused), plus generating, stopped by the person and nothing to draw on. Partial output is kept in every one of them.
- **Told and marked.** The fixed words that say it is AI, where the person first meets it on this screen, in the app doc's wording where it has one; a visible word on generated content, never an icon alone. People the output reaches outside the product (whoever receives a drafted email, the other party on a call) are told too, in fixed words that code adds.
- **The check.** For each output, what the person looks at to judge it (the source passage, the diff, the filled fields) and where that sits. If it isn't on this screen, the output isn't ready to be acted on.
- **Autonomy.** The level in force for each action here (the doc's §2) is shown. Each action that asks shows its approval as parameters (who, what, how much, reversible or not), not the model's prose; many of them are asked as one set (§2, Many at once). No approval for what can be undone: give it Undo.
- **Without it.** Each task on the screen has its path with the model off, refused or declined.
- **Generated output** is specified as behavior: what it contains and in what order; its length range and what the layout does at both ends; what it must never contain; the fixed copy around it; its actions (apply, edit, retry, discard, back to the generated version after an edit); and two or three example exchanges, good and bad. The examples go to the feature doc's owner as eval cases.
- **While it streams**, the layout holds still, the view follows the newest line only while the person is at the bottom, and Stop is a real button that cancels the work, not just the display.
- **A voice-only surface** is specified in turns: what the system says (fixed copy, or behavior with examples), what the person may say, and what happens on silence, on not understanding and on interruption. Exact values are confirmed before anything acts on them.

Depth, if available, in the ux-design skill's `references/`: `ai-feature-ux.md` (always), `conversation.md` (chat and voice), `agents.md` (runs, approvals, standing work).

## 4. Write the spec

One spec (default `docs/ux/screens/{screen}.md`; caller may redirect), kebab-case; overlays go in their parent's file with only their own states and interactions. Redesign: patch in place (old format: convert only what you touch); date changed Decisions rows with their evidence; list spec-vs-built mismatches, never silently resolved.

```markdown
# {Screen} [{version tag, if the PRD defines buckets}]
Route; entries, each with share (measured, est. or unknown) and context → exits (success, cancel, failure); users and frequency; platforms; Brief: {link}; [Assumed]: {defaults}

<!-- Budget sizes the record, never the analysis. By decision load, tables included: simple (read-only or one reversible write; one role) ≤600 words; standard ≤1,000; complex (several writes or roles; irreversible, paid, regulated or AI actions) ≤1,500; +300 per overlay, mode, pane or model-written output. Over: cut restated conventions (base rows cite them), then split into linked child specs ({screen}-{part}.md); never cut the lever, commit safeguards, a control's behavior, accessibility or a material finding. Sections are a menu (omit empty ones, heading too), except States, Interactions, Accessibility. Tables for enumerations, one short sentence per cell; sequences and anything longer as numbered steps. -->

## Job and success
{The decision made here, what follows from it, and 1-3 success criteria. Redesign: the lever with numbers, success criteria set on it; what must not regress.}

## Layout
{Regions in task order, not schema order, each with its decision and what leads; what each entry path sees first. Frequent elements visible; rare but consequential ones a labeled step away; rare minor ones cut, saying why. Cost, who is affected and what can't be undone stay beside the commit at every width. Per-width changes; design-system components.}

## Fields
| Field | Label, hint | Input, default, autofill | Rule | Error copy |
{Only what survived the Inputs ladder. Default: the most common safe choice; never preselected consent or paid extras.}

## States
| State | Trigger | User sees (literal copy) | Actions | Exit / recovery |
{The 7 base rows first, in order: empty, loading, loaded, error, partial, refreshing, offline; a row may cite the app convention plus what this screen keeps and blocks; N/A — {reason} only when the trigger cannot occur (refreshing: whenever shown data can change). Derived rows: each Breaks-on case not in Interactions; per object status: display and allowed actions; per source: empty kinds, stale, unknown (a dash and why, never 0); per write: pending, success and where the user lands, failure by class, timeout, conflict; per role; session expiry; per model: the rows of §3. Same-failure cases share a row. Never blank content already shown.}

## Interactions
| Trigger | Result and feedback | On failure (→ States row) | Focus after |
{Every control and gesture, with feedback (pressed, pending, done). A consequential commit as numbered steps: open (facts fetched), decide, submit, each outcome with its proof, focus.}

## Generated output
| Output | Contains, in order | Length | Never | Shown with (fixed copy, source, mark) | Actions |
{One row per thing a model writes here, then two or three example exchanges, good and bad, each tagged as an eval case for the feature doc.}

## Accessibility
{This screen only, over the app baseline (else WCAG 2.2 AA): headings; icon-only control names; custom-widget keys; changes announced without moving focus (a streamed reply: "Generating", then "Response ready"); focus clear of sticky bars; text for charts and color-coded status.}

## Decisions
| Decision | Runner-up | Why | Revisit when |

## Dependencies and open questions
| Question, dependency or conflict | Owner | Blocks | Default until answered |
```

## 5. Keep the docs consistent

Then patch, minimally, every doc this spec makes stale:
- **New spec file** (second and child specs too): its pending Screens entry becomes the link (tag kept), else a link in a **Screens** group at the contents' end (created if absent), never a numbered section or renumbering; a new route or nav entry gets its row.
- **A convention** asked for, or changed here for an app-wide reason: edit each surface it covers (conventions line, decisions row, sibling specs relying on it); a one-screen exception stays a Decisions row here.
- **Existing entries** (a question answered here, a pending row): resolve in place; one this spec meets but does not settle stays as written, with this spec added to what it blocks; never reorder, rename or reformat others'.
- **PRD, architecture and AI feature docs, or in a parallel batch any doc but your spec (second specs too)**: never write; return the patch lines, and log a conflict, convention change or step another run owns as a Dependencies row.

## Self-Review

Against the written files and their diffs:

- Job: each brief acceptance criterion a row or open question; a redesign changes the lever's segment, with numbers.
- Inputs: every field asked is one only the person can supply; nothing asked before the value it unlocks; no preselected consent or paid extra.
- States: base rows in order, each N/A impossible, not merely unlikely; derived rows per status, source, write, role, Breaks-on case and model failure branch.
- Every control: result, feedback, failure and recovery by class (timeout included), focus-after, a trigger a tester can create; none hover- or gesture-only or on an unspecced surface.
- Commits: consequences beside the commit, true to what the system does (timing, retention, exceptions); facts fetched on open, a failed fetch blocks; conditions keyed to the record; proof beyond a toast.
- A model: told it is AI, recipients outside the product included; a check on this screen for every output; a path without it; approvals only at irreversible or outward steps, as parameters; generated output specified as behavior with examples, fixed copy written out; nothing invented about what the model does.
- One primary action per decision region (a list's toolbar and each row are separate regions; exclusive, equally likely outcomes like Approve / Reject: equal weight, set apart); data extremes placed at the narrowest width and largest text size (web: 200%).
- Numbers and quantity words ("most") traced to the given data or tagged est.
- Docs agree: routes, glossary terms and conventions match the app doc, or a Decisions row records the deviation; conflicts, backend needs and hand-offs have owners and defaults; the report claims only edits in the diffs.
- **Footprint**: within its tier or split into child specs; nothing on the never-cut list cut; no empty section.

## Report back

Not the spec, ≤150 words: next actions first, numbered, each with owner and when; then one line per flag (reframe, where the lever is handled, conflicts, backend needs, blocking questions, risky assumptions, spec-vs-built mismatches); files written last, cut first. Patch lines follow in full, outside the count.
