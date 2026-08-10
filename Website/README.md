# EyeOh website

The site is an Astro static build prepared for Cloudflare Pages. Preview it locally with:

```bash
cd Website
npm install
npm run dev
```

Build with `npm run build`; Cloudflare Pages should publish `Website/dist`. Set `PUBLIC_DOWNLOAD_URL=/downloads/EyeOh.zip` only after a notarized release has been copied to `Website/public/downloads/EyeOh.zip`. Without that variable the site truthfully shows a coming-soon state.

The release script creates the public download only after signing and notarization succeed. Do not deploy an ad-hoc signed development build.
