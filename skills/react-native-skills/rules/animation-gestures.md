# Animation and gestures

Motion APIs, shared values, scroll-driven UI, press feedback (Reanimated 4; Gesture Handler 2 or 3).

## Motion API

| Driver | Use |
|---|---|
| A state change, A to B | Reanimated CSS transitions (`transitionProperty`, `transitionDuration`), or `withTiming` from the handler |
| Enter, exit, reorder, resize | Layout animations (`entering`, `exiting`; `layout={LinearTransition}` on the container and on siblings that move); never hand-animate `height` |
| A finger or the scroll position | Shared values written in worklets, read in `useAnimatedStyle` |

Per frame, animate non-layout props (`transform`, `opacity`, colors); layout props (`width`, `height`, `top`, `margin`, `padding`) re-run layout every frame.
**Break:** a layout prop on one small subtree, briefly. **Scale:** Reanimated's performance guide puts the limit near 100 simultaneously animated components on low-end Android (500 on iOS); for New Architecture frame drops, apply its version-specific flags, measured on release.

## State as truth

Store what is true (`pressed`, `progress`, `isOpen`); derive what is drawn (`scale`, `opacity`). Derive shared values with `useDerivedValue`; `useAnimatedReaction` is for side effects (haptics, or calling JS with `scheduleOnRN` from `react-native-worklets`; `runOnJS` on Reanimated 3).
A JS-thread read of a shared value blocks on the UI thread; show a changing number through React state or an animated `TextInput`.

## Scroll-driven UI

**Default.** Scroll position lives in a shared value (`useAnimatedScrollHandler`) or a ref, never `useState`: events arrive every frame.
**Break:** UI that must re-render (a back-to-top button) gets a boolean that crosses to JS only when it flips.

```tsx
import Animated, { useAnimatedReaction, useAnimatedScrollHandler, useSharedValue } from 'react-native-reanimated'
import { scheduleOnRN } from 'react-native-worklets'

function Feed({ onPastHeader }: { onPastHeader: (past: boolean) => void }) {
  const scrollY = useSharedValue(0)
  const onScroll = useAnimatedScrollHandler((e) => {
    scrollY.set(e.contentOffset.y) // UI thread, no re-render
  })
  useAnimatedReaction(
    () => scrollY.get() > 200,
    (past, prev) => {
      if (past !== prev) scheduleOnRN(onPastHeader, past)
    },
  )
  return <Animated.ScrollView onScroll={onScroll} scrollEventThrottle={16} />
}
```

## Press feedback

**Default.** `Pressable` (not RN's `Touchable*`) with a button role, and a label when icon-only, in the house spelling. Animate a `pressed` shared value from `onPressIn`/`onPressOut` (`pressed.set(withTiming(1))`), drawn in `useAnimatedStyle` as `transform: [{ scale: interpolate(pressed.get(), [0, 1], [1, 0.97]) }]`; only the animation's start waits for JS.
**Break:**
- Feedback must not wait on a busy JS thread: Gesture Handler 3 `Touchable` (`activeOpacity`, `activeScale`, run by the platform), or Reanimated CSS `:active` where the installed version supports it.
- The tap composes with pan, long-press or swipe, or JS FPS is measurably saturated during presses: a gesture-handler tap (`Gesture.Tap()` on RNGH 2; `useTapGesture` on 3, where `onStart` became `onActivate`). Then add `accessible`, the button role, a label and an `activate` accessibility action yourself.
- Inside Gesture Handler scrollables, use its `Pressable` or `Touchable`.

Docs: [Reanimated performance](https://docs.swmansion.com/react-native-reanimated/docs/guides/performance/) · [useSharedValue](https://docs.swmansion.com/react-native-reanimated/docs/core/useSharedValue/) · [Gesture Handler 3](https://docs.swmansion.com/react-native-gesture-handler/docs/guides/upgrading-to-3)
