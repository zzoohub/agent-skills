# Consensus and Accuracy

Read this when the gap is off-site (a cluster's answers cite third-party pages that leave you out, or answer from memory) or when an engine states something wrong about you. You can't edit the model; you change the sources it reads and give it a page of facts to fetch.

## Map the sources first

From the panel runs (`measurement.md` §5), record every cited URL with its cluster, engine, source type (own site, competitor site, editorial, third-party roundup, review platform, forum or community, video, Wikipedia or Wikidata, directory or marketplace), the share of runs citing it (7/10), and whether you are absent, present, or present but wrong. The full map lives in the AI-visibility log when one is kept; a memo shows only the top cited URLs per cluster.

The targets are the URLs cited on most runs where you are absent or wrong: those exact pages, not the platform in general. Size off-site versus on-site work from this map (cut-offs in SKILL.md's rule on reading citations), never from an industry average: citation mixes differ by engine, vertical and prompt type. Build owned presence on a platform only when the map shows engines citing it for your clusters.

## Plays by source type

| Source type | Play | Guardrail |
|---|---|---|
| Third-party roundup | Give the author what the list lacks: test access, current pricing and limits, a customer result they can verify. Ask for corrections when facts are wrong | Paid inclusion is an ad: disclosed, links `rel="sponsored"`. Cited is not recommended: check that the answer names you, not just the page |
| Review platform (G2, Capterra, app stores, Google Business Profile) | Complete the profile in the category engines cite; ask real customers after a success moment; reply to reviews | No incentives tied to positive reviews, no asking only happy customers, no staff or fake reviews |
| Forum or community (Reddit, Quora, Naver Cafe, KnowledgeiN) | Answer in the threads engines cite, with specifics; staff disclose affiliation. Post copy via the copywriting capability (social), if available | No seeded threads, sockpuppets, vote requests or undisclosed paid posts; each community's rules bind |
| Editorial and press | Offer data reporters can cite (original research, benchmarks, anonymized usage data) to the outlets engines cite, not a legacy media list | Sponsored articles are labeled and their links `rel="sponsored"` |
| Video | Publish where engines cite video for your clusters (how-to, demo), with chapters and a full transcript | Hosting and markup: `technical-seo.md` (images and video) |
| Directory, marketplace, feed | Match category and description to your canonical sentence; for shopping, the feed is the source of truth (`ai-platform-optimization.md`) | — |
| Competitor's own page | On-site work: a fair comparison page via the competitor-pages capability, if available | — |

## Decisions

**Earn the listicle; don't fake it.** Run the plays above on the exact pages engines cite. *Break:* no credible third-party comparison exists for the cluster; then publish a genuinely fair one on your own site via competitor-pages, if available, with disclosure, first-hand testing, published criteria, no self-awarded #1, and a plain statement of when a competitor wins.

**Fix the fact at its source.** Trace the cited URL that carries a wrong fact and correct it there: your facts page, a directory listing, a stale review or comparison (ask the owner, with evidence). A counter-page alone rarely beats consensus. *Break:* the wrong answer cites nothing (memory); publish or update the facts page, confirm in logs that the engine's search bot fetched it, and re-test monthly, since memory errors fade only as sources and models update.

**Never edit your own Wikipedia article.** Propose changes on its talk page (`{{edit COI}}`) with independent, reliable sources, and disclose paid editing as the Wikimedia terms of use require. Not notable yet? Earn independent coverage first; a deleted article is worse than none. No break.

**No inauthentic mentions.** Google: "Seeking inauthentic 'mentions' across the web isn't as helpful as it might seem." Communities ban it and engines discount self-promotion; an exposed sockpuppet campaign becomes the consensus about you. No break.

## Entity clarity

An engine must know which entity you are before it can describe you. In order of leverage:

1. **One canonical sentence**, "[Brand] is a [category] for [audience] that [differentiator]", on the homepage and About page, in the Organization markup `description` and on every profile, with the same category words everywhere (review-site category, LinkedIn industry, app-store category).
2. **A public facts page**: pricing and plans, limits, integrations, platforms, founding year, location, leadership and status, in visible HTML at one stable URL, dated only when facts change. It is the page an engine fetches when it searches for your facts.
3. **Markup that mirrors the page**: Organization with `sameAs` pointing to your official profiles; Product and Offer matching visible prices.
4. **Wikidata and the knowledge panel.** If the brand meets Wikidata's notability policy, keep an item with accurate statements and the official website; its Q-ID ties the entity together across languages. If Google shows a knowledge panel, get verified and suggest corrections there; its description can't be edited directly, so fix the source it quotes.
5. **Ambiguous names** (a common word, a namesake company): pair the name with the category near mentions ("monday.com, the work-management platform") and keep the full identifier consistent.

## Brand-fact prompts

Add these to every panel: what is [brand]; how much does it cost; plans and limits; does it integrate with [tool]; is it legit or safe; [brand] vs [competitor]; [brand] alternatives; is it still available. Score each answer against the facts page and trace any wrong one to its source (Decisions).

## Sentiment by root cause

Classify negative framing by the cause visible in the cited sources, then route it:

| Root cause | Move |
|---|---|
| A real product or support problem, recurring in reviews and threads | Product or support fixes it first; then reply publicly with what changed. Content can't outrun it |
| Outdated facts (old price, removed limit, fixed bug) | Update the facts page; ask review sites and list authors to refresh |
| A competitor's framing | Correct factual errors with the page owner; publish a fair comparison via competitor-pages, if available |
| Confusion with a namesake, or misinformation | Fix it at the source; disambiguate the entity |

Never suppress criticism (review gating, buried complaints, fake positives): platforms penalize it, and it becomes the story.
