# Advertising and Remove Ads

## Configuration

- AdMob app: `ca-app-pub-5162263720207671~7785962920`
- Production interstitial: `ca-app-pub-5162263720207671/8412648888`
- SDK: Google Mobile Ads 13.11.0, with its UMP consent dependency.
- Apple non-consumable: `com.toastyy.app.removeads` (Remove Ads).
- App Store Connect product: 6826369405. Base country Germany, EUR 2.99;
  worldwide availability with Apple's localized prices. Montenegro's EUR price
  was explicitly set to EUR 2.99 as well.
- Privacy link: https://toasty.app.miomideal.com/privacy.html

For build 9, `ToastyyUseTestAds` in Info.plist is **false**: Release builds
request the production unit. Debug builds always use Google's test unit. All
ads still require successful UMP consent setup;
if that fails or the device is offline, the game simply continues without ads.
UI automation disables ads and StoreKit network work with `--ui-testing`.

Ads are eligible only after a burnt run, after at least six completed rounds,
and no more often than every 120 seconds. They are preloaded and never delay
play if unavailable. Gameplay and sounds pause during full-screen presentation.
Verified StoreKit entitlements disable ad loading and presentation. Purchase
updates, pending purchases, cancellations, revocations, and restoration are
handled through StoreKit, rather than a locally trusted purchase flag.

## Before live advertising / App Review

1. The app-specific public privacy page is live. Keep it aligned with the final
   SDK/consent configuration.
2. In AdMob Privacy & messaging, publish applicable consent messages assigned
   to Toastyy. Verify consent, denial, privacy-choice reopening, offline
   behavior, and test-ad presentation on a physical iPhone.
3. Set up app-ads.txt on the developer website and link the published App Store
   listing to AdMob for app verification/readiness review.
4. Complete Apple's Paid Applications agreement, tax/banking details as required,
   product metadata and reviewer screenshot. Submit the first purchase with
   the first app version. Test sandbox purchase, restore, pending/cancelled
   purchase, reinstall, and refund behavior before claiming purchase validation.
5. Update App Store Connect privacy disclosures for the SDK and final consent
   configuration. The SDK embeds its own privacy manifest; the app's manifest
   describes its own local APIs. No ATT permission is requested by this build.
6. Build 9 enables the production unit. Register physical test devices in AdMob
   before testing production advertising; do not click live ads during testing.
   AdMob readiness/store verification remains pending the public store listing.

## TestFlight 1.0.0 (3)

Includes SDK/consent integration, frequency-limited interstitials, StoreKit
purchase/restoration UI, and the privacy link. Simulator UI tests exercise the
normal game with advertising disabled; they do not validate Google's consent
messages or a real StoreKit sandbox transaction. The public privacy page and
remaining account-side requirements must be completed separately.

## TestFlight 1.0.0 (7): non-personalized advertising

Before consent processing and Google Mobile Ads initialization, Toastyy sets
`publisherPrivacyPersonalizationState = .disabled` and disables Publisher
First-Party ID. Every interstitial request also carries `npa=1`, including test
and production units and reloads after privacy choices. UMP consent gating
remains required; non-personalized ads still process identifiers and diagnostics
for purposes such as fraud prevention and frequency capping. No ATT permission
or IDFA access is requested by the app. Test advertising remains enabled.

Device testing must confirm consent/denial, reopening privacy choices and ad
presentation. These configuration changes are not a network audit and do not
mean “no data collected”. Keep the SDK data types disclosed; finalize App Privacy
against this build and the actual AdMob account settings before publication.

References:
- https://developers.google.com/admob/ios/targeting
- https://developers.google.com/admob/ios/privacy/strategies

## Build 9

Owner confirmed sandbox purchase and restoration working on build 8. Build 9
removes diagnostic codes from user-facing purchase messages and logs lookup
failures through OSLog instead. No receipts/account data are logged. Release
ad requests use production IDs; the build-7 non-personalization restrictions
remain unchanged. No-fill / ad-load failures continue silently without blocking
the game.
