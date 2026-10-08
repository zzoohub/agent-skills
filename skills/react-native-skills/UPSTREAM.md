# Upstream and fork posture

A frozen, host-agnostic fork of [`vercel-labs/agent-skills` → `react-native-skills`](https://github.com/vercel-labs/agent-skills/tree/main/skills/react-native-skills) (MIT), taken 2026-06-04 (commit `f85be53`). Upstream, now `vercel-react-native-skills`, last changed 2026-01-27 (checked 2026-10-08); its build files (`_sections.md`, `_template.md`, `metadata.json`) and compiled `AGENTS.md` are not adopted.

**Policy:** never re-clone over this directory. Port upstream fixes by hand into the owning file; re-verify version and API claims against primary docs and type-check changed snippets.

## Where the upstream rules went (2026-10; files under `rules/`)

- lists: `list-performance-*`, `js-hoist-intl` (image sizing → images-fonts)
- animation-gestures: `animation-*`, `state-ground-truth`, `scroll-position-no-state`, `react-compiler-reanimated-shared-values`, `ui-pressable`
- navigation-native-ui: `navigation-native-navigators`, `ui-native-modals`, `ui-menus`, `ui-image-gallery`
- platform-layout: `ui-safe-area-scroll`, `ui-scrollview-content-inset`, `ui-measure-views`, `ui-styling` mechanics
- images-fonts: `ui-expo-image`, `fonts-config-plugin`; dependencies-delivery: `monorepo-*`
- SKILL.md §5: `rendering-*`, and `react-state-fallback` and `react-state-minimize` as its State rule; lists' Row state applies them to recycled rows. `react-state-dispatcher` → platform-layout's Measuring. `design-system-compound-components` keeps the rule; its Button is design-system's
- Cut: `react-compiler-destructure-functions` (false premise), `imports-design-system-folder` (design-system's)

## Local corrections to keep

All of SKILL.md, and `rules/stability-launch.md` (local, no upstream counterpart). In the rules: Hermes gaps; Reanimated 4 and Gesture Handler 3 APIs; accessibility semantics in the house spelling (`role`/`aria-*` or `accessibility*`); recycling and row state; the iOS-only → Android table; Expo Router's SDK 56 imports, native-tabs paths and form-sheet limits; RN 0.87 `backgroundImage` and ref types; pnpm 11; Expo autolinking; fingerprint runtime versions.
