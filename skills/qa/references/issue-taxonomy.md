# QA Issue Taxonomy

## Severity: consequence × exposure

Rate what the defect costs the audience named in the Frame: the consequence for a user who hits it (lost data, money, access, time or trust; recoverable or not) times its exposure (the share of that audience who hit it, how often, how large the effect). Start from the nearest anchor, move by exposure, and write the anchor and the reason for any move in the issue's Severity line. The project's own scheme wins.

| Severity | Anchors |
|---|---|
| **critical** | stored data destroyed, corrupted or silently not saved, and users can't recreate it; money moved wrongly (a charge, refund or credit of the wrong amount); a security exposure (another user's data, a secret or token, or an auth bypass); a critical journey blocked for most of the audience; an irreversible delete with neither confirmation nor undo |
| **high** | a critical journey blocked for a segment (a role, locale, browser, viewport, keyboard or screen-reader users); a save silently dropped that users can redo; wrong figures users act on; a feature broken with no workaround |
| **medium** | friction with a workaround users will find; an unhelpful error state; a display-only discrepancy (a rounding difference while the charge is right); a cosmetic defect on a payment or sign-up screen; a keyboard trap off the critical journeys |
| **low** | cosmetic, copy, or noise with no user effect |

Adjusting a rating:
- **Up** when the segment is the audience: a mobile-only blocker when most traffic is mobile, the locale a launch targets, the default role. A workaround users won't find (unlabeled, or only through support) counts as none.
- **Down** when few are exposed and the harm is recoverable: a rare race whose retry is harmless, an internal screen with a handful of users, a path behind a flag that stays off. A security exposure stays critical.
- **By magnitude**: a one-cent rounding and a doubled charge are both wrong money, not the same severity; state the amount, its direction (over- or undercharge) and how many orders or users it hits, and rate from that.
- An intermittent defect keeps its worst outcome's severity; its rate goes in Repro rate.

## Decision tier

Severity says how bad; the tier says what to do about it for this decision.
- **Fix before {decision}**: every security exposure; by default every other critical, and every high on an in-scope critical journey or changed behavior (a departure says why).
- **Fix soon**: ship, then fix; name what would make it urgent.
- **Judgment call**: a trade-off the decider owns (ship with a high in a segment this release doesn't serve; hold for a medium every launch user sees): two options, each with its cost, in one line.
- **Pre-existing** (diff-aware): outside this decision unless the change made it worse or more exposed; name criticals and highs for escalation.

## Categories

Severity follows impact; category follows type. Names are baseline keys (never rename): **functional** (behavior, saved data, security exposure), **ux** (works but misleads or stalls), **visual**, **content** (wrong or raw text), **performance**, **console** (uncaught errors, failed requests), **accessibility**, **links** (broken same-origin; scored only here).

## Signal vs noise

A console or network line counts only if it coincides with a visible failure, fires on the changed surface, or is an uncaught exception, a first-party 5xx or an unexpected 4xx; a failed request and its `Failed to load resource` line are one signal. A 4xx handled as designed (401 → sign-in, a 422 field error) is not a bug. Group dev-mode warnings, hot-reload chatter and third-party failures once, unscored; *break when* the third party sits on a critical journey (payments, auth).

Hydration errors fire during load, before the hook, via `reportError` (`Hydration failed…`; production `#418`, `#423`; React 18 also `#425`), which browse's console misses; dev builds log only some mismatches there (React 18: text, props; React 19: attributes). On a dev build, check the screenshot for the framework's error overlay; else list hydration as Not tested.

## Performance

Never on a dev server (routes compile on demand): `n/t (dev build)`. On a production build: `$B perf` (navigation timing, one sample), then LCP:
```bash
$B js "Promise.race([new Promise(r=>new PerformanceObserver(l=>{const e=l.getEntries();r(Math.round(e[e.length-1].startTime))}).observe({type:'largest-contentful-paint',buffered:true})),new Promise(r=>setTimeout(()=>r('n/a'),3000))])"
```
CLS likewise from `layout-shift` entries, summing `value` where `!hadRecentInput` (an upper bound). Report values in the Core Web Vitals poor band (LCP > 4.0 s, CLS > 0.25; INP > 500 ms, field data only), labeled `lab`: pass or fail belongs to field data at the 75th percentile.

## Accessibility

Target WCAG 2.2 AA unless the project names another. Keyboard pass per critical or changed flow (`$B press Tab`, `Enter`, `Escape`; focus via `$B js "document.activeElement.outerHTML.slice(0,80)"`): order, visible focus not hidden under sticky bars, Enter and Space activate, Escape closes, no trap. Unnamed controls in `snapshot -i` are defects. `$B snapshot -C` hits are candidates (`cursor:pointer` is inherited): drop labels and anything inside or wrapping a link, button or label; one left that acts when clicked (its `@c` ref) is a defect.

Scan in the logged-in session, with the project's own axe-core first (else the CDN), saving the output; axe runs WCAG 2.2 rules only when tagged:
```bash
{ cat node_modules/axe-core/axe.min.js 2>/dev/null || curl -sfL "https://cdn.jsdelivr.net/npm/axe-core@${AXE_VERSION:-4}/axe.min.js"
  printf '\n;axe.run(document,{runOnly:{type:"tag",values:["wcag2a","wcag2aa","wcag21a","wcag21aa","wcag22aa"]}}).then(r=>({axe:axe.version,violations:r.violations.map(v=>[v.impact,v.id,v.nodes.length].join(" ")),needsReview:r.incomplete.map(v=>v.id)}))\n'
} > /tmp/qa-axe.js && $B eval /tmp/qa-axe.js | tee <run>/evidence/axe-<page>.json
```
One finding per rule, severity from the table (not axe's impact); `needsReview` goes under Questions. Cite only the `axe` version the output printed, and store it as the baseline's `axeVersion`; a regression run whose printed version differs reruns the scan from the CDN with `AXE_VERSION` set to the baseline's, so newer rules don't read as regressions. Without the keyboard pass, mark the category "automated only". Cite target-size and contrast floors from the ux-design capability's ergonomics reference, if available, without restating numbers.
