# Human Factors

The limits a design rests on, what is known about people working with automation, how to find why people struggle, and which popular rules do not hold. Use it two ways: as constraints while designing, and as competing causes while diagnosing. In an app doc or a review, state the behavior and the evidence. A law's name is never the diagnosis or the reason.

## What does not change

| Limit | What is known | Design consequence | It does not say |
|---|---|---|---|
| Response time | About 0.1 s feels instant, about 1 s keeps the train of thought, about 10 s is where attention leaves. These are rules of thumb, not measured constants. On the web, an interaction that paints within 200 ms at the 75th percentile is rated good, above 500 ms poor | Every press shows its pressed state at once; under a second, no spinner; past ten seconds, progress with Cancel, or move the work to the background and notify | That streamed text is finished. First words arriving fast is a progress signal; the wait that counts is to the usable result |
| Working memory | About four items held at once, and only while nothing interrupts | Never make people carry a value between screens; put what must be compared side by side; show the choice instead of asking for it from memory | A cap on visible lists. Menus are scanned, not memorized, and broad ordered menus beat deep narrow ones |
| Recognition over recall | Picking from what is shown is easier than producing it | Visible options, recent items, examples in place. An empty prompt box is recall: give starting points | |
| Pointing | Time to hit a target grows with its distance and shrinks with its size | Frequent and critical targets large and near; destructive ones apart | Whether it is the right target. It says nothing about choosing or reading |
| Choosing | Time to choose grows slowly with the number of equally likely, already known options | Order and group options; recommend a default | That fewer options are faster. An unordered list is scanned line by line, a familiar ordered one (countries) fast at any length, and "too much choice" hurts only when options are hard to compare and the person's preference is unclear |
| Reading | People scan, and attention is front-loaded: in one eye-tracking study 57% of viewing time went above the fold and 74% to the first two screens | Lead with the answer; labels and headings carry the meaning; nothing essential lives in a paragraph of instructions | That people don't scroll. They do, when the top says it is worth it |
| Attention | One task at a time. A person who is interrupted often returns only after doing something else | Interrupt only for what needs this person now; keep state so that resuming costs nothing | A fixed number of minutes lost per interruption |
| Watching | Sustained attention to something that rarely changes fails within about half an hour | Never make "watch it and catch the rare problem" a person's job: alert, sample, or gate the consequential step | |
| Errors | Slips (the right intention, the wrong action) and mistakes (the wrong intention) are routine, with different cures | Slips: constraints, undo, a confirmation only at the irreversible step. Mistakes: a clearer picture of what will happen, shown before the commit | |
| Defaults | The preselected option is kept far more often than chance, by an amount that varies widely from one setting to another | The default is the design's strongest lever and its heaviest responsibility: set it to what an informed person would choose | A predictable effect size. Test it |

## People and automation

Decades of work on pilots, operators and clinicians apply unchanged to a product whose model or agent does part of the job.

| Finding | Design consequence |
|---|---|
| Automating a task leaves the person the parts nobody could automate plus the job of watching the automation: harder work, done with fading skill | Design the take-over first. The path without the model stays usable, and is used often enough to stay known |
| People over-rely on automation that is usually right, experts as much as novices, and warnings or training change little | A label saying the output may be wrong is not a safeguard. Make the check cheap and part of the flow, and gate the consequence |
| The more the system does, the better routine work goes and the worse people cope when it fails, because they have stopped following what it does | A hand-back rebuilds the picture: the goal, what is done, the state now, the one thing needed |
| Reliance is appropriate when trust matches what the system can really do | Show what was done and what it rests on; let people meet the limits early; never signal more certainty than was measured |
| People are surprised by what automation does in a mode they did not know was on | The autonomy level in force is always visible, changes only by an explicit act, and is logged |

## Symptom → causes → check

Start from the observed symptom, list the causes that compete to explain it, and run the check that tells them apart.

