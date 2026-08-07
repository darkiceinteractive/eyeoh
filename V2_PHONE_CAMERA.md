# EyeOh v2 concept: EyeOh Link

This is an exploratory product track, not part of the v1 release. EyeOh v1 remains a focused menu-bar switcher for local audio devices, local cameras, and Apple's native iPhone Continuity Camera.

## Product idea

EyeOh Link would make a phone or another Mac available as one stable camera source on the receiving Mac:

```text
Camera
✓ MacBook Pro Camera — Built-in
  AIRHUG 11 — External
  Matt's Pixel — EyeOh Link
  Use a phone as camera…
```

Choosing **Use a phone as camera…** would show a QR code and short fallback code. The phone would pair on the local network, show its own live preview, and offer only Flip Camera, Torch when supported, and Stop. EyeOh would reuse its existing Mac preview.

## Recommended architecture

1. A native iOS or Android companion captures video while visibly active.
2. The devices pair with a short-lived QR token and remember a device-scoped key.
3. Media travels over an encrypted, low-latency WebRTC connection, initially restricted to the local network.
4. EyeOh publishes one stable **EyeOh Link Camera** through Apple's Core Media I/O camera-extension API.
5. The menu chooses which paired phone or Mac feeds that virtual camera.

Receiving and previewing a stream is not enough: Zoom, Teams, Meet, FaceTime, and other apps need a camera device. The Core Media I/O extension is therefore the key Mac-side component.

## Suggested staged work

- Technical spike: publish generated frames through an EyeOh camera extension.
- Receiver spike: feed a local test stream into the extension and verify FaceTime, Zoom, Teams, browser Meet, and QuickTime.
- Pairing alpha: QR-launched browser sender to test latency and pairing across iPhone and Android without building mobile apps first.
- Production: native iOS and Android companions using the same signaling and media contract.
- Later: an EyeOh sender for another Mac or iMac using the same protocol.

## Why native companions eventually

A browser sender is an excellent prototype, but mobile browser suspension, screen locking, permission differences, HTTPS requirements, and reconnection make it less dependable. Native companions provide better camera selection, orientation, thermal handling, battery reporting, and recovery while keeping the visible UI minimal.

## Guardrails

- Video only initially; no phone microphone or virtual audio.
- No recording, filters, backgrounds, cloud library, timeline, multi-camera composition, or remote control surface.
- No account or internet relay in the first Link release.
- QR tokens expire quickly and never contain permanent credentials.
- Privacy copy must remain precise: local live frames are not recorded or uploaded. Revisit that promise before introducing any TURN or cloud relay.
- EyeOh Link must not delay or complicate v1.

## Principal risks

- Camera-extension installation and first-use onboarding.
- Some meeting apps cache camera devices and may require a restart after extension activation.
- Wi-Fi loss, frame pacing, latency, phone heat and battery use.
- Codec and orientation differences across Android hardware.
- Local-network permission and secure discovery/pairing.

## Primary references

- [Apple Continuity Camera requirements](https://support.apple.com/en-gb/102546)
- [Apple Core Media I/O camera extensions](https://developer.apple.com/documentation/coremediaio/creating-a-camera-extension-with-core-media-i-o)
- [Apple local-network privacy](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy)
- [Android CameraX architecture](https://developer.android.com/media/camera/camerax/architecture)
- [Android network-service discovery](https://developer.android.com/develop/connectivity/wifi/use-nsd)
- [WebRTC project](https://webrtc.org/)
- [W3C Media Capture and Streams](https://www.w3.org/TR/mediacapture-streams/)
