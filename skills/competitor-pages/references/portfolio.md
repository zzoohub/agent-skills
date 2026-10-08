# Portfolio: URL Map, Priority, Scale, Refresh, Diagnosis

## URL map

When comparison pages already exist, map them before triage; SKILL.md's One URL per intent rules decide every row.

1. **Inventory** every comparison URL you own (CMS export or sitemap), each with its top queries, clicks and average position for the last 3–6 months (Search Console, queries by page) and its referring domains.
2. **Group the target queries into intents**: per competitor, singular, plural and "best", vs, switch and pricing; per pair, A vs B. Singular and plural join only when SKILL.md's overlap test says so. Give each URL the intent it was built for; its impressions elsewhere are spillover. Then read the map: two URLs built for one intent that meet SKILL.md's merge evidence are a merge; URLs of different intents sharing a query are retargeted and cross-linked; an intent with no URL is a gap to triage; a URL whose intent has no demand, deals or traffic is a retire candidate.
3. **One action per URL:** keep and refresh · rebuild in place (wrong format for its intent, same URL) · retarget and cross-link (title, H1, anchors) · merge into [URL] with a 301 (SKILL.md's merge rule; the survivor folds in the other's unique content and gets the internal links) · create · retire (301 to the closest same-intent page, or to the hub if links point at it; else remove) · leave to third parties (a list intent you can't serve fairly; earn a place on the ranking lists instead).
4. **Return** one row per URL plus one per gap, no prose:

| Intent (queries) | Format | URL, existing or new | Evidence (position, clicks, links) | Action |
|---|---|---|---|---|

Before returning: SKILL.md Self-Review item 11 holds for every row, and every intent ends with one URL or a recorded "leave" decision.

## Priority

1. **Triage on deal share**, not keyword volume: how often X is named in competitive deals, loss notes, churn interviews and "what did you use before?" answers, losses counted double. Run Stage 1 only for the top 3–5; each of the rest gets one line, "not now, because …".
2. **Score = deal share × wedge.** Wedge: 2 = a provable win on a deciding criterion (Stage 1 item 3); 1 = criteria-only; 0 = no F1/F3, return the positioning gap. Break ties by winnability (the head query's top-10 formats match the page you would build), then by how often answer engines name X (Stage 1 item 4). An announced price rise, sunset or acquisition jumps the queue.
3. **Build** F1 and F3 for the top scores first, F5 where migration effort is the objection, F2/F4 only where you have first-hand evidence on every entry, and no more pages than the owner can re-verify each cadence.
4. **Return** the URL map, then a table in build order (competitor · deal share · wedge · score · pages) plus the "not now" lines, at most 300 words besides the map; draft every page the request names, else one exemplar.

## Scale tests

- **Name-swap.** Swap another competitor's name into the page: if most sentences stay true, it is a clone; don't ship it. Shared blocks (importer, security, support) are fine as a minority.
- **Rollout.** Start with the 3–5 pages that have the strongest win evidence, and review them at 60–90 days before templating more.
- **Why.** Bing: "LLMs group near-duplicate URLs into a single cluster and then choose one page to represent the set" (Bing Webmaster blog, Dec 2025). Google's spam policies, scaled content abuse included, also govern its AI responses, and it may act on spam reports competitors file.

## Linking

A hub (`/alternatives/` or `/compare/`) links to every competitor page; each competitor's F1, F2, F3 and F5 interlink; pages naming a competitor link to its comparison page.

## Refresh

- **Triggers:** the cadence (default 90 days); a change on any source URL, caught by a change monitor or scheduled re-fetch; their announcements; a dispute; the register past its Refresh-by date.
- **Procedure:** on the cadence, re-fetch and re-capture every source in the register, or in the page's sources block when there is none (a one-off refresh needs no register); on one changed source or a dispute, only the claims citing it. Re-run the price range, since one price change can move a crossover and flip a verdict. Patch what changed at the same URL, re-test the TL;DR and verdicts, re-run the Self-Review. Never rewrite (it discards what counsel reviewed and what ranks) unless the caller asks for a rebuild, diagnosis finds the wrong format or a clone, or most claims fail the Self-Review; then run the New-page stages at the same URL, keeping what earns its rankings (SKILL.md, What ranks decides).
- **Return** the full patched or rebuilt page (a diff only if asked) and a change list, one line per change: what changed, why, its source and check date.
- **Dates:** move "Updated" only on a substantive change (Google's helpful-content guidance names re-dating unchanged pages as a warning sign); a wrong claim also gets a dated correction note.
- **Fan-out:** for each changed source, reopen every page that cites it, and list the change in the handoff for sales' battlecards.

## Failure diagnosis

At 8–12 weeks after launch, judged against the page's job (Stage 1 item 6); symptoms come from the caller or search-visibility, if available.

| Symptom | Likely cause | Check, then fix |
|---|---|---|
| Not ranking (acquire pages) | Wrong format for the query; two of your pages on one intent; a clone | Top-10 formats; queries per URL (Search Console); name-swap → wrong format: rebuild at the same URL; two pages on one intent with the merge evidence, or a clone: merge (SKILL.md's rule; never across intents); else add first-hand content. Counsel re-reviews changed claims |
| Ranks, not cited in AI answers | No named, specific facts; a near-duplicate sibling (engines pick one per cluster); third-party sites dominate | Sources cited for the tracked prompts; name-swap → verdict and numbers up; differentiate or merge the clone; log off-site follow-ups |
| Cited, not recommended | Self-promotional framing | Concessions and per-segment verdicts present? → make verdicts segment-honest; earn third-party mentions |
| Traffic, low conversion | Switching cost unanswered; CTA wrong for the stage | A switching offer beside the table? → add it; deeper work via the cro capability, if available |
| Competitor complaint | A stale or unsupported claim | The source's check date and capture → the Disputes steps in `claims.md` |
