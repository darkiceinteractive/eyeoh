# EyeOh action plan and shared product handoff

**Purpose:** the durable starting point for any AI or human continuing EyeOh. It records decisions already made, ideas under investigation, non-negotiable boundaries, and the next work in order. Read this before proposing, implementing, packaging, or publishing anything.

**Last consolidated:** 18 August 2026 (Australia/Brisbane)  
**Repository:** `/Users/mattcrombie/Dev/Projects/MicBar`  
**Current public release:** EyeOh 0.4.0 (6), free direct download at `eyeoh.app`  
**Working rule:** current release artifacts, website, telemetry configuration, branding and release scripts are protected unless Matt explicitly authorises a release-scoped change.

## 1. Product in one sentence

EyeOh is a fast, private native macOS menu-bar utility for seeing and selecting the Mac's preferred microphone, speaker/output and camera—without becoming a mixer, recorder, meeting controller, media player, or general streaming server.

The product should feel immediate and confident: open the menu, understand the current route at a glance, make one selection or one volume adjustment, then get out of the way.

## 2. Product direction and decisions

### Confirmed direction

- Keep the core focused on **quick input, output and preferred-camera routing**.
- Prefer public Apple APIs and system capabilities. Do not use private APIs, scrape System Settings, or ship reverse-engineered AirPlay/Cast protocols.
- Bluetooth refinement is an approved direction. EyeOh may only reconnect a device already paired with macOS and previously seen as a Core Audio route; it must never scan for, pair, or auto-connect unknown devices.
- Output volume should be fast and prominent. Input gain is lower-frequency and must remain optional rather than cluttering the primary surface.
- Per-device input/output volume recall already exists and should remain quiet, automatic, local-only behaviour—not become a configuration project for the user.
- The menu-bar experience should feel current, tactile and polished rather than like a plain legacy NSMenu. A compact glass/material panel, clear selected-state treatment, soft cards and strong hierarchy are the design direction.
- EyeOh Core launches free in both Direct and Mac App Store editions. Do not make it a paid app merely to preserve a future IAP path.
- A subscription is not justified for local device switching or static feature unlocks. Only revisit subscriptions if there is an ongoing hosted service with real continuing cost/value (for example relay infrastructure, team fleet management, cloud configuration/history, or a maintained remote-device service).

### Explicit non-goals for the core utility

- Recording, saving, analysing or transmitting microphone/camera content.
- Audio mixing, effects, meters, conferencing automation or forcing apps to abandon an app-specific route/camera choice.
- A general-purpose AirPlay, Google Cast or Alexa implementation.
- Capturing and rebroadcasting arbitrary system audio under the guise of ordinary device switching.
- Companion software, drivers, helpers, extensions or accounts unless a separately approved remote-product scope requires them.

## 3. Current implemented baseline

### Core routes

- Core Audio lists eligible built-in, USB, Bluetooth and usable virtual input/output devices.
- EyeOh changes the default input, default output and the independently selected system-sound output using public Core Audio APIs, with rollback-aware handling where appropriate.
- It filters unsuitable/private endpoints such as Teams/Zoom routes rather than presenting misleading choices.
- It remembers volume per device, separately for input and output, only in local preferences.

### Bluetooth

- Previously seen paired Bluetooth audio routes can be shown as dimmed reconnect shortcuts when disconnected.
- Reconnection is strictly user-initiated through public IOBluetooth APIs.
- A real Onyx reconnect check has previously passed: reconnect the requested route, retain the untouched direction, and restore remembered volume after macOS publishes the device.
- Battery display is not part of the product. There is no reliable general public macOS headset-battery API. Do not add private-framework or System Settings scraping work.

### Camera

- EyeOh sets the user-preferred camera and offers an explicitly opened, local-only preview.
- It does not force apps that pin their own camera selection.
- Continuity Camera iPhones may appear through Apple’s existing feature; EyeOh does not need a phone app for that.

### Volume/UI work currently in the working tree

- The menu-bar extra has been moved from a nested standard menu to a compact material/glass panel.
- The selected **output** has a direct slider, percentage and device name at the top of the panel.
- A Settings → General → **Menu controls** toggle controls whether an **input** volume slider is also shown; it defaults off.
- The existing per-device recall continues in the storage/controller layer.
- The Swift test suite passed after this change. A real hardware write test remains intentionally opt-in and state-restoring.
- This is working-tree code only; it is not packaged, notarized, deployed, or merged by this document.

## 4. Three product classes—never conflate these

