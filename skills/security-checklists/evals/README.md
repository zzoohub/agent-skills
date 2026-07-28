# security-checklists eval harness

A reusable A/B harness that measures whether the `security-checklists` skill improves a security
review. It plants known vulnerabilities (and safe-looking "traps") in real code files, then reviews
each file **with** the skill vs. an own-knowledge **baseline**, and grades recall + precision.

See [`FINDINGS.md`](FINDINGS.md) for what four runs concluded (short version: recall never differs
in 4/4 iterations; a small, twice-reproduced precision edge on hard/subtle content at 1.3–1.8× cost;
skill left unchanged).

## Layout

```
evals/
├── FINDINGS.md                       # the investigation write-up + conclusion
├── README.md                         # this file
├── standard/                         # textbook vulns (iteration 1: frontier model; iteration 3: Sonnet rerun)
│   ├── evals.json                    #   prompts + ground-truth assertions (recall + [PRECISION] traps)
│   ├── files/                        #   5 code files under review (no vuln-naming comments)
│   ├── benchmark.json                #   iteration-1 results (frontier model)
│   └── benchmark-sonnet-rerun.json   #   iteration-3 results (Sonnet), incl. finding_ledger_totals
└── hard/                             # subtle/obscure vulns — the discriminating set (iteration 2 + iteration-4 rerun)
    ├── evals.json                    #   assertions tagged [SUBTLE] / [PRECISION]
    ├── files/                        #   5 harder files
    ├── benchmark.json                #   iteration-2 results (Sonnet), incl. finding_ledger_totals
    └── benchmark-sonnet-rerun.json   #   iteration-4 results (Sonnet rerun — reproducibility check)
```

Each `evals.json` entry has a `prompt`, the `files` to review, an `expected_output`, and
`expectations` (the graded assertions). `[PRECISION]` assertions must **not** be flagged (safe traps);
untagged/`[SUBTLE]` assertions are real vulns that should be caught. Ground truth lives only here —
the code files carry no hints.

## How to re-run (skill-creator eval loop)

Driven with the `skill-creator` skill. For each eval, spawn two subagents in one turn — one told to
use the skill (`security-checklists`), one told to review with its own knowledge only — both given
the identical file + prompt and asked to write a findings list to a run dir. Then grade, aggregate,
view.

1. **Reviewers** (per file × {with_skill, without_skill}): `general-purpose` subagents. Pin the model
   with the Agent `model` param to match the target being measured (iteration 2 used `sonnet`, the
   `reviewer` agent's real model). Save each review to
   `iteration-N/eval-<id>/<config>/run-1/outputs/review.md`. Capture `total_tokens`/`duration_ms`
   from each completion into a sibling `timing.json` — it is not recoverable later.
2. **Graders** (one per file, both arms): give each the code file, the eval's assertions, and both
   reviews; have it write `grading.json` (`expectations[].{text,passed,evidence}` +
   `summary.{passed,failed,total,pass_rate}`; the hard set adds a `finding_ledger`
   `{total_findings,true_positives,false_positives,precision}`). Rubric: a `[PRECISION]` assertion
   passes if the safe pattern isn't reported as the named vuln (a "considered/cleared" note passes);
   recall passes if the vuln is identified regardless of wording/CWE. Grade both arms by one standard.
3. **Aggregate:** from the skill-creator dir,
   `python -m scripts.aggregate_benchmark <iteration-N> --skill-name security-checklists`.
   (Token totals may need patching from the `timing.json` files — the aggregator only reads tokens
   when `time_seconds` is 0.)
4. **View:** `eval-viewer/generate_review.py <iteration-N> --benchmark <…>/benchmark.json
   [--previous-workspace <iteration-N-1>] [--static out.html]`.
   **Requires Python ≥ 3.10** (the viewer uses `X | None` type syntax; macOS system `python3` 3.9
   fails — use e.g. Homebrew `python3.14`). Serves on `127.0.0.1:3117`, or `--static` writes a
   standalone HTML.

## The two experiments that would most change the conclusion

- **Weak model:** re-run `hard/` with reviewers pinned to Haiku. If the skill lifts Haiku's recall,
  that is its justification — and the target to optimize for. If not, the case for trimming the
  pattern lists is strong.
- **Output consistency:** blind-compare with vs. without on the axes recall/precision ignore —
  CWE-citation, severity calibration, exploit-path completeness, format — via the skill-creator
  `comparator` agent.
