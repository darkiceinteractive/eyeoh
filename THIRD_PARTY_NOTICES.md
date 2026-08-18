# Third-party notices

EyeOh includes the following open-source components in official builds:

## Sparkle

- Project: <https://github.com/sparkle-project/Sparkle>
- Version: 2.9.5
- Licence: MIT, with bundled third-party notices

Sparkle is included only in the direct-download edition. Its complete licence and required third-party notices are bundled as `Sparkle-LICENSE.txt` in that application. The Mac App Store edition does not link or embed Sparkle.

## Sentry Cocoa

- Project: <https://github.com/getsentry/sentry-cocoa>
- Version: 9.25.0
- Licence: MIT
- Copyright © 2015 Sentry and contributors

EyeOh’s use of Sentry is optional at runtime and controlled by the separate crash-reporting preference.

> MIT License
>
> Copyright © 2015 Sentry and contributors
>
> Permission is hereby granted, free of charge, to any person obtaining a copy
> of this software and associated documentation files (the “Software”), to deal
> in the Software without restriction, including without limitation the rights
> to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
> copies of the Software, and to permit persons to whom the Software is
> furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all
> copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
> IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
> FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
> AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
> LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
> OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
> SOFTWARE.

EyeOh sends optional fixed-schema product events to the PostHog service through first-party networking code; it does not include the PostHog SDK in the distributed binary.
