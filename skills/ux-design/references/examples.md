# UX Design Examples

Weak lines next to better ones, all from one product: a booking tool for independent yoga and pilates studios. A client books from a link the studio shares and cancels from a link in the confirmation text; a freed spot is offered to the class's waitlist by text, one person at a time. Six studios use it in the first release, set up by hand.

## §1 Value: a slogan

**Weak:** "Value proposition: studios save time and fill more classes with a seamless booking experience."

**Better:**

- **Value:** when a client cancels a peak class, someone on the waitlist takes the spot and the owner does nothing. Value event: `spot_taken` after `spot_freed`; the first one in a studio is first value. For a client: a spot in a class that was full.
- **Business event:** the studio keeps its peak classes on the tool at the week-6 checkpoint and starts paying (PRD §2 price hypothesis). It depends on the value directly: an owner pays while freed spots keep being retaken.
- **Loop:** a cancellation (the trigger, nothing we send) → an offer by text → a tap → the spot is taken. What carries over: each class's waitlist and each client's consent to offers. Cadence: every peak class, several times a week.
- **Where they pull apart:** more offers refill more spots and wear clients out. Guard: clients opting out of waitlist texts stay at or under 5% a month (the PRD's counter-metric), and no offers go out at night.

The weak line is as true of every competitor and names nothing anyone could observe. The better one tells the designer what every screen is for, tells the analyst which two events to instrument, and says where the design must refuse the business.

## §1 Journey: a mood chart

**Weak:** "Awareness 😐 → Consideration 🙂 → Onboarding 😀 → Usage 😍 → Advocacy 🤩. Pain points: confusion. Opportunities: delight."

**Better** (the owner; a client has rows of her own):

| Stage | Arrives with | Asked of her | Got through when | Target | Likeliest loss → the design's answer |
|---|---|---|---|---|---|
| Arrive | A call with us; "no more paper list" | A Friday check of the bookings we entered from paper | She confirms the roster matches her list | Every studio, before its switch date (target: the PRD's Transition) | One wrong name and she keeps the paper → the check screen lists the differences from paper first |
| First value | A full class and a cancellation | Nothing | The first `spot_taken` in her studio | In the first week of use (target) | No cancellation that week, or one inside 2 hours → the roster shows the open spot for a walk-in |
| Repeat | Ten minutes before class | A glance at the roster; marking who came | The roster is marked for the class | Each peak class | She can't tell what the tool is doing → "Offer out to Ana until 14:20, Ben next" on the open spot |
| Commit | The week-6 checkpoint | The decision to keep it | Her peak classes stay on the tool | At least 4 of 6 studios (the PRD's rule) | The terms arrive as a surprise → they are on the settings screen from day one |
| Return after a gap | A holiday closure | Nothing | Offers resume with the timetable | No offer for a class that isn't running | Texts go out for cancelled classes → a closure pauses offers |
| Leave | The stop rule, or her choice | One request | Rosters received as a spreadsheet; clients' numbers deleted within 2 weeks | Every leaving studio | Silence afterwards → an email says what was sent, what was deleted and when |

Each row ends in something that can be counted, and the last two rows exist. Nobody can build or measure a smiley.

## Step 2 Cost ledger: a client books a spot

**Weak**, as first drawn: open the link → create an account (email, password) → verify the email in the mail app → enter name and phone → pick a class → pick a time → confirm → tick consent to texts. Eight steps, six inputs, three asks before value, one switch to another app.

**Better**, each line taken down the ladder:

| Step | The person supplies | Kind | After the ladder |
|---|---|---|---|
| Account, password | Two inputs | A fact the product could do without | Nobody: a phone number identifies a client, and a booking needs no password |
| Email verification | A switch to the mail app | A switch | Nobody |
| Class and time | Two choices | Facts the product could know | A default: the studio shares each class's own link, so both are already chosen |
| Name | One input | A fact only she holds | The person, once; remembered on this device |
| Phone | One input | A fact only she holds | The person; the field says confirmations go there |
| Consent to waitlist texts | A tick | Consent | Deferred to the first time she joins a waitlist, which is when it means something |
| Confirm | One tap | Consent | The person |

After: two steps and two inputs on the first visit, one tap on later ones, nothing asked before the booking, no switch. The prediction this makes: a client on her phone books in under a minute, unaided (target), which a five-person test can refute before anything is built.

## Step 2 Surface: "add a chatbot so clients can book by chatting"

**Weak:** a chat window on the booking page. An assistant called Mia greets the client and asks which class, which day and which time.

**Better:** booking is a choice among known options, so the link with its one tap stays: a chat would make a client type what a button does. Words already arrive somewhere else. Clients answer the confirmation text in their own way ("can't make it tonight, sorry") instead of tapping the cancel link, and the owner reads each one and frees the spot by hand [Observed: the message log].

- **The step for a model:** read a reply and sort it into *cancel*, *a question about a spot*, or *anything else*. No rule can do that; a model can, and the check is cheap.
- **Language in, controls back:** a reply read as a cancellation gets a text with one link, "Cancel Thursday 19:00 Pilates?", opening the same screen as the cancel link, where the client confirms. A misreading costs her one ignored text. Consent stays with the person.
- **Anything else goes to the owner** with the message, on the roster's waiting list. The model never answers it.
- **A result is an object:** a confirmed cancellation is a cancellation on the roster, and the refill starts the same way as from the link.
- **Without the model:** the cancel link in the confirmation text, as today.
- **Told:** the reply opens "Automatic reply from Flow Studio".

The request named a solution. The cost was real, and it was in a different place, on a different person, with a much smaller answer.

## Step 2 A model with a check: a timetable from a photo

A later release lets an owner set up her own studio. Typing a week's timetable is about 25 classes of four fields each (est.: three studios' timetables).

**Weak:** "AI-powered setup ✨: upload your timetable and our AI creates your classes automatically." A banner reads "AI can make mistakes. Please review."

**Better:**

- **The split:** a rule cannot read a photo of a printed timetable; a model can. So the model drafts and the owner checks.
- **Checking is a glance:** each drafted class sits beside the strip of the photo it was read from. A cell the model was unsure of says "Check this" in words. Everything is editable in place.
- **The result is a draft of the timetable itself,** the same object she edits by hand later. Nothing can be booked until she presses "Publish timetable", which is her consent.
- **Without the model:** "Type it in instead", on the same screen, and automatically when the photo can't be read ("We couldn't read this photo. Try another, or type the classes in").
- **Told:** "Drafted from your photo by AI" on the draft, until it is published.

The banner in the weak version moves the risk to the owner without making the check any cheaper. The better version makes the check cost less than the typing it replaces, which is the only reason to use a model here.

## §7 Proof: an intention

**Weak:** "Validation: we will run usability tests to make sure the roster is intuitive."

**Better:**

| Hypothesis | Prediction | Test | Pass |
|---|---|---|---|
| The roster answers "is anyone getting this spot?" where the owner already looks | If each open spot shows its offer in place ("Offer out to Ana until 14:20"), owners stop texting their regulars themselves when a spot frees up, as two of them did before [Observed: 2 studios]: under 1 in 10 freed spots by week 4 (target; baseline unknown → count in weeks 1–2), because the question is answered before they reach for the phone. Wrong if they still text | Before build: three owners see a roster mock with one open spot and are asked what is happening with it and what they would do | 3 of 3 say an offer is out and that they would wait. After ship: freed spots where the owner texted someone herself, asked at the weekly call; above 3 in 10 at week 4, add the client's reply to the roster |

The weak line cannot fail. The better one names the behavior, the number, the reason and the result that would change the design, and its first test costs an afternoon.
