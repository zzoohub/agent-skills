# Platform Mechanics and Launch Rules

Last verified: 2026-10-08. Each mechanic names its source; ranking systems change often, so re-check the source before quoting one to anyone. Claims about timing, length, hashtags, link placement and format, here or anywhere else, are hypotheses: test one variable at a time on this account, at least 6-8 posts per arm, and compare medians, since one outlier post drags a mean.

## Contents

1. [Feed mechanics](#feed-mechanics)
2. [Launch-day copy](#launch-day-copy): Show HN, Product Hunt, Reddit

Per-format execution (text post, thread, carousel, video) is in `references/social/post-templates.md`.

## Feed mechanics

Only mechanics that change a writing decision.

**X** (the For You ranker, published at `github.com/xai-org/x-algorithm`; its weights change often, so read the repo before quoting one):
- A post's score is a weighted sum of the *predicted probability* of each action, negative ones included: not interested, mute, block, report, no dwell. Weights apply to probabilities, not counts, so "one reply = N likes" is a misreading. An oversold hook earns the negatives.
- Posts from accounts the viewer doesn't follow are discounted; each further post from the same author in one feed is decayed, so space posts out; authors with few impressions get a lift.
- Posts older than 48 hours leave the candidate pool.
- A parameter comment in the code (`home-mixer/params/param.rs`) reads: "Directly navigating to a post (i.e., coordinating via groupchat) has no ranking impact." Blasting the link to a group chat buys no ranking.

**LinkedIn**:
- Dwell time is a ranking signal (LinkedIn Engineering, 2020): a post people stop to read beats one they like in passing.
- The Professional Community Policies forbid artificially increasing engagement, including agreeing in advance to like or reshare each other's content: no pods, no comment rings.

**Instagram**:
- The ranking explainer (about.instagram.com, 2023) predicts, for Reels: reshares, full watches, likes and audio-page visits; for Feed: time spent, comments, likes, shares and profile taps. Low-resolution, watermarked, muted, bordered or mostly-text reels, and reels already posted on Instagram, are shown less: cut repurposed clips to native vertical.
- Instagram's head (January 2025): watch time, likes per reach and sends per reach matter most; sends weigh more for reaching non-followers, likes for followers. Ask: would someone send this to one specific person?

**TikTok** ("How TikTok recommends videos #ForYou", TikTok Newsroom, 2020): finishing a longer video is a strong signal; follower count and past hits are not direct factors, so each video is judged on its own; make the topic plain in the first seconds.

**YouTube** (YouTube Help):
- Test & Compare tries up to 3 titles and thumbnails and picks the winner by watch time, not click-through: a title that misleads loses.
- Judge impressions CTR only against your own videos and traffic sources; half of channels sit between 2% and 10%, and CTR falls as impressions widen.

**Reddit**: Reddit's rules ban vote manipulation and bind you to each community's rules; the subreddit's sidebar is its self-promotion policy.

**Bluesky, Threads, Mastodon and newer networks**: same method; read the platform's own documentation on how feeds are built before claiming a mechanic.

## Launch-day copy

This skill writes the launch-day copy; the caller's launch plan, if any, sets the date and order. Default order: stagger platforms by day, not by hour, unless a separate person staffs each thread. Break: if one platform is already carrying the launch, put everyone in that thread and push the others back. On your own channels, announce the product (site or repo). What you may ask for differs by platform:

| Platform | You may | Never |
|---|---|---|
| Show HN | Announce the product itself | Ask anyone to upvote, comment on or visit the HN item; circulate its link |
| Product Hunt | Share the Product Hunt page; ask people to visit and comment | Ask for upvotes, anywhere |
| Reddit | Post where the community's rules allow; say "I built this" | Ask for votes; use a second account |

Insiders who comment (team, investors, friends) say who they are in the comment.

### Show HN

Rules (news.ycombinator.com: `showhn.html`, `newsguidelines.html`, `newsfaq.html`):
- A Show HN is something non-trivial you made that people can try now, ideally without signup or email; not a quickly generated one-off. Blog posts, sign-up pages, newsletters, lists, landing pages and fundraisers can't be Show HNs; a point release ("Foo 1.3.1 is out") isn't enough.
- Title: the plain name and what it does; no editorializing; crop gratuitous numbers and adjectives. The submit form caps titles at 80 characters.
- Ranking divides points by a power of the story's age, then applies flags, anti-abuse software and moderator action. Solicited votes get submissions, accounts and sites penalized or banned.
- Never delete and repost. If a story got no significant attention, a small number of reposts is OK.

```
Title: Show HN: [Name] – [what it does, in plain words]          (≤80 characters)
URL:   [the product or repo, usable without signup]
First comment (≤300 words):
  [Who you are; the problem you hit: the backstory]
  [How it works: the approach and the interesting decision]
  [What's unfinished or deliberately left out]
  [The specific feedback you want]
```
The maker answers in the thread with specifics for the first 3-6 hours and concedes valid criticism.

### Product Hunt

Rules (producthunt.com/launch): hunt it yourself, since a third-party hunter gives no discernible advantage; 12:01 a.m. Pacific gives the full day; never ask for upvotes, anywhere; ask people to visit and comment; launch again only with a significant new iteration.

```
Tagline: [what it does] for [whom], plain words, within the form's limit; no superlatives
Description (≤60 words): [the job] → [what's different from the usual way] → [what's free]
Gallery, first image: the product doing the job, not a logo
Maker comment (≤250 words):
  [Why we built it: the problem, as one story]
  [What it does today, and for whom]
  [What's unfinished; a launch offer only if it's real]
  [The question we want answered]
```
One named person owns the thread all day and answers every comment.

### Reddit

Read the sidebar and the last 50 posts. If no maker post survived there this month, use the sanctioned promotion thread or just take part. Break: showcase subreddits that invite launches.

```
Title: [what I built] for [the problem this community has]; "I built" up front
Body (≤200 words):
  [Who you are; the problem as this community describes it]
  [What it does, what it costs, its limits]
  [The link, only where the rules allow]
  [The feedback you want]
```
Answer every question; never argue with a moderator's call.
