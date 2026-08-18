# EyeOh distribution and monetization setup

Checked: 12 August 2026 (Australia/Brisbane)

## Decision

Launch the Mac App Store edition as a free app and keep EyeOh Core free in both channels. A paid app is not required now, and making the app paid first would add friction without improving the later In-App Purchase path.

When there is enough additional value, the preferred first product is one permanent **EyeOh Pro** non-consumable purchase. Advanced casting, remote receivers, automation and reusable routing profiles can contribute to that bundle. A separate permanent **Advanced Casting** purchase is viable only if it becomes a coherent, independently valuable product rather than a collection of experiments.

Do not use a subscription for local switching or a static feature unlock. Consider one only if EyeOh later supplies continuing costs and continuing value, such as a hosted relay, managed team fleet, cloud history/configuration or regularly maintained remote-device service.

## What is prepared locally

### Direct download

- Sparkle 2.9.5 is linked only when `EYEOH_DISTRIBUTION_CHANNEL=direct`.
- The standard native updater supplies manual checks, scheduled checks, automatic downloads, signature verification, update prompts and relaunch.
- The feed is fixed at `https://eyeoh.app/updates/appcast.xml` and checks every 24 hours when the user enables automatic checks.
- Update archives must pass EdDSA verification before extraction as well as Apple code-signing validation.
- A dedicated EdDSA key for account `au.com.darkice.eyeoh` is stored in the maintainer's login Keychain. Only its public key is committed.
- `Scripts/prepare_appcast.sh` creates a signed appcast from a notarized ZIP. `Scripts/release_direct.sh --notarize` prepares the immutable update archive and appcast after Apple notarization succeeds.
- The repository contains a valid empty appcast so a future website deploy cannot accidentally serve the HTML homepage at the feed URL before the first updater release is ready.
- Sparkle helpers are individually re-signed before the framework and host app; no `--deep` signing shortcut is used.
- Direct artifacts now use `build/direct`; this avoids overwriting the existing release candidate.

EyeOh 0.4.0 (6) does not contain an updater. The first updater-enabled release therefore requires one final manual download. Every later direct release can update through Sparkle.

Release order matters: publish the versioned ZIP and any delta files first, confirm they return 200, and publish `appcast.xml` last. Never publish a feed entry before the signed archive is reachable. The private EdDSA key must remain outside the repository and web host.

### Mac App Store

- `Scripts/build_mas_candidate.sh --local` creates a universal, sandboxed local candidate in `build/mas`.
- The MAS dependency graph does not include Sparkle. The script fails if the binary links Sparkle or its Info.plist contains direct-update keys.
- The initial free MAS candidate requests only App Sandbox, Camera and Bluetooth capabilities. It has no telemetry configuration, no network-client entitlement and a no-collected-data privacy manifest.
- `Scripts/build_mas_candidate.sh --submission` requires a Dark Ice Apple Distribution identity, a Mac App Store Connect provisioning profile for `au.com.darkice.eyeoh`, and a Mac Installer Distribution identity. It creates a signed `.pkg` but never uploads it.
- App Store updates remain exclusively controlled by the App Store.

The machine currently has the Dark Ice Developer ID identity used for direct releases, but it does not yet have a Dark Ice Apple Distribution/Mac App Distribution identity, Mac Installer Distribution identity or an installed provisioning profile matching `au.com.darkice.eyeoh`. The only installed Apple Distribution identity belongs to a different company and is deliberately rejected by the MAS script.

## App Store Connect setup

Create the app record only after the Account Holder confirms the latest agreement:

- Platform: macOS
- Name: EyeOh
- Primary language: English (Australia), if offered; otherwise English (UK)
- Bundle ID: `au.com.darkice.eyeoh`
- Suggested SKU: `EYEOH-MAC-001`
- Category: Utilities
- Price: Free
- Support URL: `https://eyeoh.app/`
- Privacy URL: `https://eyeoh.app/privacy/`

Initial listing direction:

