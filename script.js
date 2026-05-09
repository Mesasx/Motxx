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

  $$('table').forEach((table) => {
    const headers = $$('thead th', table).map((th) => th.textContent.trim());
    $$('tbody tr', table).forEach((row) => {
      $$('td', row).forEach((cell, index) => {
        if (headers[index]) cell.dataset.label = headers[index];
      });
    });
  });

  const botRoot = $('[data-contact-bot]');
  if (botRoot) {
    const messages = $('[data-bot-messages]', botRoot);
    const quick = $('[data-bot-quick]', botRoot);
    const form = $('[data-bot-form]', botRoot);
    const input = $('[data-bot-input]', botRoot);
    const progress = $('[data-bot-progress]', botRoot);
    const answers = {};
    let step = 0;

    const questions = [
      {
        key: 'empresa',
        label: 'Empresa',
        text: 'Para empezar: ¿quién sois? Nombre de empresa si quieres ponerlo, sector y tamaño aproximado.',
        quick: ['Prefiero no poner nombre', 'Industrial', 'Servicios profesionales', 'Comercio o retail'],
        placeholder: 'Ej. ingeniería técnica, 8 personas, Castilla-La Mancha',
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
      progress.textContent = `Pregunta ${step + 1} de ${questions.length}`;
      input.placeholder = question.placeholder;
      addMessage(question.text);
      renderQuick(question.quick);
      input.focus();
    };

    const formatSummary = () => questions.map((question, index) => (
      `${index + 1}. ${question.label}\n${answers[question.key] || 'Sin respuesta'}`
    )).join('\n\n');

    const finish = () => {
      progress.textContent = 'Resumen listo';
      quick.innerHTML = '';
      input.disabled = true;
      form.querySelector('button').disabled = true;

      const consent = String(answers.rgpd || '').toLowerCase();
      if (!consent.includes('sí') && !consent.includes('si') && !consent.includes('acepto')) {
        addMessage('Sin consentimiento RGPD no generamos el email. Puedes escribirnos directamente a <a href="mailto:contacto@aimotex.com">contacto@aimotex.com</a>.');
        return;
      }

      const subject = 'Diagnóstico automatizado Motex';
      const body = [
        'DIAGNÓSTICO AUTOMATIZADO MOTEX',
        '',
        formatSummary(),
        '',
        'Consentimiento RGPD: Sí.',
        'Origen: bot conversacional de aimotex.com/contacto/',
      ].join('\n');
      const href = `mailto:contacto@aimotex.com?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`;
      const htmlSummary = questions.map((question) => (
        `<dt>${escapeHtml(question.label)}</dt><dd>${escapeHtml(answers[question.key] || 'Sin respuesta')}</dd>`
      )).join('');

      addMessage(`He preparado un resumen ordenado para que Pedro, Alba y Juan empiecen con contexto.<div class="bot-summary"><dl>${htmlSummary}</dl><a class="btn btn-primary" href="${href}">Enviar resumen a Motex</a><button class="btn btn-secondary" type="button" data-bot-restart>Empezar de nuevo</button></div>`);
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
      addMessage('Arrancamos diagnóstico. Te haré pocas preguntas, pero bien elegidas.');
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
        button.textContent = 'Copiado';
        setTimeout(() => { button.textContent = previous; }, 1200);
      } catch (error) {
        button.textContent = 'Selecciona y copia';
      }
    });
  });
})();
