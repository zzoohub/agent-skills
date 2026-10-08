# Information Architecture

Structure comes from the objects users name and the words they use, and is judged by whether people find things, never by counting clicks.

## Objects first

Before any sitemap, list the objects users name (from the PRD, support tickets, search logs, the architecture's Ubiquitous Language and users' own words), each with:
- **relationships** (a project has tasks; a task has one assignee);
- **lifecycle states** (draft, active, archived, deleted), each of which becomes a filter value, a status label and a deep-link case;
- **roles × actions** (who can view, create, edit, approve, delete);
- **one home and one route**; everywhere else links to it.

Top-level navigation lists the objects or workspaces users switch between, never features, teams or the org chart. *Break when* the product is one linear task: the flow is the navigation.

## Navigation model

Start from the archetype of the primary role's top task (SKILL.md Stage 0):

| Archetype | Navigation | Density, guidance | Signature risk |
|---|---|---|---|
| Occasional transaction (booking, filing) | Linear | One question per page; save and resume | Abandonment at the ask |
| Daily workspace (projects, CRM, editor) | Object sidebar, command palette | Dense; shortcuts, bulk actions | Discoverability, permissions |
| Feed or consumption | 3–5 tabs | Minimal chrome | Empty on day 1 |
| Marketplace | Role switch | A home per role | Role confusion, trust |
| Admin console | Search first; settings by scope | Dense; audit trail | Destructive bulk actions |

Then size it:
- **Count:** as many top-level destinations as users switch between often. Tab and navigation bars hold 3–5 (platform guidance); "More" never holds a top task. Slots are a budget: a new destination must beat the weakest current one on top-task frequency, else it nests under its parent object or lives in search and the command palette. *Break when* one destination dominates: hub and spoke.
- **Depth:** drilling down is fine while each level's labels predict what lies below. Flatten when users bounce between siblings to compare them; for daily tasks, add accelerators (recent items, pins, search, a command palette) rather than flattening everything.
- **Roles:** roles with different jobs get a home each, landing on their top tasks and the items awaiting them (a moderator lands on the flagged posts, not the product's overview), plus a visible switch when one person holds two (buyer and seller). Hiding what a role can't use is not a home for it.
- **Platforms:** separate apps (a native phone app beside the web app) each make some top tasks first-class (phones typically: triage, approvals, status, replies); elsewhere a task gets a read path or an "open on desktop" hand-off, never a cramped port. A responsive web app keeps every task usable at 320 CSS px (`ergonomics.md` § Floors, Reflow): window size changes prominence, not what can be done.
- **Growth and badges:** labels stay true as content grows, so no counts or "new" inside label text. A badge counting items awaiting this user's action (approvals, assignments, unread mentions) does belong on navigation: it is how a role finds its top task. Count only what needs this person, cap the number shown, clear it when acted on, and give it a text equivalent ("Assigned to you, 3").

## Labels

Each label predicts what lies behind it, in users' words, and differs clearly from its siblings. Reject org names, code names and vague buckets ("Resources"). Settle label disputes with first-click tests, not opinions.

## Anti-patterns

Root causes, checked first in a review: one structural fix clears many symptoms, and a symptom patched alone comes back elsewhere.

| Anti-pattern | What you see | Fix |
|---|---|---|
| Navigation mirrors the product (features, modules, data model) or the org chart, not user tasks | One task spans several sections; labels name modules or teams; every role hunts in the same places | Regroup around each role's top tasks and objects |
| A role without a home | Its work sits under another role's navigation; it lands on a screen built for someone else | A landing per role: its top tasks and waiting items |
| Junk drawer | A vague bucket ("More", "Other", "Tools") holds a top task | Re-sort by task; nest under the parent object |
| One object, several homes or names | The same thing under different labels; users ask which is right | One home and one glossary term; cross-links elsewhere |
| Depth where users compare | Bouncing between siblings | Flatten that level, or add compare and accelerators |

## Settings by scope

Split settings by whom they affect: me (profile, notifications, preferences); this workspace (members, roles, integrations); billing; admin and security. Each setting has one home, linked from where the need arises (a "Notification settings" link on a notification). Add a setting only when groups of users need opposite behavior, defaulting to the larger group's; otherwise decide.

## Front doors and deep links

People arrive anywhere: shared links, notifications, email, search results. Every screen says where it is (title, object context, a parent link or breadcrumb) and what can be done there. Each deep link handles:
- **no access:** who can grant it, and a way to request it;
- **another workspace or account:** switch to it, saying so, if the user belongs to it; else name the account that has access and offer to switch;
- **deleted:** what happened, and where to go instead;
- **moved or renamed:** a redirect;
- **signed out:** sign in, then land on the target.

Routes are part of the IA: one canonical route per object view, and filters, tabs and selections worth sharing or returning to live in the URL.

## Search and the command palette

Size search by the volume per core object in a heavy account (SKILL.md Stage 0), roughly: tens → browse; hundreds → filters and saved views; thousands → search first. Search also earns prominence when users know what they want or labels vary. Daily workspaces add a command palette (⌘K or Ctrl+K) that reaches both objects and actions. Zero results is a designed state: echo the query, suggest fixes, offer to browse.

## Validate

- **Card sort** (open), before structuring, to learn how users group and name things. About 15 participants give stable patterns (NN/g); items people disagree on need cross-links or better labels.
- **Tree test or first-click test** on each role's top tasks, before building. Set the bar by stakes: in Albert and Tullis's review of 98 tree-test studies (reported by NN/g; median 62%), 61–80% success is good, 80–90% very good and over 90% excellent; mission-critical or revenue tasks aim above 90%. Report directness (right first time, no backtracking) beside success: success reached only after backtracking still means a misleading label. The best yardstick is the previous structure's result on the same tasks; comparing two trees takes about 50 participants per tree. Wrong first clicks show which label misleads: fix it and retest.

## Restructure

Restructure only when the as-is fails top tasks (first-click or tree-test failures, search terms that miss, support themes) or new objects have no home; otherwise relabel and add accelerators. Daily experts pay the relearning cost: keep old names as search and command-palette aliases for a release, and judge success by existing users' top-task time as well as new users' success.

Every shipped route change is a one-way door, and so is reverting one: people, bookmarks, sent emails and help articles have adapted to the move, so a reversal is a second migration, not an undo. Prefer fixing forward (relabel, cross-link, alias, a badge where the work waits); a reversal gets the same notices and test as any restructure. Never redirect a moved-to route back to a route that permanently redirected to it: browsers cache permanent redirects, so the pair can loop. Keep the moved-to route serving, or move forward to a new route and redirect both old routes to it.

When changing a shipped IA:
- map every old route to its new home in a Redirects-from column of the UX doc's §3 route table, and redirect old routes permanently;
- keep links in notifications, emails and bookmarks working;
- announce moved destinations in place for one release ("Billing moved to Settings");
- re-run the tree test on the top tasks and compare with the old structure's results.
