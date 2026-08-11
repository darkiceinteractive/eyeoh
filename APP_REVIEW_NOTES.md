# EyeOh Mac App Review notes

EyeOh is a menu-bar utility for choosing macOS audio defaults, reconnecting a previously used paired Bluetooth audio device, and setting or previewing the user's preferred camera. It does not install a driver, record audio or video, pair devices, run a privileged helper, or use private frameworks.

## Requested capabilities

- **App Sandbox** — required for Mac App Store distribution.
- **Camera** (`com.apple.security.device.camera`) — used only after the reviewer chooses **Preview Preferred Camera…**. The local `AVCaptureSession` stops with the preview window and no frames are saved, analysed, or transmitted.
- **Bluetooth** (`com.apple.security.device.bluetooth`) — used only after the reviewer clicks a dimmed **Device Name · Connect** shortcut for a previously seen, paired Bluetooth audio route. EyeOh calls the public `IOBluetoothDevice.openConnection(_:)` API, waits for Core Audio to publish the route, selects only the requested input or output, and restores its local volume preset. It does not scan for arbitrary devices, pair anything, or connect automatically.
- **Outgoing network client** (`com.apple.security.network.client`) — reserved for the separately controlled usage-statistics and crash-reporting switches in Settings. Source and unconfigured builds keep both providers unavailable. Official configured builds send only the fixed, documented schemas over HTTPS; EyeOh has no account, advertising, tracking, or remote content.

EyeOh deliberately does **not** request an audio-input or microphone entitlement because it never captures microphone samples. Core Audio default-device selection does not require microphone recording access.

## Review steps

1. Launch EyeOh. It appears only in the menu bar.
2. Open the menu and choose a listed Input or Output. The green check and compact menu-bar label update.
3. To verify Bluetooth, first connect a paired Bluetooth headset in macOS so EyeOh sees its Core Audio route. Choose a different route, disconnect the headset, then reopen EyeOh. Click the dimmed headset row under Input or Output. EyeOh reconnects the already-paired device and changes only the section that was clicked.
4. Choose a Camera, then click **Preview Preferred Camera…**. Grant camera permission when macOS asks. Close the preview to stop the capture session.
5. Open **Settings…** to inspect launch-at-login, remembered Bluetooth shortcut controls, Help, About, feedback, privacy choices, and links to Sound/Bluetooth Settings.

If the reviewer has no paired Bluetooth audio device, the rest of the app remains fully usable and the Bluetooth path can be inspected from Settings and the purpose string. EyeOh never attempts a connection at launch.

## Public API and privacy references

- Core Audio default selectors: `kAudioHardwarePropertyDefaultInputDevice`, `kAudioHardwarePropertyDefaultOutputDevice`, and `kAudioHardwarePropertyDefaultSystemOutputDevice`.
- Bluetooth: `IOBluetoothDevice.openConnection(_:)` with its documented completion callback.
- Camera: `AVCaptureDevice.userPreferredCamera` and a user-opened `AVCaptureSession`/`AVCaptureVideoPreviewLayer`.
- Local state: `UserDefaults` stores volume presets, remembered routes, and user choices on the Mac.
- The bundled privacy manifest and <https://eyeoh.app/privacy/> describe optional diagnostics and required-reason APIs.