| Class | Meaning | Examples | EyeOh framing |
|---|---|---|---|
| **OS-supported output routing** | Select a destination macOS exposes as an output device. Changes system output when Core Audio permits it. | Built-in speakers, USB, paired Bluetooth, some system-exposed AirPlay routes. | Core product. |
| **App-owned media casting** | An app selects a route for media that *that app itself plays*. It does not turn the Mac’s system audio into that destination. | `AVRoutePickerView`, an AVPlayer route, Google Cast receiver fetching a media URL. | A different feature; do not call it ordinary device switching. |
| **Arbitrary system-audio capture and streaming** | Capture audio produced by other apps, encode, transport, synchronize and play it on a receiver. | Mac-to-Mac audio, a phone used as a receiver, custom TV/room audio. | Separate product-scale architecture and privacy project. |

## 5. Wireless and remote-audio feasibility direction

The formal feasibility report was begun as a read-only research track but needs a final, source-refreshed report before implementation. Treat current observations as time-specific, not a shipping guarantee.

| Destination / idea | Current assessment | Companion required? | Product decision / next gate |
|---|---|---:|---|
| Paired Bluetooth speakers and headphones | **Go.** Already the strongest, smallest extension when macOS exposes the route. | No | Refine selection, reconnect, route/profile changes, error wording and volume UX. |
| HomePod, Apple TV, AirPlay speakers | **Research / conditional go.** Use only system-exposed Core Audio routes or Apple’s UI. | No for Apple-supported receiver | Establish whether each target appears as a Core Audio output and whether setting default output is reliable. |
| `AVRoutePickerView` | **Research, not a system-route solution.** It is suitable for EyeOh-owned AV playback routes. | No | Prototype only to confirm UI/behaviour; do not present it as a global output switcher. |
| Desk iMac as AirPlay Receiver | **Controlled-test candidate.** Apple can provide this without an EyeOh companion on supported Macs. | No | Obtain Matt’s approval before enabling Receiver; test eligibility, same-network/Apple Account requirements, wake, discovery, reconnect and latency. |
| Google Home, Nest, Chromecast | **No-go for ordinary routing.** Official Cast senders target Android, iOS and Web; receivers load app-owned/reachable media. | Usually receiver app/web receiver, not EyeOh companion for standard Cast | Do not build an unofficial native macOS system-audio sender. Consider only as a future app-owned dashboard/media/receiver project. |
| Alexa / Echo | **No-go for generic casting.** Supported Alexa paths are cloud music/radio/podcast service integrations, not “send this Mac’s sound”. | No simple generic receiver path | Bluetooth is the only small EyeOh-compatible route. Do not build a speculative Alexa caster. |
| Mac-to-Mac arbitrary audio | **No-go for v1.x; possible v2 product.** | Yes, unless native AirPlay solves the exact case | Treat as capture/encode/transport/receiver architecture with explicit privacy and latency gates. |
| Phone as a speaker / remote receiver | **Promising v2 companion concept.** Wi-Fi is more credible than pretending a phone is a generic Bluetooth speaker. | Yes: EyeOh Receiver for iOS/Android | Research platform limits on Bluetooth sink mode; prototype only after choosing a secure LAN receiver architecture. |

### Wireless research requirements

Before any wireless feature is approved, refresh primary-source evidence from Apple Developer/Support, Google Cast and Amazon Alexa documentation, and inspect relevant installed macOS SDK headers. Device tests are read-only first.

Do **not** without Matt’s explicit approval:

- Enable AirPlay Receiver on another Mac.
- Switch his output route, begin capture, install software, or modify another machine.
- Use private APIs or reverse-engineered protocols.

Important constraints for any custom streaming proposal: latency and clock drift; A/V sync; Bluetooth profile changes; feedback loops; protected/DRM content; recording/screen-recording and local-network permissions; encryption/pairing; network discovery; sandbox and Mac App Store policy; power/wake behaviour; and safe receiver lifecycle.

## 6. Wider remote-display, camera and dashboard ideas

These are deliberate brainstorming candidates, not approved features.

### Use cases worth evaluating

1. Put an office dashboard on a TV or display with low interaction and tolerance for modest latency.
2. Broadcast a camera feed to a local display where low latency matters more.
3. Broadcast both dashboard/screen and camera.
4. Use a phone, tablet, Windows/Linux machine, TV or small connected box as a trusted EyeOh display/receiver.

### Product/technical choices

