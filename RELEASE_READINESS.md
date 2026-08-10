# EyeOh release readiness

Checked: 10 August 2026 (Australia/Brisbane)

## Recommendation

Release EyeOh as a free, Developer ID-signed and notarized direct download first. This route matches the product, keeps installation simple, and can use the static website in this repository. Mac App Store submission is plausible but needs a dedicated sandboxed Xcode distribution target and App Review. Setapp is a later commercial channel, not a free-download channel.

No external submission or publication has been performed.

## Mac App Store assessment

EyeOh's core behaviour is not prohibited by the current guidelines:

- It uses Apple's documented Core Audio device and default-input/default-output selectors.
- Camera discovery, preference, and preview use public AVFoundation APIs. Preview is user-initiated and frames are not recorded, stored, or transmitted.
- It is a self-contained menu-bar utility and does not install a driver, helper, kernel extension, or privileged component.
- It does not capture microphone audio, request microphone access, create an account, or make telemetry network requests. Camera access is requested only for an explicitly opened local preview. Non-identifying product events are written only to local macOS Unified Logging.
- Per-device volume presets are stored locally in app preferences and never uploaded.
- Its audio switching is substantial native utility rather than a repackaged website.

The gates are:

1. Mac App Store apps must be appropriately sandboxed under guideline 2.4.5(i).
2. The submission must be packaged using Xcode technology, be self-contained, and use App Store updates under 2.4.5(ii) and (vii).
3. The app must use public APIs under guideline 2.5.1. The Core Audio constants and AVFoundation camera preference used by EyeOh are publicly documented.
4. App Review still has discretion under minimum-functionality guideline 4.2; a focused utility is defensible, but approval cannot be guaranteed.
5. A Mac App Store bundle needs an App Store Connect record, Mac Distribution signing/provisioning, screenshots, metadata, support/privacy URLs, and the “Data Not Collected” privacy response.

Prepared locally:

- `Config/EyeOh-MAS.entitlements` enables App Sandbox and its public camera capability for preview.
- `Scripts/test_mas_sandbox.sh` compiles a probe that enumerates devices and validates the current defaults inside App Sandbox. With `EYEOH_PROBE_WRITES=1`, it performs a state-restoring write check and restores input, normal output, and the independently selected system-sound output before exiting.
- The normal test suite is deterministic and does not depend on or write to attached audio hardware.
- A real-device write check is available only with `EYEOH_RUN_HARDWARE_TESTS=1`; it snapshots and restores input, output, and the separate system-sound output.

Primary sources:

- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple default input device API](https://developer.apple.com/documentation/coreaudio/kaudiohardwarepropertydefaultinputdevice)
- [Apple default output device API](https://developer.apple.com/documentation/coreaudio/kaudiohardwarepropertydefaultoutputdevice)
- [Apple App Sandbox entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.app-sandbox)
- [Apple user-preferred camera API](https://developer.apple.com/documentation/avfoundation/avcapturedevice/userpreferredcamera)
- [Apple camera sandbox entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.device.camera)

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

Bluetooth battery is deliberately not part of the release candidate. macOS can show battery information for some accessories through privileged system components, but its public `IOBluetoothDevice` API does not provide a general headset-battery property. Core Bluetooth can read the standard Battery Service only when a peripheral exposes it; doing so requires a Bluetooth purpose string, explicit user permission, and the Bluetooth sandbox entitlement. The attached Onyx headset currently exposes no battery value through macOS's public Bluetooth inventory.

Do not use private Bluetooth frameworks or scrape System Settings. A future best-effort battery feature should be optional, use only public Core Bluetooth services, and display nothing when a device does not report a value.

Primary sources:

- [Apple IOBluetooth](https://developer.apple.com/documentation/iobluetooth)
- [Apple Core Bluetooth](https://developer.apple.com/documentation/corebluetooth/)
- [Bluetooth usage description](https://developer.apple.com/documentation/bundleresources/information-property-list/nsbluetoothalwaysusagedescription)
- [Bluetooth sandbox entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.device.bluetooth)

## Direct free-download assessment

This is the shortest release path. Apple requires a public direct-distribution build to be signed with a Developer ID Application certificate, use Hardened Runtime and a secure timestamp, and be notarized. The final ticket should be stapled before publishing the ZIP.

Current local state (machine-specific signing details intentionally omitted):

- EyeOh `0.3.0 (4)` is built as a universal `arm64` + `x86_64` app, signed with the Dark Ice Developer ID certificate, and archived at `dist/EyeOh-0.3.0.zip`. Signature verification passes; it remains intentionally unnotarized until submission is authorized.
- `Scripts/release_direct.sh` builds a universal Apple Silicon/Intel app, signs it with the `APP_IDENTITY` supplied by the maintainer, verifies it, and creates a ZIP.
- Passing `--notarize` submits through `notarytool`, staples and validates the ticket, verifies Gatekeeper acceptance, then creates `Website/downloads/EyeOh.zip`.
- Notary credentials have not been assumed or tested. Set `NOTARY_PROFILE` to an existing `notarytool` Keychain profile only when publication is authorized.

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
- [x] Preferred-camera selection and permission-aware local preview implemented with public AVFoundation APIs.
- [x] Default-device eligibility filtering and capability-aware input/output volume implemented with public Core Audio APIs.
- [x] Deterministic default tests plus an explicitly opt-in, state-restoring real-device integration test.
- [x] Menu-bar-only bundle and native accessible menu.
- [x] Static product website with an honest branded hero while the final EyeOh menu screenshot is pending.
- [x] MIT software license, separate Dark Ice trademark policy, and accurate privacy language.
- [x] Branded Help and About windows, feedback mail action, and a documented privacy gate for future network diagnostics.
- [x] Universal-build, Developer ID, Hardened Runtime, ZIP, and notarization scripts.
- [x] Rerun the App Sandbox probe for `au.com.darkice.eyeoh`, including the explicitly opt-in state-restoring write check.
- [x] Build and inspect a universal EyeOh Developer ID-signed release candidate: `arm64` + `x86_64`, Hardened Runtime, secure timestamp, signature and ZIP verified. Gatekeeper correctly reports it as unnotarized until the remaining submission step.
- [x] Freeze the public name as EyeOh, bundle ID as `au.com.darkice.eyeoh`, and executable as `EyeOh`.
- [ ] Confirm the final EyeOh app icon, public domain, and repository name.
- [ ] Add the final repository, support, and privacy URLs to release metadata and the website.
- [ ] Configure or identify a `notarytool` Keychain profile.
- [ ] Explicitly authorize notarization submission.
- [ ] Notarize, staple, verify Gatekeeper, and smoke-test the downloaded ZIP on a clean user account.
- [ ] Deploy the website and publish the notarized ZIP.
