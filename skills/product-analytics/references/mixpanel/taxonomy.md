# Mixpanel Tracking Taxonomy

Tracking design for a Mixpanel project: event and property conventions, the decision order for a new behavior, the product and channel axes, and the doc set that records them. Drawn from a production Korean consumer app's taxonomy; the tool-neutral contract (committed state, server-side money, no personal data) is the event-tracking reference.

**The project's taxonomy wins.** If the project keeps Mixpanel taxonomy docs (default `docs/mixpanel/`; caller may redirect), read them before proposing an event and follow them over this reference. A conflict between the docs and the code is a finding: list it, never resolve it silently. With no docs, this reference is the default and its doc set (below) is the tracking plan.

## Events

1. **Names:** English snake_case. An interaction is verb then target (`click_product`, `view_modal`); a screen arrival is `pv_<screen>`; an outcome keeps one stable name (`input_complete`, `payment_complete`, `signup`). Context goes in properties. A name says what happened, not what it hopes to cause: a teaser view logged as `conversion` gets misread as a purchase.
2. **Shared events first.** A new behavior is a new value on a shared event before it is a new event: per-screen events scatter one behavior across names that can't be summed or compared.
3. **A button that only navigates gets no click event:** the destination's `pv_*` carries `진입경로` (where from, in bundle-level values; finer detail in `클릭위치` and `출발상품아이디`). Product cards still send `click_product`, because each card's click rate is measured.
4. **One action, one event.** Each definition states how often it fires: an impression once per area per page open, a read once per open-close.
5. **Outcomes are committed events** (`payment_complete`, `signup`, a participation), server-side where the server knows the outcome, never the button that asked for it. A server outcome carries what its analysis splits by: the client's distinct ID, the product code, and a snapshot of the client's attribution and experiment properties passed through checkout metadata. Without them, arm, channel and surface reads need workarounds.
   - Retries dedupe only when event name, distinct ID, `time` and `$insert_id` all match: set `$insert_id` from the order key and `time` to the committed moment, never the send time.
   - The track endpoint silently drops events older than five days; backfills and late sends go through import.
6. **One step-completion event** (`input_complete`, split by `입력단계번호` and `입력단계이름`), never one event per form field.
7. **Campaigns** prefix only the behaviors unique to them (`<campaign>_participate`); their clicks, impressions and arrivals use shared events split by `서비스` and `클릭위치`.
8. **Never rename a live event:** add the new name, keep both queryable, and record the switch date in the definition ("before YYYY-MM-DD: `old_name`").

### Decision Order for a New Behavior

First matching row wins; reuse an existing value of the same event before coining one.

| Behavior | Event | Split by |
|---|---|---|
| Arrives on a screen | `pv_<screen>` | `진입경로` |
| A modal or sheet opens | `view_modal`; a login sheet: `login_prompt_shown` | `유형` = the modal's name; `상태` if needed |
| A share button, anywhere | `share_click` | `페이지`, `클릭위치` |
| A card that leads to a product, in modals and overlays too | `click_product` | `클릭위치` (first segment = the page: `home_section`, `result_curation`), `대상상품아이디`, `출발상품아이디` |
| A button inside a modal or sheet | `click_cta`; its login button `login_prompt_click`, its close `login_prompt_dismiss` | `유형` = the modal's name, `클릭타입` = the button |
| Any other button that does more than navigate | `click_cta` | `클릭위치` |
| None of these: dwell, scroll, a result only the server knows, a campaign-unique act | a new event, with a one-line reason in the PR | — |

## Properties

- **Names:** Korean, no spaces, meaning first (`클릭위치`, `진입경로`, `결제금액`); a team working in another language uses its own under the same rule. Exceptions: experiment keys (`AB_<key>`) and numeric or boolean properties the backend fires, in English snake_case, one key shared by frontend and backend (`purchase_ordinal`, `is_repeat`).
- **One canonical key per concept.** Synonyms (`service_name`, `상품명`, `product_id`) collapse into the canonical key at every send path (track, register, people, server) before sending: the canonical value wins and the alias is dropped. The taxonomy keeps the deprecated → canonical table, each row with its reason.
- **Product identity:** two axes, both on every product event: the display name (`서비스`, from one constant list) and the code (`상품아이디`, the slug), bridged by one constant map. Never the database title or a UUID in either: two spellings split one product into two segments. Relationship keys stay separate: `대상상품아이디` (destination), `출발상품아이디` (origin), `패키지코드`, `패키지여부`.
- **Market and surface:** one written rule for each, used by every report: a market suffix on the display name (`-tw`) or the URL path for markets; `접속환경` (`앱` / `웹`) for the app webview vs browsers, which the browser property can't separate.
- **Money:** a numeric amount (never a string) and its currency on every payment event; "unset means the home currency" breaks the first time another market launches. Refunds are a server event keyed by the same order.
- **No personal data:** no name, email, phone, birth details or free text, on server events as much as browser ones; every send path strips them, and a stable hashed key replaces an email used for joins. Demographics derived from input (gender, age, age band) are filled in one place at send time, never at call sites.
- **Constants only:** event names, property keys and value lists come from code constants. A server-side sender often takes plain strings: check its names against the constants by hand.
- **One type per key.** A key that is deliberately an array on one event and a string on another stays untyped in Lexicon: pinning a type recasts the other event's values.