| Capability | Smallest credible path | Direction | Key dependency |
|---|---|---|---|
| Display a macOS screen on Apple hardware | Existing Apple screen-mirroring/AirPlay features | Use existing OS capabilities first | Hardware/support/network eligibility. |
| Static or slow dashboard to TV | Hosted/local web dashboard with a dedicated browser/TV app | Potentially high value; can tolerate buffered delivery | Receiver/browser/TV deployment and management. |
| EyeOh-owned dashboard to Chromecast/Google TV | Web Receiver / Android TV app rather than device-switching | Possible separate display product | A receiver app and a supported sender model. |
| Live camera to managed device | Custom companion receiver over local Wi-Fi, likely WebRTC or similar | V2 only | AVFoundation capture, camera consent, local-network permissions, encoder/receiver/security work. |
| Screen + camera with controls | Custom remote-session architecture | V2/V3 only | ScreenCaptureKit, capture consent, compositing, adaptive transport, receiver clients. |
| “Software only” room display | Receiver app on a supported endpoint | Plausible for managed hardware; not universal | Device platform, install path, discovery/pairing and fleet management. |

### Platform framing

- A simple Chromecast does not become a general native Mac application host. It receives content through Google’s receiver model; Google TV/Android TV can instead host a purpose-built app.
- A custom receiver on iOS, Android, Windows, Linux or a TV can broaden EyeOh, but it changes the product from a menu-bar utility into a multi-platform, networked system.
- Good Wi-Fi helps but does not remove the need for adaptive bitrate, connection recovery, device pairing, latency measurements, privacy controls and support tooling.
- Dashboard mode is the most commercially plausible early remote-display idea because it can accept more latency and permits a simpler product than live camera/system-audio streaming.

## 7. Distribution, updates and Mac App Store

### Current channel strategy

| Channel | State | Update mechanism | Constraint |
|---|---|---|---|
| Direct website download | Public 0.4.0 (6) release exists | Sparkle is prepared only for a future Direct build | 0.4.0 has no updater, so the first updater-enabled release requires a final manual download. |
| Mac App Store | Prepared local candidate path; not submitted | App Store only | Requires Dark Ice distribution/installer identities, exact provisioning, App Store Connect setup and review. |
| Setapp | Later possibility, not launch work | Setapp framework after acceptance | Separate bundle ID and commercial/technical obligations. |

### Non-negotiable channel boundary

- Sparkle 2.9.5 is **Direct-only** and is compiled out of MAS/source builds.
- Direct artifacts use isolated build locations (`build/direct` and channel-specific SwiftPM scratch paths). Never overwrite existing public release outputs.
- MAS builds must not contain Sparkle linkage, feed keys, updater URLs or Direct update settings.
- Mac App Store updates occur through the App Store. Do not add an external update mechanism or Dark Ice licence-key system to the MAS binary.
- Before publication, host the signed, versioned update archive first; verify it is reachable; publish the signed appcast last.

### Immediate release work (only with explicit release approval)

1. Keep 0.4.0 artifacts and production website unchanged while product work proceeds.
2. For the first Direct updater release, increment version/build; build universal; sign nested helpers; notarize/staple; generate signed appcast; test update/relaunch/security failure cases from an updater-enabled predecessor; deploy archive before feed.
3. For MAS, obtain the Dark Ice Apple Distribution and Mac Installer Distribution identities and an exact `au.com.darkice.eyeoh` provisioning profile.
4. Create App Store Connect record: macOS, Utilities, free, bundle ID `au.com.darkice.eyeoh`, suggested SKU `EYEOH-MAC-001`, EyeOh support/privacy URLs.
5. Validate the final signed sandboxed candidate, privacy manifest and App Review notes before upload. Do not submit until Matt authorises it.

### Website / download status

- The public DMG and ZIP were previously verified as downloadable, notarized/stapled and checksum-matched for 0.4.0.
- Website/download verification is time-sensitive. Re-run it immediately before claiming current availability or publishing a new release.
- Keep download analytics non-blocking: tracking failure must never stop the file download.

## 8. Monetization plan

### Decision now

- **Free EyeOh Core** in Direct and MAS.
- Do not introduce payment, account creation or a subscription in the free launch merely as a placeholder.

### First paid product, only after genuine value exists

