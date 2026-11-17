# React Native

The same roles, pairs and component contracts as the web; only the carrier changes. Each block's first line is its path. Lists, gestures, navigation and performance belong to Expo's official skills, if available.

## Table of Contents

1. [Tokens are a module](#tokens-are-a-module)
2. [Theme at first frame](#theme-at-first-frame)
3. [Button](#button)
4. [Pair test](#pair-test)
5. [Type](#type)
6. [Accessibility](#accessibility)
7. [Reduced motion](#reduced-motion)

## Tokens are a module

Follow the app's styling engine and never add a second one. A Tailwind-on-native engine (NativeWind, Uniwind) takes the web's role names as its theme variables, so one class vocabulary spans both platforms. Unistyles or Tamagui take the module below as their theme config. Plain `StyleSheet` reads it directly.

```ts
// src/shared/ui/theme.ts
export const light = {
  bg: { base: '#f9fafb', raised: '#ffffff', subtle: '#f3f4f6', accent: '#2563eb', accentHover: '#1d4ed8', danger: '#dc2626', dangerHover: '#b91c1c' },
  fg: { default: '#111827', muted: '#6b7280', link: '#2563eb', danger: '#b91c1c', onAccent: '#ffffff', onDanger: '#ffffff' },
  border: { default: '#e5e7eb', input: '#6b7280', focus: '#3b82f6' },
}

/** Typed from the first theme, so a theme with a missing or extra role doesn't compile */
export type Theme = typeof light

export const dark: Theme = {
  bg: { base: '#111827', raised: '#1f2937', subtle: '#374151', accent: '#3b82f6', accentHover: '#60a5fa', danger: '#ef4444', dangerHover: '#f87171' },
  fg: { default: '#f9fafb', muted: '#9ca3af', link: '#60a5fa', danger: '#f87171', onAccent: '#030712', onDanger: '#030712' },
  border: { default: '#374151', input: '#6b7280', focus: '#60a5fa' },
}

// Scales that no theme changes. Line heights are absolute, so each travels with its size
export const space = { xs: 4, sm: 8, md: 12, lg: 16, xl: 24 } as const
export const radius = { sm: 4, md: 8, lg: 12, full: 9999 } as const
export const type = {
  sm: { fontSize: 14, lineHeight: 20 },
  base: { fontSize: 16, lineHeight: 24 },
  lg: { fontSize: 18, lineHeight: 28 },
  xl: { fontSize: 20, lineHeight: 28 },
} as const
export const size = { touchTarget: 48 } as const // Android's 48dp, which covers iOS's 44pt
export const opacity = { disabled: 0.5 } as const
```

- **A product with one theme** exports one object and components import it. Don't invent the second theme: a design that is dark-only stays dark whatever the OS says.
- **The same roles as the web.** `bg.accentHover` is the pressed fill here: one name per intent across platforms beats a second vocabulary.
- **A web app in the same repo** shares one source. Keep this module as that source and emit the web's theme blocks from it with a short script, not a token-pipeline dependency. Two hand-kept copies drift.

## Theme at first frame

With two themes, a themed value reaches a component only through the hook. A static import of one theme would never change.

```tsx
// src/shared/ui/theme-provider.tsx
import { createContext, use, type ReactNode } from 'react'
import { useColorScheme } from 'react-native'

import { dark, light, type Theme } from './theme'

export type ThemePreference = 'system' | 'light' | 'dark'

const ThemeContext = createContext<Theme>(light)

/** Load the stored preference before the first render (keep the splash screen up), or the app flashes */
export function ThemeProvider({ preference, children }: { preference: ThemePreference; children: ReactNode }) {
  const system = useColorScheme() // follows the OS setting live
  const isDark = preference === 'dark' || (preference === 'system' && system === 'dark')
  return <ThemeContext value={isDark ? dark : light}>{children}</ThemeContext>
}

export const useTheme = () => use(ThemeContext)
```

- Native chrome (alerts, pickers, the keyboard) follows an explicit choice only if the app also calls `Appearance.setColorScheme()`. The value that hands control back to the OS has changed between releases: read the installed types.
- A brand that arrives later (after login, from remote config) replaces the themes the provider chooses between; store it so the next launch starts in it, and clear it at logout. The splash screen and the app icon are brand surfaces outside the tokens: list them.

## Button

Strings render only inside `ButtonText`: React Native draws text only inside `<Text>`, and a `typeof children === 'string'` switch breaks on mixed children (`{count} items`). While loading, the hidden label keeps the width and the accessible name. The button sets its role and state after the spread, so a call site cannot override them.

```tsx
// src/shared/ui/button.tsx
import { createContext, use, type ReactNode } from 'react'
import { ActivityIndicator, Pressable, StyleSheet, Text, View, type PressableProps } from 'react-native'

import { opacity, radius, size, space, type } from './theme'
import { useTheme } from './theme-provider'

const variants = {
  primary: { fill: 'accent', pressed: 'accentHover', on: 'onAccent' },
  danger: { fill: 'danger', pressed: 'dangerHover', on: 'onDanger' },
} as const

const ButtonContext = createContext({ color: '', loading: false })

type ButtonProps = Omit<PressableProps, 'children' | 'style'> & {
  variant?: keyof typeof variants
  loading?: boolean
  children: ReactNode
}

export function Button({ variant = 'primary', loading = false, disabled, children, ...props }: ButtonProps) {
  const { bg, fg } = useTheme()
  const { fill, pressed: pressedFill, on } = variants[variant]
  const inactive = !!disabled || loading
  return (
    <ButtonContext value={{ color: fg[on], loading }}>
      <Pressable
        {...props}
        role="button"
        aria-disabled={inactive}
        aria-busy={loading}
        disabled={inactive}
        style={({ pressed }) => [styles.root, { backgroundColor: bg[pressed ? pressedFill : fill] }, disabled && styles.disabled]}
      >
        {children}
        {loading && <ActivityIndicator color={fg[on]} style={StyleSheet.absoluteFill} />}
      </Pressable>
    </ButtonContext>
  )
}

export function ButtonText({ children }: { children: ReactNode }) {
  const { color, loading } = use(ButtonContext)
  return <Text style={[styles.text, { color, opacity: loading ? 0 : 1 }]}>{children}</Text>
}

export function ButtonIcon({ children }: { children: ReactNode }) {
  const { loading } = use(ButtonContext)
  return (
    <View aria-hidden style={{ opacity: loading ? 0 : 1 }}>
      {children}
    </View>
  )
}

const styles = StyleSheet.create({
  root: {
    minHeight: size.touchTarget,
    paddingHorizontal: space.lg,
    flexDirection: 'row',
    gap: space.sm,
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: radius.md,
    borderCurve: 'continuous',
  },
  text: { ...type.base, fontWeight: '600' },
  disabled: { opacity: opacity.disabled },
})
```

```tsx
// Any screen (shape)
<Button loading={isPending} onPress={buy}>
  <ButtonIcon>
    <CartIcon />
  </ButtonIcon>
  <ButtonText>{count} items</ButtonText>
</Button>
```

Shadows take the web's CSS string (`boxShadow`) on the New Architecture.

## Pair test

The pair list and the assertions are the web test's (`lib.md`). Only the lookup changes, because themes are objects here:

```ts
// src/shared/ui/tokens.test.ts (React Native: replaces the CSS parsing)
import { dark, light, type Theme } from './theme'

const kebab = (key: string) => key.replace(/[A-Z]/g, (letter) => `-${letter.toLowerCase()}`)

/** { fg: { onAccent } } → { 'fg-on-accent' }: the names the pair list uses on every platform */
const flatten = (theme: Theme): Record<string, string> =>
  Object.fromEntries(
    Object.entries(theme).flatMap(([category, roles]) =>
      Object.entries(roles).map(([role, value]) => [`${category}-${kebab(role)}`, value]),
    ),
  )

const themes: Record<string, Record<string, string>> = { light: flatten(light), dark: flatten(dark) }
```

The first test (every theme defines every role) is the compiler's job here: `dark: Theme` does not compile with a role missing or added.

## Type

- Sizes and line heights are absolute points, and `lineHeight` does not follow `fontSize`: change them together, which is why each style in `type` holds both.
- OS font scaling multiplies every `<Text>`. Keep it for body text, cap display and heading sizes (`maxFontSizeMultiplier={1.3}`), and turn it off (`allowFontScaling={false}`) only where a layout truly cannot grow.
- On Android, `fontWeight` picks a face only when the font files are registered as one family (the `expo-font` config plugin's `fontDefinitions`). Otherwise name each file after its PostScript name and select faces by `fontFamily`, or Android falls back without a warning.

## Accessibility

- `role` and the `aria-*` props (`aria-label`, `aria-disabled`, `aria-busy`, `aria-expanded`, `aria-hidden`) work on both platforms and override the older `accessibility*` props. `aria-live` and `aria-labelledby` are Android-only.
- A small icon control keeps its drawn size and reaches `size.touchTarget` with `hitSlop`. An icon-only control takes `aria-label`.
- Pressed, selected and error states add a cue beyond color here too: a border, a check, an icon.

## Reduced motion

Apply the policy (`motion.md`) to the live setting: read `AccessibilityInfo.isReduceMotionEnabled()`, subscribe to `reduceMotionChanged`, and remove the subscription on unmount. Animation libraries wrap this in a hook. On iOS, `AccessibilityInfo.prefersCrossFadeTransitions()` also reports a preference for cross-fades over slides.
