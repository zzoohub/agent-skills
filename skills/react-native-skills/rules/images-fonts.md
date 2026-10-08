# Images and fonts

Loading, sizing and caching images; embedding fonts so every weight resolves on both platforms.

## Images

**Default.** `expo-image` for remote images.
**Break:** the project's existing image library.

Request the pixels the device draws: `PixelRatio.getPixelSizeForLayoutSize(size)`, often 3× the layout size (not 2×), rounded up to a size your CDN caches. `allowDownscaling` (on by default) shrinks the decoded image, which saves memory but not download bytes. Use a `placeholder` (blurhash or thumbhash); heroes get `priority="high"`.

## Fonts

**Default.** Embed fonts with the `expo-font` config plugin: ready at launch, no loading state. A plugin change needs a new native build; web and Expo Go still load fonts with `useFonts`.
**Trap.** Android names the family after the file name; iOS reads it from the font file. Either name each file after its PostScript name (e.g. `Inter-SemiBold`) and use that as `fontFamily`, or group the files under one Android `fontFamily` with `fontDefinitions` and pick faces with `fontWeight`. Otherwise `fontWeight` silently falls back on Android. `getLoadedFonts()` lists what loaded.

```json
["expo-font", {
  "ios": { "fonts": ["./assets/fonts/Inter-Regular.otf", "./assets/fonts/Inter-SemiBold.otf"] },
  "android": { "fonts": [{
    "fontFamily": "Inter",
    "fontDefinitions": [
      { "path": "./assets/fonts/Inter-Regular.otf", "weight": 400 },
      { "path": "./assets/fonts/Inter-SemiBold.otf", "weight": 600 }
    ]
  }] }
}]
```

With this entry in `expo.plugins`, `fontFamily: 'Inter'` and `fontWeight: '600'` select the same face on both platforms.

Docs: [expo-image](https://docs.expo.dev/versions/latest/sdk/image/) · [expo-font](https://docs.expo.dev/versions/latest/sdk/font/) · [Expo fonts guide](https://docs.expo.dev/develop/user-interface/fonts/)
