# Design Process

Methods behind framing (SKILL.md Stage 0) and flows (Stage 2): learning the context of use, writing jobs and role cards, mapping a flow, and planning validation.

## Context of use

For each role's top tasks, learn from the PRD, support data, analytics or the live product, else record an A-nn assumption: the trigger (a notification, a deadline, a habit, a shared link; each entry point arrives with different context); the setting (device, input, connectivity, language, interruptions); time pressure and what is at stake if the task fails; first-time or daily use; and their words for things, the raw material of the glossary.

## Jobs and role cards

- **Job story** per top task, naming no feature; reuse the PRD's §2 job story where it fits.
- **Role card**, instead of a persona: the role, its top tasks with frequency and cost of failure, context of use, permissions, its words, and the evidence behind each line ([Observed], [Said] or [Assumed]). No invented names, photos or quotes.
- Several roles are normal (approval flows, marketplaces, B2B admins and members): give each its own top tasks rather than merging them.
- Research that needs participants (interviews, card sorts, tree tests, usability tests) goes into the validation plan as a hypothesis with a method. Never invent participant data, quotes or findings.

## Mapping a flow

1. **Entry points:** every way in (navigation, deep link, notification, email, search, invite); each arrives needing its context.
2. **Steps:** per step, the decision the user makes and the information it needs. Move what can run in the background (saving, processing) out of the user's path.
3. **Asking for input:** minimize decisions and inputs, not screens. One question per page for long, rare, branching or high-stakes forms; one page for short, familiar ones (sign-in, an address) or when answers must be compared side by side. Ask when people have the information at hand, and say up front what they will need to fetch. Offer save and resume for anything people may not finish in one sitting. *Break when* regulation fixes the order and the disclosures.
4. **Value before the ask:** defer signup, payment and OS permissions until people have seen what they unlock; request a permission right after the action that needs it, since the system prompt can't simply be shown again. *Break when* setting up the workspace is the value (B2B), or compliance gates entry.
5. **Decisions:** recommend a default, and say what happens if the user doesn't decide (the default applies, or the flow waits).
6. **Guidance, by frequency:** daily tools optimize for expert speed and teach through empty states and hints; rare tasks optimize for first-time success with examples and defaults. *Break when* it is a daily tool's first week: a path to the first-value event, then guidance that fades.
7. **Unhappy paths that change structure:** no access, pending approval, plan limit, conflict, a failed background job. Branch the flow for them now; write their copy later.
8. **Hand-offs between people** (approve, invite, assign, escalate): what notifies the next person and where its link lands; what the waiting person sees meanwhile ("Waiting for Dana's approval, sent Monday"); acknowledgement, so the sender knows it arrived; what happens when nobody responds: a reminder, then escalation to a named fallback (a deputy, the owner, a staffed line) after a stated time, with the item held or expired meanwhile, proceeding by default only where that is safe; and how the originator learns the outcome. Where waiting can hurt someone, the timeout is shorter than the harm takes and the escalation reaches a person.
9. **Messages outside the app** (email, push, SMS, chat): each one a flow depends on is a screen under harder constraints. It may arrive late, twice or never; it is read on a lock screen, a shared device or another account; its link lands on the object in the state described, through sign-in, and never acts by itself: mail scanners and link previews open links, so an action link opens a screen that confirms the action. Spec trigger, recipient, content (`ux-writing.md` § Messages), landing and what happens if it is never acted on; check the channel's current length, consent and opt-out rules where you rely on them.
10. **Exit and resume:** back never loses input; leaving midway saves or warns; returning lands where the user left off. Every commitment (a subscription, consent, sharing, an integration) has an exit as easy to find and finish as its entry.

## Validation plan

Test what the design bets on: the riskiest assumptions in the register, every assumption a costly-to-fail path rests on, and the proposed structure itself. A new IA, a restructure or a review's proposed fix is a hypothesis until it beats the as-is on the same tasks.

- **Tasks** per role, from its job stories: the top tasks plus the rare costly ones, set as situations in users' words, never the interface's labels ("You need last quarter's signed contract for tomorrow's audit", not "Open Documents").
- **Targets** per task: success against §1's criteria, plus first-click success or directness; time where speed is the job. Take the bar from the as-is result on the same task where one exists, else from stakes (`information-architecture.md` § Validate).

| Question | Method | Pass criterion |
|---|---|---|
| Can people find it, and do the groups match how they think? | Tree test, first-click test, card sort (`information-architecture.md` § Validate) | The task targets |
| Can people complete the flow? | Moderated usability test: about 5 participants per role per round, thinking aloud, unhelped; note first clicks, hesitations and backtracks; fix and repeat; more when a missed problem is costly | Each role's top-task success without help |
| Do people understand, and want, a new interaction? | Before full specs: a clickable prototype of the top task's happy path plus one failure, tested as above; screens that depend on it stay pending | Unaided completion; people explain it in their own words and pick it over their current way |

**After ship**, per top task: the signal that the design is failing (completion or the funnel step; time on task against the baseline; searches or back-tracks right after a navigation click; support tickets on the theme; hand-offs that time out), its baseline, the threshold that triggers action, and the action (iterate, pause the rollout, investigate). Thresholds come from the baseline or §1's criteria, never from generic benchmarks; measure via the product-analytics capability, if available, alongside the PRD's §4 metric.

Rate test findings with the severity scale in SKILL.md (Review / Diagnose Mode).
