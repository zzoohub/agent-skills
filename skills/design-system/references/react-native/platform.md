# React Native Platform

## Tokens and Theme

Follow the app's styling engine; never add a second. NativeWind or Uniwind (Tailwind classes on React Native): emit each theme's values as that engine's theme variables, under `../platform-web.md`'s utility names, so one class vocabulary spans web and native (its docs give the theme syntax). Unistyles or Tamagui: map the generated theme modules into its theme config. Plain `StyleSheet`: the context below.

The pipeline (`../pipeline.md`) emits static `base.js` and one module per theme (`light.js`, `dark.js`) with identical keys. Static tokens may be imported; themed tokens come only through the hook, or dark mode never reaches the component.

```tsx
import { createContext, use, type ReactNode } from 'react';
import { useColorScheme } from 'react-native';
import light from './generated/light';
import dark from './generated/dark';

export type Preference = 'system' | 'light' | 'dark';
export type Theme = typeof light;
const ThemeContext = createContext<Theme>(light);

// Load the persisted preference and brand before the first render (keep the splash screen up), or the app flashes.
// `themes` is the active brand's pair; omitted, the generated modules.
export function ThemeProvider({ preference, themes = { light, dark }, children }: {
  preference: Preference;
  themes?: { light: Theme; dark: Theme };
  children: ReactNode;
}) {
  const system = useColorScheme(); // follows the OS setting live
  const isDark = preference === 'dark' || (preference === 'system' && system === 'dark');
  return <ThemeContext value={isDark ? themes.dark : themes.light}>{children}</ThemeContext>;
}

export const useTheme = () => use(ThemeContext);
```

For native chrome (alerts, pickers) to follow an explicit choice, also call `Appearance.setColorScheme()`; in current docs, `'auto'` follows the system again. A brand that arrives later (fetched after login, remote config) replaces the provider's `themes` with its pair; store it so the next launch starts in it, and clear it at logout. The splash screen and app icon are brand surfaces outside tokens: list them.

## Button

Strings render only inside `ButtonText` (react-native-skills' compound-component rule, if available). While loading, the invisible label keeps the width and the accessible name. The button sets its own role and state after the prop spread, so a call site cannot override them.

```tsx
import { createContext, use, type ReactNode } from 'react';
import { ActivityIndicator, Pressable, StyleSheet, Text, View, type PressableProps } from 'react-native';
import base from './generated/base';
import { useTheme } from './theme';

const variants = {
  primary: { fill: 'accent', pressed: 'accentHover', on: 'onAccent' },
  danger: { fill: 'danger', pressed: 'dangerHover', on: 'onDanger' },
} as const;
const ButtonContext = createContext({ color: '', loading: false });

type ButtonProps = Omit<PressableProps, 'children' | 'style'> & { variant?: keyof typeof variants; loading?: boolean; children: ReactNode };

export function Button({ variant = 'primary', loading = false, disabled, children, ...props }: ButtonProps) {
  const { bg, fg, elevation } = useTheme();
  const { fill, pressed: pressedFill, on } = variants[variant];
  const inactive = !!disabled || loading;
  return (
    <ButtonContext value={{ color: fg[on], loading }}>
      <Pressable {...props} role="button" aria-disabled={inactive} aria-busy={loading} disabled={inactive}
        style={({ pressed }) => [styles.root, { backgroundColor: bg[pressed ? pressedFill : fill], boxShadow: elevation.card }, disabled && styles.disabled]}>
        {children}
        {loading && <ActivityIndicator color={fg[on]} style={StyleSheet.absoluteFill} />}
      </Pressable>
    </ButtonContext>
  );
}

export function ButtonText({ children }: { children: ReactNode }) {
  const { color, loading } = use(ButtonContext);
  return <Text style={[styles.text, { color, opacity: loading ? 0 : 1 }]}>{children}</Text>;
}

export function ButtonIcon({ children }: { children: ReactNode }) {
  const { loading } = use(ButtonContext);
  return <View aria-hidden style={{ opacity: loading ? 0 : 1 }}>{children}</View>;
}

const styles = StyleSheet.create({
  root: { minHeight: base.size.touchTarget, paddingHorizontal: base.space.component.lg, flexDirection: 'row', gap: base.space.component.sm,
          alignItems: 'center', justifyContent: 'center', borderRadius: base.radius.md, borderCurve: 'continuous' },
  text: { ...base.type.body.md, fontWeight: '600' },
  disabled: { opacity: base.opacity.disabled },
});
```

`boxShadow` takes the web's CSS string on the New Architecture, the only one since React Native 0.82 (outset shadows need Android 9+).

## Type

- Sizes and line heights are absolute points; `lineHeight` does not track `fontSize`, so recompute it with every size change.
- OS font scaling multiplies every `<Text>`: keep it for body text, cap display and headings (`maxFontSizeMultiplier={1.3}`), and disable it (`allowFontScaling={false}`) only where truly unavoidable.
- `fontWeight` picks a face on Android only when the font files are grouped under one family (react-native-skills' fonts rule, if available).

## Accessibility

- `role` and the `aria-*` props (`aria-label`, `aria-disabled`, `aria-busy`, `aria-expanded`, `aria-hidden`, …) work on both platforms and override the older `accessibility*` props; `aria-live` and `aria-labelledby` are Android-only, `aria-modal` iOS-only.
- Small icon controls keep their visual size and reach `size.touchTarget` with `hitSlop`; icon-only controls get `aria-label`.

## Reduced Motion

Apply the policy (SKILL.md § Motion) to the live setting: read `AccessibilityInfo.isReduceMotionEnabled()`, subscribe to `reduceMotionChanged` and remove the subscription on unmount (animation libraries wrap this in a hook). On iOS, `AccessibilityInfo.prefersCrossFadeTransitions()` also reports a cross-fade preference.
