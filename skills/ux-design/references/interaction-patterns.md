# Interaction Patterns

App-wide choices from this file go into the UX doc's conventions (§5) once; screens cite them.

## The 7 Universal Screen States

Loading resolves to Loaded, Empty or Error. From Loaded, a screen enters and leaves Refreshing, Partial and Offline independently; Empty is an outcome of loading, never a step before it.

| State | What the user sees | Rules |
|---|---|---|
| **Empty** | Loading finished with nothing to show | Say which kind: first use, no results, or cleared (copy: `ux-writing.md` § Empty states). Never blank |
| **Loading** | First load, nothing to show yet | A skeleton matching the layout, only for waits of a second or more; none for cached content |
| **Loaded** | The content | The primary action is available |
| **Error** | The load failed | What failed in plain words, and the recovery: retry, change the input, or who to contact |
| **Partial** | Some parts loaded, some failed | Show what succeeded; an inline error with retry where it failed |
| **Refreshing** | Updating content already on screen | Keep the content and show a small indicator; never fall back to a skeleton |
| **Offline** | No connection | What stays readable and editable follows the architecture's offline contract per object; queue writes only where it syncs them, else disable writes and say why |

States compose: Refreshing while Partial (retrying the failed pane), an Error over Loaded (a background sync fails after the content rendered), Offline over Partial. Design the composites the data makes likely; one rule resolves them: **never blank content the user already has.** A state that can't occur on a screen is written `N/A — reason`, never skipped silently.

## Beyond the base seven

List the domain states once, while mapping flows; each screen specs the ones its data makes likely:
- **Volume:** zero, one, many, too many (pagination, truncation, "N new" for live inserts instead of shifting the list).
- **Access:** no access, read-only, waiting for approval.
- **Lifecycle:** archived, deleted or moved, reached by a deep link.
- **Limits:** a plan or quota reached: what still works and how to lift it.
- **Background jobs:** running, failed, finished while the user was away.
- **Conflict:** edited elsewhere: show both versions; reload or merge.

## Containers

Choose once per object (§5), so every list opens its items the same way: a dialog for one short decision that returns here (never long input), a side panel to inspect or edit beside the list, a page for long work or anything worth a URL. Never stack dialogs: a dialog that grows a second step becomes a page.

## Unavailable actions

Hide what a role can never do. Show what a request or an upgrade could unlock as disabled but focusable, with the reason and who grants it or which plan does ("Ask a workspace admin for export access"). Check access before a form's first field, never at submit.

## Destructive actions

Decide by reversibility and by who else is affected, and prefer making an action reversible to adding a dialog:

| Action | Pattern |
|---|---|
| Reversible (archive, remove from a list) | Act at once, no dialog; Undo in the feedback plus a durable way back (trash, history, ⌘Z/Ctrl+Z) |
| Deletes the user's own content | Soft delete to a trash with a restore window |
| Irreversible, or affects other people (publish, charge, send to a list, delete shared data) | A dialog naming the object, count and consequence (copy: `ux-writing.md` § Confirmations), focus on the safe choice; Enter never confirms destruction |
| Catastrophic (a workspace, an account) | Type the name to confirm; say what else goes and what can't come back |

*Break when* a destructive action is frequent in an expert tool (deleting rows or tasks in a shared workspace): make it undoable and drop the dialog, because confirmations people see all day get clicked through. Destructive controls sit apart from frequent ones, never in Save's size and place.

## Optimistic UI

Show the result at once when success is likely and a failure can be shown in place: a like, marking as read, a reorder, a chat message shown as "sending" until it turns sent, or failed with Retry. Never show a terminal state the server hasn't confirmed: paid, booked, emailed to others, filed. *Break when* other people see the result at once and retracting it is costly (posting to a public feed): wait for confirmation, showing progress.

## Feedback channels

One channel per kind of news, app-wide:
- **Field errors:** inline at the field, input kept; long forms add a summary at the top that links to each field.
- **Item state** (saved, failed, syncing): in place, on the item.
- **System state** (offline, degraded, plan limit, maintenance): a banner that stays until the state changes.
- **Minor success:** a toast or snackbar, one at a time. A toast with an action (Undo) stays until dismissed or follows the OS accessibility timeout, and its action also exists somewhere durable.
- **Notifications** (background completion, hand-offs, mentions): only to people who must act or would be hurt to miss it; the rest goes to an activity feed or a digest. Urgency picks the channel (badge, in-app, email, push); each names the actor and the object and opens it in the state it describes. One a flow depends on is designed as a step of that flow (`design-process.md` § Mapping a flow).
- **Errors never dismiss themselves.**

## Response time

Every press shows its pressed state at once. Under a second, no spinner, and the current content stays; past about 10 s, progress with Cancel, or move the work to the background and notify.

## Forms

Validate a field when the user leaves it, then as they type once it shows an error, never while untouched; never clear input (on an error, on back, or on session expiry: sign in again and keep it); unsaved changes autosave or get a leave guard that covers system back.

## Gestures and motion

- Standard gestures for standard actions; never override system gestures (back, home, notification pull); back-swipe conflicts: `ergonomics.md` § Platform conventions.
- Every gesture action also has a visible control (for a drag, "Move to…": `ergonomics.md` § Requirements that change structure), and destructive swipe actions offer Undo.
- Each motion in a spec names its purpose and its reduced-motion variant: remove the movement, keep fades and progress. The platform owns navigation transitions; design-system owns durations, easing and the reduced-motion policy.
