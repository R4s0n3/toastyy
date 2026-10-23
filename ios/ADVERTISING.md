# Advertising and Remove Ads

## Configuration

- AdMob app: `ca-app-pub-5162263720207671~7785962920`
- Production interstitial: `ca-app-pub-5162263720207671/8412648888`
- SDK: Google Mobile Ads 13.11.0, with its UMP consent dependency.
- Apple non-consumable: `com.toastyy.app.removeads` (Remove Ads).
- App Store Connect product: 6826369405. Base country Germany, EUR 2.99;
  worldwide availability with Apple's localized prices. Montenegro's EUR price
  was explicitly set to EUR 2.99 as well.
- Privacy link: https://miomideal.com/privacy-policy

`ToastyyUseTestAds` in Info.plist remains **true**. The production unit is never
requested in this build. Test ads still require successful UMP consent setup;
if that fails or the device is offline, the game simply continues without ads.
UI automation disables ads and StoreKit network work with `--ui-testing`.

Ads are eligible only after a burnt run, after at least six completed rounds,
and no more often than every 120 seconds. They are preloaded and never delay
play if unavailable. Gameplay and sounds pause during full-screen presentation.
Verified StoreKit entitlements disable ad loading and presentation. Purchase
updates, pending purchases, cancellations, revocations, and restoration are
handled through StoreKit, rather than a locally trusted purchase flag.

## Before live advertising / App Review

1. Expand the public privacy page with a clearly identified Toastyy section.
   The current page describes the website and shop, not the app. Document local
   XP/records/settings, Google Mobile Ads and UMP, advertising data processing,
   consent and withdrawal, third-country transfers, retention/deletion,
   contact details, and Apple in-app purchases according to the final setup.
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
6. Only after these checks, set `ToastyyUseTestAds` to false for the public
   release and test the production configuration with registered test devices.

## TestFlight 1.0.0 (3)

Includes SDK/consent integration, frequency-limited interstitials, StoreKit
purchase/restoration UI, and the privacy link. Simulator UI tests exercise the
normal game with advertising disabled; they do not validate Google's consent
messages or a real StoreKit sandbox transaction. The public privacy page and
remaining account-side requirements must be completed separately.
