# PRD Examples

Near-miss pairs from one product, a post-deploy verifier for teams that ship daily.

## §1 Problem: precise but unsourced
**Weak:** "40% of deploys go unchecked, and unchecked deploys cause 70% of user-found incidents."
**Better:** "After each deploy an engineer spends 10–15 min (measured: 6 timed deploys) on dashboards, logs and staging, and skips it under pressure [Said: 4 of 5 engineers, last retro]. Last quarter customers reported 6 deploy-caused incidents before we saw them (measured: incident log). Share of deploys checked: (unknown → measure by v0.1 start, over 30 deploys)."

## §4 Metrics: an output metric, nothing traded against it
**Weak:** `| % of deploys auto-verified | — | 95% | 3 months |`, met the day the feature ships, even by a verdict that is always green.
**Better:**

| Metric | Baseline | Target | By | Counter-metric (floor) | Data source |
|---|---|---|---|---|---|
| Primary: deploy-caused incidents customers report first, per quarter | 6 (measured: incident log) | ≤2 (target: the manager's bar for keeping the tool) | checkpoint + 1 quarter | deploys per week stay at today's rate: fewer incidents from shipping less is no win | incident log, tagged by deploy |
| Leading: share of a team's green deploys whose verdict is opened within 10 min, with no dashboard session in the next 30 | 0 (measured: no verdict exists yet) | ≥70% (target: judgment, review at checkpoint) | checkpoint | green verdicts later tied to an incident: ≤1 per team | verdict-open event (built in v0.1), dashboard log |
| Also: minutes an engineer spends checking a deploy | 10–15 (measured: 6 timed deploys) | ≤3 (target: time to read a verdict and open one graph) | checkpoint | covered by the leading row's floor | timed deploys, 6 per team |

Dropped: the manager's "fewer night pages"; off-hours deploys are too rare for any checkpoint to read.

The leading metric measures the bet itself, the verdict replacing the manual pass; its counter-metric catches a verdict that is trusted but wrong.

## §6 Dev order: modules with MoSCoW as releases
**Weak:** v0.1 `health-checker` [Must], `error-rate-monitor` [Must]; v0.2 `notifier` [Should]; v0.3 `dashboard` [Could].
**Better:**

> ### v0.1 — Verdict — tests whether a verdict replaces the manual pass
> **Tests:** engineers act on a green verdict instead of the manual pass (value).
> **Audience:** 3 design-partner teams from the buyer's network.
> **Checkpoint:** week 6.
> **Build bar:** the tech lead connects services and adds or removes engineers by hand, same day (past 10 services, setup must be built); read-only metrics access and the stored log excerpts are production-grade.
> **Decision** (the PM): continue if ≥2 of 3 teams hit the leading target in weeks 4–6; change if 1 does; stop if none, and then each team's excerpts are deleted within 2 weeks.
> **Transition:** a team keeps its manual pass until the verdict matches it on 20 deploys in a row, then drops it, by week 4 at the latest, so weeks 4–6 measure the verdict alone.
> 1. deploy-verdict — the bet itself [Must] (4–5 engineer-weeks)
> 2. verdict-alerts — an unseen verdict tests nothing [Must] (1.5–2) (depends on: deploy-verdict)
> 3. delete-team-data — the partners' data terms require it [Must] (0.5) (depends on: deploy-verdict)
>
> **Musts:** 6–7.5 of 12 engineer-weeks (est., the team's): tight at the high end; if it slips, alerts go by email only.
>
> *Cut line*
>
> 4. per-service-thresholds — fewer false alarms [Should] (depends on: deploy-verdict)

Features are what a user does; the rule reads the leading indicator (incidents can't move in six weeks), counted in teams (three teams are the sample). Setup stays manual because three teams don't need self-serve; deletion is a feature because partners won't sign without it.

## §7 Non-goals: filler
**Weak:** "Out of scope: mobile apps, AI features, blockchain."
**Better:**
- Automatic rollback [later: verdicts trusted for 4 weeks]: the manager asked, but acting on an untrusted verdict multiplies the damage.
- Pre-deploy checks [never]: CI already owns them.
- Self-serve sign-up [later: a fourth team]: three invited teams are set up by hand.
- Self-hosted install [later: a customer's security review requires it] ⚠ arch: it changes how we ship and update.

## §8 Duties: a citation, not a requirement
**Weak:** "Privacy: GDPR may apply; check with legal."
**Better:** Alerts quote log lines, and partners' logs can hold their own customers' emails and IP addresses: the output is personal data even though a verdict isn't.
- Excerpts masked (emails, IPs, tokens), kept 30 days, deleted within 2 weeks of a lead's request — each partner's data-processing terms (contract, signed before v0.1 starts) — met by deploy-verdict REQ-004 and delete-team-data REQ-001 in v0.1.
