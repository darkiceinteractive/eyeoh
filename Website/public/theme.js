(() => {
  const storageKey = 'eyeoh-colour-theme';
  const root = document.documentElement;
  const media = window.matchMedia('(prefers-color-scheme: dark)');
  const saved = window.localStorage.getItem(storageKey);

  const apply = (theme, persist = false) => {
    root.dataset.theme = theme;
    document.querySelector('meta#theme-colour')?.setAttribute(
      'content',
      theme === 'dark' ? '#08141b' : '#f5f8fa'
    );
    document.querySelectorAll('[data-theme-choice]').forEach((button) => {
      button.setAttribute('aria-pressed', String(button.dataset.themeChoice === theme));
    });
    if (persist) window.localStorage.setItem(storageKey, theme);
  };

  apply(saved === 'light' || saved === 'dark' ? saved : (media.matches ? 'dark' : 'light'));

  window.addEventListener('DOMContentLoaded', () => {
    apply(root.dataset.theme);
    document.querySelectorAll('[data-theme-choice]').forEach((button) => {
      button.addEventListener('click', () => apply(button.dataset.themeChoice, true));
    });
  });

  media.addEventListener('change', (event) => {
    if (!window.localStorage.getItem(storageKey)) apply(event.matches ? 'dark' : 'light');
  });
})();
