---
name: react-native-skills
description: |
  React Native and Expo engineering on the New Architecture: lists and recycling (FlashList, Legend List), Reanimated and Gesture Handler motion, native navigation, sheets and menus, safe areas, edge-to-edge and the keyboard, images, fonts, native dependencies, OTA updates, monorepos, and crash, memory and launch regressions. Use when building, reviewing or debugging an Expo or React Native app: "janky list", "blank cells", "slow startup", "crashes since the release", "add a native library", "upgrade Expo".
  Do NOT use for: tokens, theming, typography, shadows, component APIs or reduced motion (design-system); localization and formatting (i18n); web React performance (react-best-practices).
license: MIT
source: https://github.com/vercel-labs/agent-skills/tree/main/skills/react-native-skills
---

# React Native Skills

> Fork of vercel-labs/agent-skills (MIT), frozen: merge upstream only per `UPSTREAM.md`.

**Native first, measured, both platforms.** Keep per-frame work off the JS thread. Reject JS copies of native navigation, sheets, menus and text input; dev-build performance claims; one-platform fixes; unattributed fixes.

## 1. Calibrate

Read `package.json`, the lockfile, and the app, Babel and Metro configs; ask the caller, in one batch, only what the files cannot answer, else state the default and continue (owners' trade-offs: §2).

- **Workflow:** Expo with Continuous Native Generation (CNG, default), Expo with committed native folders, or bare RN.
- **Versions:** Expo SDK, RN, and the Reanimated, Gesture Handler, list and router majors; resolve every API and import against them. RN 0.82+ runs only the New Architecture. Often recalled, now removed: `@react-navigation/*` imports under Expo Router (SDK 56), `StyleSheet.absoluteFillObject` (RN 0.85; `absoluteFill`), `InteractionManager` (0.87; `requestIdleCallback`).
- **React Compiler** (`experiments.reactCompiler` or the Babel plugin; default in new Expo apps): new code adds no `memo`, `useMemo` or `useCallback`; existing memoization stays; shared values use `.get()`/`.set()`.
- **Hermes:** modern built-ins (e.g. `toSorted`) and `Intl` constructors only where the app's Hermes (`hermes-compiler`) ships them; else `[...arr].sort()` or a polyfill loaded first.
- **Targets** (defaults): iOS and Android, no web; slowest device a 3-4-year-old mid-range Android; a ≥600 dp Android window (tablet, foldable), where Android 16 ignores orientation locks for apps targeting API 36; a development build, not Expo Go.
- **The house way wins:** its libraries (never add a parallel one) and conventions (accessibility prop spelling, state and data layer, styling, file layout, tests). These rules fix behavior, not spelling.
- **States:** every state in the screen spec (default `docs/ux/screens/{screen}.md`; caller may redirect; without one, state your assumptions), plus, where they apply: keyboard open, largest font size, dark mode, offline or slow network, permission blocked, restored after process death, deep-link cold start, first launch after an upgrade.

## 2. Frame the request

Restate the request as its problem: a library request may be met by the SDK or platform; "slow" is an interaction to measure; a one-platform bug is checked on both. When the evidence puts the problem elsewhere (another screen, the server, config, a wrong premise), say so: fix it if it is yours and the change depends on it (§4), else hand it to its owner with an actionable spec. Never leave the core problem unsolved to stay in scope. Done means the matching §7 part is complete and §8 passes.

**Requirements are decisions.** Make each stakeholder requirement measurable (metric, percentile, device class, cold or warm), check its conflicts (other requirements, platform rules, installed binaries), and cost the options. Build on your recommendation; an owner's trade-off goes under **Decisions owed** (§7), never presented as settled. Ship now the part every option needs.

**Verify.** Run the device-free checks: `tsc --noEmit`, lint, tests; on Expo, `npx expo-doctor` and `npx expo install --check`. Lock each fix with the cheapest reproducing test: Jest with React Native Testing Library, a Maestro flow, or a screenshot per platform.

**Small change** (one component or bug): calibrate what the touched code uses; skip §3's measurement unless speed or stability is the complaint. Small reply (§7), full checks.

## 3. Measure, then attribute

Dev builds mislead: JS runs far slower, FlashList can look slower than FlatList, and launch skips the update check and production SDK setup. On a release build of the slowest device, script one scenario (a Maestro flow) and read both threads: JS frame rate (FlashList `useBenchmark`, a `requestAnimationFrame` counter), UI frames (`adb shell dumpsys gfxinfo <package>`; Instruments' Animation Hitches). Compare medians of ≥3 runs per side after a warm-up, device charged and cool; a delta inside the run-to-run spread is "no measurable change".

- **UI drops, JS steady** → native work: view count, oversized images, overdraw, layout-prop animation, many animated views (images-fonts, animation-gestures).
- **JS drops** → render scope or JS work: unstable list data, parents re-rendering on input, per-row work, state set on scroll, a `key` inside recycled rows, a screen mounting mid-transition (lists, animation-gestures, navigation-native-ui).
- **Both steady, input late** → feedback waiting on JS, or conflicting gestures (animation-gestures); **content late** → data, not rendering.
- **Slow launch** → time release cold starts; defer all the first frame does not need (stability-launch).
- **Memory growth** → split JS heap from native first (stability-launch).

Name the component: React DevTools Profiler render counts (not its dev durations), then a release Hermes profile (`react-native-release-profiler`). Fix the largest cost first.

**Regressions** (a crash, OOM, ANR, launch or jank rate that moved): attribute before fixing (`rules/stability-launch.md`).
1. **Timeline:** the onset (date, binary, OTA update, OS, device class) against every change, config and server included.
2. **Root vs trigger:** the trigger often only used up headroom an older defect left: stopgap the trigger (rollout halt, rollback, flag), fix the root. A defective trigger is its own cause; turning a feature off is the owner's call (Decisions owed).
3. **Blind spots:** state what each source you rely on cannot see, and cover the gap.
4. **Reproduce** on a production-equivalent build, installed over the last store version.

*Break:* crash fixes and obvious algorithmic wins may skip medians ("unmeasured"), never attribution.

## 4. Decide

Defaults bind what the change adds or alters, plus pre-existing code its new behavior depends on (fix that); report other violations a line each with the best fix (`file:line` · problem · fix), don't refactor them.
- Lists, blank cells, keystroke jank, recycled rows, row state, chat → `rules/lists.md`.
- Motion, scroll-driven UI, press feedback, gestures → `rules/animation-gestures.md`.
- Router imports, deep links, sign-in, stacks, transitions, headers, tabs, sheets, menus, lightbox → `rules/navigation-native-ui.md`.
- Safe areas, edge-to-edge, keyboard, measuring, shadow and gradient mechanics → `rules/platform-layout.md`.
- Images, fonts → `rules/images-fonts.md`.
- Crash, OOM, ANR and launch regressions, the launch path and its config, memory → `rules/stability-launch.md`.
- Native libraries, Expo Go vs development build, OTA and store releases, CNG, permissions, upgrades, monorepos → `rules/dependencies-delivery.md`.
- Components that render text (buttons, chips) → `rules/design-system-compound-components.md`.

Siblings, if available: design-system and i18n for what the description excludes; react-best-practices for generic React, minus web-only rules (built-ins per §1).

## 5. Always (in the code §4 binds)

- **Platform parity.** An iOS-only prop (`contentInset`, `scrollIndicatorInsets`, `contentInsetAdjustmentBehavior`, `automaticallyAdjustKeyboardInsets`, Modal `presentationStyle`) ships with its Android behavior in the same change (`rules/platform-layout.md`), checked on an edge-to-edge Android screen. *Break:* cosmetic props (`borderCurve`).
- **Text.** Strings and numbers render only inside `<Text>`: `{count && <Badge />}` renders `0` when `count` is 0; use `count > 0 &&` (lint `react/jsx-no-leaked-render`).
- **State.** Store intent and truth, derive the rest in render; never mirror props or server data through an effect. A user override starts `undefined` and renders as `override ?? serverValue`, so refetches land; an optimistic one yields to the server once its write settles (`rules/lists.md`). Never touch a shared value in render.
- **Accessibility.** Custom controls expose a role, a name when icon-only, their state (selected, disabled, expanded) and a 44 pt / 48 dp target (`hitSlop` counts), in the house spelling; check them with VoiceOver and TalkBack.
- **Failure paths.** Each timeout, retry, fallback or default you add says what it loses when it fires; launch never waits on the network or an update check; safety controls (kill switches, minimum-version gates) fail toward the less harmful state and hold server-side (stability-launch).
- **Secrets** go in the Keychain or Keystore (`expo-secure-store`), never AsyncStorage or unencrypted MMKV; `EXPO_PUBLIC_` values are public.

## 6. Symptom → cause → check

- A row shows another item's state or image, or misses a refetch → recycled or copied row state, or no `recyclingKey` → lists.
- Android only: content under bars or keyboard, or a full-screen sheet → an iOS-only prop (§5) → platform-layout, navigation-native-ui.
- Works in dev, fails in release → `EXPO_PUBLIC_` values missing from the build or update, R8 stripping a reflected class, `__DEV__`-only code → reproduce in a local release build.
- Long splash offline, or restarts the crash-free rate misses → launch waiting on the network, OOM or watchdog kills → stability-launch.
- Crash after an OTA update, or a module missing in Expo Go → native code not in the binary → dependencies-delivery.
- Native crash, no JS stack → symbolicate (`adb logcat -b crash`, Xcode crash logs), name the module, place its onset (§3) → dependencies-delivery.
- "Invalid hook call" or "Tried to register two views with the same name" → duplicate `react`, `react-native` or native library → dependencies-delivery.

## 7. Output

**Length:** the caller's target when given; else scale with the independent problems and owner decisions: a small change ≤80 words plus a line per other finding, a fix ≤250 (prose outside code), a review ≤500 (≤50 per finding), a plan ≤400 plus its table, an investigation about 150 per cause plus its decisions. Budgets size the record, never the analysis: no material finding drops to fit; compress it to a line, or exceed and say why.

The parts are a menu: omit what does not apply.
- **Fix** (reproduced first: interaction, platform, device, build; fixed on both platforms): the diff; symptom · cause · evidence per cause; for speed, before/after medians against a pinned scenario and target (default: full frame rate on both threads, no blank cells, no slower launch), or "unmeasured".
- **Build** (every §1 state renders on both platforms): the code; one-line decisions (choice · why · revisit when), only for calls that are yours.
- **Investigation** (crash, OOM, ANR, launch): per independent cause, sized (users, versions, platforms): evidence (onset, root or trigger, blind spots) → fix → cost and delivery (OTA, binary or server: who gets it when); then what ships now and the production signal that confirms it.
- **Review:** findings against §5, §6 and the touched rule files, by severity, each `file:line` · area · evidence · fix.
- **Native change** (library, config plugin, permission, native edit): new-binary and OTA impact (`rules/dependencies-delivery.md`).
- **Plan** (upgrade, migration, library swap): per `rules/dependencies-delivery.md` § Upgrades, stepped until the main flows run on both platforms.
- **Decisions owed** (§2), each as goal · measurable definition · conflicts · options with cost · recommendation · default in force until answered.
- **Seen, out of scope** (§4).
- **Checked:** one line per platform (device or simulator, dev or release build, tests run), or "not run on <platform>"; device-free checks not run, and why.

Severity (correctness and parity outrank performance):
- **Critical:** a crash, data loss, a plaintext secret, one platform broken, an OTA update that can reach a binary lacking its native code, a safety control that fails toward harm and is not enforced server-side.
- **High:** measured jank, blank cells, an ANR or a launch waiting on the network, on the slowest device; a recycled row showing another item; missing text or a stray `0`; a control missing role, label or target size.
- **Medium:** unmeasured waste; a redundant dependency. **Low:** consistency.

No calibration lists, rule quotes or self-review tallies in output.

## 8. Self-Review

1. Each performance claim names device, build, target and before/after medians, or says "unmeasured".
2. Each regression: onset on the change timeline, root and trigger named, blind spots stated, a production-equivalent repro (or "not reproduced").
3. Each added timeout, retry, fallback or default says what it loses; safety controls fail safe; launch never waits on the network.
4. Each requirement is measurable; owner trade-offs sit under **Decisions owed**, each with options, cost and a recommendation; the decision-invariant part ships.
5. Code in §4's scope meets §5 (parity, `<Text>`, state, shared values, controls in the house spelling); other code is reported with a fix, not edited.
6. Recycled rows: no `key` inside, no server value copied into row state, UI state reset per item, `recyclingKey` on images.
7. APIs and imports match the installed majors; modern built-ins are Hermes-supported or replaced.
8. Native changes: new-binary and OTA impact; a new library's reason and New Architecture support; plans: an action per native dependency, a gate per step.
9. Device-free checks ran, or **Checked** says which did not and why; **Checked** covers each platform.
10. Footprint: the caller's length, else §7's budgets; every material finding present, a line each if room is short.
