# Launch scope

- Match the mobile reference's gameplay and presentation.
- Include local sounds and haptics, with independent settings.
- Start with Dry toast. DAYDREAM is the only unlockable skin and requires
  1,000,000 total XP. More skins will follow in later releases.
- Keep existing XP and records when updating from earlier TestFlight builds.
  Previously equipped skins that are unavailable or below the new threshold
  fall back to Dry toast.
- Free download, available worldwide wherever Apple permits distribution.
- Planned monetization: ads between rounds and a permanent, restorable Remove
  Ads non-consumable purchase priced at EUR 2.99 in euro storefronts, with
  localized prices elsewhere. Never interrupt an active timing challenge.

## TestFlight 1.0.0 (2)

Includes the launch collection and million-XP milestone, with existing sounds
and haptics. Ads and purchases are not implemented in this build. They require
an ad-network account and production app/ad-unit configuration, consent and
privacy setup, and an App Store Connect non-consumable product before testing
and release.

## TestFlight 1.0.0 (3)

Adds AdMob/UMP integration with test ads only, a privacy link, and StoreKit
Remove Ads purchase/restoration. See ADVERTISING.md for account-side setup,
physical-device verification, and production release gates.

## TestFlight 1.0.0 (4)

Enlarges and optically centers the toaster, simplifies the game HUD to a single
play cue, increases score and XP readability, and confines paper grain to the
background. Stops count only during the last 720 ms before the pop; early taps
keep toasting and earn no points or XP. Includes build 3's test-ad and StoreKit configuration.

## TestFlight 1.0.0 (5)

Adds smooth camera tracking as the toaster turns at the start of a round. The
active cabinet centers in the stage and returns to its optical idle offset
afterward. Reduced Motion uses an immediate transition.
