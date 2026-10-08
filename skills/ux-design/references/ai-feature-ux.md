# AI Feature UX

How people see, steer, check and recover from an AI feature. Its architecture lives in the feature doc (default `docs/arch/ai-features/{feature}.md`; caller may redirect), written by the software-architecture capability's AI Feature Mode: what the model may do, its limits, its failure handling, its data. This file decides the presentation. A state the doc doesn't define is an open question for its owner, never an invention here; until it is answered, the screens show the safe route (the manual path, a person).

## Frame first

- **The check.** What does the user verify, and how (the doc's §1)? Checking the output must cost less than doing the task. If it doesn't, redesign the output into checkable units (citations, diffs, intermediate steps) before designing any chrome.
- **A manual path.** The task stays possible without the AI: when it is down, refuses, or the user opts out. Segments the model is unproven on (a language, a user group, an input type the doc's §6 evaluation doesn't cover) take the manual path by default until evaluated.
- **Harm.** Where a wrong, late or missing answer can hurt someone (health, physical safety, money, legal standing), every waiting, unsure and down state shows a route to a person, or a safe manual action (the manual procedure, an emergency line), that works faster than the harm develops, not a queue with no time bound. A doc that routes these otherwise, or sizes escalation below that, is a conflict to log with its owner (SKILL.md, Always); the screens use the safe route meanwhile.
- **Disclosure.** Say people are dealing with AI at first contact unless that is obvious, and label generated or altered media. Legal duties vary (the EU AI Act's Article 50, for example); the doc's §7 records them, and they are confirmed at ship time.

## Autonomy, as users see it

The doc's §2 sets a level per action class. Present each:

| Level | What the user sees |
|---|---|
| Suggest | A draft to apply, edit or discard; nothing changes until they apply it |
| Approve | The exact action (what, where, whom it affects, reversible or not), editable, approved or rejected; approvals expire, and a pending one shows whom it waits on |
| Oversee | A live activity ledger and a one-step Stop that halts at the current step |
| Audit | A ledger to review afterwards, with per-action revert where the action allows it |
| Autonomous | A ledger, and the scope (actions, data) visible and changeable in settings |

Show approvals as parameters, not the model's prose, and only where the doc requires them: a stream of approvals trains people to click through.

## Failure path → states

Give each branch of the doc's §5 failure path, and each termination reason in its §4 output contract, a designed state:

| Branch | State |
|---|---|
| Wrong | Per-claim grounding (below); edit, regenerate, "report a problem" |
| Unsure | Abstain: say what is missing and the next step ("No refund policy in these documents. Upload it, or ask support"); a hand-off to a person shows who picks it up and by when, and on a harm-capable path is offered at once (Frame first) |
| Down | Feature off: the manual path, stated plainly; when to try again, if known; on a harm-capable path the human route leads, not a retry |
| Attacked (an action blocked) | Name the blocked action and why, without echoing injected text; offer the manual path |
| Runaway (a limit hit) | Which limit, when it resets, what still works; queue or a smaller model only if the doc allows |
| Stopped halfway | What completed and what didn't; resume, or undo per completed step |
| Truncated (§4) | Keep the partial output, marked incomplete, with Continue |
| Refused (§4) | Show the refusal and a way to rephrase or take the manual path; never "Unknown error" |
| Nothing retrieved | Say so rather than answer ungrounded; offer to rephrase or widen the sources |

**On-device features** (the doc's §2 placement): design each availability state the architecture lists (unsupported, disabled, downloading with size and progress, ready, busy, quota exhausted, evicted mid-session, input too long, unsupported language), each saying what still works and what the user can do.

## Generation

- Stop cancels on the server, not just the stream; the doc's partial-output policy decides what is kept, and partial output survives a failure.
- Continue after a cut-off re-prompts with the partial text and can leave a seam, so don't promise seamless resumption.
- People can steer during generation or right after Stop without losing the partial output; editing a prompt and regenerating is one action; earlier versions stay reachable.

## Grounding and trust

- Cite per claim, not per answer: mark which statements come from sources and which are the model's, and link each to its passage.
- Check that a cited passage supports its claim (the doc's §4 output contract may do this); let people flag "doesn't match".
- When sources conflict, show the conflict instead of silently picking one.
- Answers from an index show its freshness ("Indexed 2 days ago"): a stale index gives confidently wrong answers.
- Show confidence only from signals the doc has calibrated (grounding coverage, a verifier, agreement across samples); an uncalibrated score never appears as confidence, and the model's own hedges stay visible.
- High-stakes answers (money, health, legal) get a "why might this be wrong" affordance beside the route to a person (Frame first).

## Agents and actions

- Show what the agent is doing as it happens (searching, reading a file, calling a service) and keep it as the activity ledger: each action with its parameters and result.
- Show cost or quota before a long run wherever people pay per use.

## First use

Capabilities and limits on one screen or less; sample prompts or starting points people can click; what data the model sees and where it goes, as the doc states.

## Accessibility

- While a response streams, set `aria-busy` on it so screen readers don't read fragments; announce "Generating" and "Response ready" in a separate polite status region; let people jump to the finished response.
- Stop is a real button in the tab order; offer a non-streaming mode that shows the full response at once.
- Confidence and citation markers never rely on color alone; disclosure labels are text that assistive technology reads.
