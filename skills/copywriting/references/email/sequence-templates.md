# Email Programs

Pick the program by who enters it and which event ends it. The number of emails follows from the milestones people stall on, never from a template's day count. Every program uses the Default Output Format in `references/email/guide.md`, the single definition of the spec.

| Program | Who enters | Goal event (exit) | Shape |
|---|---|---|---|
| Welcome | A newsletter or list signup with no product account | First click on what was promised | One email now: deliver it and say what comes next and how often; add more only if each has its own job |
| Onboarding | A new product account | Activation | One email per milestone people stall on (below) |
| Trial | A trial account | Paid conversion | Onboarding until activated; three days before the end, a plan if activated, help or an extension if not. Card on file: that email states the amount, the charge date and how to cancel, timed to churn-prevention's notice window, if available |
| Lapsed trial | A trial that ended unpaid: never a customer | Paid conversion or return | One account-status notice to all; then 1-2 marketing emails keyed to how far they got, only to groups whose consent covers them (below) |
| Checkout recovery | Started a checkout or cart, didn't pay | Purchase | 1-2 emails while intent is fresh: a deep link back to the exact cart and the top hesitation answered; an incentive only where the cro capability's recovery rule allows, if available (default: none), never escalating; judged against a no-message holdout. Marketing class: consent, unsubscribe and suppression apply, as for win-back |
| Nurture | A lead without an account (demo request, download) | A sales-qualified action (demo booked, pricing visit) | One email per open question or objection heard in sales calls, tickets or lost deals |
| Re-engagement | A subscribed user gone quiet in the product | Return to the product | Diagnose first (below); 1-2 emails, then the sunset rule |
| Win-back | A cancelled customer | Reactivation | Keyed to the cancel reason (below) |
| Newsletter | Subscribers | Clicks that lead to the goal event | A cadence you can keep; sunset per `references/email/deliverability.md` |

## Onboarding and trial

Send one email for each milestone a user can stall on, fired when that milestone is missed past its typical completion time (your median; default 24 hours for setup, 72 for first value). Its content is the most common blocker at that step and the shortest way past it. Everything exits on the goal event. Add a story or proof email only to answer a named objection from sales calls, tickets or cancel reasons. Break: with no event data, send by day, with a skip condition on every email.

Example, a 14-day B2B trial. E1, now: the first step. E2, no data source connected by 24h: the top blocker plus one-click import. E3, connected but no first report by 72h: the report template most customers start from. E4, on the first report: invite a teammate. E5, three days before the end: choose a plan if activated, help or an extension if not. Everyone exits on payment.

## Branching

Branch only where the next need depends on what the user did, and key every branch on a product event or a click, never an open. Each branch's copy states only what is true for the people in it.

| After | If the recipient… | Next |
|---|---|---|
| A setup or milestone email | finished the step | Skip ahead to the next milestone, or exit on the goal |
| | clicked but didn't finish | The blocker at that step: a fix, a template, or a person offering to help |
| | did nothing for ~48h | A new angle or channel (in-app, a person); never the same email under a new subject |
| A value or proof email | reached the goal event | Exit; expansion or a plan only where they qualify |
| A pricing or offer email | visited pricing, didn't buy | The top objection for that plan; a person for high-value accounts |
| | bought | Exit; receipt and the first step only |
| Any email | unsubscribed, complained, or entered billing or a sales-owned flow | Exit |

Exit early on the goal, on an unsubscribe, or when the person enters a higher-priority program (billing, a sales-owned account).

## Re-engagement

Find out why they went quiet before writing. Never activated → send onboarding's blocker email instead. A periodic job → remind them at the next natural moment, such as month-end close. Switched tools → treat it like win-back. Lead with what changed or what they left unfinished. Offer an incentive only when the reason is price: routine discounts teach people to wait for the next one. No return after 1-2 emails → apply the sunset rule in `references/email/deliverability.md`.

## Lapsed trial

Never-customers, so not win-back: no "we miss you", no returning-customer offer. One account-status notice may go to everyone: the trial ended, what is kept and until when, no pitch. Everything else is marketing and goes only to groups whose consent covers it (`references/email/guide.md`, Frame 4), keyed to how far they got. Never activated → the step they stalled on and the shortest way past it, or a fresh trial if the owner allows one. Activated → what they built and whether it is still there ("Your 3 reports are saved until 30 June" only where retention is real and they have reports). Price was the blocker → a plan that fits, inside pricing's terms; any discount is the owner's call (`references/email/guide.md`, Frame 8).

## Win-back

Win-back starts after churn-prevention's cancellation confirmation (`churn-prevention/references/cancel-flow-patterns.md`), never asks the cancel reason again, and branches on the reason already captured:

- Missing feature or a bug → "what you left over is fixed", sent when the fix ships and only then.
- Price → an offer inside pricing's terms, with no invented deadline.
- Switched to a competitor, or no longer needed → one email when a major release changes the comparison, then stop.
- No reason data → at most 2 emails by day 90, then suppress.

Win-back is marketing mail: consent, unsubscribe and suppression rules apply. Failed-payment recovery is dunning, not win-back (`churn-prevention/references/dunning-playbook.md`).
