# AI Feature: {feature}

**Date**: {date} · **Spec**: {link to the feature spec, if any} · **Depth**: light | deep

<!-- Budget below this header, tables included: light ≈ 400 · deep ≈ 1,200 words. Eight numbered sections; other skills read them by number. A light feature writes `n/a — reason` where its gate needs nothing.
     Label every number: measured (source, date), derived (inputs shown), a target, or "not run" with the spike that will measure it. Pass rates and hit rates are never derived. -->

## 1. Task & decisions the model owns

**Task**: Given {X}, produce {Y}, so that {Z}. **The user verifies Y by**: […]

**The model decides**: […] · **Code decides**: […]

## 2. Shape, autonomy & authority

- **Shape**: [code · typed decision · single call · workflow · graph · agent · multi-agent], and why not the rung below (the eval failure seen there, or why it cannot work and the spike that tries it first)
- **Model class and tier**: [decision model · small · frontier; reasoning setting], or the spike that will choose
- **Placement**: [cloud · edge · on-device; default tier and fallback chain]
- **Untrusted input × sensitive access × state change or egress**, per context: […]
- **Autonomy per action class**: suggest | approve | oversee | audit | autonomous

| Tool / action | Effect (read / write / sends outside) · reversible? | Data scope | Caps | Approval | Enforced by (code outside the model) | Guard (adversarial eval case) |
|---|---|---|---|---|---|---|

## 3. Context

Prompt outline · sources and retrieval choice · context budget · compaction and memory policy · cache plan.

## 4. Output contract

Schema or free text · validation in code · handling per termination reason (completed, truncated, refused).

## 5. Failure path

| Failure | What catches it | What the user sees |
|---|---|---|
| Wrong | | |
| Unsure (signal, threshold, escalation queue and its capacity) | | |
| Down | | |
| Attacked | | |
| Runaway | | |
| Stopped halfway | | |

## 6. Eval set & release gate

Failure taxonomy with 5–10 seed cases (input → pass condition) · evaluator per failure mode · judge validation · release bound · owner (role) · baseline (measured, or "not run" + spike).

## 7. Production envelope & lifecycle

Cost per successful task (p50 / p95 / p99) vs the ceiling · latency class · quota headroom · caps per scope · caching · release unit and rollout · pinned snapshot, fallback, exit · data and regulatory duties (data minimized before prompts and traces, AI stores with retention and erasure, provider data terms, disclosure).

## 8. Open questions & risks

| Question or risk | Options | Information needed | Decide-by |
|---|---|---|---|
