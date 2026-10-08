# Platform layout

Safe areas, edge-to-edge, the keyboard, measuring views, style mechanics.

## Edge-to-edge and safe areas

Treat every Android screen as edge-to-edge: Expo SDK 54+ always enables it, and apps targeting API 36 cannot opt out on Android 16. Content sits under the system bars unless inset. Each iOS-only prop's Android path:

| iOS-only | Android path |
|---|---|
| `contentInsetAdjustmentBehavior` | insets from `react-native-safe-area-context` (`useSafeAreaInsets`, or its `SafeAreaView` with `edges`) |
| `contentInset`, `scrollIndicatorInsets` | `contentContainerStyle` padding, or a spacer |
| `automaticallyAdjustKeyboardInsets` (default `false`) | a keyboard library covering both platforms (below) |
| Modal `presentationStyle`, `allowSwipeDismissal` | a native-stack form-sheet route |

RN's `SafeAreaView` is deprecated; use `react-native-safe-area-context`.

```tsx
import { Platform, ScrollView } from 'react-native'
import { useSafeAreaInsets } from 'react-native-safe-area-context'

// Headerless screen. Under a native header, drop paddingTop.
function Screen({ children }: { children: React.ReactNode }) {
  const insets = useSafeAreaInsets()
  return (
    <ScrollView
      contentInsetAdjustmentBehavior="automatic" // iOS only
      contentContainerStyle={
        Platform.OS === 'android' ? { paddingTop: insets.top, paddingBottom: insets.bottom } : undefined
      }
    >
      {children}
    </ScrollView>
  )
}
```

## Keyboard

**Default.** Forms and chat use a library that tracks the keyboard frame on both platforms, e.g. react-native-keyboard-controller (`KeyboardProvider` at the root, `KeyboardAwareScrollView` for forms, `KeyboardStickyView` for a composer). `KeyboardAvoidingView` jumps on Android (it reacts after the keyboard opens), cannot follow an interactive dismissal, and broke under edge-to-edge before RN 0.86.
**Break:** screens where no input can sit under the keyboard.

## Measuring

Use `getBoundingClientRect()` (RN 0.82+) rather than the legacy `measure()`: read it in `useLayoutEffect` for the first frame and keep it current with `onLayout`, whose state updater returns the previous size when nothing changed (no re-render). Type the ref `useRef<ComponentRef<typeof View>>(null)`: RN 0.87+ types reject `useRef<View>`. Screen size comes from `useWindowDimensions()`, never `Dimensions.get` at module scope (stale after rotation, split screen or a fold).

## Style mechanics

Token values come from the design-system capability, if available; the RN mechanics:
- `boxShadow` renders shadow tokens on both platforms, replacing the per-platform pair (`shadow*` props on iOS, `elevation` on Android). New Architecture only; outset shadows need Android 9+, inset Android 10+.
- Gradients: `backgroundImage` (RN 0.87+; `experimental_backgroundImage` before), not a gradient library.

Docs: [ScrollView](https://reactnative.dev/docs/scrollview) · [Android 16 behavior changes](https://developer.android.com/about/versions/16/behavior-changes-16) · [View style props](https://reactnative.dev/docs/view-style-props)