- Preferred form: a permanent **EyeOh Pro** non-consumable purchase.
- Proposed MAS product ID: `au.com.darkice.eyeoh.pro`.
- Candidate Pro value: coherent advanced casting/remote-receiver functionality, trusted routing profiles, automation, or multi-device workflows—not an arbitrary paywall around basic mic/speaker/camera routing.
- A separate permanent **Advanced Casting** unlock is viable only if it is a complete, independently useful product.
- StoreKit 2 entitlement handling, Restore Purchases, sandbox testing and a submitted App Store version are prerequisites. The first non-consumable IAP is submitted with a new app version.

### Commercial guardrails

- MAS digital feature unlocks use Apple IAP. No external checkout/key field in the MAS app.
- MAS purchases do not automatically entitle Direct downloads. Do not solve that with an account/receipt-exchange system until there is a strong commercial reason.
- Consider a Direct licence only when a real commercial edition exists, and design channel/account/privacy/support implications first.
- A subscription becomes credible only for hosted relay, managed-team fleet, cloud configuration/history, or another ongoing service—not for basic local routes.

## 9. Design and UX principles

1. **One-glance state:** selected input, output and camera are unmistakable.
2. **Output first:** current output and its direct volume control are the fastest repeated task.
3. **Progressive disclosure:** input gain, disconnected Bluetooth history and advanced preferences belong behind settings/toggles, not on every opening.
4. **No fake certainty:** show only routes macOS has actually exposed; distinguish unavailable, connecting and selected states.
5. **Modern native material:** embrace macOS visual materials, rounded continuous shapes, restrained colour, selected-state clarity and accessible contrast; avoid decorative clutter.
6. **Small enough to be a menu-bar utility:** avoid turning the panel into a settings window or dashboard.
7. **Accessible by default:** labels must clearly identify device, route role and selection state; volume must remain keyboard/VoiceOver reachable.

## 10. Privacy, permissions and App Store policy baseline

- The current core does not capture mic audio, record camera frames, make accounts, or upload device names/hardware identifiers.
- Camera access is requested only for the explicitly opened preview. Bluetooth is used for the user-clicked reconnect path.
- Per-device volume presets remain local only.
- Statistics and crash reporting are separate, opt-in, and must remain accurately reflected in app privacy disclosures. An offline MAS build cannot claim “Data Not Collected” if configured telemetry/diagnostics are added later.
- Any remote companion or streaming feature requires a separate privacy design: clear intent, capture indicator, permission explanation, receiver identity/pairing, encryption, retention policy, and an explicit stop control.
- Screen/system-audio capture is not a harmless extension of route selection. It introduces additional permissions, content-protection/DRM constraints and significant review/support risk.

## 11. Current machine diagnostic context

There was a simultaneous “microphone stopped everywhere / ChatGPT voice failed” incident. Read-only checks at the time found audio devices still enumerated and Core Audio healthy. Internet later recovered; the Mac had an unusually crowded network stack, including concurrent Tailscale and WireGuard plus network filters. A transient tunnel/filter failure is plausible but not proven.

If this recurs, do not assume an EyeOh regression. First verify macOS Sound Input meter, selected device, local recording/Voice Memos behaviour, current VPN route, and service status before changing routes or restarting audio services.

## 12. Ordered roadmap and decision gates

### Now — stabilise the focused product (P0)

- [ ] Review the new glass-panel/volume interaction on the real Mac; refine sizing, scroll behaviour, VoiceOver and Slider feel based on use.
- [ ] Decide whether the new menu panel is the desired default experience or whether it needs a compact mode before release.
- [ ] Keep all current release work isolated; do not package/deploy merely because local tests pass.
- [ ] Establish source-control ownership/branching for the existing dirty working tree before mixing additional implementation work.

### Next — free core quality (P1)

- [ ] Bluetooth refinement acceptance suite: reconnect error/retry language, profile transition, preservation of other route, remembered volume, disconnected-row setting, accessibility.
- [ ] UI acceptance suite: common devices, long names, virtual devices, unavailable hardware volume, dark/light mode, small/large device lists, keyboard/VoiceOver.
- [ ] Fresh-user download/install smoke test for the published DMG when release work is authorised.
- [ ] Complete live telemetry gateway/provider/receipt checks only if telemetry will actually be enabled; retain offline-by-default otherwise.

### Parallel research — wireless routes (P1 research, no implementation yet)

