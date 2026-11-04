# EyeOh website analytics

## Measurement readiness

**70/100 — Usable with Gaps.** The implementation provides a rough download-interest signal. Provider metrics are sampled, have limited retention and do not distinguish successful button POSTs from other Function invocations. There is no reliable lifetime download or installation total.

| Category | Score | Notes |
| --- | ---: | --- |
| Decision alignment | 25/25 | Measures demand for the public release. |
| Event model clarity | 20/20 | One server-side event with fixed fields. |
| Data accuracy and integrity | 8/20 | Sampled Function invocations include repeated requests, tests and possible non-POST traffic. |
| Conversion definition | 5/15 | A request cannot prove a completed transfer, installation or first launch. |
| Attribution and context | 2/10 | Attribution is intentionally excluded to minimise collection; internal testing is not separated. |
| Governance and maintenance | 10/10 | Schema, ownership, retention, validation and privacy wording are documented. |

## Tracking plan

| Event | Description | Properties | Trigger | Decision supported |
| --- | --- | --- | --- | --- |
| `download_clicked` | A website download button sent an empty first-party request immediately before normal navigation to the DMG. | No payload or event properties. The endpoint itself defines the signal. | `POST /analytics/download` | Are visitors expressing download intent? |

## Conversion

| Conversion | Event | Counting | Used by |
| --- | --- | --- | --- |
| None yet | `download_clicked` is an intent signal, not a conversion | Treat Function invocations as a sampled estimate, including possible automation and tests. | Product and release review |

The browser sends an empty POST to `/analytics/download`. That route is the only Pages Function in the project. Cloudflare’s aggregate Function request count estimates invocations of that route, but cannot isolate successful button POSTs. EyeOh does not write an IP address, cookie, visitor or device identifier, user agent, referrer, query parameters, or free text. Cloudflare retains Pages Functions metrics for up to three months. Domain request analytics provide a separate sampled view of DMG and ZIP GET responses, with a 31-day lookback on the current plan. Neither dataset provides a lifetime download count.

Measurement is fail-open: the anchor always links directly to the DMG, so blocked JavaScript or an unavailable metrics endpoint cannot prevent the download. If more Pages Functions are added later, this project-level count must be replaced with a route-specific store before it is treated as decision-grade. The public privacy statement must be updated before this endpoint or provider changes.