### Super Properties

Super properties persist in the browser (a first-party cookie for a year, by default) and ride on every later event, including another product's on the next visit. Register none for screen values: put them on the event. Keep an allowlist of the keys the code registers and unregister everything else at load. Save URL parameters through an allowlist too: a denylist lets every new parameter onto every event.

## Channel Axes

One key per axis; never mix axes:

| Key | Axis | Set by |
|---|---|---|
| `ch` · `ct` · `cr` (with `utm_*`) | last-touch channel · campaign · creative | the analytics module, from the landing URL (super properties) |
| `최초채널` · `최초콘텐츠` | first-touch channel · campaign | the analytics module, once (profile `set_once` at login) |
| `유입소스` | first-touch referrer type, its own value space | the analytics module, on page views, conversions and payments |
| `내부유입경로` | the in-session internal source | the analytics module |
| `진입경로` | the surface that sent the event | the call site: the only channel key a call site sets |

- Credit acquisition first-touch (`최초채널`), a conversion last-touch (`ch`).
- A new ad click replaces the whole last-touch set: a URL with `ch` or `utm_source` clears `ch`, `ct`, `cr` and the six `utm_*` keys, then keeps only its own; internal links (`?ct=share`) and bare revisits keep them. Overwriting key by key mixes two clicks in one event.
- Channel = `ch`, else `utm_source`: the custom property `if(defined(ch), ch, utm_source)`. Map source aliases (`ig`, `fb` → `meta`) when measuring, not in code.
- Internal URLs never reuse a last-touch key for another meaning: the click reads as a new ad click and wipes attribution.
- Share links carry `ct=share` and the shared product's code (`sp`). The sharer's `share_click` and the receivers' visits come from different people: report them side by side, never as one funnel.

## Experiments

Assignment tags every browser event with `AB_<key>` = the variant letter: assignment, not eligibility or exposure. Server events carry no browser super properties. Each test's start (the moment the treatment turned on), weights, eligibility rule and end go in an experiment timeline: the project's A/B log, else `biz/growth/experiments.md`.

Add an exposure event where the treatment renders (Mixpanel's `$experiment_started` with "Experiment name" and "Variant name"), so assigned and exposed separate. Set the test up in Mixpanel Experiments, which then runs SRM and intervals. Tag only running tests and unregister ended keys: stale tags ride on every event.

## The Doc Set

Default `docs/mixpanel/` (caller may redirect). It is the source of truth for events and properties; `tracking-plan.md` keeps only the cross-skill index (event-tracking reference § Tracking Plan Template).

| File | Holds |
|---|---|
| `mixpanel-taxonomy.md` | the rules, decision order, product and channel axes, deprecated → canonical keys and how each is enforced, how to write a definition, change log, exceptions |
| `mixpanel-property-dictionary.md` | per property: canonical key, meaning, value shape, disposition (keep · merge → key · remove · hold) with its reason, tier (core · feature · campaign, which expires) |
| `events/<area>.md` | one section per feature, files split by product area; `common.md` maps each shared event's values to the file that defines them |

**A feature section:** title ``## Feature (`event` · `event`)``; when it fires (screen, moment, how many times); a table of event · property · value · meaning; query cautions (renames and changed values with dates and old names; exposure semantics, such as "placed on the page" vs "seen"); an analysis guide per metric it feeds (Insights formula, or Funnel steps, window, breakdown step and held property).

**Change process:** adding, changing or removing an event, property or value updates its section and the change log (date · PR · what) in the same PR. A rule broken on purpose goes in the exceptions table (target · how it differs · why), so the proposal doesn't recur. The doc set describes what fires: a design not yet built travels as ready-to-paste sections to the PR that implements it, never into the docs ahead of the code.

## Validation

Beyond the event-tracking reference's checklist: the event arrives in the production project's live view with typed properties, the expected super properties and no stale ones; every call site uses the constants; Lexicon descriptions match the definitions.
