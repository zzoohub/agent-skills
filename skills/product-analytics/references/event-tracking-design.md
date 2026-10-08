# Event Tracking Design

Writing the tracking code is a developer task.

**Start from what exists:** inventory the code's tracking calls (capture, track, gtag, dataLayer), the schema and the billing webhooks; the tracking code's git history is its changelog. Plan only the gaps.

## Naming

There is no industry standard: pick one convention, write it in the tracking plan, enforce it. This skill's default is `object_action`, lowercase with underscores, past tense (`signup_completed`, `cta_clicked`).
- Context goes in properties, not names: `cta_clicked` with `cta_location`, never `cta_hero_clicked`; `signup_completed` with `method`, never `signup_google_completed`.
- GA4 accepts letters, digits and underscores, starting with a letter, and reserves some names. Where GA4 has a recommended event, send that name (`sign_up`, `purchase`, `generate_lead`) through the plan's GA4 column, so its reports and Ads conversions work.

## Identity

- Identify at signup and login, merge the anonymous ID into the person once, and reset on logout (shared devices).
- B2B: every event carries the account key (a group), and activation and retention are computed per account.
- First-touch UTMs should survive identification as person properties (PostHog: `$initial_utm_*`); confirm it in your tool.

## Event Contract

- Fire on the committed state change (the database write, the payment confirmation), not on the click that requested it.
- Money and lifecycle events fire server-side and carry the source's idempotency key, because billing webhooks retry.
- One source per event name: `signup_completed` comes from the server only, and the client just identifies. Two sources double-count funnels.
- Money: integer minor units plus an ISO 4217 currency code, the unit declared in the plan.
- No free text that could carry personal data (search queries, error messages, form fields): send categories or lengths.
- Derive time since signup at query time; don't store it on events.
- Server SDKs batch events: flush or shut down the client before a webhook or serverless handler returns, or the events are lost.

## Governance

- Each event names the metric it feeds and an owner: no metric, no event. Start with 10–15 events.
- **State lives in the database:** compute accounts, seats, plan and MRR from app or billing tables, not from events that mirror them and drift. Instrument behavior that leaves no row (views, attempts, abandonment), plus the state changes funnels must join; the renewal and plan-change rows below are the fallback where billing is out of reach.
- Never rename a live event: add the new one, deprecate the old, note the switch date.
- Alert when a key event's daily volume leaves its band.

## Day-One Events

| Event | Side | Fires when (committed) | Key properties | Feeds |
|---|---|---|---|---|
| `lead_submitted` | client | lead or demo form accepted | `form_type`, `lead_intent` | content-site conversion |
| `signup_completed` | server | account created | `method`, `plan_type` | signups, cohorts |
| `onboarding_step_completed` | client | step saved | `step_name` | activation funnel |
| `[core_action]` (named per product, e.g. `project_created`) | where it commits | the core value action | domain properties | Aha, retention |
| `purchase_completed` | server | payment confirmed | `plan_type`, `amount_minor`, `currency`, `interval` | revenue |
| `subscription_renewed` | server | renewal invoice paid | same as purchase | revenue retention |
| `subscription_upgraded` / `subscription_downgraded` | server | plan change billed | `from_plan`, `to_plan`, new recurring `amount_minor` | NRR |
| `subscription_cancelled` | server | cancellation takes effect | `reason`, `plan_type` | churn |

Secondary features share one `feature_used` event with `feature_name`. User and account properties: `plan_type` with one value list, `signup_date`, `company_size`.

**`aha_moment_reached` is derived, then instrumented.** During discovery, compute Aha candidates from the underlying action events, so the hypothesis can change without re-instrumenting and history can be backfilled. Emit this synthetic event only once the definition is validated, as a funnel convenience, not the source of truth.

**Referral loop** (add when the loop exists): `invite_sent` is share intent (link copied, share sheet opened, invite queued; `invite_method`), because delivery of link and share-sheet invites can't be observed; `invite_clicked` (the invitee lands; `referrer_id`); `referral_completed` (server, the referred signup; `referrer_id`, `referral_source`); `reward_granted` (server; `referrer_id`, side, value).

## Tracking Plan Template

The tracking plan (default `biz/analytics/tracking-plan.md`; caller may redirect) is the single source of truth.

```markdown
# Tracking Plan — [Product]
<!-- the event table + ≤300 words; sections are a menu: omit what doesn't apply, heading included -->
Convention: [object_action, past tense] · Unit: [user | account] · Identity: [identify at …; reset on logout]
## Aha Moment
Definition: [Action X] within [Y days], [Z times] · Status: hypothesis | validated [date; evidence: reports/aha-analysis.md]
## Events
| Event | Trigger (committed state) | Side | Properties | Metric | Owner | GA4 name |
## Properties
| Property | Type / allowed values | Set when |
## UTM and channel rules
[medium vocabulary; utm_id; first-party capture of UTMs and click IDs — GA4/GTM reference]
## Funnels
[unit · ordered steps · window; full specs live in funnels.md]
## Change log
- YYYY-MM-DD: added / deprecated [event] — [reason]
```

## Validation

Before shipping tracking:
- each event fires once per committed change, with typed properties (test in the tool's debug view; watch for double fires on single-page-app navigation);
- server-side totals reconcile with the database or billing within a stated tolerance;
- internal and test accounts are filtered out;
- no personal data in properties;
- GA4 key events are marked, and the plan's change log is updated.
