# First TestFlight build

Use the Mac for the first upload so Xcode manages your signing certificates and
provisioning. No Apple password, private key, or certificate needs to enter chat
or the repository.

## Prepare the account and project

1. Use an active Apple Developer Program membership. Sign in to that account in
   **Xcode → Settings → Accounts**.
2. Install **Xcode 26 or newer**, including the iOS SDK. Apple requires Xcode 26
   and the iOS 26 SDK or newer for current App Store Connect uploads; the app's
   deployment target can remain iOS 17.
3. Pull the repository and open the native project:

   ```sh
   git pull origin main
   open ios/Toastyy.xcodeproj
   ```

4. Select the **Toastyy app target → Signing & Capabilities**. Enable
   **Automatically manage signing** and choose your paid developer team.
5. Replace the placeholder `com.toastyy.app` with a unique bundle identifier
   owned by your team, such as `com.yourcompany.toastyy`. Use that exact identifier
   in App Store Connect. These identifiers and the Team ID are not secrets.
6. Run the **Toastyy** scheme on an iPhone simulator, then on a physical iPhone
   if available. Check starting, stopping, burns, collection, and app switching.
   Review the repository's **Native iOS** Actions run for the automated checks.

## Create the App Store Connect record

In [App Store Connect](https://appstoreconnect.apple.com/), open **Apps → + → New
App**. Choose iOS, an available app name, a primary language, the matching bundle
ID, and an internal SKU such as `toastyy-ios`. The bundle ID must be registered
with your team; Xcode automatic signing normally registers it during setup.

If the app record already exists, use its bundle ID instead of creating another.

## Archive and upload

1. In the Toastyy target's **General** tab, set version `1.0.0` and build `1` for
   the first upload. Increment the build number for each subsequent upload.
2. Select the **Toastyy** scheme and an iOS device archive destination, such as
   **Any iOS Device (arm64)**, rather than an iPhone simulator.
3. Choose **Product → Archive**.
4. In Organizer, select the new archive and choose **Distribute App → App Store
   Connect → Upload**. Follow Xcode's signing and validation steps.
5. Wait for Apple's processing, then open the app's **TestFlight** tab in App
   Store Connect. Resolve any processing or export-compliance questions shown
   for the build. This app already declares `ITSAppUsesNonExemptEncryption = NO`.

For your first install, create an **internal testing** group, add your eligible
App Store Connect account, and add the processed build. Accept the invitation
in Apple's TestFlight app on your iPhone. For testers outside the App Store
Connect team, configure external testing and submit the build for Beta App
Review when Apple requires it.

After configuring signing, commit the intended bundle-ID and project changes
from the Mac so future builds use the same app identity. Do not commit Xcode
user data, signing certificates, provisioning profiles, or private keys.

## Current release setup

- The repository includes an app icon, launch configuration, privacy manifest,
  version/build settings, and an archive-enabled shared scheme.
- The developer team is intentionally unset and the bundle identifier is a
  placeholder. These need your account-specific values before distribution.
- The GitHub workflow builds/tests the simulator app. It does **not** sign,
  archive, or upload to TestFlight. Automated uploads can be configured after
  the first working signed upload.

Apple references: [SDK upload requirements](https://developer.apple.com/news/upcoming-requirements/),
[create an app record](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app),
[upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds),
[TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/).
