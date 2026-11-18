# UX Landscape Snapshot

**Last verified: 2026-11-18.** The perishable facts behind the other references: standards and law that set a floor for the interface, what platform owners publish about AI surfaces, what products have converged on, and what has been measured. The other files hold the durable rules. Product names, dates and figures appear only here, and this is the file to refresh.

**How to use it.** *P* = read in the standards body's, regulator's or vendor's own text on the date above; *S* = law-firm summaries, press or third-party measurement, usually because the primary text could not be opened. **Re-verify a row before a decision rests on it**, and record source and date in the app doc's §6. AI regulation in full, protocols and model facts are in the ai-architecture capability's `references/landscape.md`, if available; subscription and renewal law in the churn-prevention capability's `references/compliance.md`.

## Accessibility

| Fact | Source | What it changes |
|---|---|---|
| WCAG 2.2 (2024-12-12) is the current W3C Recommendation. WCAG 3.0 is a Working Draft (latest 2026-09-10) that "does not replace WCAG 2" | P: w3.org | Specify to 2.2 AA; never to a WCAG 3 draft or its contrast method |
| EU: the European Accessibility Act applies since 2025-06-28. EN 301 549 V4.1.1 (published 2026-09-02) references WCAG 2.2; its legal effect waits for citation in the Official Journal | S | Consumer products sold in the EU: 2.2 AA and an accessibility statement |
| US: the ADA Title II dates for public bodies' web and apps moved to 2027-04-26 (population of 50,000 or more) and 2028-04-26 (smaller), still WCAG 2.1 AA. Section 508 still cites WCAG 2.0. No rule for private businesses | S (Federal Register 2026-04-20, not read) | Public-sector buyers have dates; private sites face lawsuits, with 2.1 or 2.2 AA as the yardstick |
| Korea: kiosks installed before the phased dates must comply since 2026-01-28. An app must say before install whether it meets the accessibility guideline and offer a relay channel | P: Ministry of Health and Welfare (kiosks); S (apps) | Kiosk and ordering interfaces need voice guidance and an assisted alternative. The current Korean web guideline version was not verified |
| Apple's accessibility labels on the App Store are voluntary and will be required "over time". Nine features, each claimable only if every common task works with it | P: developer.apple.com | Design each core task for VoiceOver, Voice Control, larger text, dark mode, no color-only cues, contrast and reduced motion |

## Manipulative design

For each regime, the patterns it names, so a flow can be checked against them.

| Fact | Source |
|---|---|
| **EU, Digital Services Act Art. 25:** platforms must not design interfaces that deceive or manipulate. Named examples: giving one choice more prominence, asking again for a choice already made, making cancelling harder than signing up. A first fine under it was reported in 2025-12 | S |
| **EU, Digital Fairness Act:** proposed by the Commission on 2026-11-11, not law. Reported contents: a blacklist (false scarcity or popularity, defaults the person must reject, pre-ticked paid extras, renewal terms shown less prominently, fake notifications, choices made hard to refuse or withdraw), a contract-termination button, trial-end and renewal reminders, off switches for autoplay and streaks, limits on compulsive features for minors, a human contact when other channels fail | P (existence, topics); S (detail) |
| **Korea, e-commerce act** (in force 2025-02-14): hidden renewal (consent within 30 days before a price rise or a free trial turning paid), drip pricing (the total on the first screen), repeated interference (a "don't show for 7 days" option complies), preselected options, misleading visual hierarchy, obstructed cancellation. A Fair Trade Commission guideline reported in 2026-10 recommends one-click cancellation from the account home and treats cancellation only through a chatbot or a forced survey as possible obstruction | S (statute not read; fine amounts conflict) |
| **US:** the FTC's click-to-cancel rule was vacated on 2025-07-08; a notice of new rulemaking followed on 2026-03-13, with no proposed rule yet. The older federal law and state laws apply (California's amended renewal law since 2025-07-01). A 2025 settlement required cancellation by the same method as sign-up and banned a shaming decline button | P (notice); S (rest) |
| **UK:** subscription rules under the Digital Markets, Competition and Consumers Act are reported to start in January 2027 | S |

