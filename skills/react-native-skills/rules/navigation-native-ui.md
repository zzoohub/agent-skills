# Navigation and native UI

Router imports, stacks, tabs, sheets, menus, lightboxes: when native wins, when JS is justified.

## Router imports

From SDK 56, Expo Router apps import nothing from `@react-navigation/*`: focus hooks and themes come from `expo-router/react-navigation`, the JS stack and tabs from `expo-router/js-stack` and `js-tabs` (the SDK 56 codemod rewrites old imports). Read the router migration guide at each SDK step. React Navigation apps keep its packages.

Deep-link params are untrusted input: validate them. Sign-in runs in a system browser session, never an embedded WebView.

## Stacks

**Default.** A native stack (`@react-navigation/native-stack`, or Expo Router's `Stack`) configured with native header options, not a custom `header` component.
**Why.** Native chrome brings large titles, search bars, gestures and accessibility, and inherits OS redesigns (iOS 26 Liquid Glass); JS copies do not.
**Break:** a transition or header the native stack cannot express: Expo Router's `expo-router/js-stack`, or React Navigation's `@react-navigation/stack`.
A screen heavy on mount delays or stutters its push: render a light shell, then mount the rest after the stack's `transitionEnd` event.

```tsx
// app/_layout.tsx. React Navigation's createNativeStackNavigator takes the same options.
import { Stack } from 'expo-router'

export default function Layout() {
  return (
    <Stack>
      <Stack.Screen
        name="index"
        // iOS: both need a ScrollView or list as the screen's first child,
        // with contentInsetAdjustmentBehavior="automatic"
        options={{
          title: 'Inbox',
          headerLargeTitleEnabled: true,
          headerSearchBarOptions: { placeholder: 'Search' },
        }}
      />
      <Stack.Screen
        name="filters"
        // fitToContents needs explicitly sized content (no flex: 1). Android: at most 3 detents, no header.
        options={{ presentation: 'formSheet', sheetAllowedDetents: 'fitToContents' }}
      />
    </Stack>
  )
}
```

## Tabs

**Default.** Native tabs, resolved against the installed versions: Expo Router `NativeTabs` (`expo-router/unstable-native-tabs` on SDK 54-57, where SDK 54 imports `Icon` and `Label` separately; `expo-router/native-tabs` from SDK 58); React Navigation 7's experimental `createNativeBottomTabNavigator` from `@react-navigation/bottom-tabs/unstable`; or `react-native-bottom-tabs`. On iOS the first `ScrollView` in each native tab gets automatic content insets (`disableAutomaticContentInsets` turns them off).
**Break → JS tabs:** a custom tab bar (center action, animated indicator), more than 5 tabs on Android, tabs added or removed at runtime, tabs nested in tabs, or a web target the native version doesn't cover.

## Sheets and modals

**Default.** A sheet is a route: native-stack `presentation: 'formSheet'` with `sheetAllowedDetents` (above), or the SDK's native sheet (e.g. `@expo/ui`'s `BottomSheet`). RN's `<Modal>` is for full-screen content: it has no detents and its sheet styles are iOS-only, so Android shows it full screen.
**Break → a JS sheet library with New Architecture support:** a sheet held open over content the user keeps using (a map, a player), or custom snapping.
**Lightbox** (pinch, double-tap zoom, pan to close): a native one such as Galeria, not a hand-built `Modal`.

## Menus

**Default.** The SDK's native menu (e.g. `@expo/ui`'s menu drop-in) or a maintained library with New Architecture support. Never hand-position a `View` of pressables: no focus handling or screen-reader semantics, and it clips at screen edges. Check zeego's New Architecture support before choosing it.
**Break:** rows richer than a native menu allows (avatars, two-line rows): a JS popover that moves focus into the menu, labels every item, and closes on back and outside tap.

Docs: [native-stack](https://reactnavigation.org/docs/native-stack-navigator) · [Expo native tabs](https://docs.expo.dev/router/advanced/native-tabs/) · [Expo modals and sheets](https://docs.expo.dev/router/advanced/modals/) · [Expo UI](https://docs.expo.dev/versions/latest/sdk/ui/)
