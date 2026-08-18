# EyeOh release readiness

Checked: 12 August 2026 (Australia/Brisbane)

## Recommendation

EyeOh is released as a free, Developer ID-signed and notarized direct download. A Direct-only Sparkle updater and a separately compiled sandboxed MAS candidate path are now prepared locally. Mac App Store submission is plausible but still needs Dark Ice distribution/installer identities, a matching provisioning profile, an App Store Connect record and App Review. Setapp is a later commercial channel, not a free-download channel.

EyeOh `0.4.0 (6)` is published at `eyeoh.app`. No Mac App Store or Setapp submission has been performed.

## Mac App Store assessment

EyeOh's core behaviour is not prohibited by the current guidelines:

- It uses Apple's documented Core Audio device and default-input/default-output selectors.
- It uses the public IOBluetooth API only after the user clicks a remembered, paired audio-device shortcut. It does not scan for, pair, or silently connect new devices.
- Camera discovery, preference, and preview use public AVFoundation APIs. Preview is user-initiated and frames are not recorded, stored, or transmitted.
- It is a self-contained menu-bar utility and does not install a driver, helper, kernel extension, or privileged component.
- It does not capture microphone audio, request microphone access, or create an account. Camera access is requested only for an explicitly opened local preview. Separate off-by-default choices can send a fixed product-event schema to PostHog EU and stripped crash/hang diagnostics to Sentry EU in an official configured build.
- Per-device volume presets are stored locally in app preferences and never uploaded.
- Its audio switching is substantial native utility rather than a repackaged website.

The gates are:

1. Mac App Store apps must be appropriately sandboxed under guideline 2.4.5(i).
2. The submission must be packaged using Xcode technology, be self-contained, and use App Store updates under 2.4.5(ii) and (vii).
3. The app must use public APIs under guideline 2.5.1. The Core Audio constants and AVFoundation camera preference used by EyeOh are publicly documented.
4. App Review still has discretion under minimum-functionality guideline 4.2; a focused utility is defensible, but approval cannot be guaranteed.
5. A Mac App Store bundle needs an App Store Connect record, Mac Distribution signing/provisioning, screenshots, metadata, support/privacy URLs, and accurate App Privacy answers. The prepared free MAS candidate has no provider configuration or network-client entitlement and uses the no-collected-data privacy manifest. If optional providers are enabled later, “Data Not Collected” is no longer accurate: Product Interaction and Crash Data must be declared for Analytics/App Functionality, not used for tracking, and assessed carefully as not linked to identity. The random installation identifier may also require an identifier disclosure; confirm the final App Store Connect questionnaire rather than guessing.

Prepared locally:

- `Config/EyeOh-MAS.entitlements` enables App Sandbox, the public camera capability for preview and Bluetooth for explicit paired-device reconnects. The initial offline MAS candidate does not request outgoing network access.
- `Config/EyeOh-PrivacyInfo-Offline.xcprivacy` declares the required-reason APIs and no collected data for unconfigured builds. `Config/EyeOh-PrivacyInfo.xcprivacy` is reserved for builds that actually enable the optional product-interaction and crash-diagnostic providers.
- `APP_REVIEW_NOTES.md` maps each requested sandbox capability to a visible feature and gives a reviewer a short, reproducible Bluetooth and camera test path.
- `Scripts/test_mas_sandbox.sh` compiles a probe that enumerates devices and validates the current defaults inside App Sandbox. With `EYEOH_PROBE_WRITES=1`, it performs a state-restoring write check and restores input, normal output, and the independently selected system-sound output before exiting. With `EYEOH_PROBE_BLUETOOTH_READ=1`, it verifies that the sandboxed process can enumerate paired Bluetooth devices without exposing their names or addresses in logs.
- The normal test suite is deterministic and does not depend on or write to attached audio hardware.
- A real-device write check is available only with `EYEOH_RUN_HARDWARE_TESTS=1`; it snapshots and restores input, output, and the separate system-sound output.
- `Scripts/build_mas_candidate.sh` creates an isolated universal MAS candidate and rejects any Sparkle linkage or updater keys. Its submission mode remains gated on Dark Ice Mac distribution and installer identities plus a matching provisioning profile.

