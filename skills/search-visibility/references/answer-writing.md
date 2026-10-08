# Answer Writing

Read this while briefing, drafting or revising a page meant to rank and be quoted: an article from a brief, a page fix, or the answers on a docs, pricing or product page. The brief and article specs come first; the claims rule is in SKILL.md's Step 3.

## Briefs and articles

Write from the matching spec (budget in words; file in the blog dir; sections are a menu).
- **Brief** (≤500; `briefs/{slug}.md`): cluster, queries and source; intent and rewarded format; what top results and cited sources lack, and first-hand input to collect (data, screenshots, a tested example; a YMYL reviewer); sub-questions as H2s, with a length range from what each must answer; title and H1 options; links in and out; eligible markup; `[SOURCE NEEDED]` list; success metric.
- **Article** (the brief's range, else one set from the sub-questions first; `{slug}.md`): title and meta description; its information gain up front; H2s that open with the lead answer (below); facts sourced or marked, including missing first-hand input (`[SOURCE NEEDED: first-hand <what>]`), never filler; internal links; alt text; a named author; the brand voice.

Before handing over: the article states its information gain or marks what it lacks; no mark covers a fact the caller's material holds, and an article with any open mark isn't ready to publish; no conversion or narrative section became Q&A blocks; the draft follows Brand Voice; no page targets a query a competitor-page draft owns.

## The lead answer

Open each section with a lead answer: one or two sentences that are true and complete out of context, then the evidence (numbers, conditions, steps, sources). Length follows the question: a definition takes a sentence, a procedure takes numbered steps, a decision takes a condition table ("A when…, B when…"). Name each section in the searcher's words ("How much does X cost?", not "Overview"). Replace a vague hedge with the condition that makes the claim true ("for teams under 50 seats"), never with false certainty; on health, money and legal topics, keep the caveat and make it specific.

Readers, featured snippets and AI engines lifting one passage all reward such sections: this is plain good writing, not an AI format. Google says its AI features need no special structure ("There's no requirement to break your content into tiny pieces"): there is no word count to hit and no reason to chop pages into fragments.

*Break:* narrative, brand and conversion copy (a manifesto, a landing page's argument) keeps its form, and a page that already ranks and converts gets additions, not a restructure.

## Three tests

1. **Self-contained:** the subject is named; no "this", "above" or "as mentioned".
2. **Front-loaded:** the answer is the first clause; the reasoning follows.
3. **Sourced:** every number, quote and named source traces to caller material or a source opened this session; otherwise a bracketed placeholder stays until one fills it.
   - Bad: "Headless storefronts load 35% faster, according to a 2024 commerce report." Nobody opened a report; the number is invented.
   - Good: "Headless storefronts loaded [stat] faster in [source]'s [year] test of [sample]", or `[SOURCE NEEDED: load-time change after moving to headless]`.

## Cited is not absorbed

Being cited and shaping the answer are different outcomes: one page is a token link while another supplies the definitions, numbers, comparisons and steps the answer is built from. In a 2026 study of 602 prompts and 21,143 citations across ChatGPT, Google and Perplexity, pages rich in those elements had more influence, and Q&A-format pages had no more than other pages (arXiv:2604.25707). Be the page that holds the fact; FAQ formatting and markup won't do it for you.

## Google SERP features

- **Check the live SERP first** and target only the features it shows; an AI Overview's supporting links come from ranking (`ai-platform-optimization.md`), not formatting.
- **Match the format** the query shows: a paragraph lead answer, a numbered list, an HTML table (never an image of one), or a video (`technical-seo.md`, images and video).
- **Give complete lists.** Truncating a list to bait the click makes engines lift a complete one from someone else.
- **People Also Ask** questions are research input: sub-question headings and panel prompts (`measurement.md` §5), not a separate FAQ page.
- **FAQ and HowTo markup:** one rule, in `technical-seo.md` (structured data).
- **Voice:** no separate workstream or metric; spoken answers come from the same assistants and indexes. Speakable markup is a narrow Google beta for English-language news publishers.

## Images

Alt text is necessary, not sufficient. Describe what the image shows in its `alt`, and state any fact it carries (a chart's trend, a price in a screenshot) in the page text, which is what answers quote.
