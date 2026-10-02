---
name: social-content
description: |
  Social media content creation, content strategy, and multi-platform publishing.
  Use when: creating social posts, planning content calendars, developing content pillars,
  writing LinkedIn/Twitter/Instagram/TikTok/YouTube content, repurposing across platforms,
  building topic clusters, writing launch posts and threads, analyzing viral content,
  reverse-engineering top creators, building in public,
  or when user mentions "social media", "content strategy", "content calendar", "social post",
  "LinkedIn post", "Twitter thread", "Instagram carousel", "TikTok script", "YouTube script",
  "content pillar", "content repurposing", "topic cluster", "editorial calendar",
  "build in public", "Product Hunt", "Hacker News", "Reddit marketing",
  "viral content", "hook formula", "social media analytics", "engagement rate".
  Do NOT use for: email content (use email-marketing), ad creative (use ad-creative),
  SEO/blog optimization (use search-visibility), UX copy (use copywriting).
---

# Social Content & Strategy

Social media content creation, strategy, and multi-platform publishing -- built on research from 50+ sources including academic papers on virality, platform algorithm documentation, and methods from top practitioners (Justin Welsh, Alex Hormozi, Naval Ravikant, Sahil Bloom).

**Read product context first.** If `docs/prd/product-brief.md` exists, read it for product and audience info. If `biz/marketing/strategy.md` exists, read it for brand voice and channel priorities. If neither exists, ask the user or infer from the request. Treat both as read-only context — never author the product brief from here.

**Output:** when asked to save deliverables (posts, calendars, pillar docs) and a file-write capability is present, write to the social content dir (default `biz/marketing/content/social/`; caller may redirect the `biz/<area>/` root) — otherwise return inline. If the file already exists, update it in place rather than creating a duplicate.

**Drafts only.** Never post, publish, or schedule anything to a live account without the caller's explicit approval — produce the drafts and hand them back.

---

## Core Principles

These patterns hold across every platform and every successful practitioner:

1. **Shares > Likes.** Across Instagram (DM shares = top signal), TikTok (+45% share growth), Twitter (replies and retweets far outweigh likes) -- sharing is the dominant algorithmic signal. Create content people want to SEND to someone specific.
2. **Early engagement drives everything.** Twitter's 2-hour window, HN's 45-minute gravity, TikTok's follower-first testing -- every algorithm rewards fast initial engagement. Build a core community that engages quickly.
3. **Hook in 3 seconds.** First line of text, first second of video. This determines everything. Invest 80% of creative effort here.
4. **Platform-native wins.** Same insight, different execution per platform. Adapted repurposing beats copy-paste cross-posting.
5. **Long-form creates short-form.** Start with one substantial piece, fragment into platform-specific content. This is how Welsh, Hormozi, and every efficient creator operates.
6. **Consistency is the baseline.** No strategy works without showing up regularly. Algorithms reward predictability.
7. **Authenticity is non-negotiable.** Personal stories and genuine insights outperform polished corporate messaging on every platform.
8. **Community > Audience.** 1,000 real fans who interact > 10,000 silent followers. Brands with active communities see materially higher retention -- reported lifts run ~40% (Higher Logic; widely cited ~2021, verify currency before quoting).

---

## Platform Selection

Not every platform matters. Pick 2-3 based on your audience and goal.

| Goal | Primary | Secondary | Launch |
|------|---------|-----------|--------|
| B2B leads / thought leadership | LinkedIn | Twitter/X | - |
| Developer audience | Twitter/X | YouTube | Hacker News |
| Brand awareness (B2C) | TikTok | Instagram | - |
| Product launch | Twitter/X | LinkedIn | Product Hunt, HN, Reddit |
| Community building | Twitter/X | Reddit | Discord |
| E-commerce / visual | Instagram | TikTok | - |
| Indie maker / solo creator | Twitter/X | LinkedIn | PH, HN, Reddit |

### Lean Content Stack

**Primary Hub** (choose one): Newsletter, YouTube, or Blog
**Distribution** (choose 2-3): Twitter/X, LinkedIn, Instagram
**Launch platforms** (use strategically): Product Hunt, Hacker News, Reddit —
launch *strategy* and one-off assets (PH tagline, HN title, channel sequencing)
come from the caller's launch plan (if absent, ask the caller); this skill owns
the ongoing launch threads and comment engagement

**Weekly workflow:**
1. Create one long-form piece (hub content)
2. Fragment into 5-10 platform-specific posts
3. Engage 15-20 min/day on each active platform
4. Review analytics weekly; adjust monthly
5. Build email list from day one

For detailed platform strategies, algorithms, and formatting -- read `references/platforms.md`.

---

## Content Strategy Framework

### 1. Define Content Pillars (3-5 themes)
Content pillars are the core topics you consistently create around. Algorithms reward topic consistency -- LinkedIn explicitly tracks it, YouTube evaluates channels holistically, TikTok builds micro-community clusters. Going deep on a niche beats being broad.

Each pillar should:
- Align with your product's value proposition
- Address your audience's pain points and interests
- Be broad enough for many pieces, specific enough to be ownable

### 2. Map Pillars to Platforms
Match content themes to platform strengths. Not every pillar works everywhere.

### 3. Build Repurposing Workflow (Waterfall System)
One piece of content, many platforms and formats:

```
Long-form (blog/video/podcast)
  -> Twitter thread + LinkedIn post
  -> Instagram carousel + TikTok clip
  -> Email newsletter excerpt
  -> Quote graphics + audiograms
```

