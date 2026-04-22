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
document.querySelectorAll('.services-grid .reveal, .process-grid .reveal, .benefits-grid .reveal, .courses-grid .reveal').forEach((el, i) => {
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
// STRIPE PAYMENT LINKS
// =========================================================
// Sustituye las URLs por tus Payment Links reales de Stripe.
// Cómo: dashboard.stripe.com → Payment links → + Nuevo → pega el link aquí.
// Stripe Checkout soporta Apple Pay, Google Pay, Mastercard y Visa
// de forma automática cuando el navegador/dispositivo lo permite.
const STRIPE_LINKS = {
  pyme: 'https://buy.stripe.com/REEMPLAZAR_LINK_CURSO_PYME',
  n8n:  'https://buy.stripe.com/REEMPLAZAR_LINK_CURSO_N8N'
};

document.querySelectorAll('[data-stripe-link]').forEach(el => {
  el.addEventListener('click', (e) => {
    const key = el.getAttribute('data-stripe-link');
    const url = STRIPE_LINKS[key];

    // Si aún no has pegado el link real, redirigimos a WhatsApp en vez de romper la UX
    if (!url || url.includes('REEMPLAZAR')) {
      e.preventDefault();
      const msg = key === 'n8n'
        ? 'Hola, quiero inscribirme al curso Automatiza tu negocio con n8n + IA (597 €)'
        : 'Hola, quiero inscribirme al curso IA para PYMEs y autónomos (297 €)';
      window.open(`https://wa.me/34683567360?text=${encodeURIComponent(msg)}`, '_blank', 'noopener');
      return;
    }

    e.preventDefault();
    window.open(url, '_blank', 'noopener');
  });
});

// =========================================================
// CHATBOT POR REGLAS
// =========================================================
const CHATBOT = {
  WHATSAPP: 'https://wa.me/34683567360',
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
    quick: ['Inscribirme', 'Hablar por WhatsApp', 'Ver otros cursos']
  },
  {
    id: 'curso_n8n',
    patterns: ['n8n', 'avanzado', 'automatizar todo', 'flujo', 'flujos', 'workflow'],
    reply: 'El curso <strong>Automatiza tu negocio con n8n + IA</strong> es el más completo: 16 h en directo, mentoría personalizada y plantillas profesionales. Oferta de lanzamiento: <strong>597 €</strong> (antes 897 €). Conectas Claude, ChatGPT y tus herramientas en flujos reales. ¿Reservamos plaza?',
    quick: ['Reservar plaza', 'Ver todos los cursos', 'WhatsApp']
  },
  {
    id: 'curso_incompany',
    patterns: ['in-company', 'in company', 'incompany', 'empresa', 'equipo', 'plantilla', 'a medida'],
    reply: 'La formación <strong>in-company a medida</strong> la diseñamos a partir de un análisis de vuestro caso. Duración flexible, contenidos 100% adaptados y proyectos reales con vuestras herramientas. El presupuesto depende del tamaño del equipo y los contenidos. ¿Te paso con nosotros para una propuesta?',
    quick: ['Pedir presupuesto', 'WhatsApp', 'Email']
  },
  {
    id: 'precio',
    patterns: ['precio', 'precios', 'cuesta', 'cuanto', 'tarifa', 'coste', 'valen', 'pagar', 'pago'],
    reply: 'Nuestros precios:<br>• Curso IA PYMEs: <strong>297 €</strong><br>• Curso n8n + IA: <strong>597 €</strong> (oferta)<br>• In-company: a medida<br>• Automatizaciones: presupuesto cerrado tras consulta gratuita de 30 min.<br><br>Aceptamos Apple Pay, Google Pay, tarjeta (Mastercard/Visa) y PayPal.',
    quick: ['Ver cursos', 'Agendar consulta', 'WhatsApp']
  },
  {
    id: 'pago',
    patterns: ['apple pay', 'google pay', 'paypal', 'tarjeta', 'mastercard', 'visa', 'metodo de pago', 'formas de pago'],
    reply: 'Puedes pagar con <strong>Apple Pay, Google Pay, Mastercard, Visa y PayPal</strong>. El pago es seguro, procesado a través de Stripe/PayPal. Pago único, sin suscripciones. Factura con IVA incluida.',
    quick: ['Ver cursos', 'WhatsApp']
  },
  {
    id: 'contacto',
    patterns: ['contacto', 'contactar', 'hablar', 'llamar', 'telefono', 'whatsapp', 'telegram', 'email', 'correo'],
    reply: `Puedes contactarnos por:<br>• <strong>WhatsApp</strong>: <a href="${CHATBOT.WHATSAPP}" target="_blank" rel="noopener">+34 683 567 360</a><br>• <strong>Telegram</strong>: <a href="${CHATBOT.TELEGRAM}" target="_blank" rel="noopener">@MotxxBot</a><br>• <strong>Email</strong>: <a href="${CHATBOT.EMAIL}">contacto@motxx.es</a><br><br>Respuesta garantizada en menos de 24 h.`,
    quick: ['Agendar consulta', 'Ver cursos']
  },
  {
    id: 'consulta',
    patterns: ['consulta', 'cita', 'reunion', 'agendar', 'presupuesto', 'cotizacion'],
    reply: 'La consulta inicial es de <strong>30 minutos, gratuita y sin compromiso</strong>. Analizamos tu caso, identificamos qué se puede automatizar y te proponemos una solución con precio cerrado. ¿Te conecto con nosotros?',
    quick: ['WhatsApp ahora', 'Telegram', 'Email']
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
    id: 'gracias',
    patterns: ['gracias', 'muchas gracias', 'thank', 'vale', 'perfecto', 'genial'],
    reply: '¡Un placer! Si necesitas algo más, estoy aquí. Y recuerda que tienes WhatsApp y Telegram disponibles para hablar directamente con el equipo. 😊',
    quick: ['WhatsApp', 'Telegram', 'Ver cursos']
  },
  {
    id: 'despedida',
    patterns: ['adios', 'hasta luego', 'chao', 'nos vemos', 'bye'],
    reply: '¡Hasta pronto! 👋 Cuando quieras volver, aquí estaré. Si prefieres hablar con el equipo: WhatsApp +34 683 567 360 o Telegram @MotxxBot.',
    quick: []
  }
];

// Fallback si nada casa
const FALLBACK_REPLIES = [
  'No estoy seguro de haberte entendido bien. ¿Puedes reformular? O si lo prefieres, puedo pasarte directamente con el equipo por WhatsApp o Telegram.',
  'Esa pregunta se me escapa. Para darte la mejor respuesta, lo mejor es que hables con el equipo humano. ¿Te paso a WhatsApp o Telegram?',
  'No tengo una respuesta clara para eso. ¿Quieres que te ponga en contacto con nosotros? Respondemos rápido.'
];

const FALLBACK_QUICK = ['WhatsApp', 'Telegram', 'Ver cursos', 'Precios'];

// Mapeo de quick-replies a texto que se "envía" como usuario
const QUICK_MAP = {
  'ver cursos':          'cursos',
  'curso ia pymes':      'curso pyme',
  'curso n8n + ia':      'curso n8n',
  'in-company':          'in-company',
  'inscribirme':         'inscribirme',
  'reservar plaza':      'reservar plaza',
  'precios':             'precios',
  'contactar':           'contacto',
  'agendar consulta':    'consulta',
  'pedir presupuesto':   'presupuesto',
  'whatsapp':            'whatsapp',
  'whatsapp ahora':      'whatsapp',
  'hablar por whatsapp': 'whatsapp',
  'telegram':            'telegram',
  'email':               'email',
  'ver servicios':       'servicios',
  'ver otros cursos':    'cursos',
  'ver todos los cursos':'cursos',
  'cursos de formacion': 'cursos'
};

// Normaliza texto para matching (minúsculas, sin acentos)
function normalize(text) {
  return text
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[¿¡?!.,;:]/g, '')
    .trim();
}

