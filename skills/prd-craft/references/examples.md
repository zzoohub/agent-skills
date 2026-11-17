# PRD Examples

Weak sections next to better ones, all from one product: a booking tool for independent yoga and pilates studios. Its brief's test ran first. For four weeks we texted three studios' waitlists by hand whenever a client cancelled; 41 of 68 freed spots were taken, and two owners pre-paid.

## §1 Problem: precise, and unsourced

**Weak:** "No-shows cost studios up to 20% of revenue, and 73% of owners call them their biggest problem."

**Better:** "A booked spot that ends up empty earns the studio nothing, and at peak times someone else wanted it. Owners put it at 2–4 empty spots per peak class [Said: 6 of 8 owners]; nobody has counted (unknown → count from rosters in weeks 1–2 of v0.1). In the four-week test, 68 booked spots were cancelled at three studios and 41 were taken by someone on the waitlist (measured: our message log). Before, a cancelled spot stayed empty unless the owner texted her regulars herself [Observed: 2 studios]. A peak-class spot sells for $15–20 (measured: 3 price lists)."

Every number says where it came from, and the one nobody has measured is written as a task with a date.

## §3 Bet: a departure nobody approved

**Weak:** the brief's owner asked for a client app. The PRD plans text messages and web links instead, and only the report mentions it.

**Better:** "**Departures from the brief:** A client app → text messages and web links, because all 41 refills in the test happened by text and no client asked for an app [Observed: our message log]. Approver: the founder, proposed."

The evidence wins in the draft, and the person who asked can see it, argue with it and approve it.

## §4 Success: an output, with nothing traded against it

**Weak:** `| Waitlist texts sent | — | 500 a month | launch |`. Met by texting people who never answer.

**Better:**

| Metric (exact definition) | Baseline | Target | By | Counter-metric (floor) | Data source |
|---|---|---|---|---|---|
| Primary: booked spots that end up empty, per peak class, per studio | 2–4 [Said: 6 owners] (unknown → count from rosters, weeks 1–2) | ≤1 (target: the owners' bar for dropping the paper list) | checkpoint + 8 weeks | classes over capacity: 0, since overbooking would fake it | roster: booked vs came |
| Leading: share of spots freed 2+ hours before class that someone else takes before it starts, per studio | 60% by hand (measured: 41 of 68) | ≥50% with automatic offers (target: the bar the by-hand test passed) | checkpoint | clients opting out of waitlist texts: ≤5% a month | `spot_freed` and `spot_taken` events (built in v0.1) |

Dropped: the owners' "fewer messages to answer". Nobody can count it, and it follows from the leading row.

The primary is the problem itself, read from the roster. The leading row can move inside six weeks, and its floor catches refills bought by pestering people.

## §5 Scope: parts, sorted by priority

**Weak:**

> v0.1: `database-schema` [Must], `sms-service` [Must], `booking-api` [Must]
> v0.2: `waitlist-engine` [Should], `admin-dashboard` [Should]
> v0.3: `payments` [Could]

After v0.1 nobody can book a class, so it tests nothing. The keys are parts no user would recognize, and nothing says who uses it, until when, or what result would stop it.

**Better:**

> ### Now — v0.1: Peak classes
> **Tests:** a freed spot is still taken when the offer is an automatic text instead of a personal one (value).
> **Audience:** the 3 studios from the test plus 3 more from the same instructors' forum, and their clients.
> **Checkpoint:** week 6, after four weeks of use.
> **Decision** (the founder): continue if at least 4 of 6 studios hit the leading target over weeks 3–6; change if 2 or 3 do; stop if 1 or none, and then each studio gets its rosters as a spreadsheet and its clients' numbers are deleted within 2 weeks.
> **Build bar:** we set up each studio and its timetable by hand, the same day (past 10 studios, setup must be built). Payment stays at the front desk. Texts to clients, the booking record and deletion are production-grade.
> **Transition:** a studio moves its peak classes on a Monday. The Friday before, we enter that week's paper bookings and waitlists in their paper order, and the owner checks them. The paper list for those classes stops that Monday. To roll back, the owner prints the roster.
>
> 1. `class-booking` — a client books a spot from a link the studio shares — the test needs real bookings in the tool · [spec](features/class-booking.md)
> 2. `cancel-and-refill` — a client cancels from their confirmation text, and the spot is offered to the waitlist — the bet itself (depends on: `class-booking`) · [spec](features/cancel-and-refill.md)
> 3. `class-roster` — the owner sees who is coming and marks who came — replaces the paper list, and is where the primary metric is read (depends on: `class-booking`) · [spec](features/class-roster.md)
> 4. `client-data-removal` — a client asks to be forgotten, and is — the studios' terms require it before we text anyone · [spec](features/client-data-removal.md)
>
> *Cut line: above it, the Musts. What follows is dropped first to hold the checkpoint.*
>
> 5. `class-reminders` — a client gets a reminder the evening before — may cut no-shows, but the test stands without it (depends on: `class-booking`) · spec owed
>
> **Fit:** the Musts ≈ 8–12 working days (est.: the builder's), inside the two weeks before use starts.
>
> ### Later
> - `late-cancel-fee` — a studio charges for a cancellation that came too late to refill — when most freed spots come inside 2 hours of class ⚠ arch (payments)
> - `studio-sign-up` — an owner sets up their own studio — when a seventh studio asks
>
> ### Never
> - Marketing messages to clients — they gave their number for bookings, and the first promotion would cost the studio its opt-ins.
> - A public directory of classes — two owners asked for it, but it finds new clients, a different problem from empty spots.

The features are things a client or an owner does. Six studios are the sample, so the rule counts studios instead of pooling a rate. Setup stays manual because six studios don't need self-serve, deletion is a feature because nobody may be texted without it, and each Never is something a real person asked for.

## §6 Duties: a citation in place of a requirement

**Weak:** "Privacy: data protection law may apply to client data. Check with legal before launch."

**Better:** Clients gave their phone numbers to the studio, not to us, and a waitlist offer tells one client that another cancelled. The texts are personal data even though a class timetable isn't.

- Clients are texted only about their own bookings and waitlist offers; no text names another client, and each says which studio it is from and how to stop them — the consent each studio's sign-up form collects (bookings only; forms read 2026-03-02) and each studio's data-processing terms with us (contract, signed before v0.1 starts) — met by `cancel-and-refill` REQ-005 in v0.1.
- A client's name and number are deleted within 30 days of their request, or of the studio's — the same terms — met by `client-data-removal` REQ-001 in v0.1.

The weak line leaves the duty with nobody. The better ones can be built and tested, in the release that first texts a real person.