- Subtitle: **Quick audio & camera routing**
- Lead: **Switch microphones, speakers and your preferred camera from one native menu-bar utility.**
- Positioning: fast, private, native and focused; explain remembered Bluetooth reconnects without implying that EyeOh pairs devices or overrides apps with pinned routes.
- Screenshots: the real menu first, camera preview second and Settings/privacy third.
- Do not mention Pro, casting or an In-App Purchase in the free launch listing until that functionality exists in the submitted binary.

Before a submission build can be made:

1. Register or confirm the explicit App ID `au.com.darkice.eyeoh` under the Dark Ice team.
2. Create the appropriate Mac distribution and Mac installer distribution certificates with their private keys on the release Mac.
3. Generate a Mac App Store Connect provisioning profile for that App ID and distribution certificate.
4. Create the App Store Connect app record, screenshots, description, keywords, age rating, support/privacy information and App Privacy answers.
5. Run the deterministic tests, the sandbox probe, `Scripts/build_mas_candidate.sh --local`, and a real signed MAS candidate test.
6. Run `--submission`, validate the `.pkg`, then upload with Xcode or Transporter only after approval.

## Free now, paid functionality later

Apple permits a free app to add In-App Purchases later. EyeOh does not need to be a paid app at launch. To sell a feature unlock in the MAS build, it must use StoreKit/In-App Purchase; do not put a Dark Ice licence key or external checkout into that binary.

Recommended first IAP when Pro is real:

- Type: Non-Consumable
- Reference name: EyeOh Pro Permanent Unlock
- Product ID: `au.com.darkice.eyeoh.pro`
- Customer promise: one purchase, no expiry, restorable on the purchaser's Apple Account
- Family Sharing: decide before launch based on the support model

Apple requires the first non-consumable IAP to be submitted with a new app version. That makes the clean sequence: ship free EyeOh first, build the actual Pro features, add StoreKit 2 entitlement handling and Restore Purchases, test in StoreKit and sandbox, then submit the first IAP with the Pro-enabled update.

The Account Holder must accept the Paid Apps Agreement and complete banking and tax information before IAP can be offered. If eligible, Dark Ice should separately enrol in Apple's Small Business Program; its published rate is 15% on paid apps and IAP up to the program threshold.

MAS purchases do not automatically unlock a separately downloaded Developer ID app. Sharing entitlements across MAS and direct builds would require a Dark Ice account/receipt-exchange service and substantially more privacy, support and fraud work. Avoid that for the first paid release: sell through StoreKit in MAS and decide on a separate direct licence only when the commercial edition exists.

## Acceptance gates

Direct updater release:

- Increment both marketing version and build number; never reuse 0.4.0 (6).
- Build universal Developer ID app, verify every nested signature, notarize and staple.
- Generate a signed appcast and verify `sparkle:edSignature` is present.
- Test update from the previous updater-enabled version on a clean macOS user account.
- Prove corrupt archive and wrong-signature rejection.
- Prove manual check, automatic check, automatic download, Install and Relaunch, skipped version and offline behavior.
- Deploy archive/deltas before the appcast, then verify public URLs and a fresh download.

MAS release:

- Dark Ice distribution and installer identities installed; exact profile matches the bundle ID.
- Universal MAS build contains App Sandbox entitlements and no Sparkle framework, link, feed URL or public key.
- App Review notes match the actual build and no future paid feature appears in screenshots or description.
- App Privacy answers match the final telemetry configuration.
- Upload and TestFlight/App Store receipt behavior tested before submission.

## Primary sources

- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple: add a new app](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/)
- [Apple: create an App Store Connect provisioning profile](https://developer.apple.com/help/account/provisioning-profiles/create-an-app-store-provisioning-profile)
- [Apple: upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/)
- [Apple: configure In-App Purchases](https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/overview-for-configuring-in-app-purchases/)
- [Apple: submit an In-App Purchase](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase/)
- [Apple App Store Small Business Program](https://developer.apple.com/app-store/small-business-program/)
- [Apple StoreKit transaction entitlements](https://developer.apple.com/documentation/storekit/transaction/currententitlements)
- [Sparkle setup and security](https://sparkle-project.org/documentation/)
- [Sparkle publishing](https://sparkle-project.org/documentation/publishing/)
