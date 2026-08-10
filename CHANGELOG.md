# Changelog

All notable changes will be recorded here. The project follows semantic versioning once its first public release is published.

## Unreleased

- Added a native Settings window with launch-at-login, opt-in reporting consent, device maintenance, Help and About tabs; reduced the menu to frequently used controls.
- Formalised the MIT Core and future proprietary Pro boundary, IP provenance record, contributor licence agreement and pull-request acceptance workflow.
- Shortened the menu-bar device indicator and removed redundant transport labels from menu rows.
- Added branded Help and About views plus pre-addressed feedback email.
- Added a privacy-safe local diagnostics vocabulary and documented the gate for future opt-in network telemetry.
- Raised camera preview and Settings onto the active desktop when opened from the menu bar.

## 0.3.0 — EyeOh release candidate

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

## 0.2.0 — release candidate

- Added output-device switching alongside microphone switching.
- Added clearer Dark Ice blue and lime selected states.
- Added a native menu-bar app, static product page, direct-release tooling, and sandbox probe.
