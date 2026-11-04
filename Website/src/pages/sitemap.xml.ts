import type { APIRoute } from 'astro';
import { execFileSync } from 'node:child_process';
import changelog from '../../../CHANGELOG.md?raw';

const SITE = 'https://eyeoh.app';

const latestRelease = changelog.match(/^## \d+\.\d+\.\d+ - (\d{4}-\d{2}-\d{2})/m)?.[1] ?? new Date().toISOString().slice(0, 10);

// Last commit date for a source file, falling back to the latest release date
// when the build runs outside a Git checkout.
function lastModified(sourcePath: string): string {
  try {
    const date = execFileSync('git', ['log', '-1', '--format=%cs', '--', sourcePath], {
      cwd: process.cwd(),
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
    return /^\d{4}-\d{2}-\d{2}$/.test(date) ? date : latestRelease;
  } catch {
    return latestRelease;
  }
}

const pages = [
  { path: '/', lastmod: latestRelease },
  { path: '/changelog/', lastmod: latestRelease },
  { path: '/support/', lastmod: lastModified('src/pages/support.astro') },
  { path: '/privacy/', lastmod: lastModified('src/pages/privacy.astro') },
  { path: '/terms/', lastmod: lastModified('src/pages/terms.astro') },
];

export const GET: APIRoute = () => {
  const urls = pages
    .map((page) => `  <url><loc>${SITE}${page.path}</loc><lastmod>${page.lastmod}</lastmod></url>`)
    .join('\n');
  const body = `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${urls}\n</urlset>\n`;
  return new Response(body, { headers: { 'Content-Type': 'application/xml; charset=utf-8' } });
};
