# Validation

How a design bet is stated, tested and measured (SKILL.md step 7). A design is a set of predictions about what people will do. This file is about finding out early and cheaply which of them are wrong.

## A prediction, not an opinion

Each §7 row reads: **if** [the design choice], **then** [role] will [observable behavior], measured as [metric] moving from [baseline] to [target] in [sample or period], **because** [mechanism]. **Wrong if** [the result that would change the design].

- The mechanism is the reason the choice should work: a cost removed, a question answered earlier, an error made impossible. If the only reason is that other products do it, the row is an assumption.
- Grade evidence as the PRD does, strongest first: [Observed] behavior in analytics, recordings, tests or tickets; [Said] an account of a specific past instance; [Assumed] the rest, future intent included. A review adds *Walked*: you ran the task in the product yourself, which shows what the interface does, not what people do with it.
- Numbers say where they come from: (measured: source) · (est.: inputs → arithmetic) · (target: why this bar) · (unknown → measure by [milestone]).
- The pass criterion is fixed before the test runs. A threshold moved after the data is a new test.
- **Never invent participants, quotes or results.** A model asked to play a user produces assumptions, however fluent: useful for drafting test tasks and hypotheses, never recorded as an observation.

What to test: the riskiest assumptions in the register, every assumption a costly-to-fail path rests on, and any proposed structure. A new IA, a restructure or a review's proposed fix is a hypothesis until it beats the as-is on the same tasks.

## Cheapest test first

| When | Question | Method | Reads as |
|---|---|---|---|
| Before anyone is asked | Is the path shorter? Does every state have an answer? | The cost ledger's totals before and after (`journey.md`); each role walked through each flow, state by state; a keying-time estimate for a frequent expert task (below) | est. |
| From evidence already there | Where do people fail today? | Funnels, search logs, support themes, recordings | Observed |
| On a sketch | Do people see what this is, and where to go? | A five-second look, then "what is this and what would you do?"; a first-click test on a mock; a tree test on the navigation's text alone (`information-architecture.md` § Validate) | Observed, small sample |
| On a prototype | Can people complete it? Do they understand a new interaction? | A moderated test: about five people per role per round, thinking aloud, unhelped; note first clicks, hesitations and backtracks; fix and repeat | Problems found, not a rate |
| With a model in the loop | Is the behavior useful, before it is built? | A person plays the model behind the interface, or the real model answers seed tasks in a bare harness; read every transcript | Problems found; the seed tasks become the feature's first eval cases |
| In real use | Did the number move? | A staged release against a threshold; a controlled experiment through the cro capability, if available | Measured |

Screens that depend on a prototype test stay pending until it passes.

**Before anyone is asked.** For a task done many times a day by practiced people, add up the operators: a keystroke or tap about 0.2 s, pointing at a target about 1.1 s, moving a hand between keyboard and pointer about 0.4 s, and a mental step before each decision about 1.35 s. The sum ranks two designs for an expert. It says nothing about a newcomer, about errors or about whether the task is the right one.

## Tasks and targets

- **Tasks** per role, from its job stories: the top tasks plus the rare costly ones, set as situations in the person's words, never the interface's labels ("You need last quarter's signed contract for tomorrow's audit", not "Open Documents").
- **Targets** per task: success against §1's criteria, plus first-click success or directness; time where speed is the job. Take the bar from the as-is result on the same task where one exists, else from the stakes.

## Small samples

- About five people per role find the problems most people will hit. They do not measure how many people hit them. Report "4 of 5, and the fifth stopped at the address step", never "80%".
- A rate needs a sample and an interval. Four successes in five gives a 95% interval of roughly 36% to 98%. A rate you intend to quote needs dozens of people, and a comparison between two designs needs more.
- When the units are few (six studios, three teams), count them and set the rule in counts ("at least 4 of 6"). Never pool them into a rate.
- Compare with the as-is on the same tasks. A benchmark from other products does not transfer: their tasks, users and definitions differ.
- More people when a missed problem is costly: a costly-to-fail path, or users who differ from each other in a way that matters (a screen-reader user, a first-time user, the most restricted role).

## After ship

Per top task and per journey stage: the signal that the design is failing, its baseline, the threshold that triggers action, and the action (iterate, pause the rollout, investigate).

| Signal | Says |
|---|---|
| Completion of the task or the funnel step; time to first value | The path works, or where it stops |
| Time on task against the baseline | Friction, once completion is stable |
| A search or a back-step right after a navigation click | The label did not predict what was behind it |
| Support contacts on the theme | People could not recover by themselves |
| Hand-offs that time out; items waiting past their limit | The next person was not reached, or cannot act |
| The counter-metric: refunds, opt-outs, cancellations soon after a commit | The number moved at the person's expense |

A model in the loop adds its own signals (`ai-feature-ux.md` § Measure). Thresholds come from the baseline or §1's criteria, never from generic benchmarks. Measure through the product-analytics capability, if available, alongside the PRD's §4 metric. Rate test findings with the severity scale in `review.md`.
