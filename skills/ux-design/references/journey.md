# Value and Journey

From the product's value to the paths people take: the value exchange, the people and their context, the stages of the journey, what each step costs the person, and the flows that carry them (SKILL.md steps 1 and 4). Worked examples: `examples.md`.

## Value

Four lines open §1 of the app doc. Take them from the PRD (default `docs/prd/prd.md` §2–§4) and the tracking plan, and write what is unknown as unknown.

| Line | Says | Passes when |
|---|---|---|
| Value | The progress one role makes in one situation, and the **value event** that shows it happened | Someone could see it in the product's data. "Saves time" fails; "a freed spot is taken by someone on the waitlist" passes |
| Business event | What the business earns and when: a payment, a renewal, a seat, a transaction | It says how the money depends on the value event: per event, after some number of them, or regardless |
| Loop | What brings the person back, what they do, what they get, and what carries over to next time | The cadence is the job's, read from how often the situation recurs, never an engagement target |
| Where they pull apart | The point where the business can win while the person loses | It has a guard: a counter-metric with a floor (the PRD's §4), or a rule in §5 |

When the value event takes a whole cycle to arrive (a month end, a delivery), first value is the earliest moment the person sees real progress on their own data, named as its own event. A two-sided product writes the lines per side and says which side must exist first. A product whose value event nobody can name has a product question, not a UX one: return it to the caller.

**What carries over is the honest lock-in.** People stay because their records, their setup and what the product has learned about their work make the next round cheaper. Staying because leaving is hard is the other kind, and it ends in refunds, complaints and regulators.

**Where business and person pull apart**, and the side the design takes:

| The business is tempted to | The person pays with | Design instead |
|---|---|---|
| Ask before value: an account, a card, permissions, a long profile | Effort on credit, with nothing seen yet | Each ask sits after the value it unlocks (§ Stages, First value) |
| Make getting out harder than getting in | Money and trust | Every commitment has an exit as easy to find and finish as its entry, confirmed through a channel that survives it |
| Set defaults that serve itself: preselected extras, consent, renewal terms | Money or data they did not choose to give | The default is what an informed person would pick; consent and paid extras are never preselected |
| Invent pressure: false scarcity, countdowns, shaming the "no" | A decision they regret | Only real limits are stated, and both answers get equal weight |
| Farm attention: endless feeds, autoplay, streaks, notifications that carry nothing | Time, with no progress on the job | A return trigger carries the value itself or work that waits for this person; the job's cadence sets how often |
| Lean on a model's human-likeness: affection, flattery, guilt at leaving, a sponsor hidden in an answer | Misplaced trust, and for some people real harm | The assistant says it is AI, claims no feelings, disagrees when the person is wrong, and marks paid placement (`ai-feature-ux.md` § Trust) |

Most rows are also a legal exposure in several markets; the dated rules are in `landscape.md`. Cancel flows and renewal notices for subscriptions belong to the churn-prevention capability, if available; live-funnel optimization to cro.

## People and context

For each role's top tasks, learn from the PRD, support data, analytics or the live product, else record an A-nn assumption: the trigger (a notification, a deadline, a habit, a shared link; each entry point arrives with different context); the setting (device, input, connectivity, language, interruptions); time pressure and what is at stake if the task fails; first-time or daily use; and their words for things, the raw material of the glossary.

- **Job story** per top task, naming no feature; reuse the PRD's §2 job story where it fits.
- **Role card**, instead of a persona: the role, its top tasks with frequency and cost of failure, context of use, permissions, its words, and the evidence behind each line ([Observed], [Said] or [Assumed]). No invented names, photos or quotes.
- Several roles are normal (approval flows, marketplaces, B2B admins and members): give each its own top tasks rather than merging them. People reached only by a message, and people the product records without an account, are roles too.
- An AI agent acting for a person is not a role. It is a way that role's work gets done (SKILL.md step 2). Another party's assistant that operates the product for its user is a caller with that user's rights (`agents.md` § Agents as users of the product).
- Research that needs participants (interviews, card sorts, tree tests, usability tests) goes into the validation plan as a hypothesis with a method. Never invent participant data, quotes or findings.

## Stages

The journey table in §1 has one row per stage for the primary role; another role gets only the rows that differ. Each row records what the person arrives with, what the product asks of them, the event that shows they got through, a target, and the likeliest loss with the design's answer.

| Stage | The person is asking | Usual loss | Design lever |
|---|---|---|---|
| Arrive | Is this what I was promised, and is it for me? | The first screen describes the product instead of continuing what brought them; a wall before anything is shown | Carry the promise through: the words of the ad, invite, shared link or assistant's answer that sent them, the object they came for, and the first step, all visible on arrival |
| First value | What do I do, and will it be worth it? | Setup before value; an empty first screen; an ask too early | The shortest path to the value event: a ledger of its costs (below), asks moved behind value, a sample or their own imported data instead of a blank |
| Repeat | Where was I, and what needs me now? | Hunting for the place; nothing says what changed; re-entering what the product already knows | Land on the items waiting for this person; resume where they left; accelerators on the frequent path; triggers that carry the value |
| Pay or commit | Is it worth this, and can I get out? | The price or the terms appear late; the ask outruns the value seen so far | The ask follows a value event; total cost, renewal and what cannot be undone sit beside the commit; the exit is stated before the commitment |
| Return after a gap | What happened while I was away? | A dead session, stale data, a changed interface, a second onboarding | Say what changed since the last visit, restore their place, refresh before showing, never teach again what they knew |
| Leave | Can I take my things, and is it really over? | No export; a cancellation that needs a call; silence afterwards | Export and deletion are flows; a confirmation that outlives the account says what was kept, what was deleted and when |

*Break when* the motion is sales-led: the admin's journey (set up, invite, see adoption) runs first, and a member's "arrive" is an invitation they did not ask for, so it must say who sent it and why. *Break when* it is an internal rollout: there is no pay row, and "leave" is the old tool being switched off (the PRD's Transition line). *Break when* the product is two-sided: the side that must exist first gets the first journey.

**Triggers.** A person comes back because the job recurs and they think of the product, because something reaches them (a message, a calendar entry, a colleague's link), or because the product's output arrives where they already are (a report in the inbox, a text). Name the trigger of each loop. A loop whose only trigger is a promotional push is not a loop.

**Targets** come from the PRD's §4 where it has them (the leading metric is usually the first-value or repeat row), else from the as-is, else they are tagged target with the reason for the bar. The events are handed to the product-analytics capability, if available, to instrument; where no tracking plan exists yet, name the event you propose and mark it proposed.

## Cost ledger

The path to first value, and each top task, is a list of things the person must supply. Write it before designing a screen:

| Step | The person supplies | Kind | After the ladder |
|---|---|---|---|

Kind is one of: intent · a fact only they hold · a fact the product could know · a choice · a check · consent · a wait · a switch to another app or device. Take every line down the ladder in SKILL.md step 2: remove it, defer it past value, default or derive it, give it to code, give it to a model with a check, help the person, or leave it with them. Facts the product could know, waits and switches are the first to go.

The totals before and after (steps, inputs, asks, waits, switches) are the design's first prediction, and time to first value is its headline number. For a frequent expert task, estimate keying time instead (`validation.md` § Cheapest test first).

## Mapping a flow

1. **Entry points:** every way in (navigation, deep link, notification, email, search, invite, another assistant); each arrives needing its context.
2. **Steps:** per step, who does it (the person, code or a model, per the ledger), the decision the person makes and the information it needs. Move what can run in the background (saving, processing) out of the person's path.
3. **Asking for input:** minimize decisions and inputs, not screens. One question per page for long, rare, branching or high-stakes forms; one page for short, familiar ones (sign-in, an address) or when answers must be compared side by side. Ask when people have the information at hand, and say up front what they will need to fetch. Offer save and resume for anything people may not finish in one sitting. *Break when* regulation fixes the order and the disclosures.
4. **Value before the ask:** defer sign-up, payment and OS permissions until people have seen what they unlock; request a permission right after the action that needs it, since the system prompt can't simply be shown again. *Break when* setting up the workspace is the value (B2B), or compliance gates entry.
5. **Decisions:** recommend a default, and say what happens if the person doesn't decide (the default applies, or the flow waits).
6. **Guidance, by frequency:** daily tools optimize for expert speed and teach through empty states and hints; rare tasks optimize for first-time success with examples and defaults. *Break when* it is a daily tool's first week: a path to the first value event, then guidance that fades.
7. **Unhappy paths that change structure:** no access, pending approval, plan limit, conflict, a failed background job, a model that refuses, abstains or is down. Branch the flow for them now; write their copy later.
8. **Hand-offs** (below) and **messages outside the app** (below) are steps of the flow, not notes on it.
9. **Exit and resume:** back never loses input; leaving midway saves or warns; returning lands where the person left off. Every commitment (a subscription, consent, sharing, an integration, a standing instruction to an agent) has an exit as easy to find and finish as its entry.

## Hand-offs

Flows break where the work leaves one person's screen. For each hand-off between people (approve, invite, assign, escalate), specify:

- what notifies the next person, and where its link lands;
- what the waiting person sees meanwhile ("Waiting for Dana's approval, sent Monday");
- acknowledgement, so the sender knows it arrived;
- what happens when nobody responds: a reminder, then escalation to a named fallback (a deputy, the owner, a staffed line) after a stated time, with the item held or expired meanwhile, proceeding by default only where that is safe;
- how the originator learns the outcome.

Where waiting can hurt someone, the timeout is shorter than the harm takes and the escalation reaches a person.

**A hand-off to an agent follows the same list** (`agents.md`): the brief is the notice, the agent's restated plan is the acknowledgement, the run's status is what the waiting person sees, a stuck or over-budget run asks and then escalates on a timeout, and the result arrives with its evidence. A hand-off from an agent back to a person (it needs a decision, it failed, the person took over) has to rebuild what the person stopped following: the goal, what is done, the state now and the one thing needed.

## Messages outside the app

Email, push, SMS and chat messages that a flow depends on are screens under harder constraints. A message may arrive late, twice or never; it is read on a lock screen, a shared device or another account; its link lands on the object in the state described, through sign-in, and never acts by itself: mail scanners and link previews open links, so an action link opens a screen that confirms the action. Spec the trigger, the recipient, the content (`ux-writing.md` § Messages), the landing, and what happens if it is never acted on. Check the channel's current length, consent and opt-out rules where you rely on them.
