# EyeOh release security

EyeOh uses a public-source, private-release model. The source, tests and documentation can be public; only Dark Ice produces the official signed and notarized EyeOh download.

## What the public repository contains

- EyeOh source and tests.
- Reproducible source builds with telemetry providers unavailable.
- A GitHub Actions validation workflow (push to `main` or `release/**`, pull requests, manual dispatch) with read-only repository permission, no secrets, and no published artifacts.
- No Apple signing material, notarization profile, provider administration credential, deployment credential or official release workflow.

Public users can inspect, fork and compile the MIT-licensed source. They cannot sign as Dark Ice, notarize as Dark Ice, publish to the official update/download channel, access provider dashboards, or create an upstream GitHub release without repository write access.

## What remains private

The following values belong only in the Dark Ice local secret store or a future protected release environment:

- Apple Developer ID certificates and private keys.
- Apple notarization credentials and Keychain profiles.
- The Sparkle EdDSA private key stored in Keychain under the dedicated EyeOh account.
- `SENTRY_AUTH_TOKEN`, `SENTRY_ORG` and `SENTRY_PROJECT`.
- PostHog personal or project-secret API keys.
- Cloudflare deployment/API credentials.

`POSTHOG_PROJECT_TOKEN` and `SENTRY_DSN` are client ingestion identifiers, not administrator credentials. They do not grant dashboard or account access, but a determined person can extract them from any distributed client and attempt to submit false events. Keeping them out of Git prevents casual pollution of source builds; it cannot make them secret after release.

## Official release boundary

Official releases are built on an authorised Dark Ice Mac using `Scripts/release_direct.sh`. Release values are loaded from `~/.darkiceconfig/aiconfig.env`, never printed, and never committed. The build must be Developer ID signed, notarized, stapled, and checked with Gatekeeper before publication. `make release` automates publication to Cloudflare Pages and GitHub from that Mac; obtain explicit approval for those external actions before running it. Building or rehearsing a release does not publish it.

For updater-enabled direct releases, the notarized ZIP is also signed with Sparkle's dedicated EyeOh EdDSA key and added to a generated appcast. `Scripts/prepare_appcast.sh` prepares these files locally; it never deploys them. Publish the immutable archive and delta files before the appcast so no client can discover an unavailable update. Mac App Store builds use `Scripts/build_mas_candidate.sh`, contain no Sparkle code, and update only through the App Store.

There is deliberately no GitHub Actions release workflow. `.github/workflows/ci.yml` runs on pushes to `main` or `release/**`, pull requests and manual dispatch, performs only source validation (Swift tests, release metadata, shellcheck, website build and download-counting Function compilation), receives no secrets, and publishes no artifact. Pull requests from forks run with a read-only token and no secrets.

## Repository settings before making it public

1. Keep collaborator write access limited to named Dark Ice maintainers with two-factor authentication.
2. Enable secret scanning and push protection.
3. Set the default `GITHUB_TOKEN` permission to read-only and prevent Actions from creating or approving pull requests.
4. Protect `main`: require a pull request, prevent force pushes/deletion, require conversation resolution, and do not allow bypass except for an explicit emergency owner path.
5. Require approval for every workflow proposed by an external fork, because the workflow now runs on pull requests.
6. Protect release tags such as `v*` with a tag ruleset restricted to Dark Ice maintainers.
7. Create GitHub releases manually from the locally notarized archive; never accept binaries supplied by contributors.

## Ingestion abuse controls

Private build infrastructure protects signing and administrative credentials, but it does not prove that every client event came from an untouched official binary. For the first release:

- give Sentry a dedicated client key with a conservative DSN rate limit and spike protection;
- accept only known release/environment values and use strict server-side data scrubbing;
- monitor quota anomalies and rotate the client key if polluted;
- do not enable PostHog ingestion until a small `telemetry.eyeoh.app` Cloudflare Worker gateway validates the exact six-event schema, enforces payload-size and rate limits, and keeps the PostHog project token in a Worker secret.

The gateway materially reduces casual abuse and prevents the PostHog token appearing in the app, but its public endpoint can still be imitated. Cryptographic proof of an official Apple-signed client would require an attestation design and is a later hardening feature, not something GitHub secrecy alone can provide.

## Cutting a release

All steps run on an authorised Dark Ice Mac. `make help` lists every target.

1. Add release notes under `## Unreleased` in `CHANGELOG.md`.
2. `make bump VERSION=x.y.z` (the build number increments automatically; pass `BUILD=n` to set it). This updates `version.env`, the website version string, `Website/package.json` and its lockfile, dates the changelog section, and runs `Scripts/check_release_metadata.sh`.
3. Commit the bump.
4. `make release DRY_RUN=1` rehearses the pipeline: checks, an optional signed (not notarized) build when `APP_IDENTITY` is set, and a list of the steps it skipped. It never notarizes, deploys, tags or publishes.
5. `APP_IDENTITY="Developer ID Application: ..." make release` runs `make check`, `Scripts/release_direct.sh --notarize` (uses `NOTARY_PROFILE`, default `eyeoh`), builds the site, verifies that the appcast's archive and the DMG are in `Website/dist`, deploys to Cloudflare Pages, commits the regenerated `appcast.xml`, tags `vx.y.z` and, when an `origin` remote exists, pushes the tag and runs `gh release create` with the DMG and ZIP. The release refuses to start on a dirty tree or an existing tag.
6. Push the appcast commit.

`make deploy-site` publishes `Website/dist` as one Cloudflare Pages deployment (project name read from `Website/wrangler.jsonc`), so the archive, DMG and appcast go live together. It reads `CLOUDFLARE_API_TOKEN` from `~/.darkiceconfig/aiconfig.env`, falling back to `CLOUDFLARE_ADMIN_API_TOKEN`, and optionally `CLOUDFLARE_ACCOUNT_ID`; it never prints them. If neither is set, wrangler uses its existing `wrangler login` session. `make mas` runs `Scripts/build_mas_candidate.sh --submission` and needs `MAS_APP_IDENTITY`, `MAS_INSTALLER_IDENTITY` and `MAS_PROVISIONING_PROFILE`.

The social card, favicons and Apple touch icon are generated by `Scripts/build_site_assets.sh` (needs `rsvg-convert`); rerun it if the mark or the main menu screenshot changes.

Wrangler must run from `Website/` when deploying. This includes `Website/functions/analytics/download.js` with the static files; running from the repository root would miss the download-counting Function. CI separately compiles that Function with a pinned Wrangler version.
