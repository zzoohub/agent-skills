# UX Writing

Functional UI copy: names, labels, errors, empty states, confirmations, permission requests, statuses and the glossary. Brand voice and promotional copy belong to the copywriting capability, if available, and live in the Brand Voice section of `biz/marketing/strategy.md` (default; caller may redirect). Functional copy follows that section's tone map for errors, billing and security, never its persuasion (no such section: plain and calm, no humor where money, data or security is at stake).

## Terminology

- One name per object and per status across the UI, notifications, email and help, recorded in the UX doc's glossary (§2). Seed it from users' words (support tickets, search logs, interviews) and the architecture's Ubiquitous Language; where they differ, users' words win in the UI.
- Statuses double as filters and notification text, so name who or what is awaited: "Waiting for Dana's approval", not "Pending". Keep them stable once shipped.
- **Remove** takes something out of a collection and it survives; **Delete** destroys it. Use the verb for what actually happens.
- Never internal names: team names, code names, raw error codes.

## Labels and buttons

- Buttons name the action and, unless obvious, its object ("Send invoice"); never "OK", "Submit" or "Yes".
- Where "Cancel" would be ambiguous ("Cancel subscription?"), label both buttons by outcome: "Cancel subscription" / "Keep subscription".
- Labels fit at the largest text size and in the longest supported language.
- A placeholder is a format example, never the label, and meets the text-contrast floor (`ergonomics.md` § Floors); hints and constraints go in helper text tied to the field.

## Error messages

What happened and how to fix it (why, only when it changes the next step); no blame; a code only after the plain message, for support; input kept: "Couldn't save your changes. Check your connection and try again; your edits are kept."

## Empty states

What this place is, why it is empty, and the next action. First use: what will appear and the first action ("Create your first project"), with a sample or template where a blank start is hard. No results: echo the query or filters; offer to clear or widen them. Cleared or done: confirm it and offer the next useful action. A failed load is the Error state, not empty.

## Confirmations

Only where the destructive ladder (`interaction-patterns.md` § Destructive actions) calls for a dialog.
- **Title:** the action, the object and the count: "Delete 3 projects?"
- **Body:** the consequence in plain words, including what else goes ("and their 41 files") and whether it can be undone.
- **Buttons:** the destructive verb with its object ("Delete projects") and a safe exit. Never "Are you sure?" with Yes and No.

## Permission requests

- State the benefit in the user's terms; when to ask: `design-process.md` § Mapping a flow.
- Prefer context alone. Only when more detail is essential, show a custom screen before an Apple system alert: one button, titled like "Continue" or "Next", that opens the alert, and no other action (no close or cancel) unless a legal consent requires one (Apple HIG, Privacy; checked 2026-10).
- Design the denied state: what still works, and a route to Settings the next time the feature is needed.

## Messages

Email, push and SMS that a flow sends: the subject or first line names who, what and the action needed ("Sam asked you to review the Q3 plan by Thursday"), so the message works unopened, with no private detail where a lock screen shows it; one link, to that object; a recognizable sender. Channel constraints: `design-process.md` § Mapping a flow.

## Status and progress

- Progress names the work and the quantity: "Importing 240 contacts…", not "Processing…".
- A failure partway says what completed and how to finish: "180 of 240 imported. Retry the other 60."
- Show a queue position or a time estimate only when it is real.
