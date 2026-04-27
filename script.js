// =========================================================
// MOTEX — script principal
// =========================================================

// ============ NAVEGACIÓN: efecto scroll ============
const nav = document.getElementById('nav');

window.addEventListener('scroll', () => {
  if (window.pageYOffset > 50) {
    nav.classList.add('scrolled');
  } else {
    nav.classList.remove('scrolled');
  }
});

// ============ MENÚ MÓVIL ============
const navToggle = document.getElementById('navToggle');
const mobileMenu = document.getElementById('mobileMenu');

if (navToggle && mobileMenu) {
  navToggle.addEventListener('click', () => {
    navToggle.classList.toggle('open');
    mobileMenu.classList.toggle('open');
  });

  mobileMenu.querySelectorAll('a').forEach(link => {
    link.addEventListener('click', () => {
      navToggle.classList.remove('open');
      mobileMenu.classList.remove('open');
    });
  });
}

// =========================================================
// ROUTER ENTRE PÁGINAS (home / nosotros)
// =========================================================
// Las secciones con data-page="nosotros" se muestran solo en esa pestaña.
// Cuando el usuario pulsa "Nosotros" en el menú, ocultamos la home y
// mostramos solo esas secciones. La URL usa #nosotros para poder
// compartirse y para que el botón atrás del navegador funcione.

const PAGE_KEYS = ['cursos', 'nosotros']; // Páginas dedicadas dentro de la landing

function getPageFromHash() {
  const hash = (window.location.hash || '').replace('#', '').toLowerCase();
  return PAGE_KEYS.includes(hash) ? hash : 'home';
}