## What people must be told about AI

| Fact | Source | What it changes |
|---|---|---|
| **EU AI Act Art. 50** applies since 2026-08-02: people are told they are dealing with AI "at the latest at the time of the first interaction or exposure", clearly and accessibly; generated media is marked. Generators already on the market have until 2026-12-02 for machine-readable marking | S | The notice is in the first turn or screen |
| Commission guidelines (2026-07) and a voluntary code of practice on labelling (2026-06): notice built into the interface, not left in terms; say it is AI when asked; an icon with a word tested better than an icon alone; a label visible at first exposure without interaction; audio needs a spoken notice | S | A visible word beside the mark; no hover-only label |
| **Korea, AI Basic Act** (in force 2026-01-22): advance notice that a service is AI-based, generated output marked, realistic synthetic media clearly recognizable. Fines are suspended for at least a year | P (suspension); S (articles) | Announce AI at first contact, calls included |
| Companion-style assistants: California requires disclosure where a person could be misled and, for known minors, a reminder at least every three hours (since 2026-01-01); about a dozen US states have similar laws. California also passed a right to reach a human in customer service for large businesses (signed 2026-09-28) | S | Break reminders and a human route are requirements in some markets |
| No statute was found on an assistant's long-term memory. Recording-consent laws apply to voice and note-taking | — | Memory controls rest on design, not on a legal floor |

## Published guidance for AI surfaces

| Fact | Source |
|---|---|
| Apple, Human Interface Guidelines, Generative AI (updated 2026-06-08): identify when and where AI is used; avoid automating destructive or hard-to-undo actions; confirm significant actions; let people dismiss, revert and retry; never pass AI off as human | P |
| IBM, Carbon for AI (2026-08-12): every AI component carries an AI label that opens an explanation; after an edit the person can revert to the generated version | P |
| OpenAI, UI guidelines for apps inside ChatGPT (undated): an inline card with at most one primary and one secondary action; a carousel of 3–8 items; no deep navigation, nested scrolling, duplicate inputs or custom fonts. Submission rules: no ads, checkout on the product's own domain, no direct link to a checkout or upgrade page | P |
| MCP Apps: the host has the final say over display, tool access and theme; a tool must still return text where no interface is supported; consent for calls made from the embedded interface is not specified | P |
| Microsoft, design guidelines for agents (updated 2026-09-30): cards are summaries with minimal actions and complex work goes to the full app; elements a host does not support "might fail silently" | P |
| Chrome's WebMCP documentation (2026-09 to 2026-10): one function per tool; tell "execute" from "start a process"; mark consequential tools so the browser can ask the person; confirmation recomputes state; a success result must match the app's state. Android's guide says the app keeps its own confirmation | P (WebMCP); medium (Android) |
| Anthropic research (2026-02-18): requiring approval of every action "will create friction without necessarily producing safety benefits"; invest in visibility and simple ways to intervene | P |
| Not found or not readable: the current text of Google's People + AI Guidebook; any 2025–2026 revision of Microsoft's 18 guidelines for human-AI interaction | — |

## What products have converged on

| Convention | Seen in | Source |
|---|---|---|
| Named autonomy modes, always visible, switched in one gesture | Claude Code, Claude in Chrome | P |
| A fixed list that asks at every level | Claude in Chrome (permission changes, authorizations, sensitive input, permanent deletion); Chrome auto browse (purchases, social posts; hands back for sign-in, terms, account creation, final payment) | P |
| A plan before a long run, with the autonomy level chosen at approval; background runs with a list, a per-run log, a stop and a notice where the person works; output as a draft the person promotes | Claude Code, Cursor, GitHub | P |
| Memory as a readable, editable, scoped list, plus a session that does not remember | Claude, ChatGPT | P (help-page extracts) |
| Checkpoints and rewind | One product; it does not cover shell side effects or outside actions | P |
| Support assistants hand over when a customer asks for a person, and log why | Intercom Fin | P (extract) |
| Withdrawn: OpenAI retired its browser-driving agent in favor of background work that returns finished deliverables, is retiring its self-curated daily feed in favor of tasks the person schedules, and wound down in-chat checkout in spring 2026 | — | medium (help-page extracts and press) |
| Still forming: agents among teammates (their own directory identity and a human sponsor at one vendor; interface labels unverified) | — | S |

