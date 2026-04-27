// =========================================================
// MOTXX IA — script principal
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
    desc: '8 horas en directo, grupos reducidos y certificación incluida. Sin conocimientos técnicos previos.',
    price: 297
  },
  n8n: {
    name: 'Automatiza tu negocio con n8n + IA',
    desc: '16 horas en directo, mentoría personalizada y plantillas profesionales. Oferta de lanzamiento.',
    price: 597
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
    openContactModal(topic);
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
// MODAL DE CONTACTO (consultas, info, presupuesto)
// =========================================================
const contactForm   = document.getElementById('contactForm');
const contactKicker = document.getElementById('contactKicker');
const contactTitle  = document.getElementById('contactTitle');
const hiddenTopic   = document.getElementById('hiddenTopic');
const contactFormNext = document.getElementById('contactFormNext');

const CONTACT_TOPICS = {
  general: {
    kicker: 'Consulta gratuita',
    title: 'Cuéntanos tu caso',
    topic: 'Consulta general'
  },
  consulta: {
    kicker: 'Consulta gratuita',
    title: 'Agenda tu consulta de 30 min',
    topic: 'Agendar consulta gratuita'
  },
  presupuesto: {
    kicker: 'Presupuesto a medida',
    title: 'Solicita tu presupuesto',
    topic: 'Solicitud de presupuesto'
  },
  'curso-pyme': {
    kicker: 'Información de curso',
    title: 'Curso IA para PYMEs y autónomos',
    topic: 'Info: curso IA para PYMEs (297 €)'
  },
  'curso-n8n': {
    kicker: 'Información de curso',
    title: 'Curso Automatiza con n8n + IA',
    topic: 'Info: curso n8n + IA (597 €)'
  },
  'curso-incompany': {
    kicker: 'Formación in-company',
    title: 'Presupuesto formación in-company',
    topic: 'Presupuesto formación in-company'
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

// Mensaje de éxito al volver de FormSubmit de contacto
if (window.location.search.includes('consulta=ok')) {
  // Mostramos un mensaje simple con un toast-like (reutilizamos el modal de contacto)
  setTimeout(() => {
    openModal('contactModal');
    if (contactForm) {
      // Reemplazar el formulario por un mensaje de éxito
      const body = contactForm.closest('.modal-body');
      if (body) {
        body.innerHTML = `
          <div class="form-step-success active" style="display:flex;flex-direction:column;align-items:center;gap:1rem;text-align:center;padding:1rem 0;">
            <div class="success-icon">
              <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>
            </div>
            <h2 class="modal-title">¡Mensaje recibido!</h2>
            <p class="modal-subtitle">Gracias por contactar con Motxx IA. Te responderemos en menos de 24 horas hábiles al correo que nos has facilitado.</p>
            <button type="button" class="btn btn-primary" data-close-modal style="margin-top: 0.5rem;">Cerrar</button>
          </div>
        `;
      }
    }
  }, 300);
  history.replaceState(null, '', window.location.pathname);
}

// =========================================================
// CHATBOT POR REGLAS
// =========================================================
const CHATBOT = {
  TELEGRAM: 'https://t.me/MotxxBot',
  EMAIL: 'mailto:contacto@motxx.es'
};

// Base de conocimiento (intents). El primer patrón que casa, gana.
const INTENTS = [
  {
    id: 'saludo',
    patterns: ['hola', 'buenas', 'buenos dias', 'buenas tardes', 'buenas noches', 'hey', 'que tal'],
    reply: '¡Hola! 👋 Soy el asistente de Motxx IA. ¿En qué puedo ayudarte? Puedes preguntarme sobre nuestros servicios, los cursos o cómo contactar con nosotros.',
    quick: ['Ver cursos', 'Precios', 'Contactar']
  },
  {
    id: 'servicios',
    patterns: ['servicio', 'que haceis', 'que ofreceis', 'automatizar', 'automatizacion', 'que es motxx'],
    reply: 'En Motxx IA automatizamos procesos de empresas con IA. Nuestros servicios principales: atención al cliente con chatbots, gestión automática de correo, generación de contenido para redes, reservas y agenda inteligente, facturación automática e informes con IA. También formamos a equipos. ¿Te interesa alguno en concreto?',
    quick: ['Cursos de formación', 'Precios', 'Agendar consulta']
  },
  {
    id: 'cursos',
    patterns: ['curso', 'cursos', 'formacion', 'aprender', 'clases', 'programa'],
    reply: 'Tenemos 3 programas:<br>• <strong>IA para PYMEs y autónomos</strong> — 8 h · 297 €<br>• <strong>Automatiza con n8n + IA</strong> — 16 h · 597 € (el más demandado)<br>• <strong>In-company a medida</strong> — presupuesto personalizado<br><br>Puedes ver el detalle en la sección Formación o preguntarme por uno en concreto.',
    quick: ['Curso IA PYMEs', 'Curso n8n + IA', 'In-company']
  },
  {
    id: 'curso_pyme',
    patterns: ['pyme', 'pymes', 'autonomo', 'autonomos', 'iniciacion', 'basico', 'principiante'],
    reply: 'El curso <strong>IA para PYMEs y autónomos</strong> son 8 horas en directo, grupos reducidos y certificación incluida. Precio: <strong>297 €</strong> (IVA incluido). Sin conocimientos técnicos previos. ¿Quieres reservar plaza o que te cuente más?',
    quick: ['Inscribirme al curso PYMEs', 'Más información', 'Ver otros cursos']
  },
  {
    id: 'curso_n8n',
    patterns: ['n8n', 'avanzado', 'flujo', 'flujos', 'workflow'],
    reply: 'El curso <strong>Automatiza tu negocio con n8n + IA</strong> es el más completo: 16 h en directo, mentoría personalizada y plantillas profesionales. Oferta de lanzamiento: <strong>597 €</strong> (antes 897 €). Conectas Claude, ChatGPT y tus herramientas en flujos reales.',
    quick: ['Reservar plaza n8n', 'Más información', 'Ver todos los cursos']
  },
  {
    id: 'curso_incompany',
    patterns: ['in-company', 'in company', 'incompany', 'empresa', 'equipo', 'plantilla', 'a medida'],
    reply: 'La formación <strong>in-company a medida</strong> la diseñamos a partir de un análisis de vuestro caso. Duración flexible, contenidos 100% adaptados y proyectos reales con vuestras herramientas. El presupuesto depende del tamaño del equipo y los contenidos.',
    quick: ['Pedir presupuesto', 'Más información']
  },
  {
    id: 'precio',
    patterns: ['precio', 'precios', 'cuesta', 'cuanto', 'tarifa', 'coste', 'valen'],
    reply: 'Nuestros precios:<br>• Curso IA PYMEs: <strong>297 €</strong><br>• Curso n8n + IA: <strong>597 €</strong> (oferta)<br>• In-company: a medida<br>• Automatizaciones: presupuesto cerrado tras consulta gratuita de 30 min.<br><br>Aceptamos Apple Pay, Google Pay, tarjeta (Visa/Mastercard), PayPal y transferencia.',
    quick: ['Ver cursos', 'Agendar consulta']
  },
  {
    id: 'pago',
    patterns: ['apple pay', 'google pay', 'paypal', 'tarjeta', 'mastercard', 'visa', 'metodo de pago', 'formas de pago', 'pagar', 'pago'],
    reply: 'Aceptamos <strong>Apple Pay, Google Pay, tarjeta (Visa/Mastercard), PayPal y transferencia bancaria</strong>. El pago es 100% seguro, procesado a través de pasarelas certificadas PCI-DSS. Pago único, sin suscripciones. Factura con IVA incluida.',
    quick: ['Ver cursos', 'Más información']
  },
  {
    id: 'contacto',
    patterns: ['contacto', 'contactar', 'hablar', 'telegram', 'email', 'correo', 'como os contacto'],
    reply: `Puedes contactarnos por:<br>• <strong>Formulario de contacto</strong> (el más rápido)<br>• <strong>Telegram</strong>: <a href="${CHATBOT.TELEGRAM}" target="_blank" rel="noopener">@MotxxBot</a><br>• <strong>Email</strong>: <a href="${CHATBOT.EMAIL}">contacto@motxx.es</a><br><br>Respuesta garantizada en menos de 24 h.`,
    quick: ['Abrir formulario', 'Telegram', 'Email']
  },
  {
    id: 'consulta',
    patterns: ['consulta', 'cita', 'reunion', 'agendar', 'presupuesto', 'cotizacion'],
    reply: 'La consulta inicial es de <strong>30 minutos, gratuita y sin compromiso</strong>. Analizamos tu caso, identificamos qué se puede automatizar y te proponemos una solución con precio cerrado.',
    quick: ['Agendar consulta', 'Pedir presupuesto']
  },
  {
    id: 'ia',
    patterns: ['claude', 'chatgpt', 'copilot', 'herramientas', 'tecnologia', 'que ia'],
    reply: 'Trabajamos con las plataformas líderes: <strong>Claude</strong> (Anthropic), <strong>ChatGPT</strong> (OpenAI) y <strong>Copilot</strong> (Microsoft). Para orquestar flujos usamos n8n, Make y Zapier. Elegimos la tecnología que mejor encaje con tu caso.',
    quick: ['Ver servicios', 'Cursos']
  },
  {
    id: 'rgpd',
    patterns: ['rgpd', 'datos', 'privacidad', 'seguridad', 'gdpr', 'proteccion de datos'],
    reply: 'Cumplimos íntegramente el RGPD. Usamos proveedores con servidores en Europa siempre que es viable y tus datos nunca se emplean para entrenar modelos públicos. La privacidad es prioridad innegociable.',
    quick: ['Ver servicios', 'Contactar']
  },
  {
    id: 'plazo',
    patterns: ['tiempo', 'plazo', 'cuanto tarda', 'duracion', 'cuando'],
    reply: 'El plazo habitual de implantación es de <strong>1 a 4 semanas</strong> desde la primera reunión, según complejidad. Automatizaciones sencillas pueden estar operativas en días. Los cursos arrancan cuando se completa el grupo.',
    quick: ['Agendar consulta', 'Ver cursos']
  },
  {
    id: 'diagnostico_automatizacion',
    patterns: ['diagnostico', 'ahorro', 'roi', 'calcular', 'cuanto ahorro', 'cuanto puedo ahorrar', 'proceso repetitivo'],
    reply: 'Puedes usar la calculadora de ahorro de la web para estimar horas y coste mensual recuperable. Para un diagnóstico real, abrimos el formulario y analizamos tus procesos concretos.',
    quick: ['Calcular ahorro', 'Pedir presupuesto']
  },
  {
    id: 'gracias',
    patterns: ['gracias', 'muchas gracias', 'thank', 'vale', 'perfecto', 'genial'],
    reply: '¡Un placer! Si necesitas algo más, estoy aquí. 😊',
    quick: ['Ver cursos', 'Contactar']
  },
  {
    id: 'despedida',
    patterns: ['adios', 'hasta luego', 'chao', 'nos vemos', 'bye'],
    reply: '¡Hasta pronto! 👋 Cuando quieras volver, aquí estaré.',
    quick: []
  }
];

const FALLBACK_REPLIES = [
  'No estoy seguro de haberte entendido bien. ¿Puedes reformular? También puedes abrir el formulario de contacto y te responde el equipo directamente.',
  'Esa pregunta se me escapa. Para darte la mejor respuesta, lo mejor es que hables con el equipo humano. ¿Abrimos el formulario?',
  'No tengo una respuesta clara para eso. ¿Quieres que te pase al formulario de contacto? Respondemos en menos de 24 horas.'
];

const FALLBACK_QUICK = ['Abrir formulario', 'Telegram', 'Ver cursos', 'Precios'];

// Mapeo de quick-replies a texto que se "envía" como usuario
const QUICK_MAP = {
  'ver cursos':           '__go_cursos__',
  'curso ia pymes':       'curso pyme',
  'curso n8n + ia':       'curso n8n',
  'in-company':           'in-company',
  'precios':              'precios',
  'contactar':            'contacto',
  'calcular ahorro':      '__go_roi__',
  'diagnostico rapido':   '__open_presupuesto__',
  'agendar consulta':     '__open_consulta__',
  'pedir presupuesto':    '__open_presupuesto__',
  'abrir formulario':     '__open_general__',
  'inscribirme al curso pymes': '__open_curso_pyme__',
  'reservar plaza n8n':   '__open_curso_n8n__',
  'mas informacion':      '__open_general__',
  'telegram':             '__open_telegram__',
  'email':                '__open_email__',
  'ver servicios':        'servicios',
  'ver otros cursos':     '__go_cursos__',
  'ver todos los cursos': '__go_cursos__',
  'cursos de formacion':  '__go_cursos__'
};

function normalize(text) {
  return text
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[¿¡?!.,;:]/g, '')
    .trim();
}

function matchIntent(userText) {
  const clean = normalize(userText);

  // Casos especiales: quiero inscribirme/reservar → guiar al botón adecuado
  if (/\b(inscribir|reservar|comprar|apuntar)/.test(clean)) {
    if (clean.includes('n8n')) return { reply: '¡Genial! Te abro el checkout del curso de n8n + IA para que completes la inscripción. 🚀', quick: ['__open_curso_n8n__|Abrir checkout n8n + IA'] };
    if (clean.includes('pyme')) return { reply: '¡Genial! Te abro el checkout del curso IA para PYMEs. 🚀', quick: ['__open_curso_pyme__|Abrir checkout PYMEs'] };
    return {
      reply: '¡Genial! Los botones de inscripción están en cada tarjeta de curso, en la sección <strong>Formación</strong>. Aceptamos Apple Pay, Google Pay, tarjeta, PayPal y transferencia.',
      quick: ['Ver cursos']
    };
  }

  for (const intent of INTENTS) {
    for (const pattern of intent.patterns) {
      if (clean.includes(normalize(pattern))) {
        return intent;
      }
    }
  }
  return null;
}

// ============ DOM chatbot ============
const cb         = document.getElementById('chatbot');
const cbFab      = document.getElementById('chatbotFab');
const cbPanel    = document.getElementById('chatbotPanel');
const cbClose    = document.getElementById('chatbotClose');
const cbMessages = document.getElementById('chatbotMessages');
const cbQuick    = document.getElementById('chatbotQuickReplies');
const cbForm     = document.getElementById('chatbotForm');
const cbInput    = document.getElementById('chatbotInput');

let cbOpened = false;

function toggleChatbot(force) {
  const shouldOpen = typeof force === 'boolean' ? force : !cb.classList.contains('open');
  cb.classList.toggle('open', shouldOpen);
  cbFab.setAttribute('aria-expanded', String(shouldOpen));
  cbPanel.setAttribute('aria-hidden', String(!shouldOpen));

  if (shouldOpen && !cbOpened) {
    cbOpened = true;
    setTimeout(() => {
      addBotMessage('¡Hola! 👋 Soy el asistente de <strong>Motxx IA</strong>. ¿En qué puedo ayudarte hoy?');
      renderQuickReplies(['Ver cursos', 'Calcular ahorro', 'Diagnóstico rápido', 'Contactar']);
    }, 300);
  }

  if (shouldOpen) {
    setTimeout(() => cbInput && cbInput.focus(), 350);
  }
}

function addBotMessage(html) {
  const div = document.createElement('div');
  div.className = 'chat-msg chat-msg-bot';
  div.innerHTML = html;
  cbMessages.appendChild(div);
  scrollMessagesToBottom();
}

function addUserMessage(text) {
  const div = document.createElement('div');
  div.className = 'chat-msg chat-msg-user';
  div.textContent = text;
  cbMessages.appendChild(div);
  scrollMessagesToBottom();
}

function showTyping() {
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
  cbMessages.scrollTop = cbMessages.scrollHeight;
}

// Acciones especiales desencadenadas desde el chatbot
function runSpecialAction(key, displayLabel) {
  switch (key) {
    case '__go_cursos__':
      addUserMessage(displayLabel || 'Ver cursos');
      addBotMessage('Te llevo a la página de cursos. Ahí verás los programas, precios y qué incluye cada uno. 🎓');
      setTimeout(() => { toggleChatbot(false); setPage('cursos'); }, 450);
      return true;
    case '__go_roi__':
      addUserMessage(displayLabel || 'Calcular ahorro');
      addBotMessage('Te llevo a la calculadora para estimar horas y coste recuperable al automatizar. ⚡');
      setTimeout(() => {
        toggleChatbot(false);
        setPage('home', { scroll: false });
        const roi = document.getElementById('diagnostico');
        if (roi) roi.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }, 450);
      return true;
    case '__open_general__':
      addUserMessage(displayLabel || 'Abrir formulario');
      addBotMessage('Abriendo el formulario de contacto... ✉️');
      setTimeout(() => { toggleChatbot(false); openContactModal('general'); }, 400);
      return true;
    case '__open_consulta__':
      addUserMessage(displayLabel || 'Agendar consulta');
      addBotMessage('Te abro el formulario para agendar tu consulta gratuita.');
      setTimeout(() => { toggleChatbot(false); openContactModal('consulta'); }, 400);
      return true;
    case '__open_presupuesto__':
      addUserMessage(displayLabel || 'Pedir presupuesto');
      addBotMessage('Abriendo el formulario de presupuesto...');
      setTimeout(() => { toggleChatbot(false); openContactModal('presupuesto'); }, 400);
      return true;
    case '__open_curso_pyme__':
      addUserMessage(displayLabel || 'Inscribirme al curso PYMEs');
      addBotMessage('Te abro el checkout del curso IA para PYMEs. 🚀');
      setTimeout(() => { toggleChatbot(false); openCheckoutModal('pyme'); }, 400);
      return true;
    case '__open_curso_n8n__':
      addUserMessage(displayLabel || 'Reservar plaza n8n');
      addBotMessage('Te abro el checkout del curso n8n + IA. 🚀');
      setTimeout(() => { toggleChatbot(false); openCheckoutModal('n8n'); }, 400);
      return true;
    case '__open_telegram__':
      window.open(CHATBOT.TELEGRAM, '_blank', 'noopener');
      addUserMessage(displayLabel || 'Telegram');
      addBotMessage('¡Abriendo Telegram! Enlace: <a href="' + CHATBOT.TELEGRAM + '" target="_blank" rel="noopener">@MotxxBot</a>');
      return true;
    case '__open_email__':
      window.location.href = CHATBOT.EMAIL;
      addUserMessage(displayLabel || 'Email');
      addBotMessage('Abriendo tu cliente de correo. También puedes escribir a <a href="' + CHATBOT.EMAIL + '">contacto@motxx.es</a>.');
      return true;
  }
  return false;
}

function renderQuickReplies(labels) {
  cbQuick.innerHTML = '';
  if (!labels || !labels.length) return;

  labels.forEach(raw => {
    // Soporte de formato "__action__|Label visible"
    let actionKey = null;
    let label = raw;
    if (typeof raw === 'string' && raw.includes('|')) {
      const parts = raw.split('|');
      if (parts[0].startsWith('__')) {
        actionKey = parts[0];
        label = parts[1];
      }
    }

    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'quick-reply';
    btn.textContent = label;
    btn.addEventListener('click', () => {
      if (actionKey && runSpecialAction(actionKey, label)) return;

      const mapped = QUICK_MAP[normalize(label)] || label;

      // Si el valor mapeado es una acción especial, la ejecutamos
      if (typeof mapped === 'string' && mapped.startsWith('__')) {
        runSpecialAction(mapped, label);
        return;
      }

      // Si no, tratamos como mensaje normal
      handleUserMessage(mapped, label);
    });
    cbQuick.appendChild(btn);
  });
}

function handleUserMessage(rawText, displayText) {
  const text = (rawText || '').trim();
  if (!text) return;

  addUserMessage(displayText || text);
  renderQuickReplies([]);
  showTyping();

  setTimeout(() => {
    hideTyping();

    const intent = matchIntent(text);
    if (intent) {
      addBotMessage(intent.reply);
      renderQuickReplies(intent.quick || []);
    } else {
      const reply = FALLBACK_REPLIES[Math.floor(Math.random() * FALLBACK_REPLIES.length)];
      addBotMessage(reply);
      renderQuickReplies(FALLBACK_QUICK);
    }
  }, 550 + Math.random() * 400);
}

// ============ Eventos chatbot ============
if (cb && cbFab && cbPanel) {
  cbFab.addEventListener('click', () => toggleChatbot());
  cbClose.addEventListener('click', () => toggleChatbot(false));

  cbForm.addEventListener('submit', (e) => {
    e.preventDefault();
    const value = cbInput.value.trim();
    if (!value) return;
    handleUserMessage(value);
    cbInput.value = '';
  });
}
