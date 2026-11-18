# Agents

Work a person hands to an agent: several steps, tools, often out of sight, sometimes on a standing basis. Read `ai-feature-ux.md` first. What the agent may do, and at which autonomy level, is the feature doc's decision (the ai-architecture capability); this file designs how a person hands the work over, follows it, judges it and takes it back.

## When to delegate

Delegate a piece of work when its outcome can be checked without redoing it, when a wrong step is cheap to see and undo or is caught by a check the agent cannot edit, and when the person gains nothing by watching. Keep it with the person when "done" has no test, when one mistake is costly and permanent, or when their judgment at each step is the value.

The bar is the way people do the work today, counting the time they spend briefing and reviewing. A run that saves an hour of doing and costs an hour of checking has moved the work, not removed it.

## The run is a hand-off

The rules for handing work to a colleague apply unchanged (`journey.md` § Hand-offs). Each stage answers something the person needs:

| Stage | The person needs | Design |
|---|---|---|
| Brief | To say it once | The goal, the limits, what it may touch and what "done" means, taken from context before asking, and shown back as a structure they can edit |
| Plan | To catch a wrong reading before it costs time | For a long or consequential run: the plan, editable, with the autonomy level for this run chosen at the moment of approval. Skip it for short, reversible work |
| Run | To know it is working, and on what, without watching | Status in meaningful steps (done, doing, next) and what it touched, never a stream of tokens; a live view where one exists |
| Check-in | To be asked only when it matters | A question when it is blocked, with what it tried and the options as choices. The item waits in the same queue as the person's other work, with a reminder and a timeout |
| Result | To judge it quickly | The outcome first, as objects (a draft, a diff, links); then the evidence (checks run, sources used), what it could not do, what it assumed, and the next step |
| Review | To spend attention where it matters | Changes ordered by risk; a summary that opens into detail; a sample for bulk work |
| Undo | A way back | Per action where possible, a checkpoint to return to, and a plain list of what cannot be undone |

On hard tasks a well-built agent stops to ask more often than its user interrupts it. Its questions are the main channel of oversight, so design them as carefully as any form: one decision each, the options visible, the consequence of each stated.

## Stop, steer, take over

Watching is not the safeguard (`human-factors.md` § People and automation). In one large product, people with experience let the agent run unprompted about twice as often as newcomers and also interrupted it nearly twice as often: oversight moves from approving each step to following and stepping in. So:

- **Stop is always in view, takes one step and works at the current step.** It then says what was completed, what was not, and what state things are in.
- **A correction can be added while it runs,** without stopping it, and the interface says when it will be taken up.
- **Taking over is one control** wherever the agent drives an interface, and handing back is one more. Sign-in, payment details and other secrets are entered by the person or supplied by a vault; the agent never sees them.
- **A hand-back from the agent rebuilds the picture:** the goal, what is done, the state now, and the one thing needed. The person stopped following a while ago.

## Out of sight

- A run that outlasts the person's patience continues in the background. They can leave, and are told when it needs them or has finished, in the channel where they already work.
- **One list of runs, ordered by what needs the person:** waiting for you, failed, running, done. Each run has its own page with the brief, the status, the ledger of actions and the result.
- Notify for "needs you", "failed" and "done". Everything else goes to the run's page.

## A result the person answers for

- Below the autonomous level, the agent's output lands as something the person promotes: a draft message, an unpublished change, an order awaiting confirmation. Promotion is the consent.
- Where the organization requires a second person on consequential work, an agent does not replace them: the one who asked is not the only check.
- A ledger shows what was done. It does not replace judging the result, and the interface should not suggest that it does.

## What cannot be undone

A checkpoint covers what the product controls. It does not cover what has left it: a message sent, a payment made, a change in another system. Say which is which before the run starts, show what "undo" will restore, and keep the outward actions on the list that always asks (`ai-feature-ux.md` § Autonomy, as people see it).

## What it may reach

- **Scope is shown before the run and in settings:** the data it reads, the tools it can use, its limits on spend and time.
- **A grant is an object** with a giver, a purpose and an end. It is asked for at the moment of need, in steps (this once, for this run, always for this place), listed in one place, revocable and expiring. A grant wider than the task is a design failure.
- A standing permission for something consequential is confirmed again after long disuse and when the surrounding facts change (a new payee, a new audience).

## Standing work

A schedule, a trigger or a rule is an object the person owns: "when X, do Y, within Z", with its history, a pause, and a notice when it fails or has stopped doing anything.

Proactive work that has lasted in products is work the person set up and can steer. An assistant deciding by itself what to show each day has not held (`landscape.md`). For anything unrequested: a suggestion before an action, a visible reason ("because you asked last Monday"), a dismissal that teaches it, a cap on how often, and an off switch.

## Agents among people

Where agents act in a shared workspace, the conventions are still forming (`landscape.md`). The parts that follow from first principles:

- An agent has its own identity, marked as AI, and an accountable person shown beside what it does ("by the billing agent, for Dana").
- It never has more access than that person.
- Its comments, assignments and changes appear in history like anyone's, and can be told apart from the person's own.
- People address it where they work and can see whether it is running, waiting or off.

## Agents as users of the product

Other people's assistants now operate products for their users, through functions a product declares or by driving its interface. As of the snapshot in `landscape.md` this is a small and fast-growing share of sessions, and most people want help choosing, not unattended buying. Build the floor below and widen it on evidence.

- **Sort every action:** read-only, a write that can be undone, or consequential. Offer the first two to assistants as functions. Mark the third so that the assistant asks its user, and give it a "start" variant that lands the person on the product's own screen to finish.
- **Keep the product's own confirmation** at the consequential step, in words that stand alone, because the person may arrive with no conversation behind them. Recompute the state at confirmation and reject a stale plan.
- **Sign-in, accepting terms, creating an account and the final payment are where assistants hand control back.** Make each a clear, separate step with a state an agent can recognize and wait on.
- **What makes an interface workable for an agent is what makes it accessible:** native controls, visible labels, full keyboard operation, real buttons for "load more", nothing hover-only, no canvas-only widget on a path where something is bought or changed.
- **Manipulative patterns catch agents too,** in tests the more capable ones more often, and the person who delegated blames the product. Pop-ups, consent banners and bot challenges are where agents stall: expect a hand-back there, and keep a challenge off the first step of a flow you want delegated.
- **Report success only when the state changed,** and show it on screen so both the agent and its user can confirm. Mark what an agent did in the account's history apart from what the person did.
- Someone arriving from an assistant has already stated what they want: continue from there (`conversation.md` § Inside someone else's assistant).

The function contract itself (types, idempotency, identity of the caller) belongs to the architecture (`ai-architecture`'s interop reference, if available).

## Test and measure

Rehearse the run with a person playing the agent, including the branches where it is stuck, wrong, and stopped halfway, before any of it is built (`validation.md`). After ship, beside the signals in `ai-feature-ux.md` § Measure: runs finished without a check-in, time spent reviewing a result, interventions per run, undo after acceptance, runs abandoned, and standing instructions paused or deleted.
