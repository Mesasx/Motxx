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
})();