## Measured

| Finding | Source |
|---|---|
| People accepted 93% of an agent's permission prompts; the classifier that replaced routine prompts missed 17% of real over-eager actions | P: anthropic.com 2026-03-25 |
| With experience, sessions run on full auto-approve went from about 20% to over 40%, and interruptions from 5% to about 9% of turns; on the hardest tasks the agent stopped to ask more than twice as often as people interrupted; 0.8% of actions looked irreversible | P: anthropic.com 2026-02-18 |
| A source cited inside an AI summary was opened in 1% of visits (900 US adults, March 2025) | P: pewresearch.org 2025-07-22 |
| Explanations raise acceptance whether or not the answer is right; longer ones raise confidence, not accuracy; they help only when they make checking cheaper; first-person uncertainty lowers over-reliance; committing to an answer first lowers it most and is liked least | P: arXiv 2006.14779, 2401.13835, 2212.06823, 2405.00623, 2102.09692 |
| Flattering answers are rated higher and leave people more certain and less willing to mend a conflict; a thumbs-up signal amplified agreeableness in a shipped model that was rolled back | P: arXiv 2510.01395 (Science, 2026); medium: OpenAI 2025-05-02 |
| Engineers who learned a library with AI help scored 17% lower on a later quiz (52 people) | medium: anthropic.com 2026-01-29 |
| A general assistant's use: asking 49%, doing 40%, expressing 11%; over 70% outside work | P: NBER w34255 (split: medium) |
| A fully generated interface was preferred to markdown in 82.8% of pairs, with the wait of one to two minutes excluded and no measure of task success or accessibility | P: arXiv 2604.09577 |
| Text: delays of 2 to 20 s did not change abandonment in one study. Voice: delays above about 4 s lowered ratings and fillers helped. No verified tolerance threshold for voice replies | S; P: arXiv 2507.22352 |
| On ordinary sites, a single manipulative pattern worked on browsing agents about 41% of the time, more on stronger models; CAPTCHAs and pop-up banners are regular stall points | medium: arXiv 2510.18113, 2512.22894 |
| Agents' share: visits referred by AI assistants were 0.2–0.4% of sessions in two panels; one analytics vendor reports them growing fast and converting better; 6–17% of consumers say they have used an agent to shop, about half use AI to research | S; vendor data; figures conflict |

## Watch list

| Signal | Today → when it crosses |
|---|---|
| Sessions operated by someone else's agent pass about a tenth of revenue-bearing sessions | The floor in `agents.md` → a full declared function set, flows and metrics of their own |
| An operating system's assistant calls apps in your market | No declared functions → functions for the top tasks |
| The Digital Fairness Act is adopted | Good practice → its blacklist, reminders and termination button as requirements |
| WCAG 3 reaches Candidate Recommendation | 2.2 only → start mapping |
| An independent measure of how well people review agent output | An always-ask list by judgment → tuned by data |
| A shared convention for marking an agent's actions among people | A house convention → the standard |
| Voice passes about a tenth of sessions | A mode beside text → its own flows and budgets |

## Repeated but poorly supported

- "Chat will replace the interface." Products converge on words plus controls plus the work in view.
- "A person in the loop makes it safe." People approve nearly everything they are shown.
- "Showing the model's reasoning builds the right trust." It raises confidence, not accuracy.
- "People want AI to buy for them." Surveys show most want help choosing.
- "Agents are most web traffic." Those counts include every bot.
- "A proactive feed keeps people engaged." The best-known one was withdrawn.
- "Shorter time to first value causes retention." Only the correlation is established.
