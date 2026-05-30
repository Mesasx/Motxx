(() => {
  document.documentElement.classList.add('js');

  const $ = (selector, root = document) => root.querySelector(selector);
  const $$ = (selector, root = document) => Array.from(root.querySelectorAll(selector));
  const currentLang = document.documentElement.lang === 'en' ? 'en' : 'es';
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

  const localizedPath = (targetLang) => {
    const { pathname, search, hash } = window.location;
    const cleanPath = pathname.replace(/\/{2,}/g, '/');
    let targetPath;

    if (targetLang === 'en') {
      if (cleanPath === '/en' || cleanPath.startsWith('/en/')) {
        targetPath = cleanPath === '/en' ? '/en/' : cleanPath;
      } else {
        targetPath = cleanPath === '/' ? '/en/' : `/en${cleanPath}`;
      }
    } else {
      targetPath = cleanPath === '/en' || cleanPath === '/en/' ? '/' : cleanPath.replace(/^\/en(?=\/)/, '');
    }

    return `${targetPath}${search}${hash}`;
  };

  const shouldRedirectToEnglish = () => {
    if (currentLang !== 'es' || getStoredLanguage()) return false;
    const preferred = (navigator.languages?.[0] || navigator.language || '').toLowerCase();
    return preferred.startsWith('en');
  };

  if (shouldRedirectToEnglish()) {
    setStoredLanguage('en');
    window.location.replace(localizedPath('en'));
    return;
  }

  const active = document.body.dataset.active;
  if (active) {
    $$(`[data-nav="${active}"]`).forEach((link) => link.classList.add('active'));
  }

  const navToggle = $('#navToggle');
  const navMenu = $('#navMenu');
  if (navMenu) {
    const languageSwitch = document.createElement('div');
    languageSwitch.className = 'language-switch';
    languageSwitch.setAttribute('aria-label', currentLang === 'en' ? 'Language selector' : 'Selector de idioma');
    languageSwitch.innerHTML = `
      <a href="${localizedPath('es')}" hreflang="es" data-lang-choice="es" class="${currentLang === 'es' ? 'active' : ''}">ES</a>
      <span aria-hidden="true">|</span>
      <a href="${localizedPath('en')}" hreflang="en" data-lang-choice="en" class="${currentLang === 'en' ? 'active' : ''}">EN</a>
    `;
    navMenu.appendChild(languageSwitch);
  }
  $$('[data-lang-choice]').forEach((link) => {
    link.addEventListener('click', () => setStoredLanguage(link.dataset.langChoice));
  });

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
    const onScroll = () => {
      const y = window.scrollY || window.pageYOffset;
      header?.classList.toggle('is-stuck', y > 8);
      if (readProgress) {
        const h = document.documentElement.scrollHeight - window.innerHeight;
        readProgress.style.width = (h > 0 ? (y / h) * 100 : 0) + '%';
      }
      toTop?.classList.toggle('show', y > 680);
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
})();
