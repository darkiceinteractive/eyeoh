# EyeOh telemetry plan

EyeOh supports optional PostHog product statistics and Sentry crash reporting. Both controls are separate, off by default, and unavailable in source builds that have no release configuration.

Consent schema version 1 deliberately clears any saved values from the earlier placeholder-only settings. Offline/source builds also force unavailable choices off. A user therefore has to make a fresh choice in an official configured build before the first network event can be created.

## Measurement readiness: 82/100 — needs production validation

The instrumentation boundary, consent controls, EU-only configuration, event vocabulary, ownership and privacy notice are implemented and tested locally. Production project receipt, PostHog IP-discard configuration, Sentry IP scrubbing, symbol upload/symbolication and retention evidence are still required before the public build can truthfully ship with either provider configured.

Dark Ice Interactive owns the data and release configuration. Provider administration must use a named Dark Ice account with multi-factor authentication. Project tokens and DSNs are public ingestion identifiers rather than administrator credentials, but they are still injected only into official builds to limit casual event pollution. They cannot be made secret after distribution. PostHog personal API keys, project-secret API keys and Sentry auth tokens must never enter the app or repository. See `RELEASING.md`.

## Decision → event map

The goal is to learn whether EyeOh’s focused routes are being used and where the app is unstable—not to reconstruct behaviour.

| Decision | Event | Allowed properties |
|---|---|---|
| Is EyeOh being used after download? | `app_launched` | Common properties only |
| Are users switching microphones? | `input_changed` | Common properties only |
| Are users switching speakers? | `output_changed` | Common properties only |
| Is preferred-camera selection useful? | `camera_changed` | Common properties only |
| Is camera preview useful? | `preview_opened` | Common properties only |
| Are users seeking help? | `feedback_opened` | Common properties only |

Common properties are `schema_version`, `app_version`, `app_build`, `distribution`, `$process_person_profile=false`, `$geoip_disable=true`, and a random `distinct_id` generated for that installation. No event can accept arbitrary properties.

Explicitly prohibited: device and camera names, Core Audio or AVFoundation identifiers, volume values, audio, video, screenshots, window titles, URLs, email content, contact details, IP-derived location, advertising identifiers, cross-app identifiers, and free text.

There is no app-level purchase or signup conversion. The later website funnel should be measured separately as `download_started` → confirmed first `app_launched`, without joining website visitors to app installations.

## PostHog configuration

The current client can post the fixed events directly to PostHog’s batch ingestion endpoint with an ephemeral `URLSession`. It does not bundle the PostHog mobile SDK. Consequently there is no autocapture, session replay, screen capture, feature-flag loading, surveys, lifecycle capture, person-profile creation, cookie store, or offline event queue.

PostHog documents event capture as a public POST-only endpoint without request-level rate limiting. The production release must therefore route statistics through `telemetry.eyeoh.app`: a minimal Cloudflare Worker that holds the project token as a Worker secret, rebuilds only the allowlisted schema, rejects unknown events/properties and oversized requests, and rate-limits abuse. Until that gateway is deployed and validated, production builds must leave `POSTHOG_PROJECT_TOKEN` unset.

Official builds accept only `https://eu.i.posthog.com`. Before release, the project owner must:

1. enable “Discard client IP data” at project level;
2. verify GeoIP enrichment is disabled;
3. restrict project access to the minimum Dark Ice maintainers;
4. set or operationally enforce a maximum 12-month event-retention period;
5. validate each of the six events with a synthetic release build, then delete the test installation’s events.

Turning statistics off invalidates and cancels the analytics session immediately. Previously received events remain until retention expiry or a deletion request is completed.

## Sentry configuration

EyeOh includes Sentry Cocoa 9.25.0 under its MIT licence. Official builds accept only EU-region DSNs ending in `.ingest.de.sentry.io`. The SDK starts only while the crash-reporting preference is enabled.

Enabled: native crashes, watchdog terminations and app hangs. Disabled: default PII, performance tracing, automatic sessions, network/UI/system breadcrumbs, network and file instrumentation, logs, screenshots, attachments, memory introspection and analytics identifiers. The `beforeSend` hook removes user, request, breadcrumb and arbitrary-extra fields. Disabling reporting closes the SDK without a flush window and removes its local cache.

Before release, the project owner must enable Prevent Storing IP Addresses and default server-side data scrubbing, disable AI/Seer for the project, upload matching dSYMs, trigger one synthetic non-production test crash, verify symbolication and alert ownership, then remove the test issue.

## Packaging contract

`Scripts/package_app.sh` reads these environment variables without printing them:

- `POSTHOG_PROJECT_TOKEN`
- `POSTHOG_HOST` (must be `https://eu.i.posthog.com`)
- `SENTRY_DSN` (must be an EU-region DSN)
- `SENTRY_AUTH_TOKEN`, `SENTRY_ORG`, and `SENTRY_PROJECT` (release-time dSYM upload only; never embedded)
- `DISTRIBUTION_CHANNEL` (`direct`, `mas`, `setapp`, or `source`)

If no provider values are present, the packaged app reports that no service is connected and sends nothing. The public repository therefore remains runnable without a Dark Ice account.

## Release evidence still required

- [ ] PostHog EU project created; IP discard and access controls captured.
- [ ] `telemetry.eyeoh.app` gateway deployed with schema validation, payload limit, rate limiting and a Worker-held PostHog project token.
- [ ] Sentry EU project created; IP scrubbing, data scrubbing and AI-off state captured.
- [ ] Release environment values loaded from the Dark Ice secret store without appearing in logs.
- [ ] Each allowed PostHog event received with only the allowlisted properties.
- [ ] Opt-out confirmed to produce no network requests.
- [ ] Sentry synthetic crash received and symbolicated with no prohibited fields.
- [ ] Privacy page published at `https://eyeoh.app/privacy/` before the configured app ships.
- [ ] Data owner and quarterly deletion/retention review added to the release operations calendar.
