# GEO: Content Extractability Reference

How AI systems retrieve content and how to optimize your content for extraction into AI-generated answers.

---

## Table of Contents

1. [How AI Content Retrieval Works](#how-ai-content-retrieval-works)
2. [Core Extractability Principles](#core-extractability-principles)
3. [High-Value Extractable Content Patterns](#high-value-extractable-content-patterns)
4. [Content Audit Checklist for Extractability](#content-audit-checklist-for-extractability)


## How AI Content Retrieval Works

AI systems generating answers (Google AI Overviews, ChatGPT with browsing, Perplexity) use Retrieval-Augmented Generation (RAG):

1. **Chunking**: Content is broken into passages (chunks)
2. **Embedding**: Chunks are converted into numerical vector representations
3. **Retrieval**: When a user asks a question, the system finds the most semantically relevant chunks
4. **Synthesis**: Retrieved chunks are assembled into a coherent answer, often combining passages from multiple sources

Critical implication: Your content is not consumed as a whole page. Individual passages are pulled out and used in isolation, without the surrounding context from your original page.

### Two Types of AI Knowledge

**Retrieval-based (real-time)**: Systems like Google AI Mode, Perplexity with grounding, and ChatGPT with browsing retrieve content in real-time per query. Content structure and extractability directly affect whether your content is used.

**Training-based (base model)**: What the LLM learned during pre-training. This comes from massive datasets, not per-query retrieval. Content structure matters less here. What matters is consistent, authoritative publishing over time that becomes part of training data.

This reference focuses primarily on retrieval-based optimization, as it is where structural changes have immediate impact.

### Selection-During-Synthesis Is the Bottleneck (retrieval is necessary, not sufficient)

Being in the index is not enough. AirOps (548,534 retrieved pages) found ChatGPT **cites only ~15% of pages it retrieves** — 85% are evaluated and discarded during synthesis; it generates 2+ fan-out queries on **89.6% of prompts**, and **32.9% of cited pages surfaced only via a fan-out sub-query the user never typed** (treat as directional, re-verify). So structure content so a single passage cleanly answers *one implied sub-question*. Optimize to be the **named source of a specific claim**, not merely to influence the answer text (arXiv:2603.09296: an agentic repair system lifted citation rate >40% editing only ~5% of content by fixing the weakest link in the retrieval/attribution chain).

**Selection (being cited) ≠ absorption (how deeply a source shapes the answer).** Zhang et al. (arXiv:2604.25707, 602 prompts, 21,143 citations) found **Q&A/FAQ pages have NO higher answer-influence** than non-Q&A (0.0947 vs 0.1005) — FAQ *format alone is not a citation lever*. High-influence pages are instead ~11x longer, modular, query-aligned, and dense with extractable definitions/statistics/comparisons/procedures (uplift: code +77%, numbers +62%, definitions +57%, comparisons +55%). Citation breadth differs by engine (ChatGPT ~6.9 cites/prompt but highest per-source influence ~0.27; Google ~12.1; Perplexity ~16.4). **Decision:** soften any "add FAQ schema to get cited" instinct — optimize for deep absorption by being the page that supplies the actual numbers/definitions/comparisons, and cover the implied fan-out sub-questions as discrete passages.

---

## Core Extractability Principles

### 1. Self-Contained Paragraphs

Each paragraph should express one complete idea that makes sense without any surrounding context.

**Bad, context-dependent passages**:

"There are several reasons this method works. After trying it, most people find their results improve. That's why many experts recommend it."
Problem: What method? What results? What experts? Meaningless when extracted.

"As we discussed in the previous section, this approach has limitations."
Problem: References content the AI will not include.

"This is important because of what we covered above."
Problem: "What we covered above" does not exist in an AI answer.

**Good, self-contained passages**:

"Cold brew coffee steeps for 12-24 hours in cold water, producing a concentrate with 67% less acidity than hot-brewed coffee. This lower acidity makes it easier on the stomach and allows more subtle flavor notes to emerge."
Works: Complete concept. Technique, timeframe, result, and benefit all in one passage.

"The Mediterranean diet emphasizes whole grains, olive oil, fish, and vegetables while limiting red meat and processed foods. A 2023 meta-analysis of 12 studies found it reduces cardiovascular disease risk by 25%."
Works: Definition, components, and evidence in a single extractable unit.

### 2. Front-Loaded Information

Put the main point first. Supporting detail follows.

**Bad, buried answer**:

"Many people wonder about the best approach, and there are various schools of thought. Some experts suggest one thing, others another. After weighing the evidence from multiple clinical trials and considering various population demographics, the recommended daily protein intake for adults over 50 is 1.2g per kilogram of body weight."

**Good, front-loaded**:

"Adults over 50 should consume approximately 1.2g of protein per kilogram of body weight daily. This higher threshold, recommended by the European Society for Clinical Nutrition, compensates for age-related muscle loss (sarcopenia) and supports bone density maintenance."

The AI is more likely to extract the second version because the answer appears immediately.

Front-loading is grounded in a documented LLM attention bias, not folklore: the U-shaped "Lost in the Middle" pattern (Liu et al., *TACL* 2024 — strong attention at the start and end of context, weak in the middle). Position data on published pages (Kevin Indig, Feb 2026, 1.2M AI answers / 18,012 citations — single-source, directional) shows **~44.2% of AI citations come from the first 30% of a page, ~31.1% from the middle, ~24.7% from the end**. Note the end is a *downward ramp* (24.7%), so "restate the conclusion at the end" is a weaker move than a symmetric U — the opening 30% is where the highest-value liftable answer and key statistics belong.

### 3. Specific Facts Over Generalizations

AI systems preferentially extract concrete, verifiable information.

**Bad, vague**:
- "Many companies have seen success with this approach."
- "The market has grown significantly in recent years."
- "Experts generally recommend this technique."

**Good, specific**:
- "Shopify merchants using headless commerce saw a 35% improvement in page load times, according to Shopify's 2024 Commerce Report."
- "The global AI market grew from $136.6B in 2022 to $196.6B in 2023, a 44% year-over-year increase (IDC Worldwide AI Spending Guide)."
- "The American Heart Association recommends 150 minutes of moderate aerobic activity per week for cardiovascular health."

### 4. Descriptive Headings

Headings signal to AI systems what each section answers. Structure headings to match how users ask questions.

**Bad headings**:
- "Overview"
- "Details"
- "More Information"

**Good headings**:
- "What is the recommended daily water intake for adults?"
- "How does intermittent fasting affect metabolism?"
- "Best CRM software for small businesses in 2025"
- "PostgreSQL vs MySQL: key differences for enterprise development"

### 5. One Idea Per Paragraph

Do not combine multiple distinct concepts in a single paragraph. When AI retrieves a passage, it should get one clean idea, not a jumble of loosely related points.

### 6. Concrete Word-Count Targets for Liftable Blocks

Converging 2025-2026 citation analyses give specific targets (treat as directional, single-/few-study, re-verify):
- The unit AI lifts is a **40-60 word self-contained answer block**, one claim each — shorter than SEO's flowing prose (NAV43; Averi).
- The between-subhead **sections** cited most run **~120-180 words**: SE Ranking (129K domains, 216K pages, via Search Engine Journal Nov 2025) found 120-180-word sections averaged **4.6 ChatGPT citations vs 2.7** for sub-50-word sections (~70% more).
- Atomic AI paragraphs run **2-4 lines**, explicitly shorter than SEO's 3-6 line norm.
- Structural formatting independently lifts citation rate **~17.3% across six engines** (GEO-SFE, arXiv:2603.29979): paragraphs optimal at **150-300 words**, chunks over 300 words show ~31% mid-segment attention degradation, structured formats (lists/tables) extract ~43% more accurately than prose, and emphasis markers are optimal at **5-10%** of content.

**Decision:** structure pages as discrete 40-60 word answer blocks (one claim each) grouped into ~120-180 word subhead sections; keep paragraphs 150-300 words and never push a single chunk past ~300 words.

### 7. Definitive Language + Named-Entity Density

Two measurable writing traits separate cited from uncited pages (Kevin Indig, 1.2M ChatGPT responses / 18,012 verified citations, Feb 2026 — single-source, treat as directional):
- **Definitive, non-hedged statements** were cited **36.2% vs 20.2%** for hedged language (~80% higher). Write assertive declaratives; avoid "may/might/could." (Note: this is authoritative-*with-evidence*; bare confidence without statistics/quotations does not work — see Pillar 2 in `ai-platform-optimization.md`.)
- Cited content averages **~20.6% named-entity density** (brands/tools/people) vs a 5-8% English baseline. **Decision:** pack relevant named entities into liftable blocks as grounding anchors, and state claims as definitive declaratives rather than hedged prose.

### 8. Alt Text on Every Content Image

AI retrieval is text-based: an `<img>` without `alt` text contributes nothing to a chunk, so any fact carried only by the image (a chart's trend, a diagram's flow, a screenshot's UI state) is invisible to extraction. Every content image must carry descriptive `alt` text stating what the image shows — never empty, never keyword-stuffed. (Implementation details — filenames, `ImageObject` schema, captions: `technical-seo.md`.)

---

## High-Value Extractable Content Patterns

### Definition Blocks

Format: "[Term] is [clear definition]. It [primary function/purpose]. Unlike [common confusion], it [key distinction]."

Example: "Server-side rendering (SSR) generates HTML on the server for each request, sending a fully rendered page to the browser. It improves initial load time and SEO compared to client-side rendering, where the browser must download and execute JavaScript before displaying content."

### Comparison Blocks

Format: "[Option A] [key differentiator] while [Option B] [contrasting characteristic]. Choose [A] when [use case]. Choose [B] when [alternative use case]."

Example: "PostgreSQL provides advanced features like JSON querying, full-text search, and complex joins, while MySQL offers simpler setup and faster read performance for straightforward queries. Choose PostgreSQL for complex data relationships and analytical workloads. Choose MySQL for high-volume read-heavy applications with simpler schemas."

### Process/How-To Blocks

Format: "To [achieve outcome], [step with specific detail]. [Expected result or why this works]."

Example: "To reduce Docker image size, use multi-stage builds that compile code in a build stage and copy only the final binary to a minimal runtime image like Alpine. This commonly reduces image sizes by 80-90%, cutting deployment times and reducing attack surface."

### Statistic/Data Blocks

Format: "[Specific finding] according to [source, date]. This represents [context or comparison]."

Example: "Global e-commerce sales reached $6.3 trillion in 2024, according to eMarketer's annual forecast. This represents a 9.4% year-over-year increase and accounts for 21.2% of total retail sales worldwide."

### Recommendation Blocks

Format: "[Product/approach] is best suited for [specific audience/use case] because [concrete reasons]. [Key differentiator from alternatives]."

Example: "Notion is best suited for small teams (under 50 people) that need a flexible workspace combining notes, databases, and project management. Its block-based editor allows non-technical users to build custom workflows without coding, though it can become slower with very large databases."

---

## Content Audit Checklist for Extractability

For each key page, assess:

- [ ] Can each important paragraph be understood without reading the rest of the page?
- [ ] Are answers front-loaded (main point first, then supporting detail)?
- [ ] Are specific facts, numbers, and sources included rather than vague claims?
- [ ] Do headings describe what the section answers (not just "Overview" or "Details")?
- [ ] Does each paragraph focus on one idea?
- [ ] Are there clear definition, comparison, or recommendation blocks for key topics?
- [ ] Is there minimal use of context-dependent phrases ("as mentioned above", "this is why", "see below")?
- [ ] Are statistics attributed to specific sources with dates?
- [ ] Does every content image have descriptive `alt` text (no empty `alt` on images that carry information)?
- [ ] Could an AI extract any single paragraph and present it as a coherent, accurate answer?
