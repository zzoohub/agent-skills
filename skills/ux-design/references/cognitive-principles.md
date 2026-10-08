# Cognitive Principles

Diagnosing why people struggle: start from the observed symptom, list the causes that compete to explain it, and run the check that tells them apart. A law's name is never the diagnosis or the justification; the user's behavior and the evidence are.

## Symptom → causes → check

| Symptom | Competing causes | Check that separates them |
|---|---|---|
| Can't find X | The label doesn't predict X; X lives where users don't look; it's hidden by role, plan or state; the navigation follows the product's features or teams rather than this role's tasks | First clicks or a tree test on the task; search terms vs labels; the roles and plans of the users who fail; map each role's top tasks onto the navigation: one task spread over several sections is the structure, not the label |
| Work stalls between people | The next person was never told, or the message landed out of context; no reminder, timeout or escalation; the recipient can't act (access, device, sign-in) | Delivery and open rates of the notice; time in the waiting state, per item; who the stalled items wait on |
| Drop-off at step N | It asks for information not at hand; cost or commitment shows up late; validation errors; the step is slow; the offer or its copy (live signup, paywall or checkout: the cro capability, if available) | What step N asks for and when users learn it; per-field error rate; time on the step |
| Feature unused | Never seen; seen but unclear; tried and failed; no value for them | The exposure → first use → repeat use funnel; no value is a product question, not a UX fix |
| Repeated input errors | An ambiguous format; a bad default; it asks people to recall something | Errors per field: add an example or accept more formats; change the default; offer a pick list |
| Double submits, rage clicks | No feedback within about 0.1 s; a slow action with no pending state | Press and pending states; with the architecture, make the submit idempotent |
| Hesitation at a choice | Unfamiliar, unordered options; no recommended default; unclear consequences | Recordings at the choice; which option wins; ask what people expected to happen |
| Bad memory of a smooth flow | One painful moment, or a poor ending | Find the worst step and the last screen; fix those first |

## Mechanisms and their limits

- **Choice and recall:** choice time grows with unfamiliar, unordered options, yet a familiar ordered list (countries) scans fast at any length, and menus are recognized, not recalled, so no working-memory limit caps their length. Group and recommend a default; never hide options people need.
- **Conventions:** standard tasks use platform patterns. *Break when* a custom pattern measurably wins for daily experts (keyboard-first tools); record the decision.
- **Endings and resumption:** a flow is remembered by its most intense moment and its end, so end on the user's accomplishment, not an upsell. Save partial progress and offer "continue where you left off"; never fake progress.

## When principles conflict

Bigger targets versus fewer elements, standing out versus convention: the principle that protects the critical-path action of the top task on that screen wins. Apply the losing principle to everything off that path, and record the trade-off as a decision, so that a later redesign doesn't "fix" it backwards.
