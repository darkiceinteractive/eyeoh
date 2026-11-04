# EyeOh statistics gateway

The gateway accepts only the six consented app events documented in `TELEMETRY.md`. It is separate from the website download-counting Function. No project token is embedded in the app.

Run the local checks from the repository root:

```sh
node --test TelemetryGateway/test/*.test.mjs
wrangler deploy --config TelemetryGateway/wrangler.jsonc --dry-run
```

The production account is the existing Dark Ice account in `Config/EyeOh-Deployment.json`. The endpoint is `https://eyeoh-telemetry.darkice.workers.dev/events`; no custom-domain or DNS change is needed. Deployment uses the existing Cloudflare credential and the account specified in the Worker configuration.

Two Worker secrets are required: `POSTHOG_PROJECT_TOKEN` for the dedicated EyeOh EU project and `RATE_LIMIT_SALT`, a cryptographically random private salt. Set them through Cloudflare's secret input, without echoing values or placing them in files tracked by Git. Administrator credentials and Sentry credentials never belong in the Worker. Missing secrets or rate-limiter bindings fail closed with HTTP 503.

The exact request consists of `event`, random UUID-v4 `distinct_id`, UUID-v4 `uuid`, and `properties` containing only `app_version`, `app_build`, and `distribution` (`direct` or `mas`). Unknown fields, events, malformed values and bodies over 2 KiB are rejected. Requests are limited to 30 per minute for each salted daily connecting-address hash at a Cloudflare location. These hashes serve short-lived abuse counters only; they are never sent to PostHog or written to application logs. The public endpoint can still be imitated, so reporting is an opt-in usage sample rather than proof of signed clients or installations.

The Worker rebuilds the EU PostHog batch with server timestamps, person profiles and GeoIP disabled, and a null IP property. It forwards no incoming cookies, authentication, address or user-agent headers. Worker invocation logging is disabled. Provider IP-discard settings, access, retention and live event receipt still need separate verification.

After deployment and project validation, official builds may set `EYEOH_STATISTICS_ENDPOINT` to the exact owned endpoint. Keep it unset until the production checks in `TELEMETRY.md` pass. Source builds always strip this configuration. Statistics and crash reporting remain separate choices, both off by default.
