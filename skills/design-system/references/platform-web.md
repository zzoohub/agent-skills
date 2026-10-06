# Platform: Web

## Table of Contents

1. [Token Output — CSS Custom Properties](#token-output--css-custom-properties)
2. [Dark Mode](#dark-mode)
3. [Responsive](#responsive)
4. [Focus States](#focus-states)
5. [Reduced Motion](#reduced-motion)
6. [Component Usage Example](#component-usage-example)
7. [Tailwind CSS Integration](#tailwind-css-integration)
8. [Units: rem vs px](#units-rem-vs-px)

## Token Output — CSS Custom Properties

Tokens compile to CSS variables. Components reference variables, never raw values.

```css
:root {
  /* Color — semantic */
  --color-bg-primary: #f9fafb;
  --color-bg-secondary: #f3f4f6;
  --color-bg-tertiary: #e5e7eb;
  --color-bg-inverse: #111827;
  --color-bg-overlay: rgba(0, 0, 0, 0.5);
  --color-text-primary: #111827;
  --color-text-secondary: #4b5563;
  --color-text-inverse: #f9fafb;
  --color-text-link: #2563eb;
  --color-text-link-hover: #1d4ed8;
  --color-interactive-primary: #2563eb;
  --color-interactive-primary-hover: #1d4ed8;
  --color-border-default: #e5e7eb;
  --color-border-focus: #3b82f6;
  --color-status-error: #dc2626;
  --color-status-error-bg: #fef2f2;
  --color-status-success: #16a34a;
  --color-status-success-bg: #f0fdf4;

  /* Spacing */
  --spacing-component-xs: 4px;
  --spacing-component-sm: 8px;
  --spacing-component-md: 12px;
  --spacing-component-lg: 16px;
  --spacing-component-xl: 24px;
  --spacing-layout-xs: 16px;
  --spacing-layout-sm: 24px;
  --spacing-layout-md: 32px;
  --spacing-layout-lg: 48px;
  --spacing-layout-xl: 64px;

  /* Typography */
  --font-sans: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  --font-mono: 'JetBrains Mono', 'Fira Code', monospace;

  /* Motion */
  --duration-instant: 100ms;
  --duration-fast: 200ms;
  --duration-normal: 300ms;
  --duration-slow: 500ms;
  --easing-default: cubic-bezier(0.4, 0, 0.2, 1);
  --easing-enter: cubic-bezier(0, 0, 0.2, 1);
  --easing-exit: cubic-bezier(0.4, 0, 1, 1);

  /* Radius */
  --radius-sm: 4px;
  --radius-md: 8px;
  --radius-lg: 12px;
  --radius-xl: 16px;
  --radius-full: 9999px;

  /* Shadows */
  --shadow-card: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
  --shadow-dropdown: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -2px rgba(0, 0, 0, 0.1);
  --shadow-modal: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -4px rgba(0, 0, 0, 0.1);
  --shadow-toast: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 8px 10px -6px rgba(0, 0, 0, 0.1);

  /* Z-Index */
  --z-base: 0;
  --z-dropdown: 100;
  --z-sticky: 200;
  --z-overlay: 300;
  --z-modal: 400;
  --z-popover: 450;
  --z-toast: 500;

  /* Opacity */
  --opacity-disabled: 0.5;
  --opacity-overlay: 0.5;
  --opacity-hover: 0.8;
}
```

> This `:root` block is an excerpt — it omits some semantic tokens (e.g. `text.tertiary`, `border.strong`, `status.warning`/`warning-bg`). For the complete set, generate `:root` from `semantic.tokens.json` (see `references/tokens.md`).

## Dark Mode

Two-layer approach: respect system preference, allow manual override.

```css
/* System preference (auto) */
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) {
    --color-bg-primary: #111827;
    --color-bg-secondary: #1f2937;
    --color-bg-tertiary: #374151;
    --color-bg-inverse: #f9fafb;
    --color-text-primary: #f9fafb;
    --color-text-inverse: #111827;
    --color-text-secondary: #d1d5db;
    --color-text-link: #60a5fa;
    --color-interactive-primary: #3b82f6;
    --color-interactive-primary-hover: #60a5fa;
    --color-border-default: #374151;
    --color-border-focus: #60a5fa;

    --shadow-card: 0 1px 2px 0 rgba(0, 0, 0, 0.2);
    --shadow-dropdown: 0 4px 6px -1px rgba(0, 0, 0, 0.3), 0 2px 4px -2px rgba(0, 0, 0, 0.2);
    --shadow-modal: 0 10px 15px -3px rgba(0, 0, 0, 0.4), 0 4px 6px -4px rgba(0, 0, 0, 0.3);
    --shadow-toast: 0 20px 25px -5px rgba(0, 0, 0, 0.4), 0 8px 10px -6px rgba(0, 0, 0, 0.3);
  }
}

/* Manual override */
[data-theme="dark"] {
  --color-bg-primary: #111827;
  --color-bg-secondary: #1f2937;
  --color-bg-tertiary: #374151;
  --color-text-inverse: #111827;
  /* ... same color remaps + shadow overrides ... */
}
```

Set `data-theme` on `<html>`. Components never check theme — they just read CSS variables.

## Responsive

Mobile-first. Base styles are mobile, scale up with `min-width`.

```css
/* Base = mobile */
@media (min-width: 640px)  { /* sm — large phones, landscape */ }
@media (min-width: 768px)  { /* md — tablets */ }
@media (min-width: 1024px) { /* lg — laptops */ }
@media (min-width: 1280px) { /* xl — desktops */ }
```

## Focus States

Visible for keyboard users, hidden for mouse.

```css
:focus-visible {
  outline: 2px solid var(--color-border-focus);
  outline-offset: 2px;
}

:focus:not(:focus-visible) {
  outline: none;
}
```

## Reduced Motion

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
  }
}
```

## Component Usage Example

```css
.button-primary {
  background-color: var(--color-interactive-primary);
  color: var(--color-text-inverse);
  padding: var(--spacing-component-md) var(--spacing-component-lg);
  border-radius: var(--radius-md);
  font-family: var(--font-sans);
  font-size: 16px;
  font-weight: 600;
  transition: background-color var(--duration-fast) var(--easing-default);
}

.button-primary:hover {
  background-color: var(--color-interactive-primary-hover);
}
```

## Tailwind CSS Integration

If the project uses Tailwind, map design tokens to the Tailwind config so you get utility classes that use your tokens. This is the recommended approach for Tailwind projects.

### Tailwind v4 (CSS-based config)

Tailwind v4 uses CSS `@theme` to define tokens. Use `@theme inline` here: the `inline` keyword makes each generated utility emit the referenced value (`var(--color-x)`) directly, so it resolves on the element that uses the utility. Without `inline`, the utility reads Tailwind's own theme variable, and a theme variable that aliases another variable (e.g. `--color-x: var(--x)`) is resolved where the theme variable is defined (`:root`) — a `[data-theme="dark"]` override scoped to a subtree would then not reach the utility. For same-name entries like the ones below, plain `@theme` usually also works, because the unlayered `:root` / dark declarations above beat Tailwind's `@layer theme` output; `inline` keeps it correct regardless of how the token CSS is layered. With `inline`, the `:root` / `[data-theme="dark"]` overrides flow straight through to the utilities:

```css
/* globals.css */
@import "tailwindcss";

@theme inline {
  --color-bg-primary: var(--color-bg-primary);
  --color-bg-secondary: var(--color-bg-secondary);
  --color-bg-tertiary: var(--color-bg-tertiary);
  --color-bg-inverse: var(--color-bg-inverse);
  --color-text-primary: var(--color-text-primary);
  --color-text-secondary: var(--color-text-secondary);
  --color-text-inverse: var(--color-text-inverse);
  --color-text-link: var(--color-text-link);
  --color-interactive-primary: var(--color-interactive-primary);
  --color-interactive-primary-hover: var(--color-interactive-primary-hover);
  --color-border-default: var(--color-border-default);
  --color-border-focus: var(--color-border-focus);
  --color-status-error: var(--color-status-error);
  --color-status-success: var(--color-status-success);

  --shadow-card: var(--shadow-card);
  --shadow-dropdown: var(--shadow-dropdown);
  --shadow-modal: var(--shadow-modal);
  --shadow-toast: var(--shadow-toast);

  --spacing-component-xs: var(--spacing-component-xs);
  --spacing-component-sm: var(--spacing-component-sm);
  --spacing-component-md: var(--spacing-component-md);
  --spacing-component-lg: var(--spacing-component-lg);
  --spacing-component-xl: var(--spacing-component-xl);
  --spacing-layout-xs: var(--spacing-layout-xs);
  --spacing-layout-sm: var(--spacing-layout-sm);
  --spacing-layout-md: var(--spacing-layout-md);
  --spacing-layout-lg: var(--spacing-layout-lg);
  --spacing-layout-xl: var(--spacing-layout-xl);
}
```

Usage: `bg-bg-primary`, `text-text-secondary`, `shadow-card`, `p-component-md`.

### Tailwind v3 (JS config)

Tailwind v4 no longer detects `tailwind.config.js` automatically, but still loads it for backward compatibility via an explicit `@config "./tailwind.config.js";` in the CSS entry (some options — `corePlugins`, `safelist`, `separator` — are unsupported). Prefer `@theme` for new v4 projects.

```javascript
// tailwind.config.js
module.exports = {
  theme: {
    extend: {
      colors: {
        bg: {
          primary: 'var(--color-bg-primary)',
          secondary: 'var(--color-bg-secondary)',
          inverse: 'var(--color-bg-inverse)',
        },
        text: {
          primary: 'var(--color-text-primary)',
          secondary: 'var(--color-text-secondary)',
          link: 'var(--color-text-link)',
        },
        interactive: {
          primary: 'var(--color-interactive-primary)',
          'primary-hover': 'var(--color-interactive-primary-hover)',
        },
        border: {
          DEFAULT: 'var(--color-border-default)',
          focus: 'var(--color-border-focus)',
        },
        status: {
          error: 'var(--color-status-error)',
          success: 'var(--color-status-success)',
        },
      },
      boxShadow: {
        card: 'var(--shadow-card)',
        dropdown: 'var(--shadow-dropdown)',
        modal: 'var(--shadow-modal)',
        toast: 'var(--shadow-toast)',
      },
      zIndex: {
        dropdown: 'var(--z-dropdown)',
        sticky: 'var(--z-sticky)',
        overlay: 'var(--z-overlay)',
        modal: 'var(--z-modal)',
        popover: 'var(--z-popover)',
        toast: 'var(--z-toast)',
      },
    },
  },
};
```

Usage: `bg-bg-primary`, `text-text-secondary`, `shadow-card`, `z-modal`.

The key idea: Tailwind utilities become the consumption layer, CSS custom properties remain the source of truth. Dark mode works automatically because the CSS variables swap values.

## Units: rem vs px

For better accessibility, consider defining spacing and typography tokens in `rem` instead of `px`. Users who set a larger browser font size will benefit from layouts that scale proportionally.

```css
:root {
  /* rem-based spacing (1rem = 16px at default browser settings) */
  --spacing-component-xs: 0.25rem;  /* 4px */
  --spacing-component-sm: 0.5rem;   /* 8px */
  --spacing-component-md: 0.75rem;  /* 12px */
  --spacing-component-lg: 1rem;     /* 16px */
  --spacing-component-xl: 1.5rem;   /* 24px */
}
```

The px values in this skill's token definitions are the canonical reference. When outputting for web, the pipeline can convert px to rem automatically (divide by 16). For React Native, px values are correct since RN uses device-independent points.
