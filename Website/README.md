# EyeOh website

The site is deliberately dependency-free static HTML and CSS. Preview it locally with:

```bash
python3 -m http.server 8080 --directory Website
```

The download links expect a notarized release at `Website/downloads/EyeOh.zip`. The release script creates that file only after signing and notarization succeed. Do not deploy an ad-hoc signed development build as the public download.
