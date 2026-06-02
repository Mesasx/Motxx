(() => {
  document.documentElement.classList.add('js');

  const $ = (selector, root = document) => root.querySelector(selector);
  const $$ = (selector, root = document) => Array.from(root.querySelectorAll(selector));
  const docLang = document.documentElement.lang;
  const currentLang = docLang === 'en' ? 'en' : docLang === 'fr' ? 'fr' : 'es';
  const langKey = 'motex_language';

  const getStoredLanguage = () => {
    try {
      return localStorage.getItem(langKey);
    } catch (error) {
      return null;
    }
  };

  const setStoredLanguage = (lang) => {
    try {
      localStorage.setItem(langKey, lang);
    } catch (error) {
      // Ignore storage restrictions and keep navigation usable.
    }
  };

  // Rutas multi-idioma: ES en raíz, EN en /en/, FR en /fr/.
  const localizedPath = (targetLang) => {
    const { search, hash } = window.location;
    const cleanPath = window.location.pathname.replace(/\/{2,}/g, '/');
    // Quita cualquier prefijo de idioma actual para quedarnos con la ruta "neutra".
    let base = cleanPath.replace(/^\/(en|fr)(?=\/|$)/, '');
    if (base === '') base = '/';

    let targetPath;
    if (targetLang === 'es') {
      targetPath = base;
    } else {
      // /en o /fr
      targetPath = base === '/' ? `/${targetLang}/` : `/${targetLang}${base}`;
    }
    return `${targetPath}${search}${hash}`;
  };

  // Redirección automática según el idioma del navegador (solo desde ES y sin elección previa).
  const shouldRedirectTo = () => {
    if (currentLang !== 'es' || getStoredLanguage()) return null;
    const preferred = (navigator.languages?.[0] || navigator.language || '').toLowerCase();
    if (preferred.startsWith('en')) return 'en';
    if (preferred.startsWith('fr')) return 'fr';
    return null;
  };

  const autoLang = shouldRedirectTo();
  if (autoLang) {
    setStoredLanguage(autoLang);
    window.location.replace(localizedPath(autoLang));
    return;
  }

  const active = document.body.dataset.active;
  if (active) {
    $$(`[data-nav="${active}"]`).forEach((link) => link.classList.add('active'));
  }

  const navToggle = $('#navToggle');
  const navMenu = $('#navMenu');
  const siteNav = $('.site-nav');
  const brand = $('.site-nav .brand');

  // Selector de idioma con banderas (ES / EN / FR).
  const langLabel = { es: 'Selector de idioma', en: 'Language selector', fr: 'Sélecteur de langue' };
  const langs = [
    { code: 'es', flag: '🇪🇸', label: 'Español' },
    { code: 'en', flag: '🇬🇧', label: 'English' },
    { code: 'fr', flag: '🇫🇷', label: 'Français' },
  ];
  const buildLanguageSwitch = () => {
    const sw = document.createElement('div');
    sw.className = 'language-switch';
    sw.setAttribute('role', 'group');
    sw.setAttribute('aria-label', langLabel[currentLang] || langLabel.es);
    sw.innerHTML = langs.map((l) => (
      `<a href="${localizedPath(l.code)}" hreflang="${l.code}" data-lang-choice="${l.code}" ` +
      `title="${l.label}" aria-label="${l.label}" class="${currentLang === l.code ? 'active' : ''}">` +
      `<span class="flag" aria-hidden="true">${l.flag}</span></a>`
    )).join('');
    return sw;
  };

  // Header v2: el CTA "Diagnóstico" y el selector de idioma van a la derecha,
  // fuera del menú desplegable. Reorganizamos sin tocar el HTML de cada página.
  if (siteNav && navMenu && brand) {
    const actions = document.createElement('div');
    actions.className = 'nav-actions';
    const cta = navMenu.querySelector('.nav-diagnosis');
    // Clonamos el CTA para tener uno visible en la barra y otro dentro del menú.
    if (cta) {
      const ctaTop = cta.cloneNode(true);
      ctaTop.classList.add('nav-cta-top');
      actions.appendChild(ctaTop);
    }
    actions.appendChild(buildLanguageSwitch());
    // Orden visual: [toggle] [brand] [actions]
    siteNav.appendChild(actions);
  } else if (navMenu) {
    navMenu.appendChild(buildLanguageSwitch());
  }

  $$('[data-lang-choice]').forEach((link) => {
    link.addEventListener('click', () => setStoredLanguage(link.dataset.langChoice));
  });

  // --- Reestructurar el menú (aplica a todas las páginas) ---
  // Quitar Webs / Precios / Contacto del menú, bajar "Servicios" al final
  // y añadir un acceso de contacto discreto. Las páginas siguen existiendo
  // y enlazadas desde otras secciones (p. ej. Webs y Precios desde Servicios).
  const contactPath = currentLang === 'en' ? '/en/contacto/' : currentLang === 'fr' ? '/fr/contacto/' : '/contacto/';
  const endsWithSeg = (a, seg) =>
    (a.getAttribute('href') || '').replace(/[#?].*$/, '').replace(/\/$/, '').endsWith(seg);
  if (navMenu) {
    $$('a:not(.btn)', navMenu).forEach((a) => {
      if (endsWithSeg(a, '/webs') || endsWithSeg(a, '/precios') || endsWithSeg(a, '/contacto')) a.remove();
    });
    const servicios = $$('a:not(.btn)', navMenu).find((a) => endsWithSeg(a, '/servicios'));
    const diag = navMenu.querySelector('.nav-diagnosis');
    if (servicios) {
      if (diag) navMenu.insertBefore(servicios, diag); else navMenu.appendChild(servicios);
    }
    const contactLabel = {
      es: 'Prefieres escribirnos? Contáctanos',
      en: 'Prefer to write? Contact us',
      fr: 'Préférez-vous écrire ? Contactez-nous',
    };
    const contactLink = document.createElement('a');
    contactLink.className = 'nav-contact-link';
    contactLink.href = contactPath;
    contactLink.innerHTML = `${contactLabel[currentLang] || contactLabel.es} <span aria-hidden="true">→</span>`;
    navMenu.appendChild(contactLink);
  }

  // --- Mini-notificación de contacto (aparece desde la derecha al abrir el menú) ---
  const WA = '34683567360';
  const EMAIL = 'pedro@aimotex.com';
  const toastTxt = {
    es: { t: '¿Hablamos?', d: 'Escríbenos y te respondemos en menos de 24 h.', wa: 'WhatsApp', email: 'Email', close: 'Cerrar' },
    en: { t: "Let's talk", d: 'Write to us — we reply within 24 h.', wa: 'WhatsApp', email: 'Email', close: 'Close' },
    fr: { t: 'Discutons', d: 'Écrivez-nous — réponse sous 24 h.', wa: 'WhatsApp', email: 'Email', close: 'Fermer' },
  };
  const tt = toastTxt[currentLang] || toastTxt.es;
  let contactToast = null;
  const ensureToast = () => {
    if (contactToast) return contactToast;
    contactToast = document.createElement('aside');
    contactToast.className = 'contact-toast';
    contactToast.setAttribute('aria-label', tt.t);
    contactToast.innerHTML =
      `<button class="contact-toast-x" type="button" aria-label="${tt.close}">×</button>` +
      `<span class="contact-toast-icon" aria-hidden="true">` +
      `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M4 6a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H9l-4 4v-4H6a2 2 0 0 1-2-2z"/></svg></span>` +
      `<strong>${tt.t}</strong><p>${tt.d}</p>` +
      `<div class="contact-toast-actions">` +
      `<a class="btn btn-primary" href="https://wa.me/${WA}" target="_blank" rel="noopener">${tt.wa}</a>` +
      `<a class="btn btn-ghost" href="mailto:${EMAIL}">${tt.email}</a></div>`;
    document.body.appendChild(contactToast);
    contactToast.querySelector('.contact-toast-x').addEventListener('click', () => contactToast.classList.remove('show'));
    return contactToast;
  };

  // Menú desplegable centrado. Lo movemos (junto a su backdrop) al <body>
  // para que NO herede el contexto de apilamiento de la barra fija: así el
  // panel queda por encima del velo y es clicable y nítido.
  let backdrop = null;
  if (navMenu && navMenu.parentElement !== document.body) {
    document.body.appendChild(navMenu);
  }
  const setMenu = (open) => {
    navMenu?.classList.toggle('open', open);
    navToggle?.setAttribute('aria-expanded', String(open));
    document.documentElement.classList.toggle('menu-open', open);
    if (open) {
      header?.classList.remove('header-hidden');
      if (!backdrop) {
        backdrop = document.createElement('div');
        backdrop.className = 'nav-backdrop';
        backdrop.addEventListener('click', () => setMenu(false));
        document.body.appendChild(backdrop);
      }
      requestAnimationFrame(() => backdrop.classList.add('open'));
      // Notificación de contacto deslizándose desde la derecha
      const toast = ensureToast();
      setTimeout(() => toast.classList.add('show'), 280);
    } else {
      if (backdrop) backdrop.classList.remove('open');
      contactToast?.classList.remove('show');
    }
  };
  navToggle?.addEventListener('click', () => {
    setMenu(!navMenu?.classList.contains('open'));
  });
  navMenu?.querySelectorAll('a').forEach((a) => a.addEventListener('click', () => setMenu(false)));
  document.addEventListener('keydown', (e) => { if (e.key === 'Escape') setMenu(false); });

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

  $$('table').forEach((table) => {
    const headers = $$('thead th', table).map((th) => th.textContent.trim());
    $$('tbody tr', table).forEach((row) => {
      $$('td', row).forEach((cell, index) => {
        if (headers[index]) cell.dataset.label = headers[index];
      });
    });
  });

  $$('[data-workflow-showcase]').forEach((showcase) => {
    const tabs = $$('[data-workflow-tab]', showcase);
    const panels = $$('[data-workflow-panel]', showcase);

    tabs.forEach((tab) => {
      tab.addEventListener('click', () => {
        tabs.forEach((item) => item.setAttribute('aria-selected', String(item === tab)));
        panels.forEach((panel) => {
          panel.hidden = panel.id !== tab.getAttribute('aria-controls');
        });
      });
    });
  });

  const botRoot = $('[data-contact-bot]');
  if (botRoot) {
    const isEnglish = document.documentElement.lang === 'en';
    const messages = $('[data-bot-messages]', botRoot);
    const quick = $('[data-bot-quick]', botRoot);
    const form = $('[data-bot-form]', botRoot);
    const input = $('[data-bot-input]', botRoot);
    const progress = $('[data-bot-progress]', botRoot);
    const answers = {};
    let step = 0;

    const botText = isEnglish ? {
      progress: (current, total) => `Question ${current} of ${total}`,
      ready: 'Summary ready',
      noAnswer: 'No answer',
      noConsent: 'Without GDPR consent we cannot generate the email. You can write to us directly at <a href="mailto:contacto@aimotex.com">contacto@aimotex.com</a>.',
      subject: 'Automated Motex diagnosis',
      heading: 'AUTOMATED MOTEX DIAGNOSIS',
      consent: 'GDPR consent: Yes.',
      origin: 'Source: conversational bot at aimotex.com/en/contacto/',
      final: 'I have prepared an organized summary so Pedro can start with context.',
      send: 'Send summary to Motex',
      restart: 'Start again',
      intro: 'Let’s start the diagnosis. I will ask a few questions, but the right ones.',
    } : {
      progress: (current, total) => `Pregunta ${current} de ${total}`,
      ready: 'Resumen listo',
      noAnswer: 'Sin respuesta',
      noConsent: 'Sin consentimiento RGPD no generamos el email. Puedes escribirnos directamente a <a href="mailto:contacto@aimotex.com">contacto@aimotex.com</a>.',
      subject: 'Diagnóstico automatizado Motex',
      heading: 'DIAGNÓSTICO AUTOMATIZADO MOTEX',
      consent: 'Consentimiento RGPD: Sí.',
      origin: 'Origen: bot conversacional de aimotex.com/contacto/',
      final: 'He preparado un resumen ordenado para que Pedro empiece con contexto.',
      send: 'Enviar resumen a Motex',
      restart: 'Empezar de nuevo',
      intro: 'Arrancamos diagnóstico. Te haré pocas preguntas, pero bien elegidas.',
    };

    const questions = isEnglish ? [
      {
        key: 'empresa',
        label: 'Company',
        text: 'To start: who are you? Company name if you want to include it, sector and approximate size.',
        quick: ['I prefer not to add the name', 'Industrial', 'Professional services', 'Commerce or retail'],
        placeholder: 'E.g. technical engineering, 8 people, Spain',
      },
      {
        key: 'procesos',
        label: 'Processes to automate',
        text: 'Which processes would you like to automate first? The more specific, the better.',
        quick: ['Emails', 'Leads and sales', 'Invoices and quotes', 'Internal reports'],
        placeholder: 'E.g. document duplication, lead follow-up, weekly reports...',
      },
      {
        key: 'herramientas',
        label: 'Current tools',
        text: 'What tools do you use today? Email, CRM, ERP, Microsoft 365, Google Workspace, spreadsheets, WhatsApp, Telegram...',
        quick: ['Microsoft 365', 'Google Workspace', 'Sheets/Excel', 'CRM/ERP'],
        placeholder: 'List your current tools',
      },
      {
        key: 'volumen',
        label: 'Work volume',
        text: 'What approximate volume does the process have? Emails per day, leads per month, documents per week, repetitive hours...',
        quick: ['Low', 'Medium', 'High', 'I do not know yet'],
        placeholder: 'E.g. 40 emails/day, 25 quotes/month, 8 h/week',
      },
      {
        key: 'urgencia',
        label: 'Urgency',
        text: 'How urgently do you want to move this forward?',
        quick: ['This month', '1-2 months', 'This quarter', 'No rush'],
        placeholder: 'Ideal timeline',
      },
      {
        key: 'presupuesto',
        label: 'Approximate budget',
        text: 'Do you have an approximate budget or would you rather start with a diagnosis?',
        quick: ['Free diagnosis', 'EUR 290 audit', 'Less than EUR 1,000', 'EUR 2,000-5,000'],
        placeholder: 'Approximate range or “to be defined”',
      },
      {
        key: 'contacto',
        label: 'Contact details',
        text: 'Leave your name, email and phone if you want us to reply precisely.',
        quick: [],
        placeholder: 'Name · email · phone',
      },
      {
        key: 'contexto',
        label: 'Useful context',
        text: 'Last context question: is there anything we should know before the call?',
        quick: ['We want something simple', 'There is sensitive data', 'We need training', 'No, this is enough'],
        placeholder: 'Restrictions, integrations, sensitive data, schedules...',
      },
      {
        key: 'rgpd',
        label: 'GDPR consent',
        text: 'To send us this summary, we need your consent: do you agree that Motex can use this data to answer your request?',
        quick: ['Yes, I agree', 'I do not agree'],
        placeholder: 'Type “Yes, I agree” to generate the summary',
      },
    ] : [
      {
        key: 'empresa',
        label: 'Empresa',
        text: 'Para empezar: ¿quién sois? Nombre de empresa si quieres ponerlo, sector y tamaño aproximado.',
        quick: ['Prefiero no poner nombre', 'Industrial', 'Servicios profesionales', 'Comercio o retail'],
        placeholder: 'Ej. ingeniería técnica, 8 personas, España',
      },
      {
        key: 'procesos',
        label: 'Procesos a automatizar',
        text: '¿Qué procesos os gustaría automatizar primero? Cuanto más concreto, mejor.',
        quick: ['Correos', 'Leads y ventas', 'Facturas y presupuestos', 'Informes internos'],
        placeholder: 'Ej. duplicidad documental, seguimiento de leads, informes semanales...',
      },
      {
        key: 'herramientas',
        label: 'Herramientas actuales',
        text: '¿Qué herramientas usáis hoy? Email, CRM, ERP, Microsoft 365, Google Workspace, hojas de cálculo, WhatsApp, Telegram...',
        quick: ['Microsoft 365', 'Google Workspace', 'Sheets/Excel', 'CRM/ERP'],
        placeholder: 'Lista de herramientas actuales',
      },
      {
        key: 'volumen',
        label: 'Volumen de trabajo',
        text: '¿Qué volumen aproximado tiene el proceso? Correos al día, leads al mes, documentos por semana, horas repetitivas...',
        quick: ['Bajo', 'Medio', 'Alto', 'No lo sé todavía'],
        placeholder: 'Ej. 40 correos/día, 25 presupuestos/mes, 8 h semanales',
      },
      {
        key: 'urgencia',
        label: 'Urgencia',
        text: '¿Con qué urgencia queréis mover esto?',
        quick: ['Este mes', '1-2 meses', 'Este trimestre', 'Sin prisa'],
        placeholder: 'Plazo ideal',
      },
      {
        key: 'presupuesto',
        label: 'Presupuesto aproximado',
        text: '¿Tenéis un presupuesto aproximado o preferís empezar por diagnóstico?',
        quick: ['Diagnóstico gratuito', 'Auditoría 290 €', 'Menos de 1.000 €', '2.000-5.000 €'],
        placeholder: 'Rango orientativo o “por definir”',
      },
      {
        key: 'contacto',
        label: 'Datos de contacto',
        text: 'Déjanos nombre, email y teléfono si quieres que podamos responder con precisión.',
        quick: [],
        placeholder: 'Nombre · email · teléfono',
      },
      {
        key: 'contexto',
        label: 'Contexto útil',
        text: 'Última pregunta de contexto: ¿hay algo que debamos saber antes de la llamada?',
        quick: ['Queremos algo sencillo', 'Hay datos sensibles', 'Necesitamos formación', 'No, con esto basta'],
        placeholder: 'Restricciones, integraciones, datos sensibles, horarios...',
      },
      {
        key: 'rgpd',
        label: 'Consentimiento RGPD',
        text: 'Para enviarnos este resumen, necesitamos consentimiento: ¿aceptas que Motex use estos datos para responder a tu solicitud?',
        quick: ['Sí, acepto', 'No acepto'],
        placeholder: 'Escribe “Sí, acepto” para generar el resumen',
      },
    ];

    const escapeHtml = (value) => String(value)
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#039;');

    const addMessage = (text, who = 'bot') => {
      const bubble = document.createElement('div');
      bubble.className = `bot-bubble ${who}`;
      bubble.innerHTML = text;
      messages.appendChild(bubble);
      messages.scrollTop = messages.scrollHeight;
    };

    const renderQuick = (items) => {
      quick.innerHTML = '';
      items.forEach((item) => {
        const button = document.createElement('button');
        button.type = 'button';
        button.textContent = item;
        button.addEventListener('click', () => handleAnswer(item));
        quick.appendChild(button);
      });
    };

    const ask = () => {
      const question = questions[step];
      progress.textContent = botText.progress(step + 1, questions.length);
      input.placeholder = question.placeholder;
      addMessage(question.text);
      renderQuick(question.quick);
      input.focus();
    };

    const formatSummary = () => questions.map((question, index) => (
      `${index + 1}. ${question.label}\n${answers[question.key] || botText.noAnswer}`
    )).join('\n\n');

    const finish = () => {
      progress.textContent = botText.ready;
      quick.innerHTML = '';
      input.disabled = true;
      form.querySelector('button').disabled = true;

      const consent = String(answers.rgpd || '').toLowerCase();
      if (!consent.includes('sí') && !consent.includes('si') && !consent.includes('acepto') && !consent.includes('yes') && !consent.includes('agree')) {
        addMessage(botText.noConsent);
        return;
      }

      const subject = botText.subject;
      const body = [
        botText.heading,
        '',
        formatSummary(),
        '',
        botText.consent,
        botText.origin,
      ].join('\n');
      const href = `mailto:contacto@aimotex.com?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`;
      const htmlSummary = questions.map((question) => (
        `<dt>${escapeHtml(question.label)}</dt><dd>${escapeHtml(answers[question.key] || botText.noAnswer)}</dd>`
      )).join('');

      addMessage(`${botText.final}<div class="bot-summary"><dl>${htmlSummary}</dl><a class="btn btn-primary" href="${href}">${botText.send}</a><button class="btn btn-secondary" type="button" data-bot-restart>${botText.restart}</button></div>`);
      $('[data-bot-restart]', messages)?.addEventListener('click', restart);
    };

    const handleAnswer = (value) => {
      const cleanValue = value.trim();
      if (!cleanValue) return;
      const question = questions[step];
      answers[question.key] = cleanValue;
      addMessage(escapeHtml(cleanValue), 'user');
      input.value = '';
      step += 1;
      if (step < questions.length) {
        setTimeout(ask, 220);
      } else {
        setTimeout(finish, 260);
      }
    };

    const restart = () => {
      Object.keys(answers).forEach((key) => delete answers[key]);
      step = 0;
      messages.innerHTML = '';
      input.disabled = false;
      form.querySelector('button').disabled = false;
      addMessage(botText.intro);
      ask();
    };

    form.addEventListener('submit', (event) => {
      event.preventDefault();
      handleAnswer(input.value);
    });

    restart();
  }

  $$('[data-copy]').forEach((button) => {
    button.addEventListener('click', async () => {
      const text = button.getAttribute('data-copy') || '';
      try {
        await navigator.clipboard.writeText(text);
        const previous = button.textContent;
        button.textContent = document.documentElement.lang === 'en' ? 'Copied' : 'Copiado';
        setTimeout(() => { button.textContent = previous; }, 1200);
      } catch (error) {
        button.textContent = document.documentElement.lang === 'en' ? 'Select and copy' : 'Selecciona y copia';
      }
    });
  });

  /* ============================================================
     Rediseño 2026 · interacciones globales + home
     Todo va protegido: si el elemento no existe, no hace nada,
     así estas mejoras conviven con el resto de páginas.
     ============================================================ */
  const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  // Wordmark "motex" del hero: envolvemos "mot" y "ex" en spans para que
  // entren deslizándose desde los lados (la animación vive en el CSS).
  const heroMark = $('.home-hero .hero-mark');
  if (heroMark) {
    const ex = heroMark.querySelector('.logo-ex');
    const exText = ex ? ex.textContent : 'ex';
    const motText = (heroMark.textContent || 'Motex').replace(new RegExp(exText + '$'), '');
    heroMark.innerHTML = `<span class="mot">${motText}</span><span class="logo-ex">${exText}</span>`;
  }

  // Header "stuck", barra de progreso de lectura y botón "volver arriba".
  // Se crean dinámicamente si la página no los trae, así toda la web
  // (todas las subpáginas) recibe la misma capa de pulido sin tocar su HTML.
  const header = $('.site-header');
  let readProgress = $('#readProgress');
  if (header && !readProgress) {
    readProgress = document.createElement('div');
    readProgress.id = 'readProgress';
    readProgress.className = 'read-progress';
    header.appendChild(readProgress);
  }
  let toTop = $('#toTop');
  if (!toTop) {
    toTop = document.createElement('button');
    toTop.id = 'toTop';
    toTop.type = 'button';
    toTop.className = 'to-top';
    toTop.setAttribute('aria-label', currentLang === 'en' ? 'Back to top' : 'Volver arriba');
    toTop.innerHTML = '<svg width="20" height="20" viewBox="0 0 24 24" fill="none"><path d="M12 19V5M6 11l6-6 6 6" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>';
    document.body.appendChild(toTop);
  }
  if (header || toTop) {
    let lastY = window.scrollY || window.pageYOffset;
    const onScroll = () => {
      const y = window.scrollY || window.pageYOffset;
      header?.classList.toggle('is-stuck', y > 8);
      if (readProgress) {
        const h = document.documentElement.scrollHeight - window.innerHeight;
        readProgress.style.width = (h > 0 ? (y / h) * 100 : 0) + '%';
      }
      toTop?.classList.toggle('show', y > 680);
      // Auto-ocultar la barra al bajar; mostrarla al subir (no si el menú está abierto).
      if (header && !navMenu?.classList.contains('open')) {
        if (y > lastY + 4 && y > 140) header.classList.add('header-hidden');
        else if (y < lastY - 4) header.classList.remove('header-hidden');
      }
      lastY = y;
    };
    window.addEventListener('scroll', onScroll, { passive: true });
    onScroll();
  }
  toTop?.addEventListener('click', () => {
    window.scrollTo({ top: 0, behavior: reduceMotion ? 'auto' : 'smooth' });
  });

  // Cinta de integraciones (se duplica para bucle continuo)
  const marqueeRow = $('#marqueeRow');
  if (marqueeRow) {
    const tools = ['n8n', 'OpenAI', 'Slack', 'HubSpot', 'Notion', 'Gmail', 'Stripe', 'Make', 'Airtable', 'Google Sheets', 'Microsoft 365', 'Telegram', 'WhatsApp', 'Shopify'];
    const frag = document.createDocumentFragment();
    tools.concat(tools).forEach((name) => {
      const span = document.createElement('span');
      span.innerHTML = '<i></i>' + name;
      frag.appendChild(span);
    });
    marqueeRow.appendChild(frag);
  }

  // Contadores animados (impacto)
  const counters = $$('[data-count]');
  if (counters.length) {
    const animateCount = (el) => {
      const target = parseFloat(el.getAttribute('data-count')) || 0;
      const suffix = el.getAttribute('data-suffix') || '';
      if (reduceMotion) { el.textContent = target + suffix; return; }
      const dur = 1400;
      const start = performance.now();
      const tick = (now) => {
        const p = Math.min((now - start) / dur, 1);
        const eased = 1 - Math.pow(1 - p, 3);
        el.textContent = Math.round(target * eased) + suffix;
        if (p < 1) requestAnimationFrame(tick);
      };
      requestAnimationFrame(tick);
    };
    if ('IntersectionObserver' in window) {
      const cio = new IntersectionObserver((entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) { animateCount(entry.target); cio.unobserve(entry.target); }
        });
      }, { threshold: 0.6 });
      counters.forEach((el) => cio.observe(el));
    } else {
      counters.forEach(animateCount);
    }
  }

  // Diagrama de flujo automatizado (SVG generado)
  const flowEdges = $('#flowEdges');
  const flowNodes = $('#flowNodes');
  if (flowEdges && flowNodes) {
    const SVGNS = 'http://www.w3.org/2000/svg';
    const W = 1000, NW = 188, NH = 74;
    const nodes = [
      { id: 'trigger', label: 'Disparador', sub: 'Email · Formulario · API', color: '#38BDC8', x: 8, y: 50 },
      { id: 'collect', label: 'Recopilar datos', sub: 'CRM · Hojas · Docs', color: '#9DB3AA', x: 31, y: 24 },
      { id: 'ai', label: 'Procesar con IA', sub: 'Clasifica y decide', color: '#6E8BFF', x: 31, y: 76 },
      { id: 'logic', label: 'Lógica de negocio', sub: 'Reglas y condiciones', color: '#9DB3AA', x: 56, y: 50 },
      { id: 'action', label: 'Ejecutar acciones', sub: 'Crear · Enviar · Actualizar', color: '#9DB3AA', x: 80, y: 28 },
      { id: 'notify', label: 'Notificar equipo', sub: 'Slack · Email · Panel', color: '#0F5257', x: 80, y: 72 },
    ];
    const edges = [['trigger', 'collect'], ['trigger', 'ai'], ['collect', 'logic'], ['ai', 'logic'], ['logic', 'action'], ['logic', 'notify']];
    const byId = {};
    nodes.forEach((n) => { byId[n.id] = n; });
    const cx = (n) => (n.x / 100) * W;
    const cy = (n) => (n.y / 100) * 520;
    const make = (name, attrs) => {
      const el = document.createElementNS(SVGNS, name);
      Object.entries(attrs).forEach(([k, v]) => el.setAttribute(k, v));
      return el;
    };
    edges.forEach((e, i) => {
      const a = byId[e[0]], b = byId[e[1]];
      const sx = cx(a) + NW / 2, ex = cx(b) - NW / 2, mx = (sx + ex) / 2;
      const d = `M ${sx} ${cy(a)} C ${mx} ${cy(a)}, ${mx} ${cy(b)}, ${ex} ${cy(b)}`;
      flowEdges.appendChild(make('path', { class: 'flow-edge', d }));
      flowEdges.appendChild(make('path', { class: 'flow-edge-live', d }));
      if (!reduceMotion) {
        const dot = make('circle', { r: '4.5', class: 'flow-dot' });
        const am = make('animateMotion', { dur: '3.2s', begin: (i * 0.5) + 's', repeatCount: 'indefinite', path: d });
        dot.appendChild(am);
        flowEdges.appendChild(dot);
      }
    });
    nodes.forEach((n) => {
      const g = make('g', { class: 'flow-node', transform: `translate(${cx(n) - NW / 2}, ${cy(n) - NH / 2})` });
      g.appendChild(make('rect', { width: NW, height: NH, rx: '14', stroke: n.color }));
      g.appendChild(make('circle', { cx: '22', cy: NH / 2, r: '7', fill: n.color, filter: 'url(#flowSoft)' }));
      g.appendChild(make('circle', { cx: '22', cy: NH / 2, r: '3', fill: '#fff' }));
      const t1 = make('text', { class: 'ttl', x: '40', y: NH / 2 - 6 }); t1.textContent = n.label; g.appendChild(t1);
      const t2 = make('text', { class: 'sub', x: '40', y: NH / 2 + 14 }); t2.textContent = n.sub; g.appendChild(t2);
      flowNodes.appendChild(g);
    });
  }

  // Red de partículas del hero
  const heroCanvas = $('#heroCanvas');
  if (heroCanvas && heroCanvas.getContext) {
    const ctx = heroCanvas.getContext('2d');
    let w, h, dpr, raf, points = [];
    const mouse = { x: -9999, y: -9999 };
    const palette = ['#18A89B', '#38BDC8', '#6E8BFF'];
    const resize = () => {
      dpr = Math.min(window.devicePixelRatio || 1, 2);
      const r = heroCanvas.getBoundingClientRect();
      w = r.width; h = r.height;
      heroCanvas.width = w * dpr; heroCanvas.height = h * dpr;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      const count = Math.min(64, Math.floor((w * h) / 17000));
      points = [];
      for (let i = 0; i < count; i++) {
        points.push({ x: Math.random() * w, y: Math.random() * h, vx: (Math.random() - 0.5) * 0.32, vy: (Math.random() - 0.5) * 0.32, r: Math.random() * 1.7 + 1, c: palette[(Math.random() * palette.length) | 0] });
      }
    };
    const draw = () => {
      ctx.clearRect(0, 0, w, h);
      for (const p of points) {
        p.x += p.vx; p.y += p.vy;
        if (p.x < 0 || p.x > w) p.vx *= -1;
        if (p.y < 0 || p.y > h) p.vy *= -1;
        const dx = mouse.x - p.x, dy = mouse.y - p.y, dm = Math.hypot(dx, dy);
        if (dm < 150) { p.x += dx * 0.0014 * (1 - dm / 150); p.y += dy * 0.0014 * (1 - dm / 150); }
      }
      for (let i = 0; i < points.length; i++) {
        for (let j = i + 1; j < points.length; j++) {
          const a = points[i], b = points[j], d = Math.hypot(a.x - b.x, a.y - b.y);
          if (d < 124) { ctx.globalAlpha = (1 - d / 124) * 0.45; ctx.strokeStyle = a.c; ctx.lineWidth = 0.7; ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); ctx.stroke(); }
        }
      }
      ctx.globalAlpha = 1;
      for (const p of points) { ctx.beginPath(); ctx.fillStyle = p.c; ctx.shadowColor = p.c; ctx.shadowBlur = 8; ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2); ctx.fill(); }
      ctx.shadowBlur = 0;
      raf = requestAnimationFrame(draw);
    };
    resize();
    draw();
    if (reduceMotion) cancelAnimationFrame(raf);
    window.addEventListener('resize', resize);
    if (!reduceMotion) {
      window.addEventListener('mousemove', (e) => { const r = heroCanvas.getBoundingClientRect(); mouse.x = e.clientX - r.left; mouse.y = e.clientY - r.top; });
      window.addEventListener('mouseout', () => { mouse.x = -9999; mouse.y = -9999; });
    }
  }

  /* ============================================================
     Diagramas navegables (flowboard): construye el SVG desde datos
     y permite arrastrar (pan) y hacer zoom (rueda / pellizco / botones).
     Cada [data-flowboard] declara su diagrama en un <script type="application/json">.
     ============================================================ */
  const SVGNS = 'http://www.w3.org/2000/svg';
  const svgEl = (name, attrs) => {
    const el = document.createElementNS(SVGNS, name);
    for (const k in attrs) el.setAttribute(k, attrs[k]);
    return el;
  };

  const buildFlowboard = (board) => {
    const dataTag = board.querySelector('script[type="application/json"]');
    if (!dataTag) return;
    let data;
    try { data = JSON.parse(dataTag.textContent); } catch (e) { return; }

    const W = data.width || 2200;
    const H = data.height || 1200;
    const grid = document.createElement('div');
    grid.className = 'flowboard-grid';
    const viewport = document.createElement('div');
    viewport.className = 'flowboard-viewport';

    const svg = svgEl('svg', { width: W, height: H, viewBox: `0 0 ${W} ${H}` });
    const defs = svgEl('defs', {});
    const grad = svgEl('linearGradient', { id: 'fbGrad', x1: '0', y1: '0', x2: '1', y2: '0' });
    grad.appendChild(svgEl('stop', { offset: '0', 'stop-color': '#18A89B' }));
    grad.appendChild(svgEl('stop', { offset: '0.5', 'stop-color': '#4F63E6' }));
    grad.appendChild(svgEl('stop', { offset: '1', 'stop-color': '#7B5BD6' }));
    defs.appendChild(grad);
    const soft = svgEl('filter', { id: 'fbSoft', x: '-40%', y: '-40%', width: '180%', height: '180%' });
    soft.appendChild(svgEl('feGaussianBlur', { stdDeviation: '4', result: 'b' }));
    const merge = svgEl('feMerge', {});
    merge.appendChild(svgEl('feMergeNode', { in: 'b' }));
    merge.appendChild(svgEl('feMergeNode', { in: 'SourceGraphic' }));
    soft.appendChild(merge);
    defs.appendChild(soft);
    svg.appendChild(defs);

    const NW = 188, NH = 70;
    const byId = {};
    (data.nodes || []).forEach((n) => { byId[n.id] = n; });
    const cx = (n) => n.x + NW / 2;
    const cy = (n) => n.y + NH / 2;

    // Lanes (grupos)
    (data.lanes || []).forEach((l) => {
      const g = svgEl('g', { class: 'fb-lane' });
      g.appendChild(svgEl('rect', { x: l.x, y: l.y, width: l.w, height: l.h, rx: '16' }));
      const t = svgEl('text', { class: 'lane-t', x: l.x + 18, y: l.y + 28 }); t.textContent = l.title; g.appendChild(t);
      if (l.desc) { const d = svgEl('text', { class: 'lane-d', x: l.x + 18, y: l.y + 46 }); d.textContent = l.desc; g.appendChild(d); }
      svg.appendChild(g);
    });

    // Nota (caja de "cómo funciona")
    if (data.note) {
      const nb = data.note;
      const g = svgEl('g', { class: 'fb-note' });
      g.appendChild(svgEl('rect', { x: nb.x, y: nb.y, width: nb.w, height: nb.h, rx: '14' }));
      const t = svgEl('text', { class: 't', x: nb.x + 22, y: nb.y + 34 }); t.setAttribute('font-size', '18'); t.textContent = nb.title; g.appendChild(t);
      (nb.lines || []).forEach((ln, i) => {
        const p = svgEl('text', { class: 'p', x: nb.x + 22, y: nb.y + 62 + i * 22 }); p.setAttribute('font-size', '13'); p.textContent = ln; g.appendChild(p);
      });
      svg.appendChild(g);
    }

    // Edges + dots
    (data.edges || []).forEach((e, i) => {
      const a = byId[e[0]], b = byId[e[1]];
      if (!a || !b) return;
      const sx = a.x + NW, sy = cy(a), ex = b.x, ey = cy(b);
      const mx = (sx + ex) / 2;
      const d = `M ${sx} ${sy} C ${mx} ${sy}, ${mx} ${ey}, ${ex} ${ey}`;
      svg.appendChild(svgEl('path', { class: 'fb-edge', d }));
      svg.appendChild(svgEl('path', { class: 'fb-edge-live', d }));
      if (!reduceMotion) {
        const dot = svgEl('circle', { r: '4.5', class: 'fb-dot' });
        dot.appendChild(svgEl('animateMotion', { dur: '3.4s', begin: (i * 0.3) + 's', repeatCount: 'indefinite', path: d }));
        svg.appendChild(dot);
      }
    });

    // Nodes
    (data.nodes || []).forEach((n) => {
      const g = svgEl('g', { class: 'fb-node', transform: `translate(${n.x}, ${n.y})` });
      g.appendChild(svgEl('rect', { width: NW, height: NH, rx: '14', stroke: n.color || '#4F63E6' }));
      g.appendChild(svgEl('circle', { cx: '24', cy: NH / 2, r: '7', fill: n.color || '#4F63E6', filter: 'url(#fbSoft)' }));
      g.appendChild(svgEl('circle', { cx: '24', cy: NH / 2, r: '3', fill: '#0E1B15' }));
      const t = svgEl('text', { class: 'nt', x: '44', y: NH / 2 - 4 }); t.textContent = n.label; g.appendChild(t);
      if (n.sub) { const s = svgEl('text', { class: 'ns', x: '44', y: NH / 2 + 14 }); s.textContent = n.sub; g.appendChild(s); }
      svg.appendChild(g);
    });

    viewport.appendChild(svg);
    board.appendChild(grid);
    board.appendChild(viewport);

    // --- Pan & zoom ---
    let scale = 1, tx = 0, ty = 0, minS = 0.3, maxS = 2.2;
    const apply = () => { viewport.style.transform = `translate(${tx}px, ${ty}px) scale(${scale})`; };
    const fit = () => {
      const r = board.getBoundingClientRect();
      scale = Math.min(r.width / W, r.height / H) * 0.96;
      scale = Math.max(minS, Math.min(maxS, scale));
      tx = (r.width - W * scale) / 2;
      ty = (r.height - H * scale) / 2;
      apply();
    };

    const zoomAt = (factor, px, py) => {
      const r = board.getBoundingClientRect();
      const cxp = (px ?? r.width / 2);
      const cyp = (py ?? r.height / 2);
      const ns = Math.max(minS, Math.min(maxS, scale * factor));
      // mantener el punto bajo el cursor
      tx = cxp - (cxp - tx) * (ns / scale);
      ty = cyp - (cyp - ty) * (ns / scale);
      scale = ns;
      apply();
    };

    board.addEventListener('wheel', (e) => {
      e.preventDefault();
      const r = board.getBoundingClientRect();
      zoomAt(e.deltaY < 0 ? 1.12 : 0.89, e.clientX - r.left, e.clientY - r.top);
    }, { passive: false });

    // arrastre (ratón y táctil) con Pointer Events
    let dragging = false, lastX = 0, lastY = 0, pointers = new Map(), pinchDist = 0;
    board.addEventListener('pointerdown', (e) => {
      board.setPointerCapture(e.pointerId);
      pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });
      if (pointers.size === 1) { dragging = true; lastX = e.clientX; lastY = e.clientY; board.classList.add('dragging'); }
      else if (pointers.size === 2) { const p = [...pointers.values()]; pinchDist = Math.hypot(p[0].x - p[1].x, p[0].y - p[1].y); }
    });
    board.addEventListener('pointermove', (e) => {
      if (!pointers.has(e.pointerId)) return;
      pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });
      if (pointers.size === 2) {
        const p = [...pointers.values()];
        const dist = Math.hypot(p[0].x - p[1].x, p[0].y - p[1].y);
        if (pinchDist) {
          const r = board.getBoundingClientRect();
          zoomAt(dist / pinchDist, (p[0].x + p[1].x) / 2 - r.left, (p[0].y + p[1].y) / 2 - r.top);
        }
        pinchDist = dist;
      } else if (dragging) {
        tx += e.clientX - lastX; ty += e.clientY - lastY;
        lastX = e.clientX; lastY = e.clientY; apply();
      }
    });
    const endPointer = (e) => {
      pointers.delete(e.pointerId);
      if (pointers.size < 2) pinchDist = 0;
      if (pointers.size === 0) { dragging = false; board.classList.remove('dragging'); }
    };
    board.addEventListener('pointerup', endPointer);
    board.addEventListener('pointercancel', endPointer);

    // controles
    board.querySelector('[data-fb="in"]')?.addEventListener('click', () => zoomAt(1.25));
    board.querySelector('[data-fb="out"]')?.addEventListener('click', () => zoomAt(0.8));
    board.querySelector('[data-fb="fit"]')?.addEventListener('click', fit);

    fit();
    window.addEventListener('resize', fit);
  };

  $$('[data-flowboard]').forEach(buildFlowboard);
})();
