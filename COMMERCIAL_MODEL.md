# EyeOh licensing and commercial model

## Current edition: EyeOh Core

Everything in this public repository is EyeOh Core and is licensed under the MIT License unless a file explicitly says otherwise. The public receives the permanent permissions stated in that licence, including commercial use, modification, redistribution and sale, subject to retaining its copyright and permission notice.

The EyeOh and Dark Ice names, logos, app icons, screenshots and product artwork are not licensed under MIT. Their use is governed by `TRADEMARKS.md`.

## Official free build

Dark Ice Interactive Pty Ltd may provide a signed, notarized and maintained build of EyeOh Core at no charge. Official distribution, updates, documentation and support are separate from the public's right to compile or fork the source.

## Future commercial editions

Dark Ice may introduce a paid EyeOh Pro, Setapp edition, business edition, support plan, or other commercial offering. A commercial edition may combine:

- EyeOh Core under MIT, with the required notices preserved.
- New Dark Ice proprietary modules distributed under commercial terms.
- Third-party components under their respective licences.
- Hosted services, updates, support or distribution benefits.

Potential Pro capabilities must remain meaningfully separate from the focused free switcher. Candidate areas include automation rules, reusable device profiles, advanced shortcuts, managed team configuration, remote-device companions and supported integrations. No Pro capability is promised by this document.

## Source boundary

The recommended technical structure is:

- `EyeOhCore`: public MIT code and tests.
- `EyeOhApp`: the official free application target built from EyeOh Core.
- `EyeOhPro`: private commercial modules in a separate private repository or access-controlled package.
- Channel-specific packaging: separate App Store, direct-download and Setapp configurations where required.

Pro source, licence checks, payment credentials and private services must not be committed to the public repository. The public core should not contain deliberately disabled paywalled code.

## What open source permits

Third parties may use, modify, rebrand and sell forks of the MIT code if they comply with its notice requirement. They may not use protected EyeOh or Dark Ice branding in a way that implies an official build or endorsement.

Dark Ice cannot withdraw the MIT rights already granted for a published version. Dark Ice can choose a different licence for code it solely owns in future versions and can keep newly created Pro modules proprietary.

## Contributions

External contributions require acceptance of `CONTRIBUTOR_LICENSE_AGREEMENT.md`. Contributors retain copyright while granting Dark Ice enough non-exclusive rights to use their contribution in open-source and commercial editions. This policy should be reviewed by an Australian IP lawyer before the repository begins accepting material external contributions.
