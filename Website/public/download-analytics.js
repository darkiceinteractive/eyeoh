document.addEventListener('click', (event) => {
  if (!(event.target instanceof Element)) return;

  const link = event.target.closest('a[data-download]');
  if (!link || event.defaultPrevented || event.button !== 0) return;

  if (navigator.sendBeacon?.('/analytics/download')) return;

  void fetch('/analytics/download', {
    method: 'POST',
    credentials: 'omit',
    cache: 'no-store',
    keepalive: true,
  }).catch(() => {});
});
