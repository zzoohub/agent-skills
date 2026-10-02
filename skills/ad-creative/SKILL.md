---
name: ad-creative
description: |
  Ad creative development, copy generation, and batch creative production across platforms.
  Use when: creating ad copy, designing ad campaigns, generating ad variations, writing
  headlines/descriptions for ads, creating display/social/search ads, writing video ad scripts,
  or when user mentions "ad copy", "ad creative", "Facebook ads", "Google ads", "ad campaign",
  "ad variations", "ad headline", "display ad", "social ad", "PPC", "paid media creative",
  "TikTok ads", "LinkedIn ads", "UGC ads", "video ads", "hook", "scroll-stopping",
  "ad angles", "creative testing", "ad fatigue", "creative refresh".
  Do NOT use for: organic social content (use social-content skill), landing page copy
  (use copywriting skill), ad targeting/budget strategy (the caller's media plan, not creative),
  ad performance analysis (use product-analytics skill), or selecting/ethics-judging
  psychological principles themselves (use marketing-psychology skill).
---

# Ad Creative

Develop high-performing ad creative grounded in direct-response copywriting principles,
behavioral psychology, and platform-native production. This skill treats ad creation as
a science — every element has a reason, every variation has a hypothesis, and every
decision is testable.

---

## Deliverable Format

For each ad brief, produce:

1. **3-5 fully written ads** (the hero concepts across different angles/formats)
2. **A test plan** showing the hook/body/CTA/format variations to test (run them in isolation rounds — see Step 5)
3. **Landing page headline recommendation** for message-match

Each fully written ad must include:

| Field | Description |
|-------|-------------|
| **Platform** | Meta, TikTok, Google, LinkedIn, etc. |
| **Format** | Static image, video (duration), carousel, etc. |
| **Awareness Level** | Which of the 5 levels this targets |
| **Angle** | Which creative angle (Problem, Benefit, UGC, etc.) |
| **Framework** | Which copywriting framework (PAS, AIDA, BAB, etc.) |
| **Hook** | The first line / first 3 seconds |
| **Primary Text / Body** | Full ad copy |
| **Headline** | Platform headline field |
| **Description** | Platform description field (if applicable) |
| **CTA** | Button text or verbal CTA |
| **Visual Direction** | Image concept, mood, composition, or video storyboard |
| **Hypothesis** | Why this ad should work (1 sentence) |
| **Landing Page Headline** | Recommended LP headline for message-match |

For video ads, include a timestamped script table:
`| Time | Visual | Audio/Text Overlay |`

**Output:** when asked to save deliverables, write them to the marketing-assets dir (default `biz/marketing/assets/`; caller may redirect the `biz/<area>/` root). If no file-write capability is present, return the ads inline. Update an existing file in place rather than creating a duplicate.

**Drafts only.** Never launch, publish, or schedule an ad or campaign (or change live budgets/targeting) in an ad platform without the caller's explicit approval — produce the drafts and hand them back.

---

## The Creative Development Process

### Step 0: Gather the Brief (Intake)

Before diagnosing anything, collect the raw materials an ad needs. If the user's brief
is missing these, **ask 2-4 targeted clarifying questions first** — or state
clearly-labeled assumptions and flag any invented proof as `[INSERT REAL STAT]` so the
user knows what must be substantiated. **Never fabricate proof, offers, or numbers.**

Collect:
- **Product & core value prop** — what it does, the one transformation it delivers
- **Offer & price** — the specific offer, price, trial/guarantee terms
- **Audience & awareness level** — who they are and where they sit on the spectrum (Step 1)
- **Proof assets on hand** — testimonials, case studies, stats, logos, awards (use only real, substantiable proof)
- **Brand voice & visual constraints** — tone, do's/don'ts, mandatory elements
- **Mandatory disclosures/claims** — regulated-vertical rules, legal lines (see `references/ad-policy-compliance.md`)
- **Campaign objective & primary metric** — awareness, leads, or sales; how success is measured
- **Prior learnings** — past winners/losers

**Competitive / ad-library research**: before choosing an angle (Step 2), scan the Meta
Ad Library and TikTok Creative Center for the category — catalog competitor angles,
hooks, and formats; note saturated messages to avoid and white-space angles to exploit.
(Tools: Foreplay, Atria, Motion App.)

### Step 1: Diagnose the Audience's Awareness Level

Before writing a single word, determine where the audience sits on Eugene Schwartz's
awareness spectrum. This single decision shapes everything — headline approach, body
structure, CTA intensity, and creative format.

| Level | Audience State | Lead With | Example |
|-------|---------------|-----------|---------|
| **Unaware** | Doesn't know they have a problem | Story, pattern interrupt, identity | "Being the bottleneck isn't a badge of honor." |
| **Problem-Aware** | Feels the pain, no solution yet | Empathy + agitation of the problem | "Tired of manually sorting 200 support tickets daily?" |
| **Solution-Aware** | Knows solutions exist, hasn't chosen | Differentiation, mechanism, proof | "The only AI that reads context, not just keywords" |
| **Product-Aware** | Knows your product, hasn't bought | Social proof, risk reversal, offer | "Join 12,000 teams already saving 15h/week" |
| **Most Aware** | Ready to buy, needs a push | Price, urgency, direct CTA | "Annual plan: 40% off — ends Friday" |

The lower the awareness, the longer the copy and the more indirect the approach.
The higher the awareness, the shorter and more direct.

### Step 2: Choose the Creative Angle

An angle is the persuasion frame that connects your product to what the audience
cares about. Pick one angle per ad — never mix.

| Angle | When to Use | Hook Style |
|-------|------------|------------|
| **Problem/Pain** | Audience actively suffering | Agitate the pain, then reveal solution |
| **Benefit/Outcome** | Audience wants transformation | Paint the after-state vividly |
| **Social Proof** | Audience needs validation | Lead with numbers, testimonials, logos |
| **Curiosity/Mystery** | Cold audience, pattern interrupt | Open a loop the viewer must close |
| **Authority/Expert** | B2B or high-trust purchases | Lead with credibility signal |
| **Before/After** | Visual transformation possible | Show the contrast dramatically |
| **UGC/Testimonial** | Platform rewards native feel | Real person, real language, raw footage |
| **Demonstration** | Product has visible "aha" moment | Show it working in 3 seconds |
| **Urgency/Scarcity** | Bottom-funnel, ready-to-buy | Deadline, limited quantity, disappearing offer |
| **Contrarian/Hot Take** | Saturated market, need differentiation | Challenge a common belief |

### Step 3: Select the Copywriting Framework

Match framework to awareness level and angle. See `references/copywriting-frameworks.md`
for detailed templates and examples.

| Framework | Best For | Structure |
|-----------|----------|-----------|
| **PAS** (Problem-Agitate-Solve) | Problem-aware, pain angle | Name pain > intensify > introduce solution |
| **AIDA** (Attention-Interest-Desire-Action) | Broad audiences, benefit angle | Hook > engage > create want > direct action |
| **BAB** (Before-After-Bridge) | Transformation angle | Current state > dream state > your product bridges the gap |
| **4Ps** (Promise-Picture-Proof-Push) | Product-aware, social proof angle | Bold claim > visualize result > prove it > CTA |
| **SSS** (Star-Story-Solution) | UGC, testimonial angle | Relatable person > their struggle > how product solved it |

### Step 4: Write the Ad — Hook, Body, CTA

Every ad has three parts. Allocate your effort accordingly: 80% on the hook
(as Ogilvy said, "when you've written the headline, you've spent 80 cents of
your dollar"), then body, then CTA.

**Hook (first line / first 3 seconds):**
- The hook's only job is to stop the scroll and earn the next sentence
- See `references/hook-science.md` for 12 hook categories with examples
- Benchmark: 30%+ hook rate on Meta, 40%+ on TikTok = strong

**Body (value delivery):**
- One angle per ad — in longer video ads (30s+), you can include supporting
  points that serve the same angle (e.g., pain angle: name the pain, show hidden
  costs, reveal consequences), but never mix angles (don't switch from pain to
  social proof mid-ad)
- Use specific numbers over vague claims ("Save 4h/week" not "Save time")
- Match copy length to awareness level (Unaware = long, Most Aware = short)

**CTA (single clear action):**
- Direct: "Start free trial", "Get 40% off", "Download now"
- Soft: "See how it works", "Learn more", "Watch the demo"
- Match CTA intensity to awareness level (low = soft, high = direct)

**Pricing placement by awareness level:**

| Level | Where to Place Pricing |
|-------|----------------------|
| Unaware / Problem-Aware | Don't mention price. Lead with value. |
| Solution-Aware | Mention price only if it's a competitive advantage ("From $19/mo") |
| Product-Aware | Include in CTA area with risk reversal ("14 days free, then $19/mo") |
| Most Aware | Lead with the deal ("40% off — $19/mo → $11/mo") |

**Visual direction (include for every ad):**
- **Static image**: Describe composition, subject, mood, color palette, text overlay placement
- **Video**: Include timestamped storyboard (`Time | Visual | Audio/Text`)
- **Carousel**: Describe each card's visual concept and how cards flow together
- Match visual style to platform culture: lo-fi/smartphone for TikTok, slightly polished for Meta, professional for LinkedIn, clean/minimal for Display

### Step 5: Generate Variations Systematically

Test **one variable at a time** so you can attribute the result (see
`references/creative-testing.md`). Build the full pool of options you *could* test,
but launch them in **isolation rounds** — not all at once:

```
Hook options:    3-5 (different angles or emotional triggers)
Body options:    2-3 (different value props or proof types)
CTA options:     2   (direct vs soft)
Format options:  2-3 (static, video, carousel)

Round 1 — Hooks:  3-5 hooks × 1 body × 1 CTA × 1 format        = 3-5 ads
Round 2 — Body:   winning hook × 2-3 bodies × 1 CTA × 1 format
Round 3 — CTA/format: winning combo × the remaining variables
```

(Running all combinations at once is full-factorial multivariate testing — the
cross-product is 24-90 ads, which needs a large budget AND makes it hard to tell
which element won. Reserve it for the exception below.)

**Exception — algorithmic diversity (Meta Advantage+, Google PMax):** when the
platform assembles and distributes the creative, upload maximum diversity at once and
let the algorithm find winners — here breadth beats isolation. See "Creative Diversity
Testing" in `references/creative-testing.md`.

For each variation, write a one-line hypothesis: "This hook works because
[psychological principle] for [awareness level] audience."

### Step 6: Compliance Pass (before launch)

Ad creative is what platforms review and regulators scrutinize. Before launching,
run every ad through the compliance checklist in `references/ad-policy-compliance.md`:
FTC disclosure on UGC/testimonial/creator ads (#ad, Paid Partnership, in-creative),
platform prohibited/restricted content (personal attributes, before/after, health,
finance), regulated-vertical rules (Special Ad Categories change available angles),
claims substantiation (every stat has proof on file — never fabricate), and
accessibility (alt text, captions, legibility).

### Step 7: Test, Learn, Iterate

See `references/creative-testing.md` for the full testing methodology.
The core loop:

1. Launch with equal budget across variations
2. Kill underperformers after sufficient data — spend/runtime is audience-specific (cold ~$300-500 / 5-7d, warm ~$100-200 / 3-5d; see `references/creative-testing.md`)
3. Analyze winners — identify the winning ELEMENT (hook? body? CTA? format?)
4. Create next batch: keep winning elements, vary the rest
5. Refresh before fatigue — cadence is platform-specific (TikTok ~weekly, Meta bi-weekly, Google/LinkedIn 4-6 weeks; see the fatigue tables)

---

## Platform-Native Creative Philosophy

Each platform has a native content style. Ads that match this style outperform
those that don't — often dramatically. **Creative is the dominant lever in paid media** — Nielsen Catalina Solutions (2017, ~500 CPG campaigns) attributed ~47% of advertising-driven sales lift to creative, the single largest factor; Google's "~70% of campaign performance" line is a Google exec's rule of thumb (not a formal study), and AppsFlyer calls creative the single biggest driver of UA performance. Whatever the exact figure, invest in creative before targeting or budget.

### Meta (Facebook/Instagram)
- **Video dominates**: 60%+ of user time is video; Meta recommends 4:5 for Feed (fills ~20% more screen than 1:1)
- **UGC outperforms polished**: Creator-shot clips beat studio productions on hook rate by 5-10 points
- **Front-load the hook**: First 125 chars of primary text (before "See more") are everything
- **Advantage+ and Andromeda**: Creative diversity matters more than creative volume; don't just iterate on winners — repurpose winning messages across new formats

### TikTok
- **Native-first**: Ads must feel like organic FYP content, not commercials
- **UGC ROI**: +55% ROI over non-UGC; unbranded UGC +19% better than branded (vendor figures, 2025-2026 — re-verify quarterly)
- **Lo-fi wins**: +81% ROI for content without logos or heavy overlays (vendor figures, 2025-2026 — re-verify quarterly)
- **Speed**: 90% of cumulative ad-recall impact lands in the first 6 seconds (TikTok Marketing Science); refresh every 7 days
- **Production**: Smartphone-shot, quick cuts every 2-3 seconds, TikTok-native editing (captions, green screen)

### Google Ads
- **RSA optimization**: Use all 15 headline slots; mix keyword-focused, benefit-focused, and CTA headlines
- **PMax assets**: 15 headlines + 5 long headlines + 5 descriptions + 20 images + 5 videos; more = better
- **Intent matching**: Search ads must match the user's search intent exactly — keyword in headline 1
- **Refresh**: Replace low-rated assets every 4-6 weeks

### LinkedIn
- **B2B thought leadership**: Thought Leader Ads deliver 1.7x higher CTR, 1.6x more engagement
- **Funnel-stage creative**: TOF = thought leadership content, MOF = lead gen, BOF = conversion
- **Professional tone but human**: Algorithm rewards meaningful conversations, not corporate speak
- **Refresh**: Every 4-6 weeks; narrow B2B audiences fatigue faster

### Display
- **Simplicity**: One message, one image, one CTA
- **Mobile-first**: Most impressions are mobile; design for small screens
- **Legibility**: Text must be readable at banner sizes (300x250 is most common)

### Reddit, Pinterest, Snap, X, YouTube Shorts, CTV (added 2026)
- **Reddit**: Native subreddit-style copy; AMA-format works; avoid corporate tone. Conversion ads work for B2B.
- **Pinterest**: Lifestyle / aspirational visuals; 2:3 vertical pins; women + commerce-heavy audience. Idea Pins for organic-ad hybrid.
- **Snap**: Vertical full-screen video; first 2s is everything; AR Lens / Sponsored Filters for brand lift.
- **X (Twitter)**: Hot-take copy + image / short video; engagement signals matter for placement. As of 2026, some advertisers observe it is underpriced for B2B reach — verify current pricing/reach before relying on this.
- **YouTube Shorts**: Vertical, hook in 1s, captions on. Skippable vs unskippable affects message length.
- **CTV (Netflix Ads, Disney+, Roku, Hulu, FAST channels)**: 15-30s spots; pair with frequency caps; pixel-based attribution is weak — use lift studies.

### Cross-Platform Adaptation

When adapting a winning concept across platforms, transform — don't just resize.

| Source Format | Target Platform | Adaptation |
|--------------|----------------|------------|
| Meta static (PAS copy) | TikTok video | Convert primary text to voiceover, replace image with screen recording or UGC talking head, strip all brand elements |
| TikTok UGC video | Meta Feed | Keep video but add primary text (PAS format), add headline field, may slightly polish thumbnail |
| Meta Feed ad | Google RSA | Extract core benefit into 30-char headline, pain point into description, keyword into headline 1 |
| Meta Feed ad | LinkedIn | Rewrite in professional/insight tone, add thought-leadership framing, adjust CTA from consumer to B2B |
| Meta carousel | Display banner | Distill to single strongest card's message, one image, one CTA, minimal text |

When adapting across **languages/markets**, transcreate — translate the *intent* of
hooks/headlines (not the words), adapt humor/proof norms per market, and re-check
character limits after translation (see the `i18n` skill for the structural side).

For full specs, character limits, and 2026 benchmarks per platform, see
`references/platform-specs.md`.

---

## Core Principles (The Non-Negotiables)

These principles come from decades of tested advertising — Hopkins, Ogilvy, Schwartz,
and modern performance data all converge on the same truths:

1. **Specificity beats generality** — "12,847 customers" not "thousands of customers"
2. **Benefits beat features** — "Fall asleep in 8 minutes" not "Contains melatonin"
3. **One message per ad** — Trying to say two things means saying nothing
4. **Message match is mandatory** — Ad headline must match landing page headline
5. **Test, don't guess** — Write 15-25+ headlines before picking (a direct-response discipline; Ogilvy's point was to *test* them, not a fixed count)
6. **Emotion drives action** — Losses feel roughly 2x heavier than gains in lab estimates (varies by context); use loss framing where it's real (for selecting which psychological principle to apply, see the marketing-psychology skill)
7. **Hook earns attention, body earns the click** — Without the hook, nothing else matters
8. **Platform-native beats platform-agnostic** — Reformat for each platform, don't just resize
9. **Creative quality > budget or targeting** — ~47% of CPG sales lift (Nielsen Catalina, 2017); ~70% of campaign performance (Google). Invest in creative first.
10. **Design for sound-off** — Most social video is watched muted; captions/text overlays required

---

## Attribution & Measurement (2026)

Platform-reported ROAS lies post-iOS 14.5. Build a real measurement stack:

| Layer | What it does | Tools |
|---|---|---|
| Server-side conversion API | Bypasses ITP/ETP cookie loss; deduplicates with pixel | **Meta CAPI**, **Google Enhanced Conversions**, **TikTok Events API**, **LinkedIn CAPI**, **Reddit CAPI**, **Pinterest Conversions API** |
| Mobile attribution | AdAttributionKit / SKAdNetwork + AppsFlyer / Adjust / Singular postback | **AdAttributionKit** (Apple's SKAN successor — no SKAN 5.0 is coming), SKAN 4.0, AEM |
| Blended / cross-channel | MER (Marketing Efficiency Ratio) = total revenue / total ad spend | **Triple Whale**, **Northbeam**, **Polar**, **Lifesight**, **Rockerbox** |
| Incrementality | Geo holdouts, ghost-ad tests, conversion lift studies | Meta Conversion Lift, Google Geo Experiments, in-house geo splits |
| Marketing Mix Modeling | Bayesian / classical MMM at scale | Robyn (Meta OSS), LightweightMMM (Google OSS), Recast |

**Default modern stack:** server-side conversion API on every platform + a blended-ROAS dashboard (Triple Whale / Northbeam / in-house) + at least quarterly geo or conversion-lift incrementality tests. Platform ROAS alone is no longer trustworthy.

### Generative Ad Creative

- **Meta Advantage+ Creative** (auto-generates background variations, image expansion, video versions) — give it a strong source asset, not all the variations yourself
- **TikTok Symphony** (TikTok's generative ad creative tool, 2024) — Creative Center + script generation
- **Google Asset Studio** — automated asset generation for PMax campaigns
- **Midjourney / Flux / Ideogram** for static creative; **Sora / Runway / Pika / Veo** for video shots
- **Foreplay / Motion App / Atria** for creative analytics + competitive ad library tracking

Tradeoff: generative speeds up *iteration*, not *strategy*. Brief still has to be human; without an angle, generative just produces faster slop.

---

## Reference Files

| Scenario | Reference |
|----------|-----------|
| Copywriting frameworks with templates and examples | `references/copywriting-frameworks.md` |
| Hook categories, formulas, and benchmarks | `references/hook-science.md` |
| Creative testing methodology and fatigue management | `references/creative-testing.md` |
| Platform specs, character limits, image dimensions | `references/platform-specs.md` |
| AI tools for image/video/audio generation | `references/generative-tools.md` |
| Ad policy, FTC disclosure, platform/vertical compliance | `references/ad-policy-compliance.md` |

---

## Ad Types Quick Reference

### Search Ads (Google/Bing)
- **Format**: Headlines (30 chars) + Descriptions (90 chars)
- **Key**: Match user search intent exactly
- **Framework**: Direct benefit or offer (Product/Most Aware audience)

### Social Feed Ads (Meta/LinkedIn)
- **Format**: Image/video + Primary text + Headline + Description
- **Key**: Stop the scroll with visual + hook in first line
- **Framework**: PAS or BAB for Problem/Solution-Aware; SSS for UGC

### Video Ads (TikTok/Reels/YouTube)
- **Format**: 6s bumper, 15s, 30s, 60s
- **Key**: Hook in first 3 seconds, value by 5s, CTA at end
- **Framework**: SSS for UGC; AIDA for polished; PAS for pain-angle

### Carousel Ads
- **Format**: 2-10 cards, sequential story
- **Key**: Each card must stand alone AND advance the narrative
- **Framework**: BAB across cards (Card 1: Before, Cards 2-3: After, Last: Bridge)

### Display Ads
- **Format**: Banner images in standard sizes
- **Key**: Simple message, clear CTA, brand visible
- **Framework**: Direct offer or single benefit claim

### Catalog / Dynamic Product Ads (Meta Advantage+ Shopping/DPA, Google Shopping)
- **Format**: Feed-driven — the platform assembles the ad from your product catalog
- **Key**: Optimize feed copy (product titles/descriptions), image quality, and overlays (sale / free-shipping badges); test dynamic vs single-product formats
- **Framework**: Direct benefit + price/offer; proof via in-feed reviews/ratings

### Retail Media (Amazon Ads, Walmart Connect, Instacart)
- **Format**: Sponsored Products, Sponsored Brands (headline + logo + image/video), Sponsored Display, Brand Store / A+ content
- **Key**: Intent-driven and conversion-proximate (closer to Google Search than social) — keyword/title relevance + tight-headline copywriting
- **Framework**: Direct benefit/offer; Product/Most-Aware audiences

---
