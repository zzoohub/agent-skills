# Platform: React Native

## Table of Contents

1. [Token Output — TypeScript](#token-output--typescript)
2. [Dark Mode](#dark-mode)
3. [Styled Component Example](#styled-component-example)
4. [Responsive](#responsive)
5. [Accessibility](#accessibility)
6. [Reduced Motion](#reduced-motion)
7. [Icons](#icons)

## Token Output — TypeScript

```typescript
export const tokens = {
  color: {
    bg: {
      primary: '#f9fafb',
      secondary: '#f3f4f6',
      tertiary: '#e5e7eb',
      inverse: '#111827',
    },
    text: {
      primary: '#111827',
      secondary: '#4b5563',
      tertiary: '#6b7280',
      inverse: '#f9fafb',
      link: '#2563eb',
    },
    interactive: {
      primary: '#2563eb',
      primaryHover: '#1d4ed8',
      primaryActive: '#1e40af',
    },
    border: {
      default: '#e5e7eb',
      strong: '#d1d5db',
      focus: '#3b82f6',
    },
    status: {
      error: '#dc2626',
      errorBg: '#fef2f2',
      warning: '#d97706',
      warningBg: '#fffbeb',
      success: '#16a34a',
      successBg: '#f0fdf4',
    },
  },
  spacing: {
    component: { xs: 4, sm: 8, md: 12, lg: 16, xl: 24 },
    layout: { xs: 16, sm: 24, md: 32, lg: 48, xl: 64 },
  },
  radius: { none: 0, sm: 4, md: 8, lg: 12, xl: 16, full: 9999 },
  typography: {
    display:    { fontSize: 30, lineHeight: 36, fontWeight: '700' as const, letterSpacing: -0.75 },
    headingLg:  { fontSize: 24, lineHeight: 32, fontWeight: '600' as const, letterSpacing: -0.48 },
    headingMd:  { fontSize: 20, lineHeight: 28, fontWeight: '600' as const, letterSpacing: -0.3 },
    headingSm:  { fontSize: 16, lineHeight: 24, fontWeight: '600' as const, letterSpacing: -0.16 },
    bodyLg:     { fontSize: 18, lineHeight: 28, fontWeight: '400' as const, letterSpacing: 0 },
    bodyMd:     { fontSize: 16, lineHeight: 24, fontWeight: '400' as const, letterSpacing: 0 },
    bodySm:     { fontSize: 14, lineHeight: 20, fontWeight: '400' as const, letterSpacing: 0 },
    caption:    { fontSize: 12, lineHeight: 16, fontWeight: '500' as const, letterSpacing: 0.24 },
  },
  shadow: {
    card:     { shadowColor: '#000', shadowOffset: { width: 0, height: 1 }, shadowOpacity: 0.05, shadowRadius: 2, elevation: 1 },
    dropdown: { shadowColor: '#000', shadowOffset: { width: 0, height: 4 }, shadowOpacity: 0.1, shadowRadius: 6, elevation: 3 },
    modal:    { shadowColor: '#000', shadowOffset: { width: 0, height: 10 }, shadowOpacity: 0.1, shadowRadius: 15, elevation: 8 },
    toast:    { shadowColor: '#000', shadowOffset: { width: 0, height: 20 }, shadowOpacity: 0.1, shadowRadius: 25, elevation: 12 },
  },
  opacity: { disabled: 0.5, overlay: 0.5, hover: 0.8 },
  zIndex: { base: 0, dropdown: 100, sticky: 200, overlay: 300, modal: 400, popover: 450, toast: 500 },
  motion: {
    duration: { instant: 100, fast: 200, normal: 300, slow: 500 },
    easing: {
      default: { x1: 0.4, y1: 0, x2: 0.2, y2: 1 },
      enter:   { x1: 0, y1: 0, x2: 0.2, y2: 1 },
      exit:    { x1: 0.4, y1: 0, x2: 1, y2: 1 },
    },
  },
} as const;
```

> **Android shadow caveat:** `shadowOffset`/`shadowOpacity`/`shadowRadius` are iOS-only; Android renders `elevation` (which is why both are defined above), and `shadowColor` only tints that elevation shadow on Android API 28+. On the New Architecture you can unify both platforms with the `boxShadow` style prop instead (New-Architecture-only; outset shadows need Android 9+, inset shadows Android 10+).

## Dark Mode

```typescript
import { useColorScheme } from 'react-native';

const darkOverrides = {
  color: {
    bg: { primary: '#111827', secondary: '#1f2937', tertiary: '#374151', inverse: '#f9fafb' },
    text: { primary: '#f9fafb', secondary: '#d1d5db', tertiary: '#9ca3af', inverse: '#111827', link: '#60a5fa' },
    interactive: { primary: '#3b82f6', primaryHover: '#60a5fa', primaryActive: '#2563eb' },
    border: { default: '#374151', strong: '#4b5563', focus: '#60a5fa' },
  },
} as const;

// Theme provider merges tokens + dark overrides
function useThemeTokens() {
  const scheme = useColorScheme();
  if (scheme === 'dark') {
    return { ...tokens, color: { ...tokens.color, ...darkOverrides.color } };
  }
  return tokens;
}
```

## Styled Component Example

Headless hook + tokens = complete component.

```tsx
import React from 'react';
import { Pressable, Text, ActivityIndicator } from 'react-native';
import { useButton } from '../headless/useButton';
import { tokens } from '@/shared/ui/tokens';

const variants = {
  solid:   { bg: tokens.color.interactive.primary, text: tokens.color.text.inverse },
  outline: { bg: 'transparent', text: tokens.color.interactive.primary, border: tokens.color.interactive.primary },
  ghost:   { bg: 'transparent', text: tokens.color.interactive.primary },
} as const;

const sizes = {
  sm: { px: tokens.spacing.component.md, py: tokens.spacing.component.xs, ...tokens.typography.bodySm },
  md: { px: tokens.spacing.component.lg, py: tokens.spacing.component.sm, ...tokens.typography.bodyMd },
  lg: { px: tokens.spacing.component.xl, py: tokens.spacing.component.md, ...tokens.typography.bodyLg },
} as const;

interface ButtonProps {
  variant?: keyof typeof variants;
  size?: keyof typeof sizes;
  disabled?: boolean;
  loading?: boolean;
  onPress?: () => void;
  children: React.ReactNode;
}

export function Button({ variant = 'solid', size = 'md', children, ...props }: ButtonProps) {
  const { buttonProps, state } = useButton(props);
  const v = variants[variant];
  const s = sizes[size];

  return (
    <Pressable
      {...buttonProps}
      disabled={state.isDisabled}
      accessibilityRole="button"
      accessibilityState={{ disabled: state.isDisabled, busy: state.isLoading }}
      style={{
        backgroundColor: v.bg,
        paddingHorizontal: s.px,
        paddingVertical: s.py,
        borderRadius: tokens.radius.md,
        borderWidth: 'border' in v ? 1 : 0,
        borderColor: 'border' in v ? v.border : undefined,
        opacity: state.isDisabled ? tokens.opacity.disabled : 1,
        minHeight: 44, // touch target
        minWidth: 44,
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      {state.isLoading ? (
        <ActivityIndicator color={v.text} />
      ) : (
        <Text style={{ color: v.text, fontSize: s.fontSize, fontWeight: s.fontWeight }}>
          {children}
        </Text>
      )}
    </Pressable>
  );
}
```

## Responsive

```typescript
import { useWindowDimensions } from 'react-native';

function useBreakpoint() {
  const { width } = useWindowDimensions();
  return {
    isMobile: width < 768,
    isTablet: width >= 768 && width < 1024,
    isDesktop: width >= 1024,
  };
}
```

## Accessibility

| Web | React Native | Purpose |
|-----|-------------|---------|
| `role="button"` | `accessibilityRole="button"` | Semantic role |
| `aria-label="Close"` | `accessibilityLabel="Close"` | Screen reader text |
| `aria-disabled={true}` | `accessibilityState={{ disabled: true }}` | State announcement |
| `aria-hidden={true}` | `accessibilityElementsHidden={true}` (iOS) + `importantForAccessibility="no-hide-descendants"` (Android) | Hide decorative |
| `tabIndex={-1}` | `focusable={false}` | Remove from tab order |

Touch targets: Enforce `minHeight: 44, minWidth: 44` on all interactive elements. For icon-only controls that must stay visually small, keep the visual size and extend the tappable area with `hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}` (or a value computed to reach 44pt) instead of enlarging the icon.

## Reduced Motion

React Native has `AccessibilityInfo.isReduceMotionEnabled()` and a `reduceMotionChanged` listener for live updates. When reduced motion is active, skip animation entirely — set duration to 0 or render the final state.

```ts
import { AccessibilityInfo } from 'react-native';

const [reduceMotion, setReduceMotion] = useState(false);

useEffect(() => {
  AccessibilityInfo.isReduceMotionEnabled().then(setReduceMotion);
  const sub = AccessibilityInfo.addEventListener('reduceMotionChanged', setReduceMotion);
  return () => sub.remove();
}, []);
```

## Icons

- Package: `lucide-react-native` (or project's icon set)
- Decorative: `accessibilityElementsHidden={true}` (iOS) + `importantForAccessibility="no-hide-descendants"` (Android)
- Meaningful: `accessibilityLabel="description"` on the icon