function setPage(page, opts = {}) {
  const { scroll = true, updateHash = true } = opts;

  // Limpiar clases page-* previas
  document.body.classList.forEach(cls => {
    if (cls.startsWith('page-')) document.body.classList.remove(cls);
  });
  document.body.classList.add('page-' + page);

  // Actualizar enlaces activos del nav
  document.querySelectorAll('.nav-links a, .mobile-menu a').forEach(a => {
    const href = a.getAttribute('href') || '';
    const target = href.replace('#', '').toLowerCase();
    if (PAGE_KEYS.includes(target) && page === target) a.classList.add('active');
    else a.classList.remove('active');
  });

  // Actualizar URL sin forzar recarga
  if (updateHash) {
    const targetHash = page === 'home' ? '' : '#' + page;
    if (window.location.hash !== targetHash) {
      if (targetHash) {
        history.pushState({ page }, '', targetHash);
      } else {
        history.pushState({ page }, '', window.location.pathname);
      }
    }
  }

  // Scroll al inicio con animación
  if (scroll) {
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  // Re-disparar reveal en la página nueva (las secciones ocultas no se animaron)
  setTimeout(() => {
    document.querySelectorAll('.reveal:not(.visible)').forEach(el => {
      const rect = el.getBoundingClientRect();
      if (rect.top < window.innerHeight * 1.1) {
        el.classList.add('visible');
      }
    });
  }, 100);
}

// Interceptar clicks a enlaces internos para alternar páginas
document.addEventListener('click', (e) => {
  const link = e.target.closest('a[href^="#"]');
  if (!link) return;

  const href = link.getAttribute('href');
  const targetKey = href.replace('#', '').toLowerCase();

  // Caso 1: click al logo o href="#" → volver a home
  if (href === '#' || href === '') {
    e.preventDefault();
    setPage('home');
    return;
  }

  // Caso 2: click en enlace de pestaña dedicada → cambiar a esa página
  if (PAGE_KEYS.includes(targetKey)) {
    e.preventDefault();
    setPage(targetKey);
    return;
  }

  // Caso 3: click en ancla de la home (servicios, cursos, etc.)
  // Si estamos en una pestaña dedicada, primero volvemos a home y luego hacemos scroll
  if (!document.body.classList.contains('page-home')) {
    const section = document.querySelector(href);
    if (section) {
      e.preventDefault();
      setPage('home', { scroll: false });
      // Scroll a la sección tras el reflow
      setTimeout(() => {
        section.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }, 80);
    }
  }
  // Si ya estamos en home, el navegador hace el scroll por defecto
});

// Soportar botones atrás/adelante del navegador
window.addEventListener('popstate', () => {
  setPage(getPageFromHash(), { updateHash: false });
});

// Al cargar la página, inicializar según el hash de la URL
setPage(getPageFromHash(), { scroll: false, updateHash: false });

// ============ ANIMACIONES AL HACER SCROLL ============
const observerOptions = {
  threshold: 0.1,
  rootMargin: '0px 0px -80px 0px'
};

const observer = new IntersectionObserver((entries) => {
  entries.forEach(entry => {
    if (entry.isIntersecting) {
      entry.target.classList.add('visible');
      observer.unobserve(entry.target);
    }
  });
}, observerOptions);

document.querySelectorAll('.reveal').forEach(el => {
  observer.observe(el);
});

// ============ STAGGER ============
document.querySelectorAll('.services-grid .reveal, .process-grid .reveal, .benefits-grid .reveal, .courses-grid .reveal, .learning-path .reveal').forEach((el, i) => {
  el.style.transitionDelay = `${i * 0.08}s`;
});

// ============ PARALLAX SUAVE EN AURORA ============
const auroraBlobs = document.querySelectorAll('.aurora-blob');

window.addEventListener('mousemove', (e) => {
  const x = (e.clientX / window.innerWidth - 0.5) * 20;
  const y = (e.clientY / window.innerHeight - 0.5) * 20;

  auroraBlobs.forEach((blob, i) => {
    const speed = (i + 1) * 0.5;
    blob.style.transform = `translate(${x * speed}px, ${y * speed}px)`;
  });
});

// =========================================================
// LABORATORIO INTERACTIVO + CALCULADORA
// =========================================================
const AUTOMATION_DEMOS = {
  cliente: {
    badge: 'Flujo 01',
    title: 'Atención al cliente inteligente',
    nodes: [
      ['1. Cliente pregunta', 'Web, Telegram o WhatsApp reciben la consulta al instante.'],
      ['2. IA entiende', 'Detecta intención, urgencia, idioma, datos clave y probabilidad de compra.'],
      ['3. Sistema actúa', 'Responde, crea lead, agenda reunión y avisa al equipo comercial.']
    ],
    result: 'Clientes atendidos al instante y oportunidades comerciales registradas sin tocar una hoja de cálculo.'
  },
  correo: {
    badge: 'Flujo 02',
    title: 'Correo inteligente',
    nodes: [
      ['1. Entra un email', 'La bandeja recibe solicitudes, facturas, incidencias o presupuestos.'],
      ['2. IA clasifica', 'Resume, etiqueta, detecta prioridad y propone respuesta con tu tono.'],
      ['3. Automatización ejecuta', 'Crea tarea, responde borrador, archiva y avisa solo si es importante.']
    ],
    result: 'Bandeja limpia, respuestas más rápidas y menos interrupciones durante el día.'
  },
  contenido: {
    badge: 'Flujo 03',
    title: 'Contenido para redes',
    nodes: [
      ['1. Idea o noticia', 'Introduces una idea, producto, promoción o tendencia del sector.'],
      ['2. IA crea piezas', 'Genera copies, carruseles, guiones cortos y variaciones por red social.'],
      ['3. Calendario listo', 'Se organiza el calendario y se prepara publicación o revisión humana.']
    ],
    result: 'Más presencia digital sin depender de inspiración diaria ni perder horas escribiendo.'
  },
  informes: {
    badge: 'Flujo 04',
    title: 'Informes automáticos',
    nodes: [
      ['1. Datos conectados', 'Ventas, reservas, formularios, CRM o hojas de cálculo se sincronizan.'],
      ['2. IA analiza', 'Detecta tendencias, anomalías, clientes calientes y oportunidades.'],
      ['3. Informe enviado', 'Recibes un resumen accionable por email o Telegram cada semana.']
    ],
    result: 'Decisiones más rápidas porque ves lo importante sin abrir cinco herramientas distintas.'
  }
};

function renderAutomationDemo(key) {
  const demo = AUTOMATION_DEMOS[key];
  const badge = document.getElementById('demoBadge');
  const title = document.getElementById('demoTitle');
  const workflow = document.getElementById('demoWorkflow');
  const result = document.getElementById('demoResult');
  if (!demo || !badge || !title || !workflow || !result) return;

  badge.textContent = demo.badge;
  title.textContent = demo.title;
  workflow.innerHTML = demo.nodes.map((node, index) => `
    <div class="workflow-node"><strong>${node[0]}</strong><p>${node[1]}</p></div>
    ${index < demo.nodes.length - 1 ? '<div class="workflow-line"></div>' : ''}
  `).join('');
  result.textContent = demo.result;
}

document.querySelectorAll('[data-demo]').forEach(btn => {
  btn.addEventListener('click', () => {
    document.querySelectorAll('[data-demo]').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    renderAutomationDemo(btn.getAttribute('data-demo'));
  });
});

const roiEls = {
  tasks: document.getElementById('roiTasks'),
  minutes: document.getElementById('roiMinutes'),
  cost: document.getElementById('roiCost'),
  tasksValue: document.getElementById('roiTasksValue'),
  minutesValue: document.getElementById('roiMinutesValue'),
  costValue: document.getElementById('roiCostValue'),
  hours: document.getElementById('roiHours'),
  money: document.getElementById('roiMoney')
};

function formatEuro(value) {
  return Math.round(value).toLocaleString('es-ES') + ' €';
}

function updateRoiCalculator() {
  if (!roiEls.tasks || !roiEls.minutes || !roiEls.cost) return;

  const tasks = Number(roiEls.tasks.value);
  const minutes = Number(roiEls.minutes.value);
  const cost = Number(roiEls.cost.value);
  const automationFactor = 0.8;
  const monthlyHours = (tasks * minutes * 22 / 60) * automationFactor;
  const monthlyMoney = monthlyHours * cost;

  roiEls.tasksValue.textContent = tasks;
  roiEls.minutesValue.textContent = minutes;
  roiEls.costValue.textContent = `${cost} €`;
  roiEls.hours.textContent = `${Math.round(monthlyHours).toLocaleString('es-ES')} h`;
  roiEls.money.textContent = formatEuro(monthlyMoney);
}

['tasks', 'minutes', 'cost'].forEach(key => {
  if (roiEls[key]) roiEls[key].addEventListener('input', updateRoiCalculator);
});
updateRoiCalculator();


// =========================================================
// DATOS DE CURSOS
// =========================================================
const COURSES = {
  pyme: {
    name: 'IA para PYMEs y autónomos',
    desc: '8 horas de contenido guiado, práctica a tu ritmo, plataforma personalizada y mentoría semanal de dudas.',
    price: 197
  },
  n8n: {
    name: 'Automatiza tu negocio con n8n + IA',
    desc: '16 horas prácticas, flujos n8n reutilizables, ejercicios sobre tu negocio y mentoría personalizada cada semana.',
    price: 397
  }
};

// =========================================================
// GESTOR GENÉRICO DE MODALES
// =========================================================
function openModal(modalId) {
  const m = document.getElementById(modalId);
  if (!m) return;
  m.classList.add('open');
  m.setAttribute('aria-hidden', 'false');
  document.body.classList.add('modal-open');
  // Enfocar el primer campo útil tras abrir
  setTimeout(() => {
    const firstInput = m.querySelector('input:not([type="hidden"]):not([type="radio"]):not([type="checkbox"]), textarea, select');
    if (firstInput) firstInput.focus();
  }, 150);
}

function closeModal(modalId) {
  const m = document.getElementById(modalId);
  if (!m) return;
  m.classList.remove('open');
  m.setAttribute('aria-hidden', 'true');
  document.body.classList.remove('modal-open');
}

// Clicks globales para data-close-modal y data-open-contact
document.addEventListener('click', (e) => {
  const closeBtn = e.target.closest('[data-close-modal]');
  if (closeBtn) {
    const modal = closeBtn.closest('.modal');
    if (modal) closeModal(modal.id);
    return;
  }

  const openContactBtn = e.target.closest('[data-open-contact]');
  if (openContactBtn) {
    e.preventDefault();
    const topic = openContactBtn.getAttribute('data-contact-topic') || 'general';
    openSmartChatFromTopic(topic);
    return;
  }
});

// Cerrar modales con Escape
document.addEventListener('keydown', (e) => {
  if (e.key !== 'Escape') return;
  document.querySelectorAll('.modal.open').forEach(m => closeModal(m.id));
});

// =========================================================
// MODAL DE CHECKOUT (compra de curso)
// =========================================================
const checkoutModal     = document.getElementById('checkoutModal');
const checkoutForm      = document.getElementById('checkoutForm');
const summaryCourseName = document.getElementById('summaryCourseName');
const summaryCourseDesc = document.getElementById('summaryCourseDesc');
const summaryCoursePrice= document.getElementById('summaryCoursePrice');
const summaryTotal      = document.getElementById('summaryTotal');
const hiddenCourse      = document.getElementById('hiddenCourse');
const hiddenPrice       = document.getElementById('hiddenPrice');
const hiddenPayment     = document.getElementById('hiddenPayment');
const formNext          = document.getElementById('formNext');
const payBtnLabel       = document.getElementById('payBtnLabel');

function openCheckoutModal(courseKey) {
  const course = COURSES[courseKey];
  if (!course) return;

  // Rellenar resumen
  summaryCourseName.textContent = course.name;
  summaryCourseDesc.textContent = course.desc;
  summaryCoursePrice.textContent = course.price + ' €';
  summaryTotal.textContent = course.price + ' €';
  hiddenCourse.value = course.name;
  hiddenPrice.value = course.price + ' €';
  if (payBtnLabel) payBtnLabel.textContent = 'Pagar ' + course.price + ' €';

  // URL de redirección post-submit (FormSubmit redirige aquí)
  formNext.value = window.location.origin + window.location.pathname + '?pago=ok';

  // Reset al paso 1
  goToStep(1);

  openModal('checkoutModal');
}

// Enganchar botones de inscripción a curso
document.querySelectorAll('[data-course]').forEach(btn => {
  btn.addEventListener('click', (e) => {
    e.preventDefault();
    const key = btn.getAttribute('data-course');
    openCheckoutModal(key);
  });
});

// Navegación entre pasos
function goToStep(n) {
  checkoutForm.querySelectorAll('.form-step').forEach(s => s.classList.remove('active'));
  const target = checkoutForm.querySelector(`[data-step="${n}"]`);
  if (target) target.classList.add('active');

  // Stepper
  checkoutForm.closest('.modal-body').querySelectorAll('[data-step-indicator]').forEach(ind => {
    const num = parseInt(ind.getAttribute('data-step-indicator'), 10);
    ind.classList.remove('active', 'done');
    if (num === n) ind.classList.add('active');
    else if (num < n) ind.classList.add('done');
  });

  // Scroll al inicio del modal body
  const body = checkoutForm.closest('.modal-body');
  if (body) body.scrollTop = 0;
}

function validateStep(n) {
  const step = checkoutForm.querySelector(`[data-step="${n}"]`);
  if (!step) return true;

  let valid = true;
  step.querySelectorAll('input, select, textarea').forEach(el => {
    if (el.hasAttribute('required') && !el.checkValidity()) {
      valid = false;
      el.reportValidity();
    }
  });
  // Validar que haya una radio seleccionada en el paso (si hay grupo radio required)
  const radioGroups = new Set();
  step.querySelectorAll('input[type="radio"][required]').forEach(r => radioGroups.add(r.name));
  radioGroups.forEach(name => {
    const anyChecked = step.querySelector(`input[type="radio"][name="${name}"]:checked`);
    if (!anyChecked) {
      valid = false;
      const first = step.querySelector(`input[type="radio"][name="${name}"]`);
      if (first) first.reportValidity();
    }
  });
  return valid;
}

// Botones siguiente / anterior
checkoutForm.querySelectorAll('[data-next-step]').forEach(btn => {
  btn.addEventListener('click', () => {
    const currentStep = checkoutForm.querySelector('.form-step.active');
    const currentNum = parseInt(currentStep.getAttribute('data-step'), 10);
    if (!validateStep(currentNum)) return;
    goToStep(currentNum + 1);
  });
});

checkoutForm.querySelectorAll('[data-prev-step]').forEach(btn => {
  btn.addEventListener('click', () => {
    const currentStep = checkoutForm.querySelector('.form-step.active');
    const currentNum = parseInt(currentStep.getAttribute('data-step'), 10);
    goToStep(Math.max(1, currentNum - 1));
  });
});

// Submit del checkout: guardamos método de pago y dejamos que FormSubmit envíe
checkoutForm.addEventListener('submit', (e) => {
  // Guardar método de pago seleccionado en el hidden field
  const selected = checkoutForm.querySelector('input[name="payment_method"]:checked');
  if (selected) {
    const labels = {
      card: 'Tarjeta',
      apple_pay: 'Apple Pay',
      google_pay: 'Google Pay',
      paypal: 'PayPal',
      transfer: 'Transferencia bancaria'
    };
    hiddenPayment.value = labels[selected.value] || selected.value;
  }
  // FormSubmit se encarga del envío
});

// Al cargar la página, si la URL trae ?pago=ok mostramos paso 4 (éxito)
if (window.location.search.includes('pago=ok')) {
  openModal('checkoutModal');
  goToStep(4);
  // Limpiar la query
  history.replaceState(null, '', window.location.pathname);
}

// =========================================================
// MODAL DE CONTACTO (opción secundaria por email)
// =========================================================
const contactForm   = document.getElementById('contactForm');
const contactKicker = document.getElementById('contactKicker');
const contactTitle  = document.getElementById('contactTitle');
const hiddenTopic   = document.getElementById('hiddenTopic');
const contactFormNext = document.getElementById('contactFormNext');

const CONTACT_TOPICS = {
  general: {
    kicker: 'Contacto por email',
    title: 'Enviar consulta clásica',
    topic: 'Consulta general'
  },
  consulta: {
    kicker: 'Contacto por email',
    title: 'Enviar solicitud de llamada',
    topic: 'Solicitud de llamada'
  },
  presupuesto: {
    kicker: 'Opción secundaria',
    title: 'Enviar solicitud clásica por email',
    topic: 'Solicitud de presupuesto por formulario'
  },
  'curso-pyme': {
    kicker: 'Información de curso',
    title: 'Curso IA para PYMEs y autónomos',
    topic: 'Info: curso IA para PYMEs (197 €)'
  },
  'curso-n8n': {
    kicker: 'Información de curso',
    title: 'Curso Automatiza con n8n + IA',
    topic: 'Info: curso n8n + IA (397 €)'
  },
  'curso-incompany': {
    kicker: 'Formación in-company',
    title: 'Enviar solicitud clásica por email',
    topic: 'Presupuesto formación in-company por formulario'
  }
};

function openContactModal(topic) {
  const t = CONTACT_TOPICS[topic] || CONTACT_TOPICS.general;
  if (contactKicker) contactKicker.textContent = t.kicker;
  if (contactTitle)  contactTitle.textContent  = t.title;
  if (hiddenTopic)   hiddenTopic.value         = t.topic;
  if (contactFormNext) contactFormNext.value = window.location.origin + window.location.pathname + '?consulta=ok';
  openModal('contactModal');
}

if (window.location.search.includes('consulta=ok')) {
  setTimeout(() => {
    openModal('contactModal');
    if (contactForm) {
      const body = contactForm.closest('.modal-body');
      if (body) {
        body.innerHTML = `
          <div class="form-step-success active" style="display:flex;flex-direction:column;align-items:center;gap:1rem;text-align:center;padding:1rem 0;">
            <div class="success-icon">
              <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>
            </div>
            <h2 class="modal-title">¡Mensaje recibido!</h2>
            <p class="modal-subtitle">Gracias por contactar con Motex. Te responderemos en menos de 24 horas hábiles al correo que nos has facilitado.</p>
            <button type="button" class="btn btn-primary" data-close-modal style="margin-top: 0.5rem;">Cerrar</button>
          </div>
        `;
      }
    }
  }, 300);
  history.replaceState(null, '', window.location.pathname);
}

// =========================================================
// CHATBOT FULLSCREEN + PRESUPUESTO INTELIGENTE
// =========================================================
const CHATBOT = {
  TELEGRAM: 'https://t.me/MotexBot',
  EMAIL: 'mailto:contacto@aimotex.com'
};

const cb         = document.getElementById('chatbot');
const cbFab      = document.getElementById('chatbotFab');
const cbPanel    = document.getElementById('chatbotPanel');
const cbClose    = document.getElementById('chatbotClose');
const cbMessages = document.getElementById('chatbotMessages');
const cbQuick    = document.getElementById('chatbotQuickReplies');
const cbForm     = document.getElementById('chatbotForm');
const cbInput    = document.getElementById('chatbotInput');

let cbOpened = false;
let botIsFullscreen = false;
let quoteState = null;
let leadState = null;
let lastQuoteResult = null;

function normalize(text) {
  return String(text || '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[¿¡?!.,;:()]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function htmlEscape(text) {
  return String(text || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

function money(n) {
  return new Intl.NumberFormat('es-ES', { maximumFractionDigits: 0 }).format(n) + ' €';
}

function roundTo10(n) {
  return Math.round(n / 10) * 10;
}

function toggleChatbot(force, opts = {}) {
  if (!cb || !cbFab || !cbPanel) return;
  const shouldOpen = typeof force === 'boolean' ? force : !cb.classList.contains('open');
  const fullscreen = Boolean(opts.fullscreen || botIsFullscreen);

  if (shouldOpen && fullscreen) {
    botIsFullscreen = true;
    cb.classList.add('fullscreen');
  }

  cb.classList.toggle('open', shouldOpen);
  cbFab.setAttribute('aria-expanded', String(shouldOpen));
  cbPanel.setAttribute('aria-hidden', String(!shouldOpen));
  document.body.classList.toggle('chatbot-modal-open', shouldOpen && botIsFullscreen);

  if (!shouldOpen) {
    botIsFullscreen = false;
    cb.classList.remove('fullscreen');
    document.body.classList.remove('chatbot-modal-open');
  }

  if (shouldOpen && !cbOpened && !opts.skipWelcome) {
    cbOpened = true;
    setTimeout(() => {
      addBotMessage(`
        <div class="bot-welcome-card">
          <span class="chat-budget-kicker">MotexBot</span>
          <h4>Te ayudo sin formularios largos</h4>
          <p>Puedo calcular un presupuesto aproximado, hacer un diagnóstico rápido, explicarte los cursos o preparar un resumen para enviar al equipo.</p>
        </div>
      `);
      renderQuickReplies(['Presupuesto aproximado', 'Diagnóstico rápido', 'Ver cursos', 'Telegram', 'Email clásico']);
    }, 250);
  }

  if (shouldOpen) {
    setTimeout(() => cbInput && cbInput.focus(), 300);
  }
}

function openFullscreenChat(skipWelcome = true) {
  botIsFullscreen = true;
  if (skipWelcome) cbOpened = true;
  toggleChatbot(true, { fullscreen: true, skipWelcome });
}

function addBotMessage(html) {
  if (!cbMessages) return;
  const div = document.createElement('div');
  div.className = 'chat-msg chat-msg-bot';
  div.innerHTML = html;
  cbMessages.appendChild(div);
  scrollMessagesToBottom();
}

function addUserMessage(text) {
  if (!cbMessages) return;
  const div = document.createElement('div');
  div.className = 'chat-msg chat-msg-user';
  div.textContent = text;
  cbMessages.appendChild(div);
  scrollMessagesToBottom();
}

function showTyping() {
  if (!cbMessages || document.getElementById('chatTyping')) return;
  const div = document.createElement('div');
  div.className = 'chat-typing';
  div.id = 'chatTyping';
  div.innerHTML = '<span></span><span></span><span></span>';
  cbMessages.appendChild(div);
  scrollMessagesToBottom();
}

function hideTyping() {
  const t = document.getElementById('chatTyping');
  if (t) t.remove();
}

function scrollMessagesToBottom() {
  if (cbMessages) cbMessages.scrollTop = cbMessages.scrollHeight;
}

function renderQuickReplies(labels) {
  if (!cbQuick) return;
  cbQuick.innerHTML = '';
  if (!labels || !labels.length) return;

  labels.forEach(raw => {
    let actionKey = null;
    let label = raw;
    if (typeof raw === 'string' && raw.includes('|')) {
      const parts = raw.split('|');
      if (parts[0].startsWith('__')) {
        actionKey = parts[0];
        label = parts.slice(1).join('|');
      }
    }

    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'quick-reply';
    btn.textContent = label;
    btn.addEventListener('click', () => {
      if (actionKey) {
        runSpecialAction(actionKey, label);
        return;
      }
      const mapped = QUICK_MAP[normalize(label)] || label;
      if (typeof mapped === 'string' && mapped.startsWith('__')) {
        runSpecialAction(mapped, label);
      } else {
        handleUserMessage(mapped, label);
      }
    });
    cbQuick.appendChild(btn);
  });
}

const QUICK_MAP = {
  'presupuesto aproximado': '__quote_start__',
  'calcular presupuesto': '__quote_start__',
  'diagnostico rapido': '__diagnostic_start__',
  'diagnóstico rápido': '__diagnostic_start__',
  'ver cursos': '__go_cursos__',
  'cursos': '__go_cursos__',
  'precios': '__quote_start__',
  'contactar': '__quote_start__',
  'telegram': '__open_telegram__',
  'email': '__open_email__',
  'email clasico': '__open_email_form__',
  'email clásico': '__open_email_form__',
  'formulario clasico': '__open_email_form__',
  'formulario clásico': '__open_email_form__',
  'enviar al equipo': '__lead_start__',
  'guardar y enviar': '__lead_start__',
  'nueva estimacion': '__quote_start__',
  'nueva estimación': '__quote_start__',
  'curso ia pymes': '__course_pyme__',
  'curso n8n + ia': '__course_n8n__',
  'in company': '__course_company__',
  'in-company': '__course_company__',
  'inscribirme al curso pymes': '__open_curso_pyme__',
  'reservar plaza n8n': '__open_curso_n8n__'
};

const INTENTS = [
  {
    id: 'saludo',
    patterns: ['hola', 'buenas', 'buenos dias', 'buenas tardes', 'buenas noches', 'hey', 'que tal', 'buen dia'],
    reply: '¡Hola! Soy MotexBot. Puedo hacerte un presupuesto aproximado en modo chat, sin formulario largo, o explicarte los cursos y automatizaciones.',
    quick: ['Presupuesto aproximado', 'Diagnóstico rápido', 'Ver cursos', 'Telegram']
  },
  {
    id: 'servicios',
    patterns: ['servicio', 'automatizar', 'automatizacion', 'automatización', 'que haceis', 'que ofreceis', 'que es motex', 'agente', 'bot', 'ia para empresa'],
    reply: 'Automatizamos sistemas informáticos y procesos de empresa: atención al cliente, correos, documentos, reservas, presupuestos, CRM, informes, redes y flujos con n8n. La idea es convertir la IA en un empleado digital que trabaje 24/7.',
    quick: ['Presupuesto aproximado', 'Diagnóstico rápido', 'Ver cursos']
  },
  {
    id: 'cursos',
    patterns: ['curso', 'cursos', 'formacion', 'formación', 'aprender', 'clases', 'mentoria', 'mentorías', 'mentorias', 'plataforma'],
    reply: 'Nuestros cursos son personalizados: plataforma adaptada al cliente, sesiones a tu ritmo, práctica guiada, preguntas y una mentoría semanal reservada para resolver dudas. El objetivo no es aprender teoría: es hacer que la IA trabaje como un empleado más y te ahorre horas reales.',
    quick: ['Curso IA PYMEs', 'Curso n8n + IA', 'In-company', 'Inscribirme al curso PYMEs']
  },
  {
    id: 'curso_pyme',
    patterns: ['pyme', 'pymes', 'autonomo', 'autónomo', 'principiante', 'basico', 'básico', 'iniciacion', 'iniciación'],
    reply: 'El curso IA para PYMEs y autónomos cuesta 197 €. Incluye plataforma personalizada, sesiones a tu ritmo, ejercicios prácticos, prompts profesionales y mentoría semanal. Está pensado para ahorrar trabajo desde la primera semana.',
    quick: ['Inscribirme al curso PYMEs', 'Curso n8n + IA', 'Presupuesto aproximado']
  },
  {
    id: 'curso_n8n',
    patterns: ['n8n', 'workflow', 'flujos', 'flujo', 'automatiza tu negocio', 'zapier', 'make'],
    reply: 'El curso n8n + IA cuesta 397 € en lanzamiento. Aprendes a conectar IA con email, formularios, hojas de cálculo, CRM, calendario, Telegram/WhatsApp y documentos. Terminas con flujos reales para tu negocio.',
    quick: ['Reservar plaza n8n', 'Curso IA PYMEs', 'In-company']
  },
  {
    id: 'precios',
    patterns: ['precio', 'precios', 'cuesta', 'coste', 'tarifa', 'cuanto vale', 'cuanto cuesta', 'presupuesto', 'cotizacion', 'estimacion'],
    reply: 'Para no soltarte una tabla fría, lo mejor es calcularlo según tu caso. El bot te pregunta por proceso, volumen, herramientas y complejidad, y te da un rango de setup y mantenimiento.',
    quick: ['Presupuesto aproximado', 'Email clásico', 'Telegram']
  },
  {
    id: 'contacto',
    patterns: ['contacto', 'contactar', 'hablar', 'persona', 'humano', 'correo', 'email', 'telefono', 'teléfono', 'telegram'],
    reply: `Puedes seguir aquí con el bot, hablar por <a href="${CHATBOT.TELEGRAM}" target="_blank" rel="noopener">Telegram</a> o enviar la solicitud clásica por email. Pero para presupuesto rápido, lo mejor es el chat.`,
    quick: ['Presupuesto aproximado', 'Telegram', 'Email clásico']
  },
  {
    id: 'rgpd',
    patterns: ['rgpd', 'datos', 'privacidad', 'seguridad', 'gdpr', 'proteccion de datos', 'protección de datos'],
    reply: 'Diseñamos las automatizaciones con criterio de privacidad: accesos mínimos, proveedores fiables, revisión de datos sensibles y enfoque RGPD desde el inicio. En proyectos con datos delicados se define una arquitectura más controlada.',
    quick: ['Presupuesto aproximado', 'Telegram']
  },
  {
    id: 'plazos',
    patterns: ['tiempo', 'plazo', 'cuando estaria', 'cuanto tarda', 'duracion', 'urgente', 'esta semana'],
    reply: 'Un bot sencillo puede salir en pocos días. Un flujo con varias herramientas suele irse a 1-4 semanas. Si es urgente, el cotizador añade prioridad y te da una estimación más realista.',
    quick: ['Presupuesto aproximado', 'Diagnóstico rápido']
  },
  {
    id: 'gracias',
    patterns: ['gracias', 'muchas gracias', 'perfecto', 'genial', 'vale', 'ok'],
    reply: '¡Perfecto! Cuando quieras, te calculo el presupuesto o te llevo a los cursos.',
    quick: ['Presupuesto aproximado', 'Ver cursos']
  }
];

const FALLBACK_REPLIES = [
  'Puedo ayudarte con eso. Para afinar, dime qué proceso quieres automatizar: clientes, correos, reservas, facturas, informes, redes o varios procesos.',
  'Te entiendo. Para darte una respuesta útil, lo mejor es estimarlo en modo presupuesto. Son pocas preguntas y te doy un rango al momento.',
  'No quiero inventarme una respuesta genérica. Puedo calcular una estimación aproximada con tus respuestas y después, si quieres, enviarla al equipo.'
];
const FALLBACK_QUICK = ['Presupuesto aproximado', 'Diagnóstico rápido', 'Ver cursos', 'Email clásico'];

function matchIntent(userText) {
  const clean = normalize(userText);
  if (/\b(inscribir|reservar|comprar|apuntar)\b/.test(clean)) {
    if (clean.includes('n8n')) return { reply: 'Te abro el checkout del curso n8n + IA.', quick: ['__open_curso_n8n__|Abrir checkout n8n'] };
    return { reply: 'Te abro el checkout del curso IA para PYMEs.', quick: ['__open_curso_pyme__|Abrir checkout PYMEs'] };
  }
  for (const intent of INTENTS) {
    if (intent.patterns.some(pattern => clean.includes(normalize(pattern)))) return intent;
  }
  return null;
}

const QUOTE_BASE = {
  chatbot:  { label: 'Chatbot web inteligente', setup: 149, monthly: 39, desc: 'FAQ, captación de leads y derivación a contacto' },
  whatsapp: { label: 'Bot WhatsApp / Telegram', setup: 249, monthly: 59, desc: 'respuestas, cualificación y avisos al equipo' },
  email:    { label: 'Correo + documentos', setup: 299, monthly: 69, desc: 'clasificación, resúmenes, borradores y extracción de datos' },
  reservas: { label: 'Reservas y agenda', setup: 349, monthly: 79, desc: 'citas, recordatorios, confirmaciones y disponibilidad' },
  finance:  { label: 'Presupuestos, facturas y cobros', setup: 390, monthly: 89, desc: 'generación de presupuestos, seguimiento y avisos' },
  reports:  { label: 'Informes y análisis con IA', setup: 390, monthly: 89, desc: 'informes automáticos, datos y conclusiones accionables' },
  content:  { label: 'Contenido y redes sociales', setup: 290, monthly: 69, desc: 'ideas, calendarios, textos y automatización de publicaciones' },
  full:     { label: 'Sistema completo multi-proceso', setup: 590, monthly: 119, desc: 'varios flujos conectados trabajando como empleado digital' }
};

const QUOTE_STEPS = ['goal', 'volume', 'integrations', 'complexity', 'timeline'];

function classifyGoal(text) {
  const t = normalize(text);
  if (/(whatsapp|telegram|mensaje|dm|chat de clientes|instagram|redes sociales.*responder)/.test(t)) return 'whatsapp';
  if (/(correo|email|gmail|outlook|documento|pdf|contrato|factura recibida|inbox)/.test(t)) return 'email';
  if (/(reserva|reservas|cita|citas|agenda|calendar|calendario|confirmacion|recordatorio)/.test(t)) return 'reservas';
  if (/(presupuesto|factura|facturacion|cobro|pago|recibo|albaran)/.test(t)) return 'finance';
  if (/(informe|dashboard|excel|sheet|datos|analisis|analítica|metricas|reporte)/.test(t)) return 'reports';
  if (/(contenido|publicacion|post|instagram|linkedin|tiktok|marketing|redes)/.test(t)) return 'content';
  if (/(todo|varios|muchos|empresa entera|sistema completo|crm|erp|pipeline)/.test(t)) return 'full';
  if (/(chatbot|chat bot|web|faq|preguntas|lead|leads|cliente)/.test(t)) return 'chatbot';
  return 'full';
}

function classifyVolume(text) {
  const t = normalize(text);
  const numbers = (t.match(/\d+/g) || []).map(Number);
  const max = numbers.length ? Math.max(...numbers) : 0;
  if (max >= 1000 || /(muy alto|miles|muchisimo|muchísimo|masivo)/.test(t)) return 'very_high';
  if (max >= 300 || /(alto|mucho|bastante|diario|todos los dias|todos los días)/.test(t)) return 'high';
  if (max >= 50 || /(medio|normal|semanal|varias veces)/.test(t)) return 'medium';
  return 'low';
}

function classifyIntegrations(text) {
  const t = normalize(text);
  const numbers = (t.match(/\d+/g) || []).map(Number);
  const max = numbers.length ? Math.max(...numbers) : 0;
  if (max >= 4 || /(crm|erp|api|base de datos|varias|muchas|hubspot|salesforce|odoo|holded|stripe|shopify|woocommerce)/.test(t)) return 'many';
  if (max >= 2 || /(dos|tres|2|3|gmail.*sheets|calendar|excel|drive|notion|trello|slack)/.test(t)) return 'few';
  return 'one';
}

function classifyComplexity(text) {
  const t = normalize(text);
  if (/(avanzado|complejo|a medida|api|crm|documentos|varias condiciones|multi|muchas reglas|legal|sanitario|sensible)/.test(t)) return 'advanced';
  if (/(pro|profesional|bien hecho|marca|completo|pulido|serio|empresa)/.test(t)) return 'pro';
  return 'mvp';
}

function classifyTimeline(text) {
  const t = normalize(text);
  if (/(urgente|esta semana|ya|cuanto antes|rapido|rápido|hoy|manana|mañana)/.test(t)) return 'urgent';
  if (/(mes|sin prisa|cuando se pueda|tranquilo)/.test(t)) return 'relaxed';
  return 'standard';
}

function describeChoice(step, value) {
  const maps = {
    goal: {
      chatbot: 'chatbot web', whatsapp: 'WhatsApp/Telegram', email: 'correo y documentos', reservas: 'reservas y agenda', finance: 'presupuestos/facturas', reports: 'informes', content: 'contenido y redes', full: 'varios procesos'
    },
    volume: { low: 'volumen bajo', medium: 'volumen medio', high: 'volumen alto', very_high: 'volumen muy alto' },
    integrations: { one: '1 herramienta', few: '2-3 herramientas', many: '4+ herramientas/CRM/API' },
    complexity: { mvp: 'MVP rápido', pro: 'pro profesional', advanced: 'avanzado a medida' },
    timeline: { relaxed: 'sin urgencia', standard: 'plazo normal', urgent: 'prioritario/urgente' }
  };
  return maps[step]?.[value] || value;
}

function startQuoteWizard(displayLabel = 'Presupuesto aproximado') {
  openFullscreenChat();
  quoteState = {
    active: true,
    stepIndex: 0,
    answers: {},
    raw: []
  };
  leadState = null;
  lastQuoteResult = null;
  addUserMessage(displayLabel);
  addBotMessage(`
    <div class="quote-progress"><span style="width: 18%"></span></div>
    <strong>Vamos a calcularlo en modo chat.</strong><br>
    Primera pregunta: ¿qué quieres automatizar? Puedes pulsar una opción o escribirlo con tus palabras.
  `);
  renderQuickReplies([
    '__quote_goal_chatbot__|Chatbot web',
    '__quote_goal_whatsapp__|WhatsApp/Telegram',
    '__quote_goal_email__|Correos/documentos',
    '__quote_goal_reservas__|Reservas/agenda',
    '__quote_goal_finance__|Presupuestos/facturas',
    '__quote_goal_full__|Varios procesos'
  ]);
}

function startDiagnostic() {
  openFullscreenChat();
  addUserMessage('Diagnóstico rápido');
  addBotMessage('Perfecto: el diagnóstico rápido no debe mandarte a un formulario. Lo hacemos aquí. Dime en una frase qué tarea repetitiva te roba más tiempo cada semana.');
  quoteState = { active: true, stepIndex: 0, answers: {}, raw: [], diagnostic: true };
  renderQuickReplies([
    '__quote_goal_email__|Correos',
    '__quote_goal_whatsapp__|Clientes/WhatsApp',
    '__quote_goal_reservas__|Reservas',
    '__quote_goal_finance__|Presupuestos',
    '__quote_goal_reports__|Informes',
    '__quote_goal_full__|Varias tareas'
  ]);
}

function askQuoteStep() {
  const step = QUOTE_STEPS[quoteState.stepIndex];
  const progress = Math.min(94, 18 + quoteState.stepIndex * 18);
  if (step === 'volume') {
    addBotMessage(`<div class="quote-progress"><span style="width:${progress}%"></span></div>¿Qué volumen aproximado tiene al mes? Si no lo sabes, dime algo como “pocos”, “unos 100”, “más de 300” o “muchísimos”.`);
    renderQuickReplies(['__quote_volume_low__|Bajo (<50/mes)', '__quote_volume_medium__|Medio (50-300)', '__quote_volume_high__|Alto (+300)', '__quote_volume_very_high__|Muy alto (+1000)']);
  } else if (step === 'integrations') {
    addBotMessage(`<div class="quote-progress"><span style="width:${progress}%"></span></div>¿Cuántas herramientas habría que conectar? Por ejemplo web, Gmail, Sheets, Calendar, CRM, WhatsApp, Stripe, Shopify...`);
    renderQuickReplies(['__quote_integrations_one__|1 herramienta', '__quote_integrations_few__|2-3 herramientas', '__quote_integrations_many__|4+ / CRM / API']);
  } else if (step === 'complexity') {
    addBotMessage(`<div class="quote-progress"><span style="width:${progress}%"></span></div>¿Qué nivel quieres para la primera versión?`);
    renderQuickReplies(['__quote_complexity_mvp__|MVP barato y rápido', '__quote_complexity_pro__|Pro profesional', '__quote_complexity_advanced__|Avanzado a medida']);
  } else if (step === 'timeline') {
    addBotMessage(`<div class="quote-progress"><span style="width:${progress}%"></span></div>Última: ¿lo necesitas con urgencia o con un plazo normal?`);
    renderQuickReplies(['__quote_timeline_relaxed__|Sin prisa', '__quote_timeline_standard__|2-4 semanas', '__quote_timeline_urgent__|Lo necesito ya']);
  }
}

function calculateQuote() {
  const a = quoteState.answers;
  const base = QUOTE_BASE[a.goal || 'full'];
  const volumeAdd = {
    low: { setup: 0, monthly: 0 },
    medium: { setup: 80, monthly: 20 },
    high: { setup: 180, monthly: 40 },
    very_high: { setup: 350, monthly: 75 }
  }[a.volume || 'medium'];
  const integrationsAdd = {
    one: { setup: 0, monthly: 0 },
    few: { setup: 120, monthly: 20 },
    many: { setup: 280, monthly: 50 }
  }[a.integrations || 'few'];
  const complexityAdd = {
    mvp: { setup: 0, monthly: 0 },
    pro: { setup: 160, monthly: 30 },
    advanced: { setup: 420, monthly: 80 }
  }[a.complexity || 'pro'];
  const timelineAdd = a.timeline === 'urgent' ? 1.15 : 1;

  let setup = (base.setup + volumeAdd.setup + integrationsAdd.setup + complexityAdd.setup) * timelineAdd;
  let monthly = base.monthly + volumeAdd.monthly + integrationsAdd.monthly + complexityAdd.monthly;

  // Descuento de lanzamiento para mantener precios agresivos frente a mercado.
  setup = roundTo10(setup * 0.9);
  monthly = roundTo10(monthly);

  const setupLow = Math.max(149, roundTo10(setup * 0.88));
  const setupHigh = Math.max(setupLow + 40, roundTo10(setup * 1.18));
  const monthlyLow = Math.max(39, roundTo10(monthly * 0.9));
  const monthlyHigh = Math.max(monthlyLow, roundTo10(monthly * 1.15));

  return {
    base,
    setupLow,
    setupHigh,
    monthlyLow,
    monthlyHigh,
    summary: `Proyecto: ${base.label}. Volumen: ${describeChoice('volume', a.volume)}. Integraciones: ${describeChoice('integrations', a.integrations)}. Complejidad: ${describeChoice('complexity', a.complexity)}. Plazo: ${describeChoice('timeline', a.timeline)}.`,
    raw: quoteState.raw.slice()
  };
}

function showQuoteResult() {
  const result = calculateQuote();
  lastQuoteResult = result;
  quoteState.active = false;

  addBotMessage(`
    <div class="chat-budget-result quote-result-card">
      <span class="chat-budget-kicker">Estimación MotexBot</span>
      <h4>${result.base.label}</h4>
      <p>${result.base.desc}. Según tus respuestas, esta sería una estimación competitiva para una primera versión funcional:</p>
      <div class="chat-budget-numbers">
        <div><span>Setup aproximado</span><strong>${money(result.setupLow)} - ${money(result.setupHigh)}</strong></div>
        <div><span>Mantenimiento</span><strong>${money(result.monthlyLow)} - ${money(result.monthlyHigh)}/mes</strong></div>
      </div>
      <ul class="quote-includes">
        <li>Configuración inicial y pruebas.</li>
        <li>Ajustes básicos tras la entrega.</li>
        <li>Soporte y seguimiento mensual.</li>
        <li>Precio orientativo, no presupuesto cerrado.</li>
      </ul>
    </div>
  `);
  addBotMessage('Siguiente paso recomendado: enviarnos este resumen para revisarlo y devolverte un presupuesto cerrado. También puedes repetir la estimación o hablar por Telegram.');
  renderQuickReplies(['__lead_start__|Enviar resumen al equipo', '__quote_start__|Nueva estimación', 'Telegram', 'Email clásico', 'Ver cursos']);
}

function handleQuoteQuickAction(key, displayLabel) {
  if (key === '__quote_start__') {
    startQuoteWizard(displayLabel || 'Nueva estimación');
    return true;
  }
  if (!quoteState || !quoteState.active) startQuoteWizard('Presupuesto aproximado');

  const parts = key.replace('__quote_', '').replace('__', '').split('_');
  const step = parts[0];
  const value = parts.slice(1).join('_');
  addUserMessage(displayLabel || describeChoice(step, value));

  quoteState.answers[step] = value;
  quoteState.raw.push(`${step}: ${displayLabel || value}`);
  quoteState.stepIndex = Math.max(quoteState.stepIndex, QUOTE_STEPS.indexOf(step) + 1);

  if (quoteState.stepIndex >= QUOTE_STEPS.length) showQuoteResult();
  else askQuoteStep();
  return true;
}

function processQuoteFreeText(text) {
  const step = QUOTE_STEPS[quoteState.stepIndex];
  let value;
  if (step === 'goal') value = classifyGoal(text);
  if (step === 'volume') value = classifyVolume(text);
  if (step === 'integrations') value = classifyIntegrations(text);
  if (step === 'complexity') value = classifyComplexity(text);
  if (step === 'timeline') value = classifyTimeline(text);

  quoteState.answers[step] = value;
  quoteState.raw.push(`${step}: ${text}`);
  quoteState.stepIndex += 1;

  addBotMessage(`Anotado: <strong>${htmlEscape(describeChoice(step, value))}</strong>.`);
  if (quoteState.stepIndex >= QUOTE_STEPS.length) showQuoteResult();
  else askQuoteStep();
}

function startLeadCapture(displayLabel = 'Enviar resumen al equipo') {
  openFullscreenChat();
  if (!lastQuoteResult) {
    addUserMessage(displayLabel);
    addBotMessage('Antes de enviarlo necesito tener una estimación. La calculamos en un minuto.');
    startQuoteWizard('Calcular presupuesto');
    return;
  }
  leadState = { active: true, step: 'name', data: {} };
  addUserMessage(displayLabel);
  addBotMessage('Genial. Para mandar el resumen al equipo solo necesito 3 datos. ¿Cuál es tu nombre?');
  renderQuickReplies([]);
}

function processLeadAnswer(text) {
  if (!leadState || !leadState.active) return false;
  const clean = text.trim();
  if (leadState.step === 'name') {
    leadState.data.name = clean;
    leadState.step = 'email';
    addBotMessage(`Gracias, ${htmlEscape(clean)}. ¿A qué email te enviamos la respuesta?`);
    return true;
  }
  if (leadState.step === 'email') {
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(clean)) {
      addBotMessage('Ese email no parece válido. Escríbelo de nuevo, por ejemplo: nombre@empresa.com');
      return true;
    }
    leadState.data.email = clean;
    leadState.step = 'company';
    addBotMessage('Perfecto. Nombre de la empresa o proyecto. Si eres autónomo, puedes poner “Autónomo”.');
    return true;
  }
  if (leadState.step === 'company') {
    leadState.data.company = clean;
    leadState.step = 'phone';
    addBotMessage('Último dato opcional: teléfono. Si prefieres no darlo, escribe “saltar”.');
    return true;
  }
  if (leadState.step === 'phone') {
    leadState.data.phone = /saltar|no|ninguno/i.test(clean) ? '' : clean;
    submitChatQuote();
    leadState.active = false;
    return true;
  }
  return false;
}

function submitChatQuote() {
  const form = document.getElementById('chatQuoteForm');
  if (!form || !lastQuoteResult || !leadState) {
    addBotMessage('No he podido enviar el resumen automáticamente. Puedes escribirnos a contacto@aimotex.com o usar el formulario clásico.');
    renderQuickReplies(['Email clásico', 'Telegram']);
    return;
  }

  const data = leadState.data;
  const set = (id, value) => { const el = document.getElementById(id); if (el) el.value = value || ''; };
  set('chatQuoteName', data.name);
  set('chatQuoteEmail', data.email);
  set('chatQuotePhone', data.phone);
  set('chatQuoteCompany', data.company);
  set('chatQuoteProject', lastQuoteResult.base.label);
  set('chatQuoteEstimate', `${money(lastQuoteResult.setupLow)} - ${money(lastQuoteResult.setupHigh)}`);
  set('chatQuoteMonthly', `${money(lastQuoteResult.monthlyLow)} - ${money(lastQuoteResult.monthlyHigh)}/mes`);
  set('chatQuoteSummary', `${lastQuoteResult.summary}\nRespuestas: ${lastQuoteResult.raw.join(' | ')}`);

  try {
    form.submit();
    addBotMessage(`
      <div class="chat-budget-result quote-result-card">
        <span class="chat-budget-kicker">Resumen enviado</span>
        <h4>Ya tenemos tu estimación</h4>
        <p>Hemos enviado el resumen al equipo de Motex. Te responderemos en menos de 24 horas hábiles con el siguiente paso.</p>
      </div>
    `);
    renderQuickReplies(['Telegram', '__quote_start__|Nueva estimación', 'Ver cursos']);
  } catch (e) {
    addBotMessage('Ha fallado el envío automático. Puedes usar el formulario clásico o escribir directamente a contacto@aimotex.com.');
    renderQuickReplies(['Email clásico', 'Telegram']);
  }
}

function openSmartChatFromTopic(topic = 'general') {
  openFullscreenChat();
  const messages = {
    general: 'Perfecto. Antes de pedirte datos, prefiero entender qué necesitas. ¿Quieres calcular un presupuesto, ver cursos o hablar por Telegram?',
    consulta: 'Vamos a hacerlo rápido: dime qué proceso quieres automatizar y te doy una primera orientación antes de pedirte ningún dato.',
    presupuesto: 'Abrimos el presupuesto inteligente. Responde unas preguntas y te doy una estimación aproximada al momento.',
    'curso-pyme': 'Te oriento sobre el curso IA para PYMEs. ¿Buscas aprender desde cero o aplicar IA a una empresa concreta?',
    'curso-n8n': 'Te oriento sobre n8n + IA. ¿Quieres automatizar correos, clientes, reservas, informes o varios procesos?',
    'curso-incompany': 'Para formación in-company, lo mejor es un diagnóstico rápido por chat: equipo, objetivo y herramientas. Empezamos por el objetivo.'
  };
  addUserMessage(topic === 'presupuesto' ? 'Presupuesto inteligente' : 'Diagnóstico MotexBot');
  addBotMessage(messages[topic] || messages.general);
  if (topic === 'presupuesto' || topic === 'consulta' || topic === 'curso-incompany') {
    renderQuickReplies(['Presupuesto aproximado', 'Diagnóstico rápido', 'Telegram', 'Email clásico']);
  } else {
    renderQuickReplies(['Presupuesto aproximado', 'Ver cursos', 'Telegram', 'Email clásico']);
  }
}

function runSpecialAction(key, displayLabel) {
  if (key === '__quote_start__' || key.startsWith('__quote_')) {
    return handleQuoteQuickAction(key, displayLabel);
  }
  switch (key) {
    case '__diagnostic_start__':
      startDiagnostic();
      return true;
    case '__lead_start__':
      startLeadCapture(displayLabel);
      return true;
    case '__go_cursos__':
      addUserMessage(displayLabel || 'Ver cursos');
      addBotMessage('Te dejo la página de cursos abierta detrás, pero mantengo este chat para que no pierdas la conversación.');
      setPage('cursos');
      return true;
    case '__go_roi__':
      addUserMessage(displayLabel || 'Calcular ahorro');
      addBotMessage('Te llevo a la calculadora de ahorro y mantengo el chat abierto.');
      setPage('home', { scroll: false });
      setTimeout(() => {
        const roi = document.getElementById('diagnostico');
        if (roi) roi.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }, 80);
      return true;
    case '__open_email_form__':
      addUserMessage(displayLabel || 'Email clásico');
      addBotMessage('De acuerdo. Esta es la opción secundaria: abriré el formulario clásico por email.');
      setTimeout(() => { toggleChatbot(false); openContactModal('presupuesto'); }, 350);
      return true;
    case '__open_general__':
    case '__open_consulta__':
    case '__open_presupuesto__':
      openSmartChatFromTopic(key === '__open_presupuesto__' ? 'presupuesto' : 'consulta');
      return true;
    case '__open_curso_pyme__':
      addUserMessage(displayLabel || 'Inscribirme al curso PYMEs');
      addBotMessage('Te abro el checkout del curso IA para PYMEs.');
      setTimeout(() => { toggleChatbot(false); openCheckoutModal('pyme'); }, 350);
      return true;
    case '__open_curso_n8n__':
      addUserMessage(displayLabel || 'Reservar plaza n8n');
      addBotMessage('Te abro el checkout del curso n8n + IA.');
      setTimeout(() => { toggleChatbot(false); openCheckoutModal('n8n'); }, 350);
      return true;
    case '__course_pyme__':
      addUserMessage(displayLabel || 'Curso IA PYMEs');
      addBotMessage('IA para PYMEs cuesta 197 €. Lo importante: plataforma personalizada, avance a tu ritmo, ejercicios prácticos y mentoría semanal para resolver dudas. Lo enfocamos a que la IA sea un empleado digital que te quite tareas reales.');
      renderQuickReplies(['Inscribirme al curso PYMEs', 'Curso n8n + IA', 'Telegram']);
      return true;
    case '__course_n8n__':
      addUserMessage(displayLabel || 'Curso n8n + IA');
      addBotMessage('n8n + IA cuesta 397 €. Aprendes a crear flujos reales: leads, correos, reservas, documentos, informes, CRM y avisos. Incluye mentoría semanal y plantillas reutilizables.');
      renderQuickReplies(['Reservar plaza n8n', 'Curso IA PYMEs', 'Presupuesto aproximado']);
      return true;
    case '__course_company__':
      addUserMessage(displayLabel || 'In-company');
      addBotMessage('La formación in-company parte desde 690 € para equipos pequeños. La plataforma y los ejercicios se adaptan a vuestra empresa. Podemos estimarla con el mismo bot.');
      renderQuickReplies(['Presupuesto aproximado', 'Email clásico', 'Telegram']);
      return true;
    case '__open_telegram__':
      addUserMessage(displayLabel || 'Telegram');
      window.open(CHATBOT.TELEGRAM, '_blank', 'noopener');
      addBotMessage(`Abriendo Telegram. También puedes entrar aquí: <a href="${CHATBOT.TELEGRAM}" target="_blank" rel="noopener">@MotexBot</a>`);
      return true;
    case '__open_email__':
      addUserMessage(displayLabel || 'Email');
      window.location.href = CHATBOT.EMAIL;
      addBotMessage(`Abriendo tu correo. Dirección: <a href="${CHATBOT.EMAIL}">contacto@aimotex.com</a>`);
      return true;
  }
  return false;
}

function handleUserMessage(rawText, displayText) {
  const text = (rawText || '').trim();
  if (!text) return;

  const mapped = QUICK_MAP[normalize(text)];
  if (mapped && String(mapped).startsWith('__')) {
    runSpecialAction(mapped, displayText || text);
    return;
  }

  addUserMessage(displayText || text);
  renderQuickReplies([]);
  showTyping();

  setTimeout(() => {
    hideTyping();

    if (leadState && leadState.active) {
      processLeadAnswer(text);
      return;
    }

    if (quoteState && quoteState.active) {
      processQuoteFreeText(text);
      return;
    }

    const intent = matchIntent(text);
    if (intent) {
      addBotMessage(intent.reply);
      renderQuickReplies(intent.quick || []);
    } else {
      addBotMessage(FALLBACK_REPLIES[Math.floor(Math.random() * FALLBACK_REPLIES.length)]);
      renderQuickReplies(FALLBACK_QUICK);
    }
  }, 450 + Math.random() * 300);
}

// ============ Eventos chatbot ============
if (cb && cbFab && cbPanel) {
  cbFab.addEventListener('click', () => toggleChatbot());
  if (cbClose) cbClose.addEventListener('click', () => toggleChatbot(false));

  if (cbForm) {
    cbForm.addEventListener('submit', (e) => {
      e.preventDefault();
      const value = cbInput.value.trim();
      if (!value) return;
      handleUserMessage(value);
      cbInput.value = '';
    });
  }
}

// Botones externos para lanzar diagnóstico/presupuesto sin formulario.
document.querySelectorAll('[data-start-budget-bot]').forEach(btn => {
  btn.addEventListener('click', () => {
    startQuoteWizard('Presupuesto aproximado');
  });
});

// Botones explícitos de formulario clásico, solo como opción secundaria.
document.addEventListener('click', (e) => {
  const formBtn = e.target.closest('[data-open-contact-form]');
  if (!formBtn) return;
  e.preventDefault();
  const topic = formBtn.getAttribute('data-contact-topic') || 'presupuesto';
  openContactModal(topic);
});
