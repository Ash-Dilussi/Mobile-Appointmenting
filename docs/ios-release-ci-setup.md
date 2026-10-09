# iOS Release CI Setup

The repository contains an `ios-testflight` workflow in `codemagic.yaml`. It
runs on hosted macOS, restores the real Firebase configuration, installs pods,
creates or fetches App Store signing files, builds a signed IPA, and uploads it
to TestFlight.

The workflow intentionally fails before compilation if any owner-controlled
credential is missing or if the Firebase plist belongs to a different bundle
or Firebase project.

## Current release identity

- Provisional bundle ID: `com.ashDilussi.bookly`
- Firebase project: `bookly-1f5f7`
- Google Sign-In and Google Calendar are outside the first iOS release scope.
- No push, universal-link, or additional iOS capability is enabled.

If App Store Connect registers a different final bundle ID, update the Runner
bundle identifiers and `BUNDLE_ID` in `codemagic.yaml`, register that exact ID
as a new Firebase iOS app, and replace the Firebase secret before building.

## 1. Supply the Firebase configuration

1. In Firebase Console, open project `bookly-1f5f7`.
2. Register an iOS app with bundle ID `com.ashDilussi.bookly`.
3. Download its real `GoogleService-Info.plist`.
4. Base64-encode it on Windows PowerShell:

   ```powershell
   [Convert]::ToBase64String(
     [IO.File]::ReadAllBytes('GoogleService-Info.plist')
   ) | Set-Clipboard
   ```

5. In Codemagic, create the `firebase_credentials` variable group.
6. Add `IOS_FIREBASE_CONFIG_BASE64`, paste the encoded value, and mark it
   Secret.

Do not commit `GoogleService-Info.plist`; it is deliberately ignored. The
workflow restores it only on the ephemeral build machine, validates the
project/bundle IDs, and derives the Dart Firebase options from the same file.

## 2. Supply Apple signing credentials

After Apple Developer Program enrollment is approved:

1. Confirm that the registered App ID and App Store Connect app use the exact
   release bundle ID.
2. In App Store Connect, create a dedicated API key with App Manager access.
3. Download the `.p8` private key once and record its Key ID and Issuer ID.
4. In Codemagic, create the `appstore_credentials` variable group and add these
   three Secret values:

   - `APP_STORE_CONNECT_KEY_IDENTIFIER`
   - `APP_STORE_CONNECT_ISSUER_ID`
   - `APP_STORE_CONNECT_PRIVATE_KEY` (the complete `.p8` contents)

The workflow uses these values to fetch or create an Apple Distribution
certificate and App Store provisioning profile. No signing identity is
committed to the repository.

## 3. Run and verify

1. Connect the repository in Codemagic and select the YAML workflow.
2. Run `ios-testflight` from a clean checkout.
3. Confirm the workflow completes Firebase validation, `pod install`, focused
   analysis/tests, signing, and `flutter build ipa`.
4. Confirm the build appears in TestFlight.
5. Install it on a physical iPhone and verify:

   - Firebase initialization completes without a missing-config error.
   - Email/password registration and login work.
   - Google Sign-In and Google Calendar controls are absent.
   - Contact import requests Contacts access only when selected.
   - Bookly-initiated calls hand off to the external dialer.

Record the Codemagic build URL, TestFlight build number, device/iOS version,
and results in `docs/agents/project-status.md`. Only after that run passes can
Spec 02's signed-build acceptance criterion be marked complete.