// Busca la intención que mejor case
function matchIntent(userText) {
  const clean = normalize(userText);

  // Casos especiales: quiero inscribirme/reservar → guía a los botones
  if (/\b(inscribir|reservar|comprar|apuntar)/.test(clean)) {
    return {
      reply: '¡Genial! Los botones de inscripción están en cada tarjeta de curso, justo en la sección <strong>Formación</strong> 👆 Aceptamos Apple Pay, Google Pay, tarjeta y PayPal. Si prefieres que te guíe, escríbenos por <a href="' + CHATBOT.WHATSAPP + '" target="_blank" rel="noopener">WhatsApp</a>.',
      quick: ['Ver cursos', 'WhatsApp']
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
    // Mensaje de bienvenida diferido
    setTimeout(() => {
      addBotMessage('¡Hola! 👋 Soy el asistente de <strong>Motxx IA</strong>. ¿En qué puedo ayudarte hoy?');
      renderQuickReplies(['Ver cursos', 'Precios', 'Agendar consulta', 'Contactar']);
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

function renderQuickReplies(labels) {
  cbQuick.innerHTML = '';
  if (!labels || !labels.length) return;

  labels.forEach(label => {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'quick-reply';
    btn.textContent = label;
    btn.addEventListener('click', () => {
      const key = normalize(label);
      // Si el quick es un canal directo, abrimos
      if (key === 'whatsapp' || key === 'whatsapp ahora' || key === 'hablar por whatsapp') {
        window.open(CHATBOT.WHATSAPP, '_blank', 'noopener');
        addUserMessage(label);
        addBotMessage('¡Te he abierto WhatsApp en una pestaña nueva! Si no se ha abierto, aquí tienes el enlace: <a href="' + CHATBOT.WHATSAPP + '" target="_blank" rel="noopener">+34 683 567 360</a>');
        return;
      }
      if (key === 'telegram') {
        window.open(CHATBOT.TELEGRAM, '_blank', 'noopener');
        addUserMessage(label);
        addBotMessage('¡Te he abierto Telegram en una pestaña nueva! Enlace: <a href="' + CHATBOT.TELEGRAM + '" target="_blank" rel="noopener">@MotxxBot</a>');
        return;
      }
      if (key === 'email') {
        window.location.href = CHATBOT.EMAIL;
        addUserMessage(label);
        addBotMessage('Abriendo tu cliente de correo. También puedes escribirnos a <a href="' + CHATBOT.EMAIL + '">contacto@motxx.es</a>.');
        return;
      }

      // El resto, tratamos como mensaje normal usando el mapa
      const mapped = QUICK_MAP[key] || label;
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

  // Simular "pensando"
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

  // Cerrar con Escape
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && cb.classList.contains('open')) {
      toggleChatbot(false);
    }
  });
}