- [ ] Finish the evidence-backed feasibility report from primary sources, with an explicit capability matrix and go/no-go outcome for Bluetooth, Apple route picker, AirPlay-to-Mac, Google Cast, Alexa and custom Mac-to-Mac streaming.
- [ ] Read-only inventory on the current Mac: record which paired Bluetooth/AirPlay routes appear in Core Audio and their transport/capabilities.
- [ ] With Matt’s approval, controlled desk-iMac AirPlay Receiver test: enable, discover, select, measure latency, test sleep/wake/reconnect, then restore prior settings.
- [ ] Prototype/verify `AVRoutePickerView` semantics: whether it controls only EyeOh-owned media or system-wide output. Do not ship before the distinction is documented in UI and support copy.
- [ ] Resolve phone-as-receiver platform constraints, especially whether iOS/Android can reliably behave as a Bluetooth audio sink. Prefer a trusted Wi-Fi receiver investigation.

### Distribution and MAS (P1, separately approved)

- [ ] Direct updater release readiness: test a signed end-to-end update path from an updater-enabled predecessor; first transition from 0.4.0 remains manual.
- [ ] Obtain missing Dark Ice MAS signing/provisioning identities and create the App Store Connect record.
- [ ] Build and test the final offline MAS candidate; verify no Sparkle or Direct-update residue.
- [ ] Create real screenshots/metadata from the submitted binary only; do not advertise Pro/casting before it exists.
- [ ] Upload/submit only after Matt’s explicit authorisation.

### V1.1 candidate — OS-supported wireless refinement (P2)

**Go only if research validates it:** stronger Bluetooth experience plus simple discovery/selection of wireless destinations that macOS already exposes as Core Audio output devices. This remains route selection—not custom casting or system-audio streaming.

### V2 candidate — trusted EyeOh Receiver (P3)

**Explore only after a product brief and pricing decision:** companion apps for iOS/Android, followed by selected Windows/Linux/TV platforms, for local dashboard display and possibly live camera/audio. Start with dashboard display; do not start with arbitrary system audio. Required design work includes LAN-only vs hosted relay, pairing/encryption, discovery, device management, support model, latency budget and App Store/Play policy.

### V3 candidate — managed remote presentation (P4)

Potential office/fleet product: dashboard playlists, TV/device management, remote camera/screen sessions and optional hosted relay. This is the first area where a subscription may be justified, if it pays for real operating infrastructure and support.

## 13. Verification rules for future agents

- Run `darkice-index --check` and read `.darkice/INDEX.md` plus applicable `AGENTS.md` before work.
- Inspect Git status first. This repository currently has a deliberately dirty release/updater/MAS working tree; preserve unrelated changes.
- Use `swift test` for deterministic checks. Do not run `EYEOH_RUN_HARDWARE_TESTS=1`, change a route, enable AirPlay Receiver, start capture, or alter a second machine without Matt’s explicit approval.
- Before any website/release claim, re-verify live artifacts and metadata. A local build, HTTP 200 or provider acceptance is not proof of full user delivery/availability.
- Before any new external integration, use current primary documentation. State assumptions as assumptions and label time-sensitive device findings.
- Never expose signing material, telemetry credentials, private keys or account data in logs, commits or handoffs.

## 14. Key project references

- `README.md` — current user/build overview.
- `ROADMAP.md` — initial wireless research scope and source links.
- `RELEASE_READINESS.md` — release/MAS/privacy/sandbox evidence and gates.
- `DISTRIBUTION_AND_MONETIZATION.md` — updater channel separation, MAS setup and commercial decisions.
- `Sources/EyeOh/AudioDeviceStore.swift` and `Sources/EyeOh/CoreAudioClient.swift` — core routing/volume behaviour.
- `Sources/EyeOh/EyeOhMenuView.swift` and `Sources/EyeOh/EyeOhSettingsView.swift` — current menu-panel/volume UX.
- `WORKLIST.md` — live-session fence; respect it when another agent is working.

## 15. Short decision summary

1. **Ship/maintain free, focused EyeOh Core.**
2. **Go on Bluetooth refinement and direct output volume UX.**
3. **Research Apple-supported AirPlay routes; do not promise system-wide routing from `AVRoutePickerView`.**
4. **Test the iMac only with explicit approval; no companion is needed if Apple AirPlay Receiver solves the exact route.**
5. **No-go for Google Cast/Alexa as generic Mac-system-audio switches.**
6. **Treat phone/TV/Windows/Linux receiving, camera broadcasting, dashboards and Mac-to-Mac system audio as separate companion/streaming products.**
7. **Free now; permanent Pro/IAP later when substantive features exist; no subscription absent ongoing hosted value.**
8. **Maintain clean Direct/MAS separation and do not disturb the public release without approval.**