Primary sources:

- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple default input device API](https://developer.apple.com/documentation/coreaudio/kaudiohardwarepropertydefaultinputdevice)
- [Apple default output device API](https://developer.apple.com/documentation/coreaudio/kaudiohardwarepropertydefaultoutputdevice)
- [Apple App Sandbox entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.app-sandbox)
- [Apple user-preferred camera API](https://developer.apple.com/documentation/avfoundation/avcapturedevice/userpreferredcamera)
- [Apple camera sandbox entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.device.camera)

## Direct download and Mac App Store together

Apple supports both macOS distribution models: Developer ID plus notarization for software distributed by its developer, and App Store distribution for a sandboxed build. EyeOh can therefore keep the notarized website download after a Mac App Store edition launches; there is no Mac App Store exclusivity requirement in the reviewed rules.

Maintain two release configurations from the same source tree:

- **Direct:** Developer ID signed, Hardened Runtime, notarized and stapled. Dark Ice owns download hosting and updates and may later use its own direct-edition licensing.
- **Mac App Store:** Apple Distribution signing and provisioning, App Sandbox, only the capabilities used by that submitted build, and updates only through the Mac App Store. Digital feature unlocks inside this edition must follow StoreKit/In-App Purchase rules; do not add a Dark Ice licence screen or key system to the MAS binary.

Using the existing `au.com.darkice.eyeoh` bundle identifier for both configurations is the simplest product choice when installing one channel should replace the other. This is a product recommendation rather than an Apple requirement. Use separate identifiers only if side-by-side installation is genuinely needed, because that creates separate preferences, sandbox containers, receipts, and migration work. The App Store record's bundle identifier becomes fixed after a build is uploaded.

The two editions may differ where sandbox or review rules require it. Compile direct-only functionality out of the MAS target, clearly compare editions on the website, and ensure MAS screenshots and metadata advertise only functionality present in the reviewed binary. The current free core has no payment conflict.

That separation is now enforced by the package manifest and isolated channel build directories: Sparkle 2.9.5 is a Direct-only dependency, while MAS/source builds compile a no-op updater controller and are checked for accidental Sparkle links and feed keys. See `DISTRIBUTION_AND_MONETIZATION.md` for the operational release and free-now/IAP-later plan.

Primary sources:

- [Apple macOS distribution comparison](https://developer.apple.com/macos/distribution/)
- [Apple Developer ID](https://developer.apple.com/support/developer-id/)
- [Apple App Sandbox configuration](https://developer.apple.com/documentation/xcode/configuring-the-macos-app-sandbox)
- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple App Store marketing guidelines](https://developer.apple.com/app-store/marketing/guidelines/)

## Camera assessment

The supported camera feature is a preference, not a forced global route. EyeOh sets `AVCaptureDevice.userPreferredCamera`; apps that adopt Apple's `systemPreferredCamera` behaviour can follow it, while Teams, Zoom, browsers, and other apps may retain a camera explicitly selected in their own settings.

The live preview uses a local `AVCaptureSession` only while its window is open. It does not record, save, analyse, or transmit frames. Camera permission is requested at the point the user opens preview, with `NSCameraUsageDescription` and the camera sandbox entitlement present in packaged builds.

An eligible iPhone is supported without a companion app through Apple's Continuity Camera and appears in the same camera list. Using another Mac or iMac as a camera is not a Continuity Camera feature. Doing that properly would require a separate network companion and Core Media I/O camera extension, adding pairing, local-network privacy, latency, security, system-extension, and distribution work; it is not part of the initial release.

Primary sources:

- [Apple preferred camera APIs](https://developer.apple.com/documentation/avfoundation/avcapturedevice)
- [Apple camera preview layer](https://developer.apple.com/documentation/avfoundation/avcapturevideopreviewlayer)
- [Apple Continuity Camera requirements](https://support.apple.com/en-gb/102546)
- [Apple Core Media I/O camera extensions](https://developer.apple.com/documentation/coremediaio/creating-a-camera-extension-with-core-media-i-o)

## Bluetooth battery assessment

EyeOh 0.4 adds a deliberately narrower Bluetooth feature: after a paired Bluetooth audio device has appeared through Core Audio, EyeOh remembers its local display name, Core Audio role, and Bluetooth address. When that route is absent, the menu can show a dimmed Connect shortcut. Connection is initiated only by a user click through the public `IOBluetoothDevice.openConnection()` API. EyeOh then waits for macOS to publish the Core Audio route, makes it the requested default, and restores the locally saved volume preset. Users can hide these shortcuts or erase the remembered list in Settings. EyeOh does not discover, pair, or automatically connect unknown devices.

The direct and Mac App Store entitlement sets both declare Bluetooth access, and packaged builds include `NSBluetoothAlwaysUsageDescription`. The App Sandbox probe has verified Core Audio reads/writes and paired-device enumeration with those capabilities. A real Onyx disconnect/reconnect test also passed against the signed 0.4 build: the remembered rows appeared, reconnect completed, the requested input changed, the untouched output was preserved, and the original input was restored afterward.

Bluetooth battery is deliberately not part of the release candidate. macOS can show battery information for some accessories through privileged system components, but its public `IOBluetoothDevice` API does not provide a general headset-battery property. Core Bluetooth can read the standard Battery Service only when a peripheral exposes it; doing so requires a Bluetooth purpose string, explicit user permission, and the Bluetooth sandbox entitlement. The attached Onyx headset currently exposes no battery value through macOS's public Bluetooth inventory.

Do not use private Bluetooth frameworks or scrape System Settings. A future best-effort battery feature should be optional, use only public Core Bluetooth services, and display nothing when a device does not report a value.

Primary sources:

- [Apple IOBluetooth](https://developer.apple.com/documentation/iobluetooth)
- [Apple Core Bluetooth](https://developer.apple.com/documentation/corebluetooth/)
- [Bluetooth usage description](https://developer.apple.com/documentation/bundleresources/information-property-list/nsbluetoothalwaysusagedescription)
- [Bluetooth sandbox entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.device.bluetooth)

## Direct free-download assessment

This is the shortest release path. Apple requires a public direct-distribution build to be signed with a Developer ID Application certificate, use Hardened Runtime and a secure timestamp, and be notarized. EyeOh's primary download is a stapled DMG containing the app and an Applications shortcut; a ZIP remains available as a fallback.

Current release state (machine-specific signing details intentionally omitted):

- EyeOh `0.4.0 (6)` is built as a universal `arm64` + `x86_64` app, signed with the Dark Ice Developer ID certificate, notarized and stapled as both the app and signed DMG, and published at `https://eyeoh.app/downloads/EyeOh.dmg` with a ZIP fallback. Gatekeeper accepts the app as Notarized Developer ID software, and the downloaded DMG/ZIP files match the local SHA-256 release checksums.
- `Scripts/release_direct.sh` builds a universal Apple Silicon/Intel app, signs it with the `APP_IDENTITY` supplied by the maintainer, verifies it, and creates a DMG plus fallback ZIP.
- Passing `--notarize` submits the app archive through `notarytool`, staples the app, builds and notarizes the DMG, validates both tickets, verifies Gatekeeper acceptance, then creates `Website/public/downloads/EyeOh.dmg` and `EyeOh.zip` for the Astro build.
- The validated `notarytool` Keychain profile is named `eyeoh`. Keep it in Keychain and pass it through `NOTARY_PROFILE=eyeoh` for authorized releases.

Primary sources:

- [Apple notarization overview](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [Apple custom notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)

## Setapp assessment

Setapp can be considered after EyeOh has a mature public release, but it is not simply another place to host a free app:

- Setapp is curated and requires agreement plus technical review.
- It expects complete, tested software; trial/test builds, ads, donations, and extra paid functionality are not allowed for Setapp users.
- macOS apps must be Developer ID-signed and notarized.
- The current Setapp Framework must be integrated after acceptance, including activation and usage reporting for a menu-bar extra.
- A separate bundle ID using the `-setapp` suffix is required.
- Universal `arm64` and `x86_64` support is required and must be declared using `MPSupportedArchitectures`.
- Setapp's submission package also requires a 1024×1024 external `AppIcon.png` and its current update-security configuration, including `NSUpdateSecurityPolicy`.

Do not add the Setapp Framework to the free direct build. Maintain a separate Setapp product configuration after Setapp accepts the app.

Primary sources:

- [Setapp developer onboarding](https://setapp.com/developers)
- [Setapp app requirements](https://docs.setapp.com/docs/preparing-your-application-for-setapp)
- [Setapp macOS framework setup](https://docs.setapp.com/docs/macos)
- [Setapp supported architectures](https://docs.setapp.com/docs/specify-supported-architectures)
- [Setapp submission bundle requirements](https://docs.setapp.com/docs/submitting-apps-for-review)

## Release checklist

- [x] Input and output switching implemented with public Core Audio APIs.
- [x] Explicit reconnect shortcuts for previously seen paired Bluetooth audio devices, with user-controlled visibility and history clearing.
- [x] Preferred-camera selection and permission-aware local preview implemented with public AVFoundation APIs.
- [x] Default-device eligibility filtering and capability-aware input/output volume implemented with public Core Audio APIs.
- [x] Deterministic default tests plus an explicitly opt-in, state-restoring real-device integration test.
- [x] Menu-bar-only bundle and native accessible menu.
- [x] Astro/Cloudflare Pages product website with a current branded product screenshot showing native audio routes, Continuity Camera, and Desk View.
- [x] MIT software license, separate Dark Ice trademark policy, and accurate privacy language.
- [x] Documented the MIT Core/commercial Pro boundary, current IP provenance, and CLA-gated external contribution process.
- [x] Branded Help and About views, feedback mail action, and an implemented consent-gated diagnostics boundary.
- [x] EU-only PostHog and Sentry release configuration with source builds offline by default.
- [x] Native Settings window with Service Management launch-at-login, separate off-by-default reporting choices, and consolidated Help/About/system actions.
- [x] Universal-build, Developer ID, Hardened Runtime, DMG/ZIP, and notarization scripts.
- [x] Public-source/private-release boundary documented; upstream GitHub Actions limited to a manual, read-only, secret-free source validation run.
- [x] Rerun the App Sandbox probe for `au.com.darkice.eyeoh`, including the explicitly opt-in state-restoring write check.
- [x] Verify the full sandbox capability set—App Sandbox, Camera, Bluetooth, and Network Client—and document an App Review demonstration for each used feature.
- [x] Perform a reversible real-device Bluetooth test: disconnect Onyx, confirm remembered Input/Output rows, reconnect from EyeOh, preserve the untouched output route, and restore the original input afterward.
- [x] Build and inspect a universal EyeOh Developer ID-signed release candidate: `arm64` + `x86_64`, Hardened Runtime, secure timestamp, signature and ZIP verified. Gatekeeper correctly reports it as unnotarized until the remaining submission step.
- [x] Freeze the public name as EyeOh, bundle ID as `au.com.darkice.eyeoh`, and executable as `EyeOh`.
- [x] Confirm the final EyeOh app icon and public domain.
- [ ] Rename or publish the repository under its final public EyeOh name.
- [ ] Deploy and validate the rate-limited `telemetry.eyeoh.app` PostHog gateway before enabling usage statistics in production.
- [ ] Add the final repository, support, and privacy URLs to release metadata and the website.
- [ ] Complete the provider-side and receipt checks in `TELEMETRY.md`; current source build has no provider credentials.
- [x] Configure and validate the `eyeoh` `notarytool` Keychain profile.
- [x] Receive explicit authorization and submit the release to Apple notarization.
- [x] Sign, notarize and staple the app and DMG; verify the DMG and mounted app with Gatekeeper; verify that published DMG/ZIP checksums match the release artifacts.
- [x] Deploy the website and publish the notarized DMG plus fallback ZIP at `eyeoh.app`.
- [ ] Smoke-test the downloaded DMG from a fresh macOS user account.