### 4. Create Editorial Calendar
Plan weekly, batch creation, schedule distribution. See `references/topic-clusters.md` for calendar templates and batching system.

### 5. Measure and Optimize
Track engagement per pillar and platform. Double down on what works. See `references/metrics-benchmarks.md` for benchmarks and what to track.

---

## Content Creation Process

1. **Check context** -- Read product brief for product/audience info
2. **Choose platform and format** -- Match content to platform strength (see `references/platforms.md`)
3. **Write the hook first** -- Use frameworks from `references/post-templates.md`
   - Hook-Story-Offer (HSO): hook, relatable narrative, present solution
   - Hook-Retain-Reward (Hormozi): stop scroll, maintain attention, deliver value
   - PAS: Problem, Agitation, Solution
4. **Apply viral psychology** -- Content spreads via high-arousal emotions: awe (positive), anger and anxiety (negative) all boost sharing; low-arousal sadness suppresses it (Berger & Milkman, 2012). Optimize for shares, not just likes. See `references/reverse-engineering.md` for the science.
5. **Follow 80/20 rule** -- 80% pure value, 20% product mention (stricter on Reddit: 90/10)
6. **Plan repurposing** -- How does this fragment for other platforms?
7. **Engage after posting** -- Respond to comments within 30-60 min. Comments-as-content — replies with standalone-quality insight, later mined as new posts — is one of the most underused growth tactics.

---

## Hook System (Quick Reference)

### Curiosity Hooks
- "Most people don't know this about [topic]..."
- "I spent [time] studying [topic]. Here's what I found:"
- "The real reason [outcome] happens isn't what you think."

### Story Hooks
- "3 years ago, I [struggle]. Today, [outcome]."
- "I almost [gave up/failed] when [pivotal moment]..."
- "Here's a story I've never shared:"

### Value Hooks
- "[Number] [things] I wish I knew about [topic]:"
- "Stop doing [common mistake]. Do this instead:"
- "How to [desirable outcome] (without [common pain]):"

### Contrarian Hooks
- "[Common belief] is wrong. Here's why:"
- "I stopped [common practice] and [positive result]."
- "Everyone talks about [X]. Nobody mentions [Y]."

### Data Hooks
- "We analyzed [N] [things]. Here's what the data shows:"
- "[Surprising statistic]. Here's why that matters:"

For the full hook library, content frameworks (HSO, AIDA, PAS, STEPPS), and platform-specific templates -- read `references/post-templates.md`.

---

## Build-in-Public Framework

Building in public creates authentic content and compounds audience before launch.

**What to share:**
- Revenue numbers and user milestones (transparent, real)
- Technical challenges and how you solved them
- Failed experiments and learnings
- Feature decisions and the reasoning behind them
- Customer feedback stories

**Where to share:**
- Twitter/X (#buildinpublic), Indie Hackers, Reddit (r/SideProject, r/startups)
- LinkedIn for professional narrative, personal blog for long-form

**Why it works:** People root for transparent builders. Behind-the-scenes content triggers relatability and trust. Launching to an already-invested build-in-public audience typically converts far better than a cold Product Hunt push alone.

---

## Community Building

Community > broadcast. The shift from audience to community is real.

**Implementation:**
- **Reply to every comment** thoughtfully (not just "Thanks!"). 73% of consumers will switch to a competitor if a brand doesn't respond on social (Sprout Social; widely cited ~2021, verify currency before quoting).
- **Ask follow-up questions** to deepen conversations
- **Turn great comments** into new post ideas
- **Create exclusive spaces** (broadcast channels, Discord, groups) for superfans
- **Feature community members** in your content
- **Facilitate member-to-member connections** -- not just you-to-them
- **Have a plan for negative virality.** If a post draws a pile-on, respond calmly once, don't feed the outrage, and know when to mute or disengage -- high-arousal anger spreads fastest

**Micro-communities** (Twitter Communities, LinkedIn Groups, Instagram Broadcast Channels) often outperform large passive followings.

---

## Practitioner Methods (Quick Summary)

| Creator | Platform | Method | Key Insight |
|---------|----------|--------|-------------|
| **Justin Welsh** | LinkedIn | Daily post, niche down, 45-min engagement window | Profile = storefront. Content > newsletter > digital products. ~$4M+/yr solo, zero paid ads. |
| **Alex Hormozi** | Multi | Long-form first, repurpose everything, Hook-Retain-Reward | "Give 10x more value than expected." Volume + clarity. $4M content budget. |
| **Naval Ravikant** | Twitter/X | Extreme brevity, timeless principles, low frequency | 5-10 posts/month. Each ignites platform-wide discussion. Quality compounds. |
| **Sahil Bloom** | Twitter + Newsletter | Zone of Genius, frameworks as pillars, newsletter as hub | Intersection of skills, passion, and market need. |

---

## When to Read Which Reference

| Scenario | Reference |
|----------|-----------|
| Platform-specific strategies, algorithms, formatting | `references/platforms.md` |
| Hook formulas, content frameworks, post templates | `references/post-templates.md` |
| Viral psychology, reverse-engineering creators, why content spreads | `references/reverse-engineering.md` |
| Content pillars, topic clusters, editorial calendars, repurposing system | `references/topic-clusters.md` |
| Engagement benchmarks, metrics to track, analytics framework | `references/metrics-benchmarks.md` |

---
