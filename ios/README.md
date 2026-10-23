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

- Turn the 3D knob, drag it horizontally, or use the four difficulty buttons.
- Drag the physical lever down, tap it, or use **Pull to Start**.
- Tap the 3D scene or **Stop Toaster** just before the pop. The last 150 ms is a
  perfect save. Missing ends the run; permanent records and XP remain.
- The four cabinet buttons toggle sound, haptics, settings, and records.
  Equivalent labeled controls are available through the native interface.
- Open the collection to equip unlocked toast. New levels automatically equip
  their new finish, matching the web client.

## Implemented

- Original toaster geometry, dimensions, and normals converted to bundled USDZ.
- Non-AR perspective camera, warm lighting, floor shadows, heater glow,
  centered knob rotation, linked lever handle and inset, shaped bread, and crumbs.
- Four difficulty ranges and multipliers, accelerating rounds, timing grades,
  cumulative run scores, streak bonuses, best records, and automatic cooldowns.
- Eight toast finishes with native procedural textures and PBR materials, matching
  web XP thresholds and rewards. The patterns are native redraws, not exact
  pixel copies of the web canvas textures.
- Native collection, settings, records, help, local persistence, synthesized
  audio, haptics, and foreground interruption handling.
- Accessible start/stop and difficulty controls, VoiceOver labels, and reduced
  motion support for the presentation and toast pop.
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
burns, the collection, and sound settings; the first test saves a screenshot in
the result bundle. The workflow selects an available iPhone automatically.

`swift test` also runs on Linux with Swift 6.0 or newer. It validates the portable
rules, not SwiftUI or RealityKit. The first implementation was created on Linux.
The initial Mac CI run has since successfully compiled the iOS Simulator app;
check the **Native iOS** Actions run for the separate UI-test outcome. A
successful simulator build does not validate device signing or distribution.

Before treating the port as device-verified, run the Xcode build and UI tests,
then check framing on small and large iPhones, the physical knob and lever hit
areas, audio and haptics on hardware, app switching, and metallic finishes.
Visual polish still needed for exact web parity includes the projected housing
legends, smoke and steam, grill marks, and the full web result effects.
Web localStorage saves are not imported; native progress starts fresh. Signing,
App Store metadata, and distribution have not been configured.

## Structure

- `Sources/ToastyyCore`: platform-independent state machine, scoring, progression,
  and ballistic toast motion. Time and randomness are injected for tests.
- `Toastyy/App`: SwiftUI entry, observable state, versioned UserDefaults save,
  synthesized audio, and UIKit haptics.
- `Toastyy/Scene`: RealityKit view, native bread meshes, texture painting, camera,
  lighting, and direct 3D interaction.
- `Toastyy/Views`: native game, collection, settings/help, and records screens.
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
