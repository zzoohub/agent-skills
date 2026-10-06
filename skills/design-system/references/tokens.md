# Token Definitions

DTCG-inspired format. Single source of truth for all platforms.

## Table of Contents

1. [File Structure](#file-structure)
2. [Primitive Tokens](#primitive-tokens)
3. [Semantic Tokens](#semantic-tokens)
4. [Dark Theme](#dark-theme)
5. [Component Tokens (Tier 3 — Use Sparingly)](#component-tokens-tier-3--use-sparingly)

> **Note on DTCG conformance:** This file uses CSS-string shorthands for some `$value`s rather than the strict DTCG object forms. The `shadow` tokens use a raw CSS string (not the object form `{color, offsetX, offsetY, blur, spread}`), and `dimension` tokens (spacing, radius) use strings like `"4px"` rather than the DTCG object `{ "value": 4, "unit": "px" }`. If you need strict DTCG conformance for Style Dictionary v4 / Terrazzo / Tokens Studio, expand both the shadow and dimension tokens to the structured object format per the DTCG 2025.10 spec. Otherwise, these CSS-string variants ship fine through custom Style Dictionary transforms.

## File Structure

```
src/shared/ui/tokens/
├── primitive.tokens.json    # Raw values — never use directly
├── semantic.tokens.json     # Intent-based — use in components
├── themes/
│   ├── light.tokens.json    # Default (can be implicit)
│   └── dark.tokens.json     # Remaps semantic only
└── component.tokens.json    # Optional overrides (rare)
```

## Primitive Tokens

Bounded palette of raw values. These exist so semantic tokens have something to reference. Components never import these.

```json
{
  "color": {
    "gray": {
      "50":  { "$value": "#f9fafb", "$type": "color" },
      "100": { "$value": "#f3f4f6", "$type": "color" },
      "200": { "$value": "#e5e7eb", "$type": "color" },
      "300": { "$value": "#d1d5db", "$type": "color" },
      "400": { "$value": "#9ca3af", "$type": "color" },
      "500": { "$value": "#6b7280", "$type": "color" },
      "600": { "$value": "#4b5563", "$type": "color" },
      "700": { "$value": "#374151", "$type": "color" },
      "800": { "$value": "#1f2937", "$type": "color" },
      "900": { "$value": "#111827", "$type": "color" },
      "950": { "$value": "#030712", "$type": "color" }
    },
    "blue": {
      "50":  { "$value": "#eff6ff", "$type": "color" },
      "300": { "$value": "#93c5fd", "$type": "color" },
      "400": { "$value": "#60a5fa", "$type": "color" },
      "500": { "$value": "#3b82f6", "$type": "color" },
      "600": { "$value": "#2563eb", "$type": "color" },
      "700": { "$value": "#1d4ed8", "$type": "color" },
      "800": { "$value": "#1e40af", "$type": "color" }
    },
    "red": {
      "50":  { "$value": "#fef2f2", "$type": "color" },
      "500": { "$value": "#ef4444", "$type": "color" },
      "600": { "$value": "#dc2626", "$type": "color" }
    },
    "amber": {
      "50":  { "$value": "#fffbeb", "$type": "color" },
      "500": { "$value": "#f59e0b", "$type": "color" },
      "600": { "$value": "#d97706", "$type": "color" }
    },
    "green": {
      "50":  { "$value": "#f0fdf4", "$type": "color" },
      "500": { "$value": "#22c55e", "$type": "color" },
      "600": { "$value": "#16a34a", "$type": "color" }
    }
  },
  "spacing": {
    "0":  { "$value": "0px",  "$type": "dimension" },
    "1":  { "$value": "4px",  "$type": "dimension" },
    "2":  { "$value": "8px",  "$type": "dimension" },
    "3":  { "$value": "12px", "$type": "dimension" },
    "4":  { "$value": "16px", "$type": "dimension" },
    "5":  { "$value": "20px", "$type": "dimension" },
    "6":  { "$value": "24px", "$type": "dimension" },
    "8":  { "$value": "32px", "$type": "dimension" },
    "10": { "$value": "40px", "$type": "dimension" },
    "12": { "$value": "48px", "$type": "dimension" },
    "16": { "$value": "64px", "$type": "dimension" },
    "20": { "$value": "80px", "$type": "dimension" }
  },
  "radius": {
    "none": { "$value": "0px",    "$type": "dimension" },
    "sm":   { "$value": "4px",    "$type": "dimension" },
    "md":   { "$value": "8px",    "$type": "dimension" },
    "lg":   { "$value": "12px",   "$type": "dimension" },
    "xl":   { "$value": "16px",   "$type": "dimension" },
    "2xl":  { "$value": "24px",   "$type": "dimension" },
    "full": { "$value": "9999px", "$type": "dimension" }
  },
  "shadow": {
    "sm":  { "$value": "0 1px 2px 0 rgba(0, 0, 0, 0.05)", "$type": "shadow" },
    "md":  { "$value": "0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -2px rgba(0, 0, 0, 0.1)", "$type": "shadow" },
    "lg":  { "$value": "0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -4px rgba(0, 0, 0, 0.1)", "$type": "shadow" },
    "xl":  { "$value": "0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 8px 10px -6px rgba(0, 0, 0, 0.1)", "$type": "shadow" }
  },
  "opacity": {
    "disabled": { "$value": "0.5",  "$type": "number" },
    "overlay":  { "$value": "0.5",  "$type": "number" },
    "hover":    { "$value": "0.8",  "$type": "number" }
  },
  "zIndex": {
    "base":     { "$value": "0",   "$type": "number" },
    "dropdown": { "$value": "100", "$type": "number" },
    "sticky":   { "$value": "200", "$type": "number" },
    "overlay":  { "$value": "300", "$type": "number" },
    "modal":    { "$value": "400", "$type": "number" },
    "popover":  { "$value": "450", "$type": "number" },
    "toast":    { "$value": "500", "$type": "number" }
  }
}
```

## Semantic Tokens

Every value a component uses comes from here. The naming tells you what it's for, not what it looks like.

```json
{
  "color": {
    "bg": {
      "primary":   { "$value": "{color.gray.50}",  "$type": "color" },
      "secondary": { "$value": "{color.gray.100}", "$type": "color" },
      "tertiary":  { "$value": "{color.gray.200}", "$type": "color" },
      "inverse":   { "$value": "{color.gray.900}", "$type": "color" },
      "overlay":   { "$value": "rgba(0, 0, 0, 0.5)", "$type": "color" }
    },
    "text": {
      "primary":   { "$value": "{color.gray.900}", "$type": "color" },
      "secondary": { "$value": "{color.gray.600}", "$type": "color" },
      "tertiary":  { "$value": "{color.gray.500}", "$type": "color" },
      "inverse":   { "$value": "{color.gray.50}",  "$type": "color" },
      "link":      { "$value": "{color.blue.600}", "$type": "color" },
      "linkHover": { "$value": "{color.blue.700}", "$type": "color" }
    },
    "interactive": {
      "primary":       { "$value": "{color.blue.600}", "$type": "color" },
      "primaryHover":  { "$value": "{color.blue.700}", "$type": "color" },
      "primaryActive": { "$value": "{color.blue.800}", "$type": "color" }
    },
    "border": {
      "default": { "$value": "{color.gray.200}", "$type": "color" },
      "strong":  { "$value": "{color.gray.300}", "$type": "color" },
      "focus":   { "$value": "{color.blue.500}", "$type": "color" }
    },
    "status": {
      "error":      { "$value": "{color.red.600}",   "$type": "color" },
      "errorBg":    { "$value": "{color.red.50}",    "$type": "color" },
      "warning":    { "$value": "{color.amber.600}", "$type": "color" },
      "warningBg":  { "$value": "{color.amber.50}",  "$type": "color" },
      "success":    { "$value": "{color.green.600}", "$type": "color" },
      "successBg":  { "$value": "{color.green.50}",  "$type": "color" }
    }
  },
  "shadow": {
    "card":     { "$value": "{shadow.sm}",  "$type": "shadow" },
    "dropdown": { "$value": "{shadow.md}",  "$type": "shadow" },
    "modal":    { "$value": "{shadow.lg}",  "$type": "shadow" },
    "toast":    { "$value": "{shadow.xl}",  "$type": "shadow" }
  },
  "spacing": {
    "component": {
      "xs": { "$value": "{spacing.1}",  "$type": "dimension" },
      "sm": { "$value": "{spacing.2}",  "$type": "dimension" },
      "md": { "$value": "{spacing.3}",  "$type": "dimension" },
      "lg": { "$value": "{spacing.4}",  "$type": "dimension" },
      "xl": { "$value": "{spacing.6}",  "$type": "dimension" }
    },
    "layout": {
      "xs": { "$value": "{spacing.4}",  "$type": "dimension" },
      "sm": { "$value": "{spacing.6}",  "$type": "dimension" },
      "md": { "$value": "{spacing.8}",  "$type": "dimension" },
      "lg": { "$value": "{spacing.12}", "$type": "dimension" },
      "xl": { "$value": "{spacing.16}", "$type": "dimension" }
    }
  }
}
```

## Dark Theme

Remaps semantic tokens only. Components and primitives stay unchanged.

```json
{
  "color": {
    "bg": {
      "primary":   { "$value": "{color.gray.900}", "$type": "color" },
      "secondary": { "$value": "{color.gray.800}", "$type": "color" },
      "tertiary":  { "$value": "{color.gray.700}", "$type": "color" },
      "inverse":   { "$value": "{color.gray.50}",  "$type": "color" },
      "overlay":   { "$value": "rgba(0, 0, 0, 0.7)", "$type": "color" }
    },
    "text": {
      "primary":   { "$value": "{color.gray.50}",  "$type": "color" },
      "secondary": { "$value": "{color.gray.300}", "$type": "color" },
      "tertiary":  { "$value": "{color.gray.400}", "$type": "color" },
      "inverse":   { "$value": "{color.gray.900}", "$type": "color" },
      "link":      { "$value": "{color.blue.400}", "$type": "color" },
      "linkHover": { "$value": "{color.blue.300}", "$type": "color" }
    },
    "interactive": {
      "primary":       { "$value": "{color.blue.500}", "$type": "color" },
      "primaryHover":  { "$value": "{color.blue.400}", "$type": "color" },
      "primaryActive": { "$value": "{color.blue.600}", "$type": "color" }
    },
    "border": {
      "default": { "$value": "{color.gray.700}", "$type": "color" },
      "strong":  { "$value": "{color.gray.600}", "$type": "color" },
      "focus":   { "$value": "{color.blue.400}", "$type": "color" }
    },
    "status": {
      "error":     { "$value": "{color.red.500}",            "$type": "color" },
      "errorBg":   { "$value": "rgba(239, 68, 68, 0.15)",    "$type": "color" },
      "warning":   { "$value": "{color.amber.500}",          "$type": "color" },
      "warningBg": { "$value": "rgba(245, 158, 11, 0.15)",   "$type": "color" },
      "success":   { "$value": "{color.green.500}",          "$type": "color" },
      "successBg": { "$value": "rgba(34, 197, 94, 0.15)",    "$type": "color" }
    }
  },
  "shadow": {
    "card":     { "$value": "0 1px 2px 0 rgba(0, 0, 0, 0.2)", "$type": "shadow" },
    "dropdown": { "$value": "0 4px 6px -1px rgba(0, 0, 0, 0.3), 0 2px 4px -2px rgba(0, 0, 0, 0.2)", "$type": "shadow" },
    "modal":    { "$value": "0 10px 15px -3px rgba(0, 0, 0, 0.4), 0 4px 6px -4px rgba(0, 0, 0, 0.3)", "$type": "shadow" },
    "toast":    { "$value": "0 20px 25px -5px rgba(0, 0, 0, 0.4), 0 8px 10px -6px rgba(0, 0, 0, 0.3)", "$type": "shadow" }
  }
}
```

Dark mode shadows use higher opacity values because on dark surfaces, subtle shadows are invisible. The shadow color stays pure black in both themes — only the opacity (alpha) increases, not the color. Status tokens also remap in dark mode: foregrounds shift to lighter shades (`*.500`) and the `*Bg` fills become low-opacity tints, so alerts and toasts don't render as near-white blocks on a dark surface.

## Component Tokens (Tier 3 — Use Sparingly)

Only when a specific component needs values that don't map to any semantic token. Most components should never need this.

```json
{
  "button": {
    "borderRadius": { "$value": "{radius.md}", "$type": "dimension" },
    "paddingX": {
      "sm": { "$value": "{spacing.component.md}", "$type": "dimension" },
      "md": { "$value": "{spacing.component.lg}", "$type": "dimension" },
      "lg": { "$value": "{spacing.component.xl}", "$type": "dimension" }
    }
  }
}
```
