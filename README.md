# EyeOh

EyeOh is a tiny, native macOS menu-bar utility for changing the system's default microphone and speakers, choosing a preferred camera, and checking the camera framing without opening System Settings.

EyeOh is a free Dark Ice utility. Its app mark and colour system use the canonical geometry and current live `darkice.au` anchors: Ice Blue `#008BB4`, Lime `#A0CE4E`, and Charcoal `#323643`.

## What EyeOh does

- Lists input devices Core Audio says can be a system default, including USB, Bluetooth, built-in, and usable virtual drivers such as BlackHole or Loopback while excluding private Teams/Zoom endpoints.
- Lists output devices and switches both the default app output and macOS system-sound output.
- Shows software volume for capable selected devices and remembers separate input/output presets by device.
- Lists built-in, external, Desk View, and available iPhone Continuity cameras.
- Sets macOS's public user-preferred camera and provides an explicitly opened live preview that is never recorded.
- Marks the current system defaults and switches either one with a click.
- Refreshes audio devices automatically when they connect, disconnect, or change elsewhere; cameras refresh whenever the menu opens or you choose Refresh.
- Opens Sound Settings for input volume and other advanced controls.
- Runs menu-bar only, with no Dock icon.

EyeOh changes the macOS **system default input**. An app such as Teams or Zoom can be configured to use a specific device instead of the system default; in that case, change the app's own microphone setting back to “Default” for it to follow EyeOh.

Camera selection sets macOS's **user-preferred camera**. Apps that follow Apple's system camera preference can adopt it; an app with its own pinned camera can still override it. Camera permission is requested only when you open the preview window. An eligible nearby iPhone appears automatically through Continuity Camera and does not require a separate EyeOh phone app.

## Build and run

Requires macOS 14 or later and Swift 6.2 or newer. The current release candidate is tested with Xcode 26.6 and Swift 6.3.3.

```bash
./run-menubar.sh --test
```

The default test suite is deterministic and does not change the Mac's audio settings. Maintainers can explicitly run the real-device write check with:

```bash
EYEOH_RUN_HARDWARE_TESTS=1 swift test
```

The ad-hoc signed app bundle is created at `build/EyeOh.app` and launched automatically. Stop it with:

```bash
./stop-menubar.sh
```

## Release preparation

See `RELEASE_READINESS.md` for the current Mac App Store, Setapp, and free direct-download assessment. To create a universal Developer ID-signed release candidate without submitting it for notarization:

```bash
APP_IDENTITY="Developer ID Application: Your Company (TEAMID)" ./Scripts/release_direct.sh
```

The public website lives in `Website/`. Its download is populated only after an explicitly authorized notarization run succeeds.

## Contributing

See `CONTRIBUTING.md` for the development workflow and `SECURITY.md` for responsible vulnerability reporting. The code is MIT-licensed. Official Dark Ice names and artwork are covered separately by `TRADEMARKS.md`.

## Scope guardrails

This utility has one job: make the Mac's preferred audio and video inputs and audio output quick to see and switch. Favourites, optional shortcuts, and launch at login may make that job faster without changing it. Mixing, effects, recording, live audio meters, camera controls, and meeting-app automation are deliberately out of scope.
