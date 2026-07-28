# security-checklists — empirical evaluation findings

**Date:** 2026-07-28 · **Method:** skill-creator eval loop (with-skill vs. without-skill A/B) ·
**Status:** concluded — **no changes made to the skill** (coverage judged excellent; see conclusion).

## Question

Does the `security-checklists` skill measurably improve a security code review — catching more real
vulnerabilities (recall), avoiding false alarms (precision), or being more thorough — enough to
justify its context cost? Measured by planting known vulnerabilities (and safe-looking "traps") in
real code files and reviewing each **with** the skill vs. **without** it (own-knowledge baseline),
identical file and prompt otherwise.

## Four iterations

| | Iteration 1 | Iteration 2 | Iteration 3 | Iteration 4 |
|---|---|---|---|---|
| Executor model | frontier (general-purpose default) | **Sonnet** | **Sonnet** | **Sonnet** |
| Set | standard (textbook) | hard (subtle/obscure) | standard (rerun on Sonnet) | hard (rerun — reproducibility check) |
| Files | 5 (orders, auth, ssrf-proxy, llm-chat, precision-crucible) | 5 (jwt/oauth, payments races, ssrf-bypassable-guard, path+xss, subtle-crypto) | same 5 as iter 1 | same 5 as iter 2 |
| Metric | planted-vuln recall + trap precision | + **finding ledger**: total TP/FP/precision over *every* finding | + finding ledger | + finding ledger |

Iterations 3–4 were run after switching the session default model to Sonnet 5, specifically to (a)
get a Sonnet data point on the *standard* set (iteration 1 only ever ran that set on a frontier
model) and (b) check whether iteration 2's hard-set result was a stable pattern or single-run noise.

### Results

**Iteration 1** (frontier, standard) — 26 assertions:
- Recall/precision: **100% vs 100%** (26/26 each). Every planted vuln caught, all 10 traps cleared, by both arms.
- Cost: with-skill **1.78×** tokens (96.8k vs 54.2k mean), **1.78×** wall-clock (240s vs 135s).

**Iteration 2** (Sonnet, hard) — 23 assertions + finding ledger:
- Recall: **100% vs 100%** (23/23 each) — every subtle planted vuln caught by both (JWT `kid`→key-swap forgery, TOCTOU double-spend, idempotency-key race, cumulative-refund overflow, bcrypt 72-byte truncation, non-constant-time `secure_compare`, PBKDF2-1000, bypassable SSRF blocklist, path-containment prefix bug, blacklist stored-XSS).
- Finding ledger: with-skill **29 TP / 0 FP** (precision 1.00) vs baseline **33 TP / 1 FP** (precision 0.97).
- Cost: with-skill **1.29×** tokens (102.8k vs 79.6k); ~1.06× time.

**Iteration 3** (Sonnet, standard — new data point) — 26 assertions + finding ledger:
- Recall: **100% vs 100%** (26/26 each) — same tie as iteration 1; switching the executor to Sonnet didn't surface a skill advantage on textbook vulns either.
- Finding ledger: with-skill **40 TP / 0 FP** vs baseline **39 TP / 0 FP** — a wash, both perfectly precise.
- Cost: with-skill **1.56×** tokens (122.3k vs 78.4k); **1.13×** time (much closer to parity than iteration 1's 1.78× — Sonnet's own baseline reviews simply took longer, narrowing the relative overhead).

**Iteration 4** (Sonnet, hard — reproducibility rerun) — 23 assertions + finding ledger:
- Recall: **100% vs 100%** (23/23 each) — reproduces iteration 2 exactly; every subtle vuln caught by both arms again.
- Finding ledger: with-skill **31 TP / 0 FP** (precision 1.00) vs baseline **34 TP / 1 FP** (precision 0.97) — same shape as iteration 2, but the baseline's one false positive landed on a **different file** this time (crypto_utils's bcrypt cost factor, vs. iteration 2's JWT `kid` finding). The *pattern* reproduced; the specific miss didn't.
- Cost: with-skill **1.31×** tokens (103.6k vs 79.0k, matching iteration 2's 1.29× almost exactly); time now at **~parity** (1.01×) — on Sonnet, the skill's wall-clock overhead fully washes out, leaving only the token premium.
- One grader caught something the TP/FP ledger can't see: with-skill's SSRF finding on `fetcher.js` included a factually wrong claim about which IP-encoding bypasses work (decimal/hex/octal encodings of `127.0.0.1` don't actually bypass Node's URL parser — the baseline correctly excluded them, with-skill didn't). This didn't flip any assertion, but it's a real output-quality defect the ledger is blind to, and this instance favored the **baseline**.

Full per-file ledgers for all four iterations are in `standard/benchmark.json` and `hard/benchmark.json`.

## Conclusion

Across **4 iterations spanning 2 model tiers × 2 difficulty levels × (fresh run + rerun) = 40
reviews**, recall **never once differed** — 100%/100% in every single iteration, no exceptions. The
with-skill arm never caught a vulnerability the baseline missed, or vice versa.

The one **reproducible** signal is a precision/thoroughness trade-off that appears specifically on
the **hard/subtle set, on both independent Sonnet runs**: the baseline is slightly more exploratory
(finds ~3–4 more legitimate issues per 5-file set) but makes almost exactly one false positive per
run; the with-skill arm is marginally less thorough but has never made a single false positive across
any of the 4 iterations (0 FP in 120+ graded findings, standard set included). This is a real,
twice-observed pattern — not the single-run noise iteration 2 alone would have been — but it is a
small effect (~1 miss in ~30 findings) bought at a **stable ~1.3× token cost on hard content** (1.4–
1.8× on the easy content, where nobody makes mistakes anyway so the cost buys nothing).

**Interpretation.** The gap is not missing coverage — the checklist content is broad, current (OWASP
Top 10:2025, NIST SP 800-63B-4, LLM Top 10), and accurate. The gap is that **for capable models the
exhaustive per-domain pattern lists are recall the model already holds**, so they mostly add token
cost. The parts that plausibly earn their keep are the narrow ones this eval can only partially
score: the **"Before You Report — Exploitability Discipline"** section (the apparent source of the
reproduced precision edge), the **Review Output Contract** (consistency of CWE/severity/exploit-path
— see the fetcher.js counter-example above, where output-quality actually favored the *baseline* once,
a reminder this axis is genuinely a coin flip, not a settled skill advantage), and the genuinely rare
checks.

**Decision (2026-07-28, reconfirmed after iterations 3–4): leave the skill unchanged.** Strong models
not needing a checklist for common vulnerability classes is expected, not a defect. Trimming the
pattern lists was considered and **declined** — the skill's most likely real justifications remain
**untested**, and are exactly what a trim would risk:
- **Weak models** (e.g. Haiku) — checklist scaffolding usually has real headroom there; not measured.
- **Output consistency** — format/CWE-citation/severity calibration; the one data point we have on this axis (fetcher.js, iteration 4) went *against* the skill, so this is not a slam-dunk justification either — it needs a dedicated blind comparison, not incidental grader remarks.

## Limitations

Single run per arm per iteration (no variance bars within an iteration — though iterations 2 and 4
now provide a same-condition rerun, which is the main mitigation); grader-adjudicated TP/FP
classification carries some subjectivity; planted vulns, though subtle, are still curated (not
wild); the executor was a strong model throughout (Fable-tier for iteration 1, Sonnet for 2–4). A
weak-model run and a dedicated blind output-consistency comparison are the two experiments that
would most change the picture — see `README.md` to run them.
