# Form CRO

Lead capture, contact, demo, quote, application and survey forms. Signup → `references/signup-flow-cro.md`; checkout and payment → `references/checkout-cro.md`; an in-product form's behavior and states → screen-design, if available. For demo forms, judge on meetings held, not requests.

## Leak signatures

- **Drop at one field** → valid edge inputs rejected (international phone numbers, apostrophes in names, postcodes). Confirm: field errors by input pattern. Fix.
- **Submissions up, SQLs flat after shortening** → a qualifier was removed. Confirm: lead→SQL rate before vs after. Restore it as a conditional field.
- **Demo requests complete, meetings don't happen** → the gap between submit and scheduling. Confirm: request→meeting-held rate and time to first contact. Test scheduling at submit.
- **High starts, low submits on mobile** → keyboard types, autofill, or errors that clear input. Confirm: field drop by device and replays. Fix.
- **A CAPTCHA added for spam, completions fall** → the challenge blocks people. Confirm: completion before vs after. Prefer invisible checks (honeypot, server-side scoring); any CAPTCHA needs an alternative in another sensory mode (WCAG 1.1.1).

## Judgment calls

- **Before removing a qualifier**, check last month's enrichment match rate: a low rate means sales loses its routing data.
- **Multi-step** helps when answers branch the path (quotes, applications). Break when it only splits the same effort.
- **Set expectations at the submit**: what happens next and when; a response-time promise only if sales keeps it.

## Field set (redesign only)

Each field with its reason (routing, qualification, legal) and its order; each removed field names what it protected and its replacement (enrichment, a conditional field, invisible spam checks). Labels, buttons and errors appear as copy direction for copywriting.
