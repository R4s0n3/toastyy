# Toastyy for iPhone

A native SwiftUI and RealityKit port of the web client at commit
`fd5b6a332b9eb4cb22b0d4480835119a35bb7294`. The native app lives inside the web
Git repository so its reference and implementation stay versioned together.
There is no WebView, JavaScript runtime, Godot dependency, backend, or runtime
asset download.

## Open on a Mac

1. Install Xcode 16 or newer with an iOS Simulator runtime.
2. Open `Toastyy.xcodeproj` (the project is checked in; no generator is needed).
3. Select the **Toastyy** scheme and an iPhone simulator, then press **Run**.
4. For a physical iPhone, select your Apple development team in the Toastyy
   target's **Signing & Capabilities** and choose a unique bundle identifier.
   The minimum supported version is iOS 17. The app runs in portrait.

For TestFlight distribution, use **Xcode 26 or newer** and follow the
[first-upload guide](TESTFLIGHT.md). Local development can use older supported
Xcode versions; Apple's current upload requirements are stricter.

The only package is the local `ToastyyCore` package. There are no external Swift
dependencies. Camera permission is unnecessary: the scene uses RealityKit's
[non-AR camera mode](https://developer.apple.com/documentation/realitykit/perspectivecamera).

## Play

The screen mirrors the web client one to one; there are no extra native-only buttons.

- Tap the 3D knob or drag it horizontally to set difficulty.
- Drag the physical lever down, or tap it, to start.
- Touch anywhere on the stage, or **Stop Toaster**, just before the pop. The last
  150 ms is a perfect save. Missing ends the run; permanent records and XP remain.
- The four cabinet buttons toggle sound and haptics and open settings and records.
  The **?** button opens settings and how to play.
- Open the tray under the toaster to see and equip unlocked toast. New levels
  automatically equip their new finish, matching the web client.

## Implemented

- Original toaster geometry, dimensions, and normals converted to bundled USDZ.
- Web look and layout: bundled Manrope and DM Mono (SIL OFL, licenses in
  `Resources/Fonts`), the web color tokens, paper grain, transparent 3D stage,
  the web camera framing between the copy and the tray, printed housing legends,
  browning dial, and indicator lights.
- Non-AR perspective camera, warm lighting, contact shadow, heater glow,
  knob detents, linked lever handle and inset, shaped bread, and crumbs.
- Web feedback: status pill, heat meter, steam, heat aura, danger vignette,
  stop-key urgency, result card with perfect and new-best badges, score count-up,
  flying points, streak badge, burn shake and flashes, and the loading screen.
- Four difficulty ranges and multipliers, accelerating rounds, timing grades,
  cumulative run scores, streak bonuses, best records, and automatic cooldowns.
- Eight toast finishes with native procedural textures and PBR materials, matching
  web XP thresholds and rewards. The patterns are native redraws, not exact
  pixel copies of the web canvas textures.
- Web-style collection, settings, records and help dialogs, local persistence,
  synthesized audio, haptics, and foreground interruption handling.
- The physical controls are SwiftUI hit areas over their projected 3D positions,
  so VoiceOver can use the lever, the adjustable knob, and the cabinet buttons.
  Reduced motion is respected.
- App icon, launch background, required-reason privacy manifest, shared scheme,
  gameplay tests, UI smoke tests, and a GitHub Actions Mac build/test workflow.

## Validate

From this directory, on a Mac with Xcode:

```sh
swift test
xcodebuild -project Toastyy.xcodeproj -scheme Toastyy \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Toastyy.xcodeproj -scheme Toastyy \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO test
```

Replace the simulator name with an installed device from `xcrun simctl list`.
The UI tests launch with isolated, non-persisted records and fixed random timing.
They exercise loading the actual USDZ, starting and stopping a round, automatic
burns, the collection, sound settings, records, and the knob, and save screenshots
of each screen in the result bundle. The workflow selects an available iPhone automatically.

`swift test` also runs on Linux with Swift 6.0 or newer. It validates the portable
rules, not SwiftUI or RealityKit. The first implementation was created on Linux.
The initial Mac CI run has since successfully compiled the iOS Simulator app;
check the **Native iOS** Actions run for the separate UI-test outcome. A
successful simulator build does not validate device signing or distribution.

Before treating the port as device-verified, run the Xcode build and UI tests,
then check framing on small and large iPhones, the physical knob and lever hit
areas, audio and haptics on hardware, app switching, and metallic finishes.
Remaining differences from the web: the 3D steam, smoke and sparkle particles,
grill marks, the cabinet buttons' press travel, and the collection preview, which
tilts a 2D slice instead of rendering a 3D one.
Web localStorage saves are not imported; native progress starts fresh. Signing,
App Store metadata, and distribution have not been configured.

## Structure

- `Sources/ToastyyCore`: platform-independent state machine, scoring, progression,
  and ballistic toast motion. Time and randomness are injected for tests.
- `Toastyy/App`: SwiftUI entry, observable state, versioned UserDefaults save,
  synthesized audio, and UIKit haptics.
- `Toastyy/Scene`: RealityKit view, native bread meshes, texture painting, camera,
  lighting, housing print, and projected control positions.
- `Toastyy/Views`: game screen, dialogs, and the shared theme (`Theme.swift`).
- `Toastyy/Resources`: original converted toaster, provenance, assets, and privacy.

## Asset maintenance

`Toaster.usdz` is included in the app. To regenerate it after changing the web
model, use Python with `usd-core` (tested with 26.11):

```sh
uv run --with usd-core==26.11 python Tools/convert_toaster.py
```

The converter preserves all 33,136 triangles, centers each mesh pivot, separates
the moving lever inset from the cabinet buttons, and verifies the packaged mesh
count. It intentionally rejects unsupported source changes. Its SHA-256 and web
baseline are recorded in `Toaster.provenance.json`. Review the provenance commit
when updating the reference.

If app source files are added, update the Xcode project in Xcode. A maintainer
generator is also included (`gem install xcodeproj -v 1.28.1`, then
`ruby Tools/generate_project.rb`). It recreates the project and shared scheme;
reapply any custom signing or project settings afterward.
