# EyeOh website analytics

## Measurement readiness

**84/100 — Usable with Gaps.** The implementation answers one decision: whether visitors are expressing intent by clicking the public download. It deliberately does not attempt behavioural analytics, user attribution, completed-install measurement, or cross-device identity.

| Category | Score | Notes |
| --- | ---: | --- |
| Decision alignment | 25/25 | Measures demand for the public release. |
| Event model clarity | 20/20 | One server-side event with fixed fields. |
| Data accuracy and integrity | 16/20 | First-party browser requests are reliable, but automation and repeated clicks may still count. |
| Conversion definition | 9/15 | A click is an intent signal, not a completed transfer, installation, or first launch. |
| Attribution and context | 4/10 | Attribution is intentionally excluded to minimise collection. |
| Governance and maintenance | 10/10 | Schema, ownership, retention, validation and privacy wording are documented. |

## Tracking plan

| Event | Description | Properties | Trigger | Decision supported |
| --- | --- | --- | --- | --- |
| `download_clicked` | A website download button sent an empty first-party request immediately before normal navigation to the DMG. | No payload or event properties. The endpoint itself defines the signal. | `POST /analytics/download` | Are visitors expressing download intent? |

## Conversion

| Conversion | Event | Counting | Used by |
| --- | --- | --- | --- |
| None yet | `download_clicked` is an intent signal, not a conversion | Count successful Function requests; expect some automation/repeat inflation. | Product and release review |

The browser sends an empty POST to `/analytics/download`. That route is the only Pages Function in the project, so Cloudflare’s aggregate Function request count is the download-intent count. EyeOh does not write an IP address, cookie, visitor or device identifier, user agent, referrer, query parameters, or free text. Cloudflare retains Pages Functions metrics for up to three months.

Measurement is fail-open: the anchor always links directly to the DMG, so blocked JavaScript or an unavailable metrics endpoint cannot prevent the download. If more Pages Functions are added later, this project-level count must be replaced with a route-specific store before it is treated as decision-grade. The public privacy statement must be updated before this endpoint or provider changes.
