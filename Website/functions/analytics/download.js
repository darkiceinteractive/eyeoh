export function onRequestPost() {
  return new Response(null, {
    status: 204,
    headers: {
      'Cache-Control': 'no-store',
      'X-Robots-Tag': 'noindex, noarchive',
    },
  });
}
