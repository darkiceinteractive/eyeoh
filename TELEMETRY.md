# EyeOh telemetry readiness

EyeOh 0.3.0 ships without network analytics or a third-party crash-reporting SDK. It records a deliberately small event vocabulary in macOS Unified Logging only:

- `input_changed`
- `app_launched`
- `output_changed`
- `camera_changed`
- `preview_opened`
- `feedback_opened`

These events never include audio-device or camera names, hardware identifiers, volume levels, audio, video, email content, or free text.

## Current readiness: 38/100 — broken for network collection

The product goal and event vocabulary exist, but no provider, consent flow, data owner, retention period, deletion process, staging validation, production credentials, or alerting path has been approved. Adding an SDK before those decisions would contradict the published privacy promise and would not create trustworthy analytics.

## Release gate for network diagnostics

Before enabling any external analytics or automatic crash submission:

1. Choose the provider and nominate a Dark Ice data owner.
2. Define the exact event schema and ban device names, IDs, audio, video and free text.
3. Make sharing opt-in and disabled by default for existing users.
4. Document retention, deletion, data location and processor terms.
5. Update the app and website privacy notices before collection begins.
6. Validate development, release and crash flows without using real customer data.
7. Verify provider receipt and symbolication, then record release evidence.

Until this gate is complete, feedback email and local Apple crash reports are the supported diagnostic path for the direct-download build.