| Symptom | Competing causes | Check that separates them |
|---|---|---|
| Can't find X | The label doesn't predict X; X lives where people don't look; it's hidden by role, plan or state; the navigation follows the product's features or teams rather than this role's tasks | First clicks or a tree test on the task; search terms against labels; the roles and plans of the people who fail; map each role's top tasks onto the navigation: one task spread over several sections is the structure, not the label |
| Leaves before first value | The first screen doesn't continue what brought them; an ask comes before anything is shown; the first run is empty; the first step needs something they don't have at hand | The arrival source against the first screen's words; where in the ledger the first ask sits; what the first screen shows a brand-new account |
| Work stalls between people | The next person was never told, or the message landed out of context; no reminder, timeout or escalation; the recipient can't act (access, device, sign-in) | Delivery and open rates of the notice; time in the waiting state, per item; who the stalled items wait on |
| Drop-off at step N | It asks for information not at hand; cost or commitment shows up late; validation errors; the step is slow; the offer or its copy (live signup, paywall or checkout: the cro capability, if available) | What step N asks for and when people learn it; per-field error rate; time on the step |
| Feature unused | Never seen; seen but unclear; tried and failed; no value for them | The exposure → first use → repeat use funnel; no value is a product question, not a UX fix |
| An AI feature unused | Nothing shows what it can do; its first results were wrong; checking costs more than doing; it sits apart from the work | What the first three results were for people who stopped; time from result to accept; where it sits relative to the object it serves |
| Results accepted unread; approvals clicked through | Checking is costly; approvals are frequent and look alike; the consequence isn't shown | Time between result and accept; the share approved unchanged; errors found later |
| A request retyped in other words; a conversation left after a turn or two | The product's reading of the request isn't shown; the only way to correct is to type again; the answer buries the result | The rephrase rate; where in the answer people stop; what they do next (search, leave) |
| People do by hand what an agent could do | They can't see what it will touch; nothing can be undone; one failure they remember | Ask what they feared; show scope and undo before a run and compare uptake |
| Repeated input errors | An ambiguous format; a bad default; it asks people to recall something | Errors per field: add an example or accept more formats; change the default; offer a pick list |
| Double submits, rage clicks | No feedback within about 0.1 s; a slow action with no pending state | Press and pending states; with the architecture, make the submit idempotent |
| Hesitation at a choice | Unfamiliar, unordered options; no recommended default; unclear consequences | Recordings at the choice; which option wins; ask what people expected to happen |
| Bad memory of a smooth flow | One painful moment, or a poor ending | Find the worst step and the last screen; fix those first |

## Rules of thumb that do not hold

Each is repeated widely and fails when checked. None is a reason in a design or a finding in a review.

- **"Everything within three clicks."** A test of it found no relation between the number of clicks and success, and almost nobody gave up after three. What predicts success is whether each label says what lies behind it.
- **"Seven items at most in a menu."** The memory limit applies to what must be held in mind, not to what is on screen.
- **"People don't scroll."** See Reading above.
- **"Five users are enough."** Enough to find the problems most people hit, in repeated rounds. Not enough to measure anything (`validation.md` § Small samples).
- **"A habit takes 21 days."** The one careful study found a median of 66 days and a range from 18 to 254, longer for anything effortful. Take the cadence from the job, never from a streak.
- **"Losses weigh twice as much as gains."** It depends on the stakes: clear for meaningful amounts, weak or absent for small ones.
- **"Nudges work."** Their pooled effect shrinks to nearly nothing once unpublished failures are accounted for. Some do work, so test each; none replaces removing a cost.
- **"A progress bar with a head start gets completed."** The evidence is from paper loyalty cards. Show progress that is real.
- **"A shorter time to first value raises retention."** Only the correlation is established, and motivated people both reach value early and stay. Treat a shorter path as a prediction and test it (the product-analytics capability's encouragement test, if available).
- **"Tours and tooltips onboard people."** No controlled evidence, and people skip them. A first screen that works without explanation is the alternative.

## When principles conflict

Bigger targets against fewer elements, standing out against convention: the principle that protects the critical-path action of the top task on that screen wins. Apply the losing principle to everything off that path, and record the trade-off as a decision, so that a later redesign doesn't "fix" it backwards.

Standard tasks use platform patterns. *Break when* a custom pattern measurably wins for daily experts (keyboard-first tools): record the decision. A flow is remembered by its hardest moment and its end, so end on what the person accomplished, not on an upsell; save partial progress and offer "continue where you left off"; never fake progress.

## Sources

Checked 2026-11-18. Response-time limits: Nielsen 1993, after Miller 1968 and Card et al. 1991; web.dev on Interaction to Next Paint. Memory and menus: Cowan 2001; Larson and Czerwinski 1998. Scrolling: NN/g 2018 (120 participants). Watching, take-over, over-reliance, modes: Bainbridge 1983; Parasuraman and Manzey 2010; Endsley and Kiris 1995; Onnasch et al. 2014; Lee and See 2004; Sarter and Woods 1995. Defaults: Jachimowicz et al. 2019 (58 studies). Choice: Scheibehenne et al. 2010; Chernev et al. 2015. Nudges: Mertens et al. 2022 and the reanalysis by Maier et al. 2022. Three clicks: Porter 2003. Habits: Lally et al. 2010. Loss aversion: Zeif and Yechiam 2022. Loyalty cards: Kivetz et al. 2006; Nunes and Drèze 2006.
