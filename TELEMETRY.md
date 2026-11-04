# EyeOh telemetry plan

EyeOh supports optional PostHog product statistics and Sentry crash reporting. Both controls are separate, off by default, and unavailable in source builds that have no release configuration.

Consent schema version 1 deliberately clears any saved values from the earlier placeholder-only settings. Offline/source builds also force unavailable choices off. A user therefore has to make a fresh choice in an official configured build before the first network event can be created.

## Measurement readiness: 55/100, awaiting provider access and production validation

The consent boundary, owned gateway, EU-only forwarding and event vocabulary have local regression coverage. This is a readiness assessment, not a usage metric: decision alignment 25/25, event model 20/20, data integrity 4/20, conversion 4/15, attribution 0/10 and operational governance 2/10. Provider access, actual receipt, IP-discard settings, symbolication and retention checks remain incomplete. EyeOh 0.5.0 build 8 contains no provider configuration and sends no app diagnostics.

Dark Ice Interactive owns the data and release configuration. Provider administration must use a named Dark Ice account with multi-factor authentication. The Sentry DSN is a public ingestion identifier injected only into configured official builds. The PostHog project token stays in the gateway secret store and never enters the app. Neither identifier grants administrative access. PostHog personal API keys, project-secret API keys and Sentry auth tokens must never enter the app or repository. See `RELEASING.md`.

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

There is no app-level purchase or signup conversion. The website separately counts aggregate `download_clicked` intent through an empty first-party POST to a dedicated Cloudflare Pages Function. It does not identify the visitor or join a website click to an app installation. A future configured app may provide a separate aggregate `app_launched` count, but the two datasets must not be linked or presented as proof that a particular download installed successfully.

## PostHog configuration

The client posts fixed events to the owned gateway at `https://eyeoh-telemetry.darkice.workers.dev/events` using an ephemeral, cookie-free `URLSession`. It does not bundle the PostHog mobile SDK. Consequently there is no autocapture, session replay, screen capture, feature-flag loading, surveys, lifecycle capture, person-profile creation, cookie store, or offline event queue.

PostHog documents event capture as a public POST-only endpoint without request-level rate limiting. The gateway in `TelemetryGateway/` holds the project token as a Worker secret, rebuilds only the allowlisted schema, rejects unknown fields and requests over 2 KiB, and limits callers to 30 requests per minute per Cloudflare location. It hashes the connecting IP with a private salt and daily rotation only for short-lived abuse counters; raw IPs and these keys never enter the forwarded event. It forwards no client headers, disables Worker invocation logs and adds `$ip=null`, `$geoip_disable=true` and `$process_person_profile=false`. The existing Workers subdomain avoids a production DNS change. Until gateway deployment and provider receipt are validated, release builds must leave `EYEOH_STATISTICS_ENDPOINT` unset. See `TelemetryGateway/README.md`.

The client accepts only the exact owned gateway URL. Only the gateway contacts `https://eu.i.posthog.com`. Before release, the project owner must:

1. enable “Discard client IP data” at project level;
2. verify GeoIP enrichment is disabled;
3. restrict project access to the minimum Dark Ice maintainers;
4. set or operationally enforce a maximum 12-month event-retention period;
5. validate each of the six events with a synthetic release build, then delete the test installation’s events.

Turning statistics off invalidates and cancels the analytics session immediately. Previously received events remain until retention expiry or a deletion request is completed.

## Sentry configuration

EyeOh includes Sentry Cocoa 9.25.0 under its MIT licence. Official builds accept only EU-region DSNs ending in `.ingest.de.sentry.io`. The SDK starts only while the crash-reporting preference is enabled.

Enabled: native crashes, watchdog terminations and app hangs. Disabled: default PII, performance tracing, automatic sessions, network/UI/system breadcrumbs, network and file instrumentation, logs, screenshots, attachments, memory introspection and analytics identifiers. The `beforeSend` hook removes user, request, breadcrumb and arbitrary-extra fields. Disabling reporting closes the SDK without a flush window and removes its local cache.

Before release, the project owner must enable Prevent Storing IP Addresses and default server-side data scrubbing, disable automated issue analysis for the project, upload matching dSYMs, trigger one synthetic non-production test crash, verify symbolication and alert ownership, then remove the test issue.

## Packaging contract

`Scripts/package_app.sh` reads these environment variables without printing them:

- `EYEOH_STATISTICS_ENDPOINT` (the exact owned gateway URL, after live validation)
- `SENTRY_DSN` (must be an EU-region DSN)
- `SENTRY_AUTH_TOKEN`, `SENTRY_ORG`, and `SENTRY_PROJECT` (release-time dSYM upload only; never embedded)
- `DISTRIBUTION_CHANNEL` (`direct`, `mas`, or `source`)

Source packages strip provider configuration even if release variables are inherited. If no provider values are present, the packaged app reports that no service is connected and sends nothing. The public repository therefore remains runnable without a Dark Ice account.

## Release evidence still required

- [ ] PostHog EU project created; IP discard and access controls captured.
- [ ] `eyeoh-telemetry.darkice.workers.dev` gateway deployed with schema validation, payload limit, rate limiting and a Worker-held PostHog project token.
- [ ] Sentry EU project created; IP scrubbing, data scrubbing and automated-analysis-disabled state captured.
- [ ] Release environment values loaded from the Dark Ice secret store without appearing in logs.
- [ ] Each allowed PostHog event received with only the allowlisted properties.
- [ ] Opt-out confirmed to produce no network requests.
- [ ] Sentry synthetic crash received and symbolicated with no prohibited fields.
- [ ] Privacy page published at `https://eyeoh.app/privacy/` before the configured app ships.
- [ ] Data owner and quarterly deletion/retention review added to the release operations calendar.
