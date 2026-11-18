# Review and Diagnose

Auditing a shipped product or a UX doc, and finding why people struggle. **Read-only by default**: edit only when asked, as targeted patches. A review writes no app doc unless asked.

## 1. Scope

Name the decision the review feeds (a launch gate, a redesign's priority, one complaint) and the roles, tasks and platforms in it. A complaint sets where you start, not what you check: trace it to the structure that produces it, and check that structure for every role.

## 2. Evidence, strongest first

The live product; funnels (default `biz/analytics/funnels.md`) and support themes; routes in code; the docs. Walk each in-scope top task (the browse or qa capability, if available; else screenshots or code routes), covering across the walks:

- a new, empty account, from the way a real person arrives to the first value event, counting what is asked of them before it;
- a full account (long names, lists past one page);
- the most restricted role;
- the smallest supported window;
- keyboard alone, and a screen reader on the critical path;
- where a model is in the loop: a request it gets wrong, one it refuses, one stopped midway, one that needs approval, and the feature switched off.

## 3. Sweep

The shell (navigation, header, global actions, notifications) and each in-scope screen, walked or read from code and screenshots:

- **Value path.** The first screen continues what brought the person; nothing is asked before the value it unlocks; the first run is not empty; each role lands on what waits for it; every commitment has an exit as easy as its entry; nothing in `journey.md` § Value's left column is present.
- **Structure.** Navigation follows each role's top tasks, not the product's features, modules or org chart; one home and one name per object; no vague bucket holds a top task (`information-architecture.md` § Anti-patterns).
- **Shell access.** Location and state shown by more than color; every item reachable and operable by keyboard, focus visible; icon-only items named; nothing hover-only; targets, contrast, text scaling and reflow at the floors in `ergonomics.md`.
- **Conventions.** None of: a dialog for a reversible action, a vague "Are you sure?", a placeholder as label, a custom pattern for a standard task, promotion inside a task.
- **AI surfaces.** People are told it is AI; checking an output costs less than doing the task; the task still works without the model; every failure branch has a state; what the model did and what it used are visible; the active autonomy level is shown; approvals appear only at irreversible or outward steps and show exact parameters; stop works and says what was done; what it remembers can be seen and deleted (`ai-feature-ux.md`).

## 4. Tag

Each finding is Observed (analytics, recordings, tests, tickets), Walked (you ran the task) or Inferred (docs or code only). An Inferred 🔴 or 🟠 names the check that would confirm it. Never claim a walk you did not run.

## 5. Diagnose

Cause first: from each symptom through its competing causes (`human-factors.md` § Symptom → causes → check, which also says what goes to cro), never from a law's name. Then group symptoms under the root cause they share. 3D and XR surfaces use their references' Diagnose tables.

## 6. Drift

Screens group ↔ `docs/ux/screens/`; route rows without a screen; base states missing without `N/A — reason`; screens contradicting §5; the spec against what shipped; an AI screen against its feature doc (a failure branch with no state, an autonomy level shown differently from the one recorded).

## 7. Severity

By task impact. A root cause takes its symptoms' combined impact: the worst of them, one level up when it spans several roles or top tasks. Within a level, order by users or sessions affected (funnels, recordings), else by the task's frequency rank, labeled an estimate.

- 🔴 blocks a top task or the path to first value; loses data or money; exposes data; leaves someone at risk of harm without a fast human route; locks assistive-technology users out of a top task; lets a model take an irreversible or outward action without the person's consent or a working stop; hides that it is AI where the law requires saying so; a pattern a regulator names as manipulative on a paid path; a spatial comfort or physical-safety hazard.
- 🟠 a top task succeeds only with major error, delay or help; a secondary task is blocked; a device or posture can't perform a core action; checking a model's output costs more than doing the task; an approval nobody can judge, or so frequent it is clicked through.
- 🟡 friction with a workaround.
- 🟢 polish.

## 8. Propose and test

Each structural root cause gets the proposed structure (navigation model, each role's landing, route changes with their migration) as a hypothesis, with tasks per role, success and first-click targets against the as-is, and post-ship signals with action thresholds (`validation.md`).

## 9. Report

Sized by where the cause lies, not by the request: one flow about 500 words; the structure or the whole app about 1,500; with no doc, an as-is summary of at most 300 more. Exceed only to keep a material finding, a proposed structure or its test plan, and say so.

1. The answer to the scoped decision: go, go after named fixes, or no-go.
2. Root causes, each with the symptoms it explains, its severity and evidence.
3. The fix order as its own list: 🔴 stopgaps now, cheap top-task fixes, then the structural fix with its migration and test.
4. Taste kept apart from defects; what works and must survive, by name.
5. The top ten or so findings in full (location, user impact, evidence and tag, severity, fix); the rest one line each.

Before sending: the answer comes first; root causes lead, with combined impact across every role; the sweep ran; each structural fix carries a proposed structure, its test and thresholds; each 🔴 and 🟠 has a location, an evidence tag, the impact and a fix (Inferred: its confirming check); what must survive is named.
