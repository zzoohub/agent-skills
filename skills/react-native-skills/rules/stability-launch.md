# Stability and launch

Attributing crash, OOM, ANR and launch regressions; the launch path; config, flags and sessions at launch; memory.

## Attributing a regression

Chart the metric by day and by binary version, OTA update, platform, OS version and device class, then overlay every change: binary releases with their rollout percentage, updates, remote config and flag edits, backend deploys, third-party SDK changes (some change server-side), OS and Android System WebView releases, and shifts in who installs (a campaign, a new market).

| Onset | Points to |
|---|---|
| Starts with one binary or update, grows with its adoption | that release: diff native dependencies, SDK bumps, config plugins, launch code |
| One date, across versions | server, config or flags, a third-party SDK, an OS or WebView release |
| Grows with account age or usage | accumulating data: caches, local database, persisted state |
| Overall rate up, each cohort flat | population mix: compare within device class and version |

**Root vs trigger.** Ask what made the trigger harmful. A new SDK initialized at launch pushes an already slow synchronous launch past the watchdog; a feature with more images exposes an unbounded cache. The root fix restores the headroom the next change will need.

| Evidence | Blind to |
|---|---|
| Crash reporter | OOM and watchdog kills, missing or only inferred (size them from Xcode Organizer terminations, MetricKit exit metrics, Play vitals' user-perceived LMK rate, Android 11+ `ApplicationExitInfo`); crashes before it initializes (native startup, bundle load); sampled, rate-limited or filtered events; frames without dSYMs, R8 mappings or each update's source maps |
| Store consoles (App Store Connect, Xcode Organizer, Play vitals) | users who don't share diagnostics; OTA updates (keyed by binary); the latest days (data arrives late) |
| Analytics funnels | sessions that end before the first event; events queued offline and never sent |
| Averages | the slow-device tail: read p90 and p95 per device class |
| Dev and debug builds | Hermes bytecode, the update check, production SDK init and config |
| QA runs, test accounts | real data volume, cold or missing network, the slowest devices, the first launch after an upgrade |

**Reproduce** with production conditions: a release build with production config, update setting and SDK init; an account with realistic data; slow or no network (Network Link Conditioner, emulator throttling); the slowest supported device; installed over the previous store version, not fresh.

## Launch path

Time release cold starts (`adb shell am start -S -W <package>/<activity>`; Instruments' App Launch). List everything before the first frame and mark each item: needed for it, deferrable (after the first frame, `requestIdleCallback`, or first use), or removable.
- **Native:** SDK inits in `AppDelegate`/`MainApplication` or their config plugins (crash, analytics, ads, push, payments).
- **Updates:** expo-updates waits up to `fallbackToCacheTimeout` ms for a new update before launching the cached one. Keep it 0, the default: launch now, download in the background, apply on the next launch (sooner: a foreground check, `rules/dependencies-delivery.md`). It and `checkAutomatically` are build-time settings, so installed binaries keep their wait until replaced.
- **JS:** module scope of every eagerly imported file; root providers that hold rendering (storage hydration, auth restore, remote config, runtime fonts); a splash hidden only after a promise that may never resolve offline.

Mark the first useful frame in JS and log it with the binary and update id, so production shows its distribution per device class.

## Config, flags and sessions at launch

- **The first frame never waits on the network.** The first screen renders last-known content (a persisted query cache) or skeletons; a splash held for content is short and bounded. Config: launch on last-known-good (persisted with its fetch time), or bundled defaults when there is none; fetch fresh config in the background and apply it at a safe point or on the next launch.
- **Last-known-good is proven, not just fetched.** Promote a fetched config only after it parses, validates against this binary's schema, and a launch using it reaches the first screen. Persist a launch-attempt count before applying it; after two launches that fail, drop it, launch on the previous last-known-good (bundled defaults if none) and fetch fresh. Otherwise a bad config replays before every fetch: a crash loop no server revert can reach.
- **Each fallback says what it loses.** Bundled defaults are as old as the binary: time-bound values (prices, promotions, deadlines, legal text) carry their validity window and expire to a safe value. A timeout that drops to defaults silently undoes whatever the server changed since the build.
- **Safety controls** (kill switches, minimum-version gates, maintenance mode, compliance or entitlement checks): decide per control whether wrongly on or wrongly off does more harm, and fail toward the lesser. Unknown state keeps last-known-good, and the server enforces the control too, so a client that fails open does no damage.
- **Sessions:** a token refresh that fails offline at launch keeps the cached session; it never signs the user out.
- **Retries** back off with jitter: a config outage must not turn every launch into a retry storm.

## Memory

- **JS heap or native.** Split first with `adb shell dumpsys meminfo <package>` (Java, native, graphics). JS: heap snapshots in React Native DevTools' Memory panel, taken after repeating one navigation round trip; retained size should return to baseline. Native: Instruments (Allocations, Leaks) and Android Studio's profiler (heap dump, native allocations); decoded bitmaps (about width × height × 4 bytes each) live here, invisible to JS snapshots.
- **Usual roots:** images decoded larger than drawn (`rules/images-fonts.md`), a player or decoder per mounted row, list windows keeping many rows mounted (FlatList `windowSize`, a large `drawDistance`), unbounded in-memory caches (query, image), listeners, timers and subscriptions never removed, stacks and tabs keeping many screens mounted, closures holding large responses.
- OOM reaches support as "the app restarts", and terminations, not the crash-free rate, show it.

Docs: [expo-updates](https://docs.expo.dev/versions/latest/sdk/updates/) · [Reduce terminations](https://developer.apple.com/documentation/xcode/reduce-terminations-in-your-app) · [ApplicationExitInfo](https://developer.android.com/reference/android/app/ApplicationExitInfo) · [React Native DevTools](https://reactnative.dev/docs/react-native-devtools)
