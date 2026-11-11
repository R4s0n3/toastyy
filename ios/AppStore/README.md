# App Store submission preparation

Prepared for App Store Connect app 6826357624.

## Current release preparation · 2026-11-11

- Build 6 uploaded to TestFlight; includes dedicated support/privacy links.
- Both build 6 simulator UI tests passed.
- Support/privacy pages deployed and HTTPS-verified on toasty.app.miomideal.com.
- app-ads.txt also deployed and text/plain-verified on miomideal.com for crawler discovery.
- Current description, review notes and three gameplay screenshots saved in Apple.
- Support/marketing URLs and app-specific privacy policy URL saved in Apple.
- Paid Apps Agreement remains Pending User Info; W-8BEN is Missing Tax Info.
  Bank details are Processing and DSA trader verification is In Review.
- AdMob consent configuration and final App Privacy declaration remain open.
- The public app has not been submitted for review. Advertising remains test-only.

## Latest handoff · 2026-11-10

- TestFlight 1.0.0 (5) uploaded successfully with the approved enlarged toaster,
  final-720-ms stop window, and centered active camera.
- App Store Connect and AdMob require a fresh browser login. Processing,
  test-group assignment, contracts and account changes could not be verified.
- Current screenshots in `screenshots/` replace the old local assets. All four
  are unmodified 1206 × 2622 PNGs with no alpha, captured from successful UI
  tests on iPhone 17 Pro / iOS 26.5. Their upload to Apple is still pending.
- Review notes and description now explain WAIT → STOP and ignored early taps.
- `launch-kit/todo.html` is the interactive owner checklist. The directory also
  contains test notes, device checks, App Privacy worksheet and ready support
  website / app-ads.txt files with deployment instructions.
- Public app-ads.txt returned HTTP 404; privacy page still presents itself as
  website privacy. Neither website nor account configuration was published.
- Both current UI tests passed. The larger-phone drag test now travels 180 pt
  and verifies the game status, rather than treating the hidden STOP button as
  proof that a round started. App code is unchanged from uploaded build 5.

The historical preparation below remains a record, not a fresh account audit.

## Earlier account preparation · 2026-10-23
No submission has been sent for App Review.

## Prepared in App Store Connect

- Version 1.0.0; English description, promotional text, keywords, copyright,
  and reviewer instructions from listing.en-US.json.
- Three unmodified screenshots from successful UI tests on iPhone 17 Pro,
  1206 × 2622, RGB with no alpha. Uploaded for the required medium display size.
- Subtitle: “A tiny game of perfect timing”. Primary category Games, with
  Casual and Simulation subcategories.
- Age-rating questionnaire: advertising present; no UGC/chat/social media,
  unrestricted browsing, mature content, medical advice, violence or gambling.
  Apple's calculated rating is 4+. Not marked Made for Kids.
- Reviewer sign-in requirement removed; the app has no account system.
- Manual release selected. Free download and all 175 storefronts configured,
  including future storefronts. Unvalidated Apple Silicon Mac and Vision Pro
  availability disabled for the iPhone-first launch.
- Privacy policy URL entered: https://miomideal.com/privacy-policy.
- Remove Ads product 6826369405 has its reviewer screenshot and instructions.

## Blocking account and website work

- Owner explicitly authorized acceptance of the Paid Apps Agreement on
  2026-10-23. The agreement checkbox was selected and Agree invoked; Apple
  requires two-factor authentication before completing acceptance. Business
  still shows New. Complete Apple's authentication and verify the resulting
  agreement status, then any required tax/banking setup.
- Owner explicitly authorized EU trader registration. Trader was selected and
  the existing Apple account address/phone plus legal@miomideal.com entered.
  Apple's flow reached Verify Email Address; verification and final registration
  remain incomplete. The agreement authentication is open in a separate tab.
- Support email legal@miomideal.com and existing Apple review-contact details
  were confirmed by the owner and entered. The working contact page
  https://miomideal.com/legal-notice is the current Support URL.
- Owner confirmed distribution rights. Model source is Adobe Substance 3D
  free library; provenance records that confirmation and Adobe's larger-work
  license guidance. Fonts include OFL licenses; audio is synthesized locally.
- The public privacy page currently covers the website/shop only. Review and
  publish the Toastyy-specific addition in privacy-addition.de.md after
  confirming the final ad configuration. It is a draft, not a published policy.
- Publish a real support page; support-page.en.md contains prepared content.
  Suggested address https://miomideal.com/toastyy does not exist yet; the existing
  legal-notice page already provides the confirmed support contact.
- Publish app-ads.txt at https://miomideal.com/app-ads.txt (currently 404), preserving
  any other publishers' entries if the site later adds them.
- AdMob preview is at Google's login screen; user must sign in directly.
  Publish applicable UMP messages for the correct Toastyy app and verify them
  on device before releasing live advertising.

## Build and data checks before submission

- Build 3 still has ToastyyUseTestAds=true. Do not submit that as the final live-ad
  release. After account/privacy setup, prepare and validate a production build
  with safe test-device protection during testing.
- Verify sandbox purchase, cancellation/pending purchase, restoration, reinstall,
  and refund/revocation behavior on a physical iPhone. Simulator UI tests do not
  prove that real App Store product fetching or purchase is available.
- Verify UMP consent/denial/reopening, eligible ad breaks, ad dismissal, offline
  gameplay, and that verified purchasers never load or show ads.
- sdk-privacy-manifests.json captures the exact Google Mobile Ads 13.11.0 and
  UMP 3.1.0 manifests. Google declares coarse location, device IDs, advertising
  data, product interaction, and diagnostics. This is not a “Data Not Collected”
  app once the advertising SDK runs.
- Finalize App Privacy using the actual consent/personalization configuration,
  including data linked to users and tracking. A manifest is an input to that
  assessment, not a substitute for the final app's behavior. No inaccurate
  privacy label has been published.
- Validate the final archive, select it for version 1.0.0, attach the Remove Ads
  purchase to the same first submission, and submit only once blockers clear.

## Sources

- https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications
- https://developer.apple.com/app-store/review/guidelines/
- https://developers.google.com/admob/ios/privacy/data-disclosure
- https://developers.google.com/admob/ios/privacy
- https://support.google.com/admob/answer/9363762
