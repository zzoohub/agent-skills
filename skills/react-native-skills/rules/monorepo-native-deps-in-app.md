---
title: Install Native Dependencies in App Directory
impact: CRITICAL
impactDescription: required for autolinking on RN CLI / Expo before SDK 54; keeps one native version
tags: monorepo, native, autolinking, installation
---

## Install Native Dependencies in App Directory

In a monorepo, packages with native code should be installed in the native app's
directory directly. React Native CLI autolinking, and Expo autolinking before
SDK 54, only link the app's own direct dependencies—they won't find native
dependencies installed in other packages. Since Expo SDK 54, Expo autolinking
resolves transitive dependencies and supports isolated (pnpm/bun) installs, so
this is no longer strictly required there—but listing the dep in the app still
pins the single native version that gets compiled (only one version of a native
module can be built into an app).

**Incorrect (native dep in shared package only):**

```
packages/
  ui/
    package.json  # has react-native-reanimated
  app/
    package.json  # missing react-native-reanimated
```

Autolinking fails (RN CLI / Expo before SDK 54)—native code not linked.

**Correct (native dep in app directory):**

```
packages/
  ui/
    package.json  # has react-native-reanimated
  app/
    package.json  # also has react-native-reanimated
```

```json
// packages/app/package.json
{
  "dependencies": {
    "react-native-reanimated": "4.1.0"
  }
}
```

Even if the shared package uses the native dependency, the app should also list it
so autolinking detects and links the native code. In the shared package, declaring
the native dep as a `peerDependency` (plus a `devDependency` for local tooling)
instead of a regular dependency avoids installing a second copy.
