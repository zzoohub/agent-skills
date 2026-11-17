# Feature Spec Examples

Weak lines next to better ones, all from one spec: `cancel-and-refill`, in a booking tool for independent yoga and pilates studios. A client cancels from a link in their confirmation text, and the freed spot is offered to the class's waitlist.

## A requirement nobody can test

**Weak:** "REQ-002: The system shall notify waitlisted clients promptly when a spot becomes available."

**Better:**

- **REQ-002** [Must] A freed spot is offered to the waitlist one person at a time, in the order they joined.
  - AC: Given a full class that starts in 5 hours, with Ana then Ben on its waitlist, when a booked client cancels, then within 5 minutes Ana gets a text offering the spot and Ben gets nothing.
  - AC: Given Ana hasn't answered after 20 minutes, when her offer runs out, then Ben gets the offer.
  - AC: Given Ana's offer has run out, when she opens its link and tries to accept, then she is told the spot has gone, no booking is made, and she keeps her place on the waitlist.

"Promptly" and "notify" leave the builder to pick the numbers and the tester with nothing to run. Each AC names its starting state with real values and ends in something a stranger can see. The last is the negative case: a link that was valid a minute ago.

## A decision left open

**Weak:** "Open questions: How long should an offer last? What if two people accept at once? (TBD with engineering.)"

**Better:**

| Decision | Chosen | Rejected (why) | Reversible? |
|---|---|---|---|
| Who gets a freed spot | One offer at a time, 20 minutes each, in joining order | Text everyone and take the first tap: it rewards whoever is on their phone and lets down everyone else who was texted | Yes |
| Offers at night | None between 21:00 and 08:00, studio time; the roster shows the spot open and offers resume at 08:00 | Text at any hour: opt-outs would cost the studio its waitlist | Yes |
| Too late to refill | No offers inside 2 hours of class; the roster shows the spot open for a walk-in (proposed) | Offer until class starts: in the by-hand test no spot offered inside 2 hours was taken (measured: message log) | Yes |
| Delay before an offer | Up to 5 minutes after the cancellation | Instant: nothing in the test suggests minutes matter 2 hours ahead. The thread's "check every 5 minutes" is adopted as what a client would notice | Yes |

- [ ] Do the studios' sign-up forms cover waitlist texts, or only booking confirmations? — blocks: REQ-002 · owner: each studio owner · default if unanswered by the first studio's switch: a client opts in to waitlist texts when joining a waitlist

A builder could build each of these two ways and clients would notice, so the spec chooses and says what it turned down. One offer at a time also removes the race: two people can't accept the same spot. What stays open is a fact only the studios have, and it carries a default so nobody waits.

## HOW in place of WHAT

**Weak:** "A cron job checks for cancellations every 5 minutes and pushes waitlisted users onto a queue; offers are rows with a 20-minute TTL."

**Better:** "An offer goes out within 5 minutes of the cancellation (REQ-002) and lasts 20 minutes (Decisions)."

The spec keeps what a client would notice: how long they wait, and how long they have. The mechanism belongs to whoever builds it.

## The people nobody listed

**Weak:** one journey: "The client cancels. The next person on the waitlist gets a text and books."

**Better** adds everyone else the change reaches:

- **The owner,** before class: opens the roster and sees who cancelled, who took the spot and which offer is still out. She can give an open spot to a walk-in, which withdraws the offer and tells that client the spot has gone.
- **A client holding an old link:** opens an offer that has run out, sees that the spot has gone, and keeps their place.
- **A client on the waitlist who no longer wants the class:** declines from the offer text, and the offer moves on at once instead of waiting 20 minutes.

## Existing data, forgotten

**Weak:** "Rollout: enable for all studios at launch."

**Better:** "Existing records: each class's paper waitlist is entered in its paper order the Friday before the studio switches, and the owner checks it. Clients entered from paper never agreed to waitlist texts, so they get none until they opt in at their next booking; the roster shows the owner who hasn't. In flight: a cancellation texted to the owner after the switch is entered by her on the roster, which frees the spot the same way. Do now: the Friday before, tell clients the link replaces texting the owner. Rollout: per studio, on its switch date. Off switch: per studio; when off, a cancellation opens the spot on the roster and nobody is texted."

The weak line assumes the feature starts in an empty world. People were already on waitlists and already cancelling by text, and what happens to them is a product decision.

## An outcome nobody can measure

**Weak:** "Success: clients love the waitlist and adoption is high."

**Better:** "Outcome: share of spots freed 2+ hours before class that someone else takes before it starts · baseline 60% by hand (measured: 41 of 68, the brief's test) · target ≥50% with automatic offers by the week-6 checkpoint (target: the PRD's leading metric) · guardrail: clients opting out of waitlist texts ≤5% a month · measured by `spot_freed` and `spot_taken` (not tracked yet: REQ-007) · if missed: read the offers that ran out, by hour of day, before changing the window."
