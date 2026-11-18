# Information Architecture

Structure comes from the objects people name and the words they use, and is judged by whether people find things, never by counting clicks.

## Objects first

Before any sitemap, list the objects people name (from the PRD, support tickets, search logs, the architecture's Ubiquitous Language and their own words), each with:
- **relationships** (a project has tasks; a task has one assignee);
- **lifecycle states** (draft, active, archived, deleted), each of which becomes a filter value, a status label and a deep-link case;
- **roles × actions** (who can view, create, edit, approve, delete);
- **one home and one route**; everywhere else links to it.

Top-level navigation lists the objects or workspaces people switch between, never features, teams or the org chart. *Break when* the product is one linear task: the flow is the navigation.

**A model's work adds objects like any other.** Give each one states, a home and a route, as for the rest:

| Object | States worth a label | Home |
|---|---|---|
| Conversation (a thread with an assistant) | active, archived, shared | A history the person can search, rename and delete |
| Run (one piece of delegated work) | queued, running, waiting for you, done, failed, stopped | A list sorted by what needs the person; one page per run (`agents.md`) |
| Approval | waiting, approved, rejected, expired | The same queue as other items waiting for this person |
| Standing instruction (a schedule, a trigger, a rule) | on, paused, failing | Beside the object it acts on, and in one list of everything that runs unattended |
| What it remembers; what it may reach | — | Settings, by scope: me, this workspace |

**Results are objects, not messages.** A draft, a report, a booking or a changed record that a model produced is saved as the product's own object, in that object's home, with its normal actions and a note of how it was made. The conversation or the run links to it. A result that exists only as a message cannot be found, shared, permissioned or edited later.

## Navigation model

Start from the archetype of the primary role's top task (SKILL.md step 1):

| Archetype | Navigation | Density, guidance | Signature risk |
|---|---|---|---|
| Occasional transaction (booking, filing) | Linear | One question per page; save and resume | Abandonment at the ask |
| Daily workspace (projects, CRM, editor) | Object sidebar, command palette | Dense; shortcuts, bulk actions | Discoverability, permissions |
| Feed or consumption | 3–5 tabs | Minimal chrome | Empty on day 1 |
| Marketplace | Role switch | A home per role | Role confusion, trust |
| Admin console | Search first; settings by scope | Dense; audit trail | Destructive bulk actions |
| Assistant (ask, get an answer or a draft) | The composer leads; history and saved results beside it | Starting points instead of a blank box | Nothing shows what it can do; results lost in old threads |
| Delegated work (an agent does the job) | What needs you first; then runs, results, standing instructions | Status over detail; evidence on demand | Work done unseen; approvals nobody reads |

Most products with a model in them stay one of the first five, with the model inside the objects' own screens: do not add an "AI" destination for work that belongs to an object. Use the last two only when asking or delegating is the primary role's top task.

Then size it:
- **Count:** as many top-level destinations as people switch between often. Tab and navigation bars hold 3–5 (platform guidance); "More" never holds a top task. Slots are a budget: a new destination must beat the weakest current one on top-task frequency, else it nests under its parent object or lives in search and the command palette. *Break when* one destination dominates: hub and spoke.
- **Depth:** drilling down is fine while each level's labels predict what lies below. Flatten when people bounce between siblings to compare them; for daily tasks, add accelerators (recent items, pins, search, a command palette) rather than flattening everything.
- **Roles:** roles with different jobs get a home each, landing on their top tasks and the items awaiting them (a moderator lands on the flagged posts, not the product's overview), plus a visible switch when one person holds two (buyer and seller). Hiding what a role can't use is not a home for it.
- **Platforms:** separate apps (a native phone app beside the web app) each make some top tasks first-class (phones typically: triage, approvals, status, replies); elsewhere a task gets a read path or an "open on desktop" hand-off, never a cramped port. A responsive web app keeps every task usable at 320 CSS px (`ergonomics.md` § Floors, Reflow): window size changes prominence, not what can be done.
- **Growth and badges:** labels stay true as content grows, so no counts or "new" inside label text. A badge counting items awaiting this person's action (approvals, assignments, unread mentions, runs waiting for them) does belong on navigation: it is how a role finds its top task. Count only what needs this person, cap the number shown, clear it when acted on, and give it a text equivalent ("Assigned to you, 3").

## Labels

Each label predicts what lies behind it, in people's own words, and differs clearly from its siblings. Reject org names, code names and vague buckets ("Resources"). Name an AI feature by what it does ("Summarize", "Draft a reply"), never by the technology or a sparkle. Settle label disputes with first-click tests, not opinions.

## Anti-patterns

Root causes, checked first in a review: one structural fix clears many symptoms, and a symptom patched alone comes back elsewhere.

| Anti-pattern | What you see | Fix |
|---|---|---|
| Navigation mirrors the product (features, modules, data model) or the org chart, not user tasks | One task spans several sections; labels name modules or teams; every role hunts in the same places | Regroup around each role's top tasks and objects |
| A role without a home | Its work sits under another role's navigation; it lands on a screen built for someone else | A landing per role: its top tasks and waiting items |
| Junk drawer | A vague bucket ("More", "Other", "Tools") holds a top task | Re-sort by task; nest under the parent object |
| One object, several homes or names | The same thing under different labels; people ask which is right | One home and one glossary term; cross-links elsewhere |
| Depth where people compare | Bouncing between siblings | Flatten that level, or add compare and accelerators |
| The model as a place | An "AI" or "Assistant" tab holds work that belongs to objects; the same thing can be done two ways with different results | Put the model's action on the object's own screen; keep one home per result |
| Work trapped in a conversation | People scroll old threads to find what was made; results can't be shared or edited | Save results as objects; link from the thread |

## Settings by scope

Split settings by whom they affect: me (profile, notifications, preferences, what an assistant remembers about me); this workspace (members, roles, integrations, what agents may reach and do); billing; admin and security. Each setting has one home, linked from where the need arises (a "Notification settings" link on a notification). Add a setting only when groups of users need opposite behavior, defaulting to the larger group's; otherwise decide.

## Front doors and deep links

People arrive anywhere: shared links, notifications, email, search results, a link in an assistant's answer. Every screen says where it is (title, object context, a parent link or breadcrumb) and what can be done there. Each deep link handles:
- **no access:** who can grant it, and a way to request it;
- **another workspace or account:** switch to it, saying so, if the person belongs to it; else name the account that has access and offer to switch;
- **deleted:** what happened, and where to go instead;
- **moved or renamed:** a redirect;
- **signed out:** sign in, then land on the target.

Routes are part of the IA: one canonical route per object view, and filters, tabs and selections worth sharing or returning to live in the URL.

## Search, the command palette and the ask box

Size search by the volume per core object in a heavy account (SKILL.md step 1), roughly: tens → browse; hundreds → filters and saved views; thousands → search first. Search also earns prominence when people know what they want or labels vary. Daily workspaces add a command palette (⌘K or Ctrl+K) that reaches both objects and actions. Zero results is a designed state: echo the query, suggest fixes, offer to browse.

An **ask box** (a question in plain words) is search plus a model, not a second product. Its results are the product's objects with their normal actions; an answer in prose names the objects it was drawn from and links them; the filters it inferred appear as controls the person can change; and when nothing supports an answer it says so and falls back to plain results. Keep one box: a separate "search" and "ask AI" make people guess which one knows.

## Validate

- **Card sort** (open), before structuring, to learn how people group and name things. About 15 participants give stable patterns (NN/g); items people disagree on need cross-links or better labels.
- **Tree test or first-click test** on each role's top tasks, before building. Set the bar by stakes: NN/g reports a review of 98 tree-test studies by Albert and Tullis with a median success of 62% (the middle half between 37% and 83%), and rates 61–80% good, 80–90% very good and over 90% excellent; mission-critical or revenue tasks aim above 90%. A right first click matters most where there is no other way round: across 12 studies of mostly government sites it roughly doubled eventual success (87% against 46%), in tree tests the gap is far wider, and on sites with search and other routes far narrower. Report directness (right first time, no backtracking) beside success: success reached only after backtracking still means a misleading label. The best yardstick is the previous structure's result on the same tasks; comparing two trees takes about 50 participants per tree. Wrong first clicks show which label misleads: fix it and retest.

## Restructure

Restructure only when the as-is fails top tasks (first-click or tree-test failures, search terms that miss, support themes) or new objects have no home; otherwise relabel and add accelerators. Daily experts pay the relearning cost: keep old names as search and command-palette aliases for a release, and judge success by existing users' top-task time as well as new users' success.

Every shipped route change is a one-way door, and so is reverting one: people, bookmarks, sent emails and help articles have adapted to the move, so a reversal is a second migration, not an undo. Prefer fixing forward (relabel, cross-link, alias, a badge where the work waits); a reversal gets the same notices and test as any restructure. Never redirect a moved-to route back to a route that permanently redirected to it: browsers cache permanent redirects, so the pair can loop. Keep the moved-to route serving, or move forward to a new route and redirect both old routes to it.

When changing a shipped IA:
- map every old route to its new home in a Redirects-from column of the app doc's §3 route table, and redirect old routes permanently;
- keep links in notifications, emails and bookmarks working;
- announce moved destinations in place for one release ("Billing moved to Settings");
- re-run the tree test on the top tasks and compare with the old structure's results.
