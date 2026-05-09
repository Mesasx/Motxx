(() => {
  document.documentElement.classList.add('js');

  const $ = (selector, root = document) => root.querySelector(selector);
  const $$ = (selector, root = document) => Array.from(root.querySelectorAll(selector));

  const active = document.body.dataset.active;
  if (active) {
    $$(`[data-nav="${active}"]`).forEach((link) => link.classList.add('active'));
  }

  const navToggle = $('#navToggle');
  const navMenu = $('#navMenu');
  navToggle?.addEventListener('click', () => {
    const isOpen = navMenu?.classList.toggle('open');
    navToggle.setAttribute('aria-expanded', String(Boolean(isOpen)));
  });

  const observer = 'IntersectionObserver' in window ? new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add('is-visible');
        observer.unobserve(entry.target);
      }
    });
  }, { threshold: 0.12, rootMargin: '0px 0px -6% 0px' }) : null;

  $$('.reveal').forEach((el) => {
    const rect = el.getBoundingClientRect();
    if (!observer || rect.top < window.innerHeight * 0.92) {
      el.classList.add('is-visible');
    } else {
      observer.observe(el);
    }
  });

  const cookieBanner = $('#cookieBanner');
  const cookieKey = 'motex_cookie_consent';
  if (cookieBanner && !localStorage.getItem(cookieKey)) {
    cookieBanner.hidden = false;
  }
  $('[data-cookie-accept]')?.addEventListener('click', () => {
    localStorage.setItem(cookieKey, 'analytics');
    cookieBanner.hidden = true;
  });
  $('[data-cookie-reject]')?.addEventListener('click', () => {
    localStorage.setItem(cookieKey, 'technical');
    cookieBanner.hidden = true;
  });

  $$('[data-mailto-form]').forEach((form) => {
    form.addEventListener('submit', (event) => {
      event.preventDefault();
      const data = new FormData(form);
      const subject = 'Solicitud de diagnóstico Motex';
      const body = [
        `Nombre: ${data.get('nombre') || ''}`,
        `Email: ${data.get('email') || ''}`,
        `Empresa: ${data.get('empresa') || ''}`,
        '',
        'Qué quiere automatizar:',
        `${data.get('mensaje') || ''}`,
      ].join('\n');
      const email = form.dataset.mailto || 'contacto@aimotex.com';
      window.location.href = `mailto:${email}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`;
    });
  });

  $$('table').forEach((table) => {
    const headers = $$('thead th', table).map((th) => th.textContent.trim());
    $$('tbody tr', table).forEach((row) => {
      $$('td', row).forEach((cell, index) => {
        if (headers[index]) cell.dataset.label = headers[index];
      });
    });
  });

  $$('[data-copy]').forEach((button) => {
    button.addEventListener('click', async () => {
      const text = button.getAttribute('data-copy') || '';
      try {
        await navigator.clipboard.writeText(text);
        const previous = button.textContent;
        button.textContent = 'Copiado';
        setTimeout(() => { button.textContent = previous; }, 1200);
      } catch (error) {
        button.textContent = 'Selecciona y copia';
      }
    });
  });
})();
