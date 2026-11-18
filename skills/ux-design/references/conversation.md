# Conversation

Chat, an assistant panel and voice: surfaces where the person says what they want in words. Read `ai-feature-ux.md` first; this file adds what is specific to talking. Whether a step belongs in a conversation at all is decided in SKILL.md step 2.

## When words are the right input

Words win when the request is open-ended, when the person can describe a thing but not find it, when a rare command would cost a hunt through menus, and when a result is refined by going back and forth. About half of what people do with a general assistant is asking, and much of the rest is refining a draft, so design for the second and third turn, not only the first.

Words lose to controls when the options are known, the value is exact, the action is frequent, or two things must be compared. Nobody should type a sentence for what a button does, several times a day.

- **The conversation directs; the work sits beside it.** A draft, a table or a plan under discussion is shown as itself, editable by hand, and the conversation changes it. A transcript is a poor place to keep or revise anything.
- **An assistant inside a product acts on what is in view.** It takes the open record, the selection and the person's role as context without being told, and its results apply to that object. An assistant that must be told what the person is looking at is a second product.

## Understanding and repair

Two people talking keep checking that they understood each other. An interface has to do the same, at a cost that matches the stakes.

- **Show the reading.** When being wrong is cheap, the result is the evidence ("Flights to Busan on Friday:" above the list). When the action is costly, slow or reaches other people, state the reading as parameters and wait.
- **Repair costs one step.** Edit the last request in place; change one parameter through a control; pick another reading from the two or three nearest ones. Never make the person start over, and never lose what they typed.
- **Ask or assume.** Assume, say what was assumed and proceed when a wrong guess is quick to see and undo. Ask first when a wrong reading wastes real time or money (a long run, a message to a customer): one question at a time, with the likely answers as buttons. The test: ask when the chance of misreading times the cost of a wrong result is more than the cost of the question. Never ask for what the context already says.
- **Offer controls inside the conversation.** A few buttons or checkboxes that collect context cut typing and what the person must remember, and give better results than an open question.

## The shape of an answer

- The answer or the result first, then what it rests on, then the next step. No preamble, no restating the question.
- Length follows the question. Padding reads as certainty and is not.
- Structure comes back as structure: a table, a list, a card with its actions, never a paragraph describing them.
- Say what was not done and what could not be found.
- Suggested follow-ups are the job's real next steps, never bait to keep the person talking.

## Starting points

An empty box asks for recall and shows nothing about what is possible. Give three to five starting points tied to the person's own data and the object in view, say plainly what it cannot do, and remove the examples once the person types. Frequent users get direct routes (commands, mentions of objects) instead of sentences.

## Controls it generates

- **The frame is fixed.** The input, Stop, the autonomy level and the navigation are never generated and never move.
- **Generated controls come from a catalog the product owns.** The model chooses and fills components; it never invents one. Each component has its states, one primary action and no navigation of its own, and code validates what the model placed.
- **A fully generated interface** has been preferred to plain text in rating studies that left out the wait (a minute or more) and measured neither task success nor accessibility. Use it for open-ended information, never on a path where someone pays, books or changes a record.

## Threads and history

A conversation is an object (`information-architecture.md`): it has a title the person can change, can be found by search, resumed, deleted and shared with a stated audience (`ai-feature-ux.md` § What it sees and remembers).

- One thread per job. A long thread degrades and hides its results: offer a fresh thread that carries a summary across, and say when earlier turns were condensed.
- Editing an earlier request branches the thread; the earlier version stays reachable.
- Inside a product, a thread about an object is reachable from that object.

## Handing over to a person

- An explicit request for a person is honored at once. It never loops back to the assistant.
- The hand-over carries the conversation, so nobody is asked again. It says who picks it up, by when and through which channel, and what happens outside staffed hours.
- Record why each hand-over happened; the reasons show where the assistant's range ends.
- The direction back, from a person to the assistant, is designed on purpose or not offered.
- A commitment is never cancellable only through a conversation: the direct control exists beside it (`journey.md` § Value).

## Sensitive conversations

Long, emotionally intense sessions, signs of distress and young users need more than an answer. Design the detection with the feature doc's owner and the path out here: resources, a suggestion to pause, a trusted person, human help. Heavy use of an engaging assistant goes with more dependence, so judge these features on what happens to people, never on time spent. Several markets set duties for companion-style assistants and for minors (`landscape.md`).

## Voice

Take the cheapest mode that does the job: a press-to-talk or an explicit "done" removes the least reliable part, a text field beside the microphone removes the worst failures, and a path without speech stays for the people and places where speech does not work.

- **Silence is the failure.** People leave gaps of about a fifth of a second between turns and plan their reply before the other has finished, so a pause of seconds reads as not being understood. Start the reply within about a second where the platform allows, acknowledge before slow work ("Let me check that"), and never leave dead air. Beyond a few seconds people rate the assistant less able and are less willing to return.
- **Interruption is normal.** When the person starts speaking, the system stops, and keeps only what was actually heard.
- **Exact values are confirmed.** Names, numbers, amounts and dates are read back or shown on a screen before anything acts on them. Nothing acts on a partial transcript.
- **Short turns:** one idea, at most three options, and an offer to send the detail in writing.
- **Not heard, not understood:** ask again in different words, then offer another channel. Never repeat the same sentence.
- Say it is AI in the first seconds; tell every party when a call is recorded; never ask for a secret aloud; assume a shared or noisy room.

## Inside someone else's assistant

When the product appears inside another company's assistant, it is a guest. The host decides the display, the theme and what the embedded interface may do, and hosts publish rules that change (`landscape.md`). What they currently agree on:

1. The smallest surface: one card, one primary action, at most one secondary.
2. No navigation, nested scrolling or second view inside a card. More goes to a full view or to the product's own site.
3. The host's type and theme; the brand shows as an accent and in the words.
4. No second input box or control that copies the host's own.
5. A text-only equivalent always exists, because the host may refuse the display or lack one.
6. A consequential action gets the product's own confirmation. Do not assume the host asked.
7. Payment, upgrades and account creation happen on the product's own site: design the hand-over and the return.
8. A person arriving from an assistant has already said what they want. Land them on that object in that state, never on a home page.

## Test and measure

Before building, let a person play the assistant behind the interface, or run the real model on seed requests in a bare harness, and read every transcript (`validation.md`). After ship, keep reading transcripts where people rephrase, stop or leave, and watch, beside the signals in `ai-feature-ux.md` § Measure: turns to the outcome, the share of conversations left after the first answer, and how hand-overs to a person ended.
