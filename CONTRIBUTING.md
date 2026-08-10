# Contributing

Thanks for helping improve this small macOS utility.

## Contributor agreement

Bug reports, feature discussions and testing feedback are welcome without a contributor agreement. Code, documentation, design or other material intended for inclusion in the repository can be merged only after the contributor accepts `CONTRIBUTOR_LICENSE_AGREEMENT.md`.

For a pull request to be eligible for review, the contributor must:

1. Read the current contributor licence agreement.
2. Add their own entry to `CLA-SIGNATURES.md` in the pull request.
3. Affirm the agreement in the pull-request checklist.

The contributor keeps ownership of their work. The agreement gives Dark Ice a broad, non-exclusive licence so contributions can remain in the MIT project and also be used in supported or commercial EyeOh editions. A maintainer must verify that the pull-request author matches the signature entry before merging.

## Development

1. Use macOS 14 or later with Swift 6.2 or newer.
2. Create a focused branch and keep unrelated changes out of the patch.
3. Run `swift test` and `shellcheck Scripts/*.sh run-menubar.sh stop-menubar.sh`.
4. If you intentionally need the real-device write test, run `EYEOH_RUN_HARDWARE_TESTS=1 swift test`. It changes and restores the current Core Audio defaults; do not run it in shared or unattended environments.
5. Describe the behaviour change and manual verification in the pull request.

The ordinary test suite must remain deterministic and must not change audio hardware state or depend on particular devices being attached.

## Scope

The product is intentionally focused on quickly switching macOS input and output defaults and choosing a preferred camera. Proposed features should preserve that narrow purpose, low background resource use, and no-recording/no-tracking privacy model. Mixing, effects, recording, live audio meters, advanced camera controls, remote-camera transport, and meeting-app automation are out of scope for v1.

## Branding

Source contributions are MIT-licensed. The official product name and Dark Ice artwork are protected separately; see `TRADEMARKS.md`. Forks intended for distribution must use their own name and artwork.
