# EyeOh website

The site is an Astro static build prepared for Cloudflare Pages. Preview it locally with:

```bash
cd Website
npm install
npm run dev
```

Build with `npm run build`; Cloudflare Pages should publish `Website/dist`. Set `PUBLIC_DOWNLOAD_URL=/downloads/EyeOh.dmg` and `PUBLIC_ZIP_DOWNLOAD_URL=/downloads/EyeOh.zip` only after the notarized artifacts have been copied into `Website/public/downloads/`. Without those variables the site truthfully shows a coming-soon state.

The DMG is the primary download and contains EyeOh plus an Applications shortcut for the standard drag-to-install flow. The ZIP is retained as a fallback. The release script creates both public downloads only after signing and notarization succeed. Do not deploy an ad-hoc signed development build.
