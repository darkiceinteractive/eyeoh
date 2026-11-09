# Changelog

All notable changes will be recorded here. The project follows semantic versioning once its first public release is published.

## Unreleased

## 0.5.1 - 2026-11-09

- Match selected device names to their lime checks in dark mode and show them in blue in light mode.
- Refresh the website with a clearer download, illustrated device scenarios, installation steps, and support links.
- Add a separate demo build with sample devices for testing Bluetooth reconnect and an unplugged preferred camera.

## 0.5.0 - 2026-10-30

### Added

- Mic Lock and device priority: rank your inputs and outputs and EyeOh keeps the highest ranked connected device active (off by default).
- Global Mute Microphone control in the menu, with a muted indicator in the menu bar. Mute only undoes its own changes.
- Optional global keyboard shortcuts (Settings > Shortcuts) to mute the mic, cycle input or output, and open the menu.
- Keep my camera selected: EyeOh restores your chosen camera after restart, wake, or when an iPhone camera appears. Apps with their own camera setting, such as Zoom and Teams, still override this.
- Menu warns when the active input is muted or at zero volume, with a one-click fix.

### Fixed

- Restore the compact native menu so input, output and camera devices stay visible. Keep Bluetooth reconnect, mute, volume presets, priority status and camera preferences available.
- Input going stale or silent after Bluetooth headsets connect or disconnect. EyeOh now follows stream changes and repairs a default input that has no usable stream.
- Reconnecting a Bluetooth device no longer restores outdated device IDs.
- The menu and menu bar icon now update straight away when another app or System Settings mutes the microphone.

## 0.4.1 - 2026-08-18

- Add Sparkle automatic updates to the direct-download edition, with signed update archives and an appcast published at eyeoh.app.
- Keep the Mac App Store candidate free of updater code and update keys, with a build check that rejects any Sparkle link.
- Add a sandboxed Mac App Store candidate build with its own entitlements and a no-collected-data privacy manifest.
- Add release tooling for universal Developer ID builds, notarization, DMG and ZIP packaging, and release metadata checks.
- Improve website accessibility and add responsive WebP screenshots.

## 0.4.0 - Bluetooth reconnect shortcuts

- Remember Bluetooth audio devices that have appeared as a Mac input or output and keep them visible when disconnected.
- Connect a remembered paired device from the Input or Output section, wait for its Core Audio route, select it, and restore its saved volume.
- Preserve the untouched audio direction when macOS activates both Bluetooth profiles during a reconnect.
- Request Bluetooth access only after an explicit reconnect action; EyeOh does not scan broadly, pair devices, or auto-connect at launch.
- Add local remembered-device controls, clear-history confirmation, Bluetooth Settings shortcut, public Bluetooth purpose string, and direct/MAS Bluetooth entitlements.

## 0.3.0 - First public EyeOh release

- Added a native Settings window with launch-at-login, opt-in reporting consent, device maintenance, Help and About tabs; reduced the menu to frequently used controls.
- Formalised the MIT Core and future proprietary Pro boundary, IP provenance record, contributor licence agreement and pull-request acceptance workflow.
- Shortened the menu-bar device indicator and removed redundant transport labels from menu rows.
- Added branded Help and About views plus pre-addressed feedback email.
- Added separate off-by-default PostHog EU usage statistics and Sentry EU crash reporting, with release-only configuration, strict event allowlisting, IP/privacy controls and source builds offline by default.
- Rebuilt the public site as an accessible Astro static build for Cloudflare Pages, with a responsive product illustration and complete privacy/support routes.
- Replaced the generic Dark Ice cube tile with EyeOh's own minimal input-pulse-output mark in the Dark Ice palette.
- Raised camera preview and Settings onto the active desktop when opened from the menu bar.
- Renamed the product, executable, bundle, archive, website, and public identifier to EyeOh.
- Added public AVFoundation preferred-camera selection for built-in, external, Desk View, and Continuity cameras.
- Added a permission-aware live camera preview that stops when its window closes and never records frames.
- Added camera sandbox entitlements, a clear usage description, deterministic store tests, and camera limitations to release documentation.
- Added a custom input-to-output routing symbol for the macOS menu bar.
- Filtered app-private virtual endpoints using Core Audio's default-device eligibility while retaining usable virtual audio drivers.
- Added capability-aware input/output volume controls with per-device remembered presets.
- Replaced periodic audio-device polling with Core Audio change notifications.
- Made hardware write verification explicitly opt-in and state-preserving.
- Prepared open-source contribution, security, licensing, and CI documentation.

## 0.2.0 - release candidate

- Added output-device switching alongside microphone switching.
- Added clearer Dark Ice blue and lime selected states.
- Added a native menu-bar app, static product page, direct-release tooling, and sandbox probe.
