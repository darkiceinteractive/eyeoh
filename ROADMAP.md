# EyeOh roadmap

This file records candidate work beyond the current release. It is not a promise of availability and must not expand the scope of a release candidate already in acceptance.

## Near-term candidate: wireless and remote audio destinations

**Status:** research only; explicitly excluded from EyeOh 0.3.0.

**Product intent:** keep EyeOh focused on quick route selection while exploring destinations that macOS does not present as ordinary local Core Audio outputs.

### Route classes

| Destination | Likely approach | Companion app | Initial assessment |
|---|---|---:|---|
| Paired Bluetooth speaker/headset | Existing Core Audio output enumeration and selection | No | Probably already covered when macOS exposes the device as a selectable output. Validate reconnect, profile changes, latency and remembered volume. |
| HomePod, Apple TV, AirPlay speaker | Apple `AVRoutePickerView` or a system-exposed AirPlay output | No | Strongest extension candidate. Prefer Apple's own route picker; do not implement or reverse-engineer AirPlay. Determine whether the chosen route can represent system audio or only media owned by EyeOh. |
| Another supported Mac, such as the desk iMac | Enable AirPlay Receiver on the destination Mac, then select it through Apple's route UI | No, for supported AirPlay-to-Mac hardware/software | Apple supports using a Mac as an AirPlay speaker/display. Validate the exact source/destination Macs, Apple Account/network requirements, wake behaviour and latency. |
| Chromecast, Google Home or Nest speaker | Google Cast Sender plus a receiver that fetches a media URL | Usually no destination companion, but a sender/receiver application model is required | Not equivalent to changing the Mac's default output. Google's supported sender SDKs target Android, iOS and Web, not a native macOS system-output switcher. Suitable for casting media EyeOh owns or can legally expose as a stream, not arbitrary app/system audio. |
| Alexa or Echo speaker | Bluetooth, or a cloud music/radio/podcast service integrated through Alexa Skills | No simple generic receiver app | There is no general supported “cast this Mac's sound” API. Alexa's official music path expects a catalog/cloud service and HTTPS streams. Bluetooth may be the only appropriately small EyeOh path. |
| Arbitrary sound from this Mac to another Mac/device | Capture system audio, encode/transport it, and render it on a trusted receiver | Yes, unless the destination already supports AirPlay | Separate product-scale work: permissions, latency, clock drift, discovery, encryption, pairing, feedback prevention, DRM, receiver lifecycle and likely a companion app. Not a route-switching feature. |

### Scope boundary

The preferred next increment is **discover and select OS-supported wireless routes**, not “turn EyeOh into an audio streaming server.” EyeOh should use public platform pickers and existing system receivers where possible. Any feature that captures or retransmits audio must be treated as a separate architecture, privacy and distribution project.

### Research gates

1. Test whether each paired Bluetooth and AirPlay target appears in Core Audio and whether setting it as the default output works reliably.
2. Prototype `AVRoutePickerView` on macOS and establish whether it changes system-wide output or only an EyeOh-owned playback route.
3. Enable AirPlay Receiver on the desk iMac and validate audio-only routing, discovery, wake/reconnect and latency without installing anything.
4. Confirm whether a supported native macOS Google Cast sender exists; do not ship an unofficial Cast protocol implementation.
5. Confirm that Alexa offers no generic sender route before limiting that target to Bluetooth or a future cloud media-service integration.
6. Produce a recommendation with three explicit buckets: `route only`, `media casting`, and `system-audio streaming`.

### Primary platform references

- [Apple AVRoutePickerView](https://developer.apple.com/documentation/avkit/avroutepickerview)
- [Apple: stream audio with AirPlay](https://support.apple.com/en-us/105068)
- [Apple: use a Mac as an AirPlay receiver](https://support.apple.com/guide/mac-help/mchld7e543a0/mac)
- [Google Cast overview](https://developers.google.com/cast/docs/overview)
- [Google Cast audio devices](https://developers.google.com/cast/docs/audio)
- [Amazon Music, Radio, and Podcast Skill API](https://developer.amazon.com/en-US/docs/alexa/music-skills/understand-the-music-skill-api.html)
