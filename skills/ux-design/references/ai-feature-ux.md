# AI Feature UX

How people direct, see, check and recover from anything a model does in the product: a generated field, a summary, an assistant, an agent. Read it for every AI surface; `conversation.md` adds chat and voice, `agents.md` adds delegated work.

The feature's architecture lives in its feature doc (default `docs/arch/ai-features/{feature}.md`; caller may redirect), written by the ai-architecture capability: what the model may do, its limits, its failure handling, its data. This file decides the presentation. A state the doc doesn't define is an open question for its owner, never an invention here; until it is answered, the screens show the safe route (the manual path, a person).

## The trade

A model on a step takes work off the person and hands back three costs: saying what they want, checking what they got, and staying in control of what is done for them. The step is worth giving to a model when

> say + wait + check + (how often it is wrong × the cost of noticing and fixing) + (how often a wrong result slips through × the harm)

comes to less than doing the step. Estimate each term for the real users and the model's measured reliability on their inputs (the feature doc's §6), not for a demo.

- **Lower the cost of saying:** take intent from context (the object in view, the selection, the last action) before asking for words; offer starting points; show the reading back as controls (SKILL.md step 2).
- **Lower the cost of checking:** shape the output so that checking is a glance. A diff instead of a rewritten document, the source excerpt beside the claim, a filled form instead of a paragraph, three options instead of one.
- **When checking still costs as much as doing,** the step is not ready for a model. An agent that does not beat the way people work today is not ready to ship.
- **Where the skill is the point** (learning, a decision the person must own), help without replacing: explain, question, critique. In a controlled study, people who learned a tool with AI help scored markedly lower on a later test of it than those who learned without.

## Frame first

- **A manual path.** The task stays possible without the model: when it is down, refuses, or the person opts out. Segments the model is unproven on (a language, a user group, an input type the doc's §6 evaluation doesn't cover) take the manual path by default until evaluated.
- **Harm.** Where a wrong, late or missing answer can hurt someone (health, physical safety, money, legal standing), every waiting, unsure and down state shows a route to a person, or a safe manual action (the manual procedure, an emergency line), that works faster than the harm develops, not a queue with no time bound. A doc that routes these otherwise, or sizes escalation below that, is a conflict to log with its owner (SKILL.md, Always); the screens use the safe route meanwhile.
- **Disclosure.** Say it is AI at the first interaction, on the surface itself, not in terms or settings; label generated or altered media where it appears, with a mark that needs no hover or tap; answer truthfully when asked. People the model's output reaches outside the product (whoever receives a message it wrote, the other party on a call) are told as well, in fixed words that code adds. Several jurisdictions now require this (`landscape.md`); the doc's §7 records the duties that apply.

## Autonomy, as people see it

The doc's §2 sets a level per action class. Present each:

| Level | What the person sees |
|---|---|
| Suggest | A draft to apply, edit or discard; nothing changes until they apply it |
| Approve | The exact action (what, where, whom it affects, reversible or not), editable, approved or rejected; approvals expire, and a pending one shows whom it waits on |
| Oversee | A live activity ledger and a one-step Stop that halts at the current step |
| Audit | A ledger to review afterwards, with per-action revert where the action allows it |
| Autonomous | A ledger, and the scope (actions, data) visible and changeable in settings |

