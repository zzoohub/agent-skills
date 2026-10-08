# Ergonomics & Accessibility

The floors and platform defaults that UX specs are judged against. This file is the library's single home for these numbers: other skills cite it rather than restating them, and design-system encodes them as component minimums and contrast pairs.

## Conformance target

Design to WCAG 2.2 AA unless the PRD or the architecture (default `docs/arch/context.md` §5 C-03) requires more. The legal floor depends on jurisdiction and sector and changes over time, so confirm it at ship time (EU: the European Accessibility Act through EN 301 549, and the Web Accessibility Directive for the public sector; US: the ADA and Section 508).

## Floors

| Requirement | Floor |
|---|---|
| Pointer target | ≥24×24 CSS px, or spaced so that a 24 px circle centered on each smaller target intersects no other target or circle (WCAG 2.2 SC 2.5.8, AA; exceptions for inline links, equivalent controls, browser controls and essential sizes) |
| Touch target | iOS 44×44 pt by default, 28×28 pt minimum (Apple HIG); Android 48×48 dp. The hit area may exceed the visible control. XR targets: `xr-design.md` § Input map |
| Spacing (iOS) | About 12 pt around controls with a bezel, about 24 pt around those without |
| Text contrast | 4.5:1; large text (≥18 pt, or ≥14 pt bold) 3:1; placeholders included (SC 1.4.3, AA) |
| Non-text contrast | 3:1 for control boundaries, states, focus indicators and meaningful icons (SC 1.4.11, AA) |
| Focus | Always visible (SC 2.4.7, AA), ≥3:1 against adjacent colors, never fully hidden by sticky bars, banners or chat widgets, which must leave room for it (SC 2.4.11, AA). A 2 px outline is a house default; the full Focus Appearance rule (SC 2.4.13) is AAA |
| Reflow | Usable at 320 CSS px wide without horizontal scrolling, which equals 1280 px at 400% zoom (SC 1.4.10, AA); content that needs two dimensions (maps, data tables, editors) is exempt |
| Text size | Web: text resizes to 200% (SC 1.4.4, AA). iOS: up to the largest accessibility size (AX5: Body 17 → 53 pt). Android: 200% font scale |
| Timing | Time limits can be turned off or extended (SC 2.2.1, A), toasts with an action included (`interaction-patterns.md` § Feedback channels) |
| Flashing | No more than three flashes in any one second (SC 2.3.1, A) |

## Requirements that change structure

These shape flows and layouts, so they belong in the UX doc, not only in component code:
- **Dragging (SC 2.5.7, AA) and path or multi-finger gestures (SC 2.5.1, A):** each has a single-pointer alternative (Move up and down, "Move to…", zoom buttons).
- **Consistent help (SC 3.2.6, A):** help (contact, chat, FAQ) sits in the same relative place on every screen that offers it.
- **Redundant entry (SC 3.3.7, A):** never ask again for what the user gave earlier in the same process; prefill it or offer it to select.
- **Accessible authentication (SC 3.3.8, AA):** no memory or puzzle test to sign in without an alternative; allow paste and password managers; passkeys qualify. Object-recognition tests pass at AA; SC 3.3.9 (AAA) removes that exception.
- **Color is never the only signal**, the current location and selection in navigation included: pair it with text, an icon, shape or weight (web: `aria-current` on the current item).
- **Keyboard and screen readers:** every control, navigation menus included, is reachable and operable by keyboard, and nothing opens only on hover; focus order follows reading order and returns to an overlay's trigger when it closes; changes that don't move focus are announced in a status region.
- **Motion:** every motion in a spec names its reduced-motion variant (`interaction-patterns.md` § Gestures and motion).
- **Translucent surfaces** (glass materials): check legibility with Reduce Transparency and Increase Contrast on.

## Layout by window, not device

- Lay out by window size class, never by device model. iOS: compact and regular. Android: compact (<600 dp), medium (600–839), expanded (840–1199), large (1200–1599), extra-large (≥1600). Web: break where the content breaks, from the 320 CSS px floor.
- Windows change size (split view, foldables, desktop windows, rotation): the layout follows the window and keeps its state. On large screens (smallest width over 600 dp) Android ignores apps' orientation, resizability and aspect-ratio locks, with no opt-out from API 37 (games excepted), so tablet and foldable layouts need both orientations.
- Read safe areas (camera cutouts, home indicator, rounded corners, system bars) at runtime; never hardcode insets. Android draws apps edge to edge (the default from Android 15; no opt-out for apps targeting Android 16).

## Platform conventions

Follow each platform's patterns for standard tasks, naming patterns, not API classes; deviate only where a custom pattern measurably wins for daily experts, and record it as a decision. Recent changes that alter structure (checked 2026-10; re-check before citing):
- **Back on iOS:** from iOS 26, swiping anywhere in a pushed view's content goes back, so leading-edge swipe actions and horizontal carousels there need a deliberate resolution.
- **Top-level navigation on Android:** a navigation bar on compact windows, a rail on wider ones; Material 3 Expressive deprecates the drawer in favor of an expanded rail.

Actions and menus are never hover-only. Placement: platform conventions beat thumb-zone charts; keep frequent one-handed actions within reach on phones.
