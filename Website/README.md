# EyeOh website

The site is an Astro static build prepared for Cloudflare Pages. Preview it locally with:

```bash
cd Website
npm install
npm run dev
```

Build with `npm run build`; Cloudflare Pages should publish `Website/dist`. Once the notarized artifact exists at `Website/public/downloads/EyeOh.dmg`, the website links to it directly. `PUBLIC_DOWNLOAD_URL` remains available only as a deliberate build-time override. Set `PUBLIC_ZIP_DOWNLOAD_URL=/downloads/EyeOh.zip` when the fallback ZIP is present.

The DMG is the primary download and contains EyeOh plus an Applications shortcut for the standard drag-to-install flow. The ZIP is retained as a fallback. The release script creates both public downloads only after signing and notarization succeed. Do not deploy an ad-hoc signed development build.

The landing page uses authentic EyeOh captures from `public/assets/`, with WebP versions for delivery and PNG fallbacks. Re-capture product UI when visible behaviour changes; do not replace it with a mock that implies unavailable functionality. The header theme control stores only a local light/dark preference in the browser and sends nothing. The first-party download-intent counter is documented in `ANALYTICS.md` and is intentionally separate from app diagnostics.

The public privacy statement must describe the provider configuration in the shipping artifact. EyeOh 0.4.0 contains no PostHog token/host or Sentry DSN, so it sends no EyeOh analytics or crash reports even though consent-gated provider code exists in the source.
