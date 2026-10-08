# Email Copy Guidelines

How the email reads, from the inbox row to the CTA. Word budgets and the output block live in the Default Output Format in `references/email/guide.md`. Persuasion structures live in `references/persuasion-frameworks.md`; use them only when the email has to persuade, since transactional and onboarding mail are instructions, not arguments.

## The inbox row

- **From:** a person ("Maya at Acme") for lifecycle and sales mail that invites replies; the brand for transactional mail and newsletters. Keep it stable: a new From name reads as a stranger.
- **Subject:** expected mail (a receipt, a triggered step, a trial ending) says what's inside: "Your March invoice", "Your trial ends Friday". Curiosity only for editorial mail from a sender the reader already trusts, paid off in the first line. There is no character target, but the first ~30 characters must carry the meaning alone, because phones and summaries cut the rest. Never a fake "Re:" or "Fwd:", never the reader's name as the hook, never urgency the facts don't support.
- **Preview:** always set; it completes the subject and never repeats it. Apple Mail can show an AI summary in its place, and Gmail puts Gemini summary cards atop long opened threads, so the first two body lines must state the point plainly on their own.

## The body and the voice

- **Shape:** the hook first (the reader's situation, their news, or the payoff the subject promised), then why it matters now, the one step, the CTA, the sign-off. Never open with yourself ("I hope", "We're excited", "My name is").
- **Voice:** one person writing to one person. Contractions, plain words, paragraphs of one to three sentences; read it aloud and rewrite whatever sounds like a memo or an ad. Tone follows the relationship: warm and practical in onboarding, short and direct in re-engagement, no pressure in win-back, plain and calm about money, data or security.
- One job per email. More than two steps → a numbered list; one idea per paragraph.
- Proof only where it answers a doubt the reader has at this step, placed beside that doubt.
- **A reason to act now** must be true: a dated deadline with its reason, or what the reader already has and keeps or loses (saved work, a locked price, unused credit), stated only for recipients it's true for. No true reason → no urgency; give the benefit instead (lever cards: `references/psychology/guide.md`).
- **Sign-off:** a named person when replies are welcome, and someone reads them; the brand for transactional mail.

## The CTA

If the reader already wants the action (pay the invoice, finish a setup they started, pick a plan before the trial ends), put the CTA on the first screen. If the email has to persuade, put it after the argument and repeat it once at the end. Button text is verb + outcome ("Connect your bank", "Choose a plan"); one primary button, anything else a text link. Newsletters and digests are multi-link by design.

## Personalization

- Behavior beats the name: "Your first report is ready" proves you know what happened; "Hi Sam" proves only that a database field exists.
- Every merge token has a fallback that reads naturally ("Hi there", never "Hi ,").
- Per-recipient variants generated at scale must differ in substance, not in swapped fields: filters score near-identical mass mail as bulk whatever produced it.

## Rendering

The email reads fully with images off: real text, alt text that carries the message, no copy baked into images. Single column, body text at least 14px, enough contrast, no meaning carried by color alone; check logos with transparent backgrounds in dark mode. Keep the HTML light: Gmail clips heavy messages (`references/email/deliverability.md`).

## A/B tests

Design them here; the readout belongs to product-analytics, and the record is a test card in the cro capability's format, if available.

- **Test order for lifecycle mail:** send vs. don't send (the holdout) > trigger and timing > offer > audience > subject. Subjects come last: they move opens, which you can't measure, more than clicks or the goal event.
- **Size before you test.** Per arm, n ≈ 16·p(1−p)/Δ², with p the mean of the two rates (5% significance, 80% power). At a 3% click rate, detecting 3.0% → 3.6% needs about 14k recipients per arm; 3k per arm detects only a ~40% change. If the smallest lift your volume can detect exceeds ~25% relative, don't test: ship the better-reasoned variant and watch the guardrails.
- Judge on clicks or the goal event, never opens. One variable per test, arms sent at the same time, and no stopping at the first significant peek.
