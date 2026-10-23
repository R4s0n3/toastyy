# Toastyy

The native iPhone app is in [`ios/`](ios/README.md). Open
[`ios/Toastyy.xcodeproj`](ios/Toastyy.xcodeproj) on a Mac with Xcode 16 or newer
and run the **Toastyy** scheme on an iPhone simulator or signed device.

The native app uses SwiftUI and RealityKit and bundles the original toaster as
USDZ. Its gameplay reference is web commit
`fd5b6a332b9eb4cb22b0d4480835119a35bb7294`.

The web client remains at this repository's root:

```sh
npm ci
npm run dev
```

Validate the web client with `npm run check`, `npm test`, and `npm run build`.
Validate native gameplay with `cd ios && swift test`. See the
[native README](ios/README.md) for simulator builds, UI tests, port coverage,
and validation limits.
