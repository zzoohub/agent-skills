# Platform-Specific Strategies

Detailed strategy, algorithm mechanics, formatting, and best practices for each platform. Updated for 2025-2026.

---

## Table of Contents

1. [LinkedIn](#linkedin)
2. [Twitter/X](#twitterx)
3. [Instagram](#instagram)
4. [TikTok](#tiktok)
5. [YouTube](#youtube)
6. [Reddit](#reddit)
7. [Product Hunt](#product-hunt)
8. [Hacker News](#hacker-news)
9. [Cross-Platform Principles](#cross-platform-principles)

---

## LinkedIn

### Algorithm Mechanics
LinkedIn is fundamentally different from other platforms -- it's designed to **prevent virality**, not encourage it. The algorithm prioritizes relevance to professional interests over raw engagement.

**Three-step filter:**
1. **Content quality check** -- spam detection, engagement bait filtering (aggressive in 2025-2026)
2. **Early engagement test** -- shown to small subset; comments and dwell time measured
3. **Broader distribution** -- if early signals are strong, shown to wider network

**Key signals (in order of weight):**
- Comments and meaningful discussions (comments >> likes)
- Dwell time (how long people spend reading)
- "See more" clicks (longer posts that hold attention)
- Topic relevance to viewer's professional interests
- Creator recognition (consistent posting on a specific topic builds algorithmic authority)

**Important:** Posts can resurface 2-3 weeks later if still relevant. LinkedIn values relevance over recency.

### Content Formats

| Format | Engagement | Best For |
|--------|-----------|----------|
| Carousel (PDF) | Highest | Frameworks, step-by-steps, data |
| Text-only post | High | Stories, insights, hot takes |
| Document post | High | Guides, checklists |
| Native video | Medium | Behind-scenes, talking head |
| Poll | Medium | Engagement, research |
| Newsletter | Medium | Recurring thought leadership |
| External link | Low | Blog traffic (put link in comments) |

### Posting Strategy
- **Frequency**: 1x/day (Justin Welsh posts daily, early morning East Coast)
- **Best times**: Tue-Thu, 8-10am local time
- **Post length**: 1,200-1,500 characters sweet spot. Longer posts trigger "see more"; the click is widely believed (industry consensus, not LinkedIn-documented) to function as a dwell/engagement signal.
- **Hashtags**: 3-5 relevant, in the post itself (LinkedIn retired the Creator Mode toggle in March 2024 and removed profile topic hashtags, so hashtags no longer carry a profile-level role)

### Tactical Playbook
- **First 45 minutes are critical** -- respond to all comments immediately. Welsh's rule: engage within 45 minutes.
- External links suppress reach -- put links in first comment
- Carousels keep users on-platform longer = more algorithmic favor
- Tag people sparingly and only if they'll engage back
- Engage with 6-8 professionals in your niche weekly
- **Profile optimization**: Banner = clear CTA, Headline = value proposition, Featured section = storefront, About = PAS narrative

### Formatting Template
```
[Hook line -- bold statement, question, or surprising insight]

[Line break]

[Short paragraph -- context, story, or setup]

[Line break]

[Bullets or numbered list -- the core value]
- Point 1
- Point 2
- Point 3

[Line break]

[Closing thought or question to drive comments]

#hashtag1 #hashtag2 #hashtag3
```

---

## Twitter/X

### Algorithm Mechanics
Three-stage pipeline via "Home Mixer": candidate retrieval (~1,500 tweets), ranking, filtering.

**Engagement scoring weights -- historical** (the 2023 open-sourced "heavy ranker", relative to a like = 0.5):
- Reply: **13.5** (a reply the author responds to: **~75**)
- Profile click + engagement: **12**
- Conversation click + reply/like: **11**; conversation click + stay ≥2 min: **10**
- Retweet: **1.0** (~2x a like)
- Like: **0.5**
- Negative feedback / report: heavily negative (−74 / −369)

**Current ranker (re-verify):** in January 2026 X open-sourced the Grok-based transformer that now ranks the For You feed (`xai-org/x-algorithm`, substantially updated May 2026); it replaces the 2023 heavy ranker, so the weights above are history, not current values. Check that repo before quoting any weighting.

**Takeaway (from the 2023 release):** replies and dwell dominated; retweets were only ~2x a like -- the widely-quoted "20x retweet" is a myth. Optimize for replies and save-worthy depth, not just retweets.

**Critical window:** First 2 hours determine reach. Speed of engagement matters more than total engagement.

**X Premium (formerly Twitter Blue):** gives a real visibility boost -- the 2023 open-sourced code multiplied verified (Premium) authors' scores ~4x in-network and ~2x out-of-network; re-verify against the current ranker. Pay-to-play matters for serious growth.

### Content Formats

| Format | Best For |
|--------|----------|
| Thread (5-15 tweets) | Deep dives, tutorials, stories |
| Single tweet | Hot takes, observations, one-liners |
| Quote tweet + insight | Riding trending topics |
| Poll | Quick engagement |
| Image + text | Data, screenshots, infographics |
| Video (< 2 min) | Demos, behind-scenes (2-4x more reach than text) |

### Posting Strategy
- **Frequency**: 3-5 tweets/day for growth (mix of original + replies)
- **Best times**: Mon-Fri, 8-10am and 12-1pm
- **Thread length**: 5-15 tweets, front-load value
- **Hashtags**: 0-2 (less is more on Twitter)

### Tactical Playbook
- **First tweet of a thread determines everything** -- invest 80% of effort there
- Media-rich tweets get ~2x algorithmic boost vs text-only
- Replies and conversations boost reach more than likes
- Engage in others' threads to build reciprocity
- Quote tweets with added insight > plain retweets
- Respond to replies within first 30 minutes
- Build "reply chains" with high-influence accounts in your niche

### Thread Structure
```
Tweet 1 (Hook): [Bold claim or promise -- this determines everything]

Tweet 2: [Context -- why this matters, personal credibility]

Tweets 3-N: [Content -- one point per tweet, visual when possible]

Tweet N+1: [Summary or actionable takeaway]

Tweet N+2: [CTA: "If this was helpful, RT the first tweet so others see it too."]
```

---

## Instagram

### Algorithm Mechanics
Instagram runs **separate algorithms** for Feed, Stories, Reels, and Explore. As of the 2024-2025 rollout, "Views" became the headline metric across most formats (verify per-format/region, as rollout varied).

**Key signals (2025-2026):**
- **DM shares are the strongest signal.** If users send your content to friends, the algorithm treats it as highly distributable. Design content that passes "the DM test" -- would someone send this to a specific friend?
- Watch time: 50%+ must watch past the first 3 seconds or content gets deprioritized
- Saves and shares weight more than likes
- Originality: algorithm detects duplicate sounds, recycled formats, heavily templated visuals

**Engagement behavior shift:**
- Comments per post fell -16%
- Shares per post rose +12%
- DM sharing is now the dominant signal

### Content Formats

| Format | Reach | Engagement | Best For |
|--------|-------|-----------|----------|
| Reels (up to 3 min since Jan 2025; short still common) | Highest | 2.46% avg | Discovery, trends, reach |
| Carousels (slides) | High | Highest | Education, tips, shareable |
| Stories | Low (followers only) | High | Daily updates, polls, depth |
| Static post | Medium | Medium | Quotes, announcements |
| Collab posts | Very High | High | Shared audiences |

### Posting Strategy
- **Frequency**: 1-2 posts/day + 3-5 Stories
- **Optimal mix**: 3-4 Reels/week + 2-3 carousels + 1-2 static posts
- **Best times**: Mon-Fri, 11am-1pm and 7-9pm
- **Caption**: First 125 chars visible -- front-load hook
- **Hashtags**: up to 5 relevant (Instagram began capping post and Reel captions at 5 hashtags in Dec 2025)

### Tactical Playbook
- Design content people want to **send to friends** (the "DM test")
- First 3 seconds must hook -- text overlays, pattern interrupts, surprising visuals
- Carousels for educational/shareable; Reels for reach
- Stories with interactive stickers (polls, questions) boost algorithm signals
- Optimize captions with searchable keywords (Social SEO)
- Use alt text for discoverability and accessibility
- Collaborate via Collab posts for shared audiences
- Post consistently -- gaps reduce reach

### Carousel Best Practices
```
Slide 1 (Cover): Hook -- bold text, visual intrigue, curiosity gap
Slides 2-8: Content -- one point per slide, large readable text
Final slide: CTA -- "Save this", "Share with a friend", "Follow for more"
Design: Consistent brand colors, readable fonts, minimal text per slide
```

---

## TikTok

### Algorithm Mechanics
**Reported 2025-2026 shift: follower-first testing** (creator-observed, not officially documented — verify before betting a strategy on it): new videos appear to be shown to existing followers first, with follower performance gating non-follower reach. If it holds, it moves TikTok from "anyone can go viral" toward loyal-follower-base-first.

**Three main signals:**
1. User interactions (watch, like, share, comment, skip)
2. Video information (captions, hashtags, sounds)
3. User information (language, country, device)

**Critical metrics:**
- Rewatch/loop rate (highest priority)
- Completion rate: creators report **~70%+ for viral reach in 2026** (vs ~50% cited for 2024) — directional, no official threshold exists
- Shares and meaningful comments
- "Qualified Views" = users watching past the 5-second mark

**"Micro-virality" model:** Algorithm is built around communities, not random viral hits. Niche focus builds algorithmic identity.

### Content Formats

| Format | Best For |
|--------|----------|
| Short video (15-60s) | Quick tips, reactions, trends |
| Medium video (1-3 min) | Tutorials, stories, explainers |
| Duet/Stitch | Reacting to others, adding context |
| Photo carousel | Listicles, before/after |
| Live | Q&A, building community |

### Posting Strategy
- **Frequency**: 1-4x/day (but quality over quantity in 2026)
- **Video length**: 30-60 seconds sweet spot
- **Hashtags**: 3-5, include 1-2 trending + niche
- **Best times**: Check TikTok analytics -- varies widely by audience

### Tactical Playbook
- **Build loyal follower base first** -- if the reported follower-first testing holds (see above), they are your "test audience"
- Create content that encourages rewatches (hidden details, complex info, satisfying loops)
- Keep niche-focused to build community identity
- Front-load the hook in first 1-2 seconds
- Use trending sounds but with original visuals and angles
- Captions/subtitles improve completion rates
- Reply to comments with video for extra reach
- Don't delete underperforming videos -- they can resurface

### Content Formula
```
0-1 sec: [Hook -- text on screen + verbal hook, pattern interrupt]
1-3 sec: [Setup -- context for the value, build curiosity]
3-30 sec: [Delivery -- the actual content, tight and dense]
30-60 sec: [Payoff + CTA or loop back to start for rewatch]
```

---

## YouTube

### Algorithm Mechanics
YouTube runs **five separate recommendation systems**: Home, Suggested Videos, Search, Subscriptions, and Shorts. Each has different ranking factors.

**Satisfaction-weighted discovery** (long-running and increasingly weighted — survey-based "valued watchtime", not new in 2025): beyond clicks and watch time, YouTube measures whether viewers **felt their time was well spent**. High-satisfaction content gets boosted.

**Key insights:**
- Shorts recommendation engine is now **fully decoupled** from long-form (poor Shorts won't drag down your long-form)
- **Channel-level evaluation** -- YouTube judges channels holistically, not just individual videos
- New channels can gain traction based on content quality alone -- subscriber count matters less
- 3 uploads/week = 8x faster view growth, 3x faster subscriber growth vs <1/month

### Content Formats

| Format | Best For |
|--------|----------|
| Long-form (8-20 min) | Authority, deep dives, tutorials |
| Shorts (up to 3 min since Oct 15, 2024; square or vertical) | Discovery, top-of-funnel |
| Live streams | Community, events, Q&A |
| Community posts | Engagement, polling, updates |

### Posting Strategy
- **Long-form frequency**: 3/week for growth (or 1-2 for consistent quality)
- **Shorts frequency**: 3-5/week for discovery
- **Focus**: Thumbnails and titles are the most critical investment

### Tactical Playbook
- Invest heavily in **thumbnail design and A/B testing** -- CTR determines everything
- First 30 seconds determine retention; front-load value or curiosity
- Structure videos with **pattern interrupts every 2-3 minutes** to maintain retention
- Create "bingeable" content series that encourage session time
- Use Shorts as top-of-funnel, long-form for depth and authority
- End screens and cards for cross-video promotion
- Community tab for audience engagement and polling

### Video Structure
```
0-30s: Hook + promise (what viewers will get)
30s-2m: Context (why this matters)
2m-end: Delivery (structured value with pattern interrupts every 2-3 min)
Last 30s: CTA (subscribe, next video, link in description)
```

---

## Reddit

### Algorithm Mechanics
Community-driven; each subreddit has unique norms. ~130M daily active uniques, ~515M weekly (Q2 2026 earnings: 130.3M DAUq, 514.6M WAUq).

**Key signals:**
- Upvote velocity -- fresh posts with fast early upvotes surface quickly
- Comment quality and depth signal value
- Ring detection is sophisticated -- coordinated upvoting = domain bans

### The 90/10 Rule
- **90% pure value contribution** (answering questions, sharing insights, helping others)
- **10% subtle product mentions** (only when genuinely relevant)
- Listen first, post second -- understand subreddit culture before participating

### Posting Strategy
- **Minimum**: 6-8 weeks of consistent engagement before posting own content
- **Daily**: 15-20 minutes genuine participation
- **Build karma** through helpful comments first
- **Frame**: "Sharing what I learned" not "promoting my product"

### Tactical Playbook
- Target relevant subs: r/Entrepreneur, r/startups, r/SideProject, r/indiehackers, niche-specific
- AMA sessions generate thousands of interactions
- Behind-the-scenes and transparency content resonates strongly
- "Build in public" stories with honest numbers
- **Never** use multiple accounts for upvoting
- Share genuine expertise; Reddit's audience is highly BS-sensitive
- Comment quality > post quantity

### What Gets Upvoted
- Original research or data analysis
- Honest failure stories with specific lessons
- Detailed how-to posts with actual steps
- Resources that save people significant time
- Transparent revenue/growth posts

---

## Product Hunt

> Launch *strategy* — the timing call, tagline, channel sequencing — belongs to the caller's launch plan; on conflict it wins. This section is platform mechanics for the launch threads and comment engagement this skill owns.

### Pre-Launch (30+ days before)
1. Start participating in PH discussions (comments, upvotes, feedback to other makers)
2. Build "hunter" network -- get people to follow your product page and maker profiles
3. Prepare assets: compelling headline, description, gallery images, video demo
4. Structure: headline communicates value, supporting sentence reinforces, gallery feels connected

### Launch Day Execution
1. **Launch at 12:01 a.m. Pacific Time** (PH's daily leaderboard reset; PST or PDT depending on the date) for maximum voting window
2. Assign one person to own the PH thread and respond to ALL comments
3. Have first comment ready: explain the "why" behind the product
4. **Announce your launch to your existing audience** (newsletter, social followers, customers) — they can decide to engage or not. ⚠️ **Do NOT coordinate upvotes via private DMs or pre-arranged "helpers"** — that violates Product Hunt's community guidelines and can result in delisting or account ban. See the "Ethical vs prohibited launch tactics" box below.
5. Respond to every comment within minutes

### Title/Positioning Formula
- Use simple language
- Clearly state who the product is for
- Lead with the problem solved, not features
- Example: "Loom -- Video messaging for work" (clear, benefit-focused)

### Post-Launch
- Thank supporters personally
- Follow up with everyone who signed up
- Collect and act on feedback
- Can relaunch with significant product iterations (PH allows multiple launches)

### What Kills a Launch
- Asking publicly for upvotes (against PH rules)
- Generic description that could apply to any product
- No video or demo
- Slow comment response
- No pre-launch community

---

## Hacker News

> Same ownership note as Product Hunt above: launch strategy and the one-off title are the launch plan's call; this section covers HN mechanics for the threads and comments this skill owns.

### Algorithm & Ranking
- Time-decayed vote scoring: score ≈ (points − 1) / (age in hours + 2)^1.8, times penalties -- the score decays continuously with age, not in fixed steps
- A story with 10 upvotes in 15 minutes outranks one with 50 upvotes in 6 hours
- High-karma comments amplify visibility
- Aggressive filtering of voting rings -- domains can be banned permanently

### Optimal Timing (Pacific Time)
- **Best**: Tuesday-Thursday, 8:00-10:00 AM (engineers reading before standup)
- **Alt**: Sunday 6:00-9:00 PM (low competition, engaged audience)
- **Avoid**: Friday afternoons, Monday mornings

### Title Formula
- **45-65 characters** for full mobile display
- Front-load quantifiable results
- Use digits, version numbers, or time-boxed results
- Example: "Show HN: I cut my AWS bill 82% with a 200-line Lambda"
- **Avoid**: listicles, superlatives, clickbait, marketing language

### Content Requirements
- 1,200+ words with original visuals and novel insights
- Best formats: technical deep-dives with benchmarks, Show HN with live demo + GitHub repo, failure/revenue transparency posts
- Must feel educational, not promotional

### First 30 Minutes Playbook
1. Post from a stable network (avoid known VPN IPs that can look like ban-evasion)
2. Add a 60-word TL;DR as first comment
3. **Share your submission with your existing audience** (newsletter, followers, mailing list) — readers choose to engage or not. ⚠️ **Do NOT coordinate votes** via DMs, Slack channels, or pre-arranged helper groups. HN's guidelines explicitly forbid this ("Please don't ask people to upvote / downvote / flag") and detect voting rings aggressively — entire domains can be banned permanently. See "Ethical vs prohibited launch tactics" below.
4. Respond to all comments within 10 minutes
5. Share demo/repo as a top-level comment

### What Kills Submissions
- Duplicate content, paywalls, email gates
- Multiple title edits (resets timestamps)
- Public upvote requests
- Fresh accounts without comment history
- Any paid upvote services
- **Vote coordination via DM / Slack / chat groups** — same penalty as paid upvotes

---

## Ethical vs Prohibited Launch Tactics (HN & Product Hunt)

These platforms both rely on community-driven ranking, and both explicitly prohibit organized voting. The line is sometimes mis-drawn — here's the clear version:

| ✅ Legitimate ("ship to your audience") | ❌ Prohibited (vote manipulation) |
|---|---|
| Email your newsletter that your product launched, with a link | DM specific people: "please upvote my launch at 9am" |
| Tweet "we just launched on Product Hunt" with the link | Pre-coordinate a Slack/Discord group to upvote in the first 30 minutes |
| Mention to existing customers that you're on Show HN today | Create a list of "supporters" instructed to upvote and comment with talking points |
| Reply to people who ask about your work | Pay for upvotes or use bot networks |
| Build genuine HN/PH presence months before launch (comments, feedback to others) | Create fresh accounts to upvote your own submission |
| Ask for feedback on your launch ("would love your thoughts") | Ask for upvotes ("please upvote my launch") |

**Why the distinction matters:** "I shipped, here's the link" lets the recipient decide. "Please upvote me at 9am" coordinates their behavior — that's a voting ring. Both platforms' detection is sensitive to *coordinated timing*, *talking-point similarity in comments*, and *vote sources clustered to one network or org*. Soft enforcement is shadowban; hard enforcement is domain/account permanent ban.

When in doubt: **announce your launch broadly, never instruct specific behavior.**

---

## Emerging Platforms (2025-2026)

For tech / B2B / creator audiences these are real distribution channels now — worth adding to the platform mix.

### Bluesky
- AT Protocol-based; growing rapidly through 2025 as a Twitter/X alternative for tech, journalism, science, dev audiences
- Tone: closer to early Twitter — casual, conversational, fewer hot takes
- **Custom feeds** (algorithmic feeds anyone can publish) are the underrated leverage — get into the right feeds to multiply reach
- No formal ad platform yet; organic-only
- Cross-post from Twitter/X carefully — recycled Twitter content often falls flat

### Threads (Meta)
- Tied to Instagram identity; algorithmic feed favoring engagement
- Tone: lighter than LinkedIn, more visual than Twitter
- Image + short text posts outperform pure text
- Federated with the fediverse (ActivityPub) but most reach is in-app
- Good for consumer brands with existing Instagram audience

### Mastodon / Fediverse
- ActivityPub federation across many independent servers
- Tech-leaning, anti-algorithm audience; chronological feed
- No central "algorithm to game" — growth is via genuine threads + boosts
- Cross-posting from Twitter/X is tolerated but native-first does better
- Often ignored for marketing because it doesn't scale like ad platforms — but a passionate niche audience for OSS / privacy / developer tools

### Substack Notes
- Twitter-style notes attached to a Substack publication
- Audience = your newsletter subscribers + Substack network discovery
- Strongest for writers / thought leaders who already have a Substack

---

## Cross-Platform Principles

### What Works Everywhere
1. **Hook fast** -- first line/second determines everything
2. **Native content** -- adapt, don't duplicate across platforms
3. **Consistency** -- regular posting beats occasional virality
4. **Engagement** -- reply to comments, don't just broadcast
5. **Value first** -- teach, entertain, or inspire before promoting

### Content Adaptation (Not Duplication)

Same insight, different execution:

| Platform | Adaptation |
|----------|-----------|
| LinkedIn | Professional framing, business impact, structured post, ask a question |
| Twitter/X | Punchy take, thread for depth, conversational tone, visual media |
| Instagram | Visual carousel, aesthetic, save-worthy, DM-shareable |
| TikTok | Talking head, authentic, trend-adapted, subtitles, loop-friendly |
| YouTube | Long-form authority piece, strong thumbnail, retention structure |
| Reddit | Educational framing, honest/transparent, community-first language |
| PH/HN | Technical depth, show results with data, demo/repo links |

### Platform-Specific Engagement Windows

| Platform | Critical Window | Action |
|----------|----------------|--------|
| LinkedIn | First 45 min | Reply to all comments |
| Twitter/X | First 2 hours | Engage in replies |
| Instagram | First 1 hour | Reply + story boost |
| TikTok | First 1 hour | Reply to comments (video replies) |
| YouTube | First 24 hours | Reply to comments, community post |
| Reddit | First 1 hour | Upvote velocity is everything |
| HN | First 30 min | 8-10 upvotes + thoughtful comments |