- **The level in force is named and always visible** where the work happens, and changing it is one explicit act that the ledger records. People are surprised by what a system does in a mode they did not know was on.
- **A short, fixed list of actions asks every time, at every level:** paying or committing money, permanent deletion, entering credentials or granting access, sending or publishing to other people, and changing its own permissions. Take the list from the doc; where it is missing, this is the default and a question for its owner.
- **When those actions come many at a time, ask once for the set:** a list ordered by what most needs a look (a new recipient, an unusual amount, and a draft the model was unsure of where a calibrated signal says so), each line removable, one confirmation. Twenty identical prompts teach the same clicking through as two hundred.
- **Everything else gets boundaries and a cheap stop, not a prompt.** People approve nearly every prompt they are shown (93% in one large product's data), so a stream of approvals trains clicking through. Outside that list, an approval that is granted nearly every time carries no information: remove it, or raise its threshold. On the list, a high approval rate is a reason to make the check cheaper and better ordered, never to drop the ask.
- **Show an approval as parameters,** not the model's prose: the recipient, the amount, the file, the diff. The person approves what will happen, not a description of it.
- **A rule typed into a conversation is not a control.** "Don't touch production" or "read-only for now" has to be a mode the system enforces and displays, or the interface must say it cannot promise it.

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

**On-device features** (the doc's §2 placement): design each availability state the architecture lists (unsupported, disabled, downloading with size and progress, ready, busy, quota exhausted, evicted mid-session, input too long, unsupported language), each saying what still works and what the person can do.

## Generation

- Stop cancels on the server, not just the stream; the doc's partial-output policy decides what is kept, and partial output survives a failure.
- Continue after a cut-off re-prompts with the partial text and can leave a seam, so don't promise seamless resumption.
- People can steer during generation or right after Stop without losing the partial output; editing a request and regenerating is one action; earlier versions stay reachable.
- Every result can be dismissed, retried and reverted from where it appears. After the person edits generated content, the generated version stays one step away.
- While text streams, the layout holds still: follow the newest line only while the person is at the bottom, and stop following the moment they scroll.
- Show what is happening in specific words ("Reading 14 invoices"), not a generic spinner. For text, a few honest seconds of work cost little; silence costs more.

## Trust

Reliance is right when it matches what the model can really do. The interface moves it in both directions.

- **Cite per claim, with the evidence in view.** Mark which statements come from sources and which are the model's, and show the supporting passage beside the claim or one tap away. A bare link is not a check: in one large measurement, people opened a source cited in an AI summary on about 1 visit in 100.
- **An explanation earns its place only by making the check cheaper.** Explanations raise acceptance whether or not the answer is right, and longer ones raise confidence without raising accuracy. Point to the source span or the changed lines; do not justify.
- Check that a cited passage supports its claim (the doc's §4 output contract may do this); let people flag "doesn't match". When sources conflict, show the conflict instead of silently picking one. Answers from an index show its freshness ("Indexed 2 days ago").
- **Uncertainty in plain first-person words** ("I'm not sure, but…") lowers over-reliance where an impersonal disclaimer does not. Use it only where a calibrated signal says the answer is shaky (the doc decides which signal). An uncalibrated score never appears as confidence, and a standing "AI can make mistakes" line protects nobody.
- **On a costly decision, have the person commit first:** they give their own answer or pick the option before the model's is shown. It cuts over-reliance and people dislike it, so keep it for high stakes (money, health, legal) and put the route to a person beside it (Frame first).
- **No flattery, no pretended feelings, no person.** An assistant that agrees with everything is rated higher and leaves people worse off: more sure they are right, less willing to mend a conflict. It disagrees when the person is wrong, never claims emotions or a human identity, and marks paid placement. A thumbs-up rate rewards agreeableness, so it is feedback for the team, never the target a personality is tuned to.

## Fixed words and generated words

A spec can state literally only the words the product controls: labels, states, the disclosure, the refusal and failure messages, the confirmation. These are fixed copy and are written out (`ux-writing.md`).

What the model writes is specified as behavior: what an answer contains and in what order, its length range, what it must never do, and two or three example exchanges, good and bad. Hand those examples to the feature doc's owner as eval cases (its §6); a behavior that no eval checks is a hope. Anything that must be said exactly (a legal notice, a price, a medical warning) is fixed copy inserted by code, never left to the model.

## What it sees and remembers

- **Context is visible.** Show what the model is working from right now (the open record, the attached files, the connected sources), and let the person add or remove items. People otherwise assume it sees everything or nothing.
- **Memory is the person's data.** What is remembered across sessions can be read as a list, corrected, deleted, switched off, and scoped (this project, this workspace, me). When a remembered fact shaped an answer, say so in the answer, because a wrong memory otherwise repeats in every session. Offer a session that neither reads nor writes memory.
- **Who else will see it is shown before the act.** Sharing a conversation or a result states its audience (a private link, the workspace, the public web) on the control itself, and publishing to the open web is a separate, explicit act, never a checkbox inside a private share.

## First use

Capabilities and limits on one screen or less; starting points drawn from the person's own data where possible ("Summarize yesterday's 14 unread threads"); what the model sees and where the data goes, as the doc states; and one early, real encounter with a limit, so that trust starts calibrated.

## Accessibility

- While a response streams, set `aria-busy` on it so screen readers don't read fragments; announce "Generating" and "Response ready" in a separate polite status region; let people jump to the finished response.
- Stop is a real button in the tab order; offer a non-streaming mode that shows the full response at once.
- Confidence, citation and AI-label markers never rely on color or an icon alone; disclosure labels are text that assistive technology reads.

## Measure

What people do with the output is the evidence. Hand these to the product-analytics capability, if available, each with a baseline and a threshold (`validation.md` § After ship):

| Signal | Says |
|---|---|
| Applied as is, applied after edits, discarded | Whether the output is usable; a high edit share means the shape is wrong |
| Regenerate, rephrase and retry rates | The request was misread, or the output missed |
| Time from result to accept | What checking costs. Near zero on a consequential output means nobody is checking |
| Undo or revert soon after accepting | Errors caught late: checking was too hard |
| Approvals granted unchanged, and time to approve | Above about nine in ten, in seconds, the prompt is not a control |
| Stops, takeovers, corrections mid-run | People are steering, which is healthy when it rises with experience and scope |
| Hand-offs to a person, and how they ended | Where the model's range ends |
| The task's outcome and the PRD's counter-metric | Whether any of it helped. A preference rating is not an outcome |
