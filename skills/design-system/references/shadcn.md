# shadcn/ui + cva + Radix Primitives Integration

shadcn isn't a library — it's a code-gen tool that copies components into your repo. Tokens flow through CSS variables; variants are built with `class-variance-authority` (cva); accessibility comes from Radix Primitives.

## Table of Contents

1. [Stack](#stack)
2. [File layout (FSD-aware)](#file-layout-fsd-aware)
3. [CLI config — components.json](#cli-config--componentsjson)
4. [The cn helper](#the-cn-helper)
5. [Button with cva (reads design tokens via Tailwind classes)](#button-with-cva-reads-design-tokens-via-tailwind-classes)
6. [Why asChild via Radix Slot](#why-aschild-via-radix-slot)
7. [Token integration with Tailwind v4](#token-integration-with-tailwind-v4)
8. [Forms — pair with react-hook-form + zod](#forms--pair-with-react-hook-form--zod)
9. [When NOT to use shadcn](#when-not-to-use-shadcn)
10. [Alternatives](#alternatives)


## Stack

| Layer | Tool |
|---|---|
| Headless primitives | Radix via the unified `radix-ui` package (Dialog, Popover, Select, etc.; older projects import per-primitive `@radix-ui/react-*` packages) — or Base UI, chosen at `npx shadcn create` |
| Variants | `class-variance-authority` (cva) |
| Class merging | `tailwind-merge` + `clsx` (exposed as `cn()`) |
| Tokens | Tailwind v4 `@theme` reading project CSS variables |
| Generator | `npx shadcn@latest add <component>` |

## File layout (FSD-aware)

```
shared/ui/
├── button.tsx           # shadcn-generated, owned by us
├── dialog.tsx           # shadcn-generated, owned by us
└── lib/
    └── cn.ts            # cn helper
```

## CLI config — `components.json`

The shadcn CLI is driven by a project-root `components.json` (style, the Tailwind CSS entry path, RSC/tsx flags, import aliases, and registries). Because this FSD layout puts `cn` at `@/shared/ui/lib/cn` rather than the CLI default `@/lib/utils`, set the aliases so generated components import from the right place:

```json
{
  "aliases": {
    "utils": "@/shared/ui/lib/cn",
    "components": "@/shared/ui"
  }
}
```

Without this, `npx shadcn@latest add` scaffolds imports like `@/lib/utils` that won't resolve in this structure.

## The `cn` helper

```ts
import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}
```

## Button with cva (reads design tokens via Tailwind classes)

```tsx
import { cva, type VariantProps } from 'class-variance-authority';
import { cn } from '@/shared/ui/lib/cn';
import { Slot } from 'radix-ui'; // unified package; older projects: import { Slot } from '@radix-ui/react-slot'

const buttonVariants = cva(
  'inline-flex items-center justify-center gap-2 rounded-md font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 disabled:opacity-50',
  {
    variants: {
      variant: {
        primary: 'bg-interactive-primary text-white hover:bg-interactive-primary-hover',
        secondary: 'border border-border-default bg-bg-secondary hover:bg-bg-tertiary',
        danger: 'bg-status-error text-white hover:bg-status-error/90',
        ghost: 'hover:bg-bg-secondary',
      },
      size: {
        sm: 'h-8 px-3 text-sm',
        md: 'h-10 px-4',
        lg: 'h-12 px-6 text-lg',
      },
    },
    defaultVariants: { variant: 'primary', size: 'md' },
  }
);

interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {
  asChild?: boolean;
}

export function Button({ className, variant, size, asChild, ...props }: ButtonProps) {
  const Comp = asChild ? Slot.Root : 'button'; // with @radix-ui/react-slot: `Slot`
  return <Comp className={cn(buttonVariants({ variant, size, className }))} {...props} />;
}
```

## Why `asChild` via Radix `Slot`

`<Button asChild><Link to="/">Home</Link></Button>` — renders a real `<a>` (from your Link) but inherits Button's classes. Avoids div-in-link / link-in-button structural problems.

Since February 2026 the shadcn new-york templates import Radix from the unified `radix-ui` package (`import { Slot } from 'radix-ui'`, used as `Slot.Root`) instead of the per-primitive `@radix-ui/react-*` packages. Migrate existing components with `npx shadcn@latest migrate radix`, then remove the unused `@radix-ui/react-*` dependencies.

## Token integration with Tailwind v4

Tokens are defined as CSS custom properties in `:root` (see `platform-web.md`); an `@theme inline` block bridges them into Tailwind's utility generator so cva can consume `bg-*`/`text-*`/`hover:*` classes. Use the `inline` keyword: it makes each generated utility emit the referenced value (`var(--color-x)`) directly, so it resolves on the element that uses the utility. Without `inline`, a theme variable that aliases another variable is resolved where Tailwind defines it (`:root`), so a theme override scoped to a subtree would not reach the utility; for same-name entries the unlayered `:root` / dark declarations usually win over Tailwind's `@layer theme` output anyway, but `inline` keeps it correct regardless of layering. With `inline`, runtime overrides flow through correctly. Keep `:root` and utility names identical (both kebab-case):

```css
@theme inline {
  --color-interactive-primary: var(--color-interactive-primary);            /* utility → :root value */
  --color-interactive-primary-hover: var(--color-interactive-primary-hover);
}
```
→ Tailwind generates `bg-interactive-primary` and `hover:bg-interactive-primary-hover`, both resolving to the `:root` variables — so dark mode just works.

## Forms — pair with react-hook-form + zod

shadcn's `Form` component wraps react-hook-form with Radix's `Label` and a `FormField` adapter. Use `@hookform/resolvers/zod` for schema-typed forms.

## When NOT to use shadcn

- Highly bespoke design language that doesn't map to Radix Primitives' interaction model
- Need fully framework-agnostic components (shadcn is React-only; for Vue/Solid see Park UI, Ark UI, Kobalte)
- Strict bundle-size constraints where the Radix dependency is too much

## Alternatives

- **Park UI / Ark UI** — same idea, multi-framework via Zag.js
- **Headless UI** — Tailwind Labs' own headless library; smaller surface area
- **Base UI** — unstyled React library (stable 1.x) from the creators of Radix, Material UI and Floating UI; shadcn can also generate its components on Base UI instead of Radix (pick it in `npx shadcn create`)
