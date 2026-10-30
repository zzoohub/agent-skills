# PostHog: Analysis Guide

How this skill's methods run in PostHog: tracking conventions, identity, the query surface, experiments and the traps. Vendor behavior below was checked against PostHog's docs on 2026-10-30; confirm in the current docs before a decision rests on it.

## Tracking Conventions

- Events `object_action`, lowercase snake_case, past tense (`signup_completed`, `cta_clicked`); properties snake_case. The tracking plan is one file (`tracking-plan.md`, event-tracking reference § Tracking Plan Template).
- Autocapture and `$pageview` help discover behavior; metrics rest on named events (or a saved action that names them), so a page redesign can't move a metric silently.
- Server events (`posthog-node`, the Python SDK) reuse the person's distinct ID; flush or shut the client down before a serverless or webhook handler returns. Duplicates are not dropped at ingestion: a retry merges with the original only eventually, without guarantee, and only when it repeats the event name, distinct ID, original timestamp and UUID. Give each server event a deterministic UUID from its source (e.g. a UUIDv5 of the webhook event's ID).

## Identity

- `identify(user_id)` at signup and login merges the anonymous ID into the person; `reset()` at logout on shared devices.
- Person processing defaults to `identified_only`: anonymous events carry no person properties, so person-property filters and cohorts miss them. `identify()` attributes past events to the person but adds no properties to them.
- First touch: the `$initial_utm_*`, `$initial_referrer` and `$initial_referring_domain` person properties, kept by the SDK and set once when the person is identified. Last-touch `utm_*` event properties are not backfilled.
- B2B: attach every event to the account with `group('company', account_id)` and compute activation and retention per group. Group analytics is a paid add-on (up to 5 group types), and anonymous events don't join groups.

## Query Surface

- **Typed insights** for standard reads: trends, funnels, retention, lifecycle, stickiness, paths. They make fewer errors than hand-written SQL.
- **SQL (HogQL)** for the rest: signup-anchored cohort tables (the retention reference's query, translated), event-derived MRR, Carrying Capacity, health-score backtests, and GRR/NRR from a billing source synced into PostHog's data warehouse. Write an explicit `LIMIT`: SQL results stop at 100 rows by default (up to 50,000 per query through the API).
- **Funnels:** state the conversion window, the step order (sequential, strict or any order), exclusion steps and the breakdown's attribution (which step's property value). Correlation analysis shortlists Aha candidates; RPV, coverage and lift are computed separately (Aha reference).
- **Retention:** returning criterion "On" (bracket, the default) for period retention, never "On or after" (cumulative). For an acquisition cohort, start on "first ever occurrence": "first time" means first within the date range, and "recurring" counts every period.
- Turn on the project's internal and test user filter in every insight, and check the project timezone before reconciling days with the database.

## Experiments

Experiments run on feature flags. Exposure is `$feature_flag_called` unless a custom exposure event, carrying `$feature/<flag-key>`, is set; users who saw more than one variant are excluded by default. The default engine is Bayesian, with frequentist (optionally sequential) as the alternative: note which ran. Read the readout's interval against the MDE (A/B reference § 6) only after the A/B reference's validity checks; a holdout runs as the experiment's holdout group or a flag variant kept until the decision metric matures.

## Qualitative

Surveys run the Sean Ellis question on the qualifying users and in waves (retention reference § PMF Evidence); session replays explain small-n drop-offs and inconclusive tests.
