
// =========================================================
// MOTEX — Interacciones multipágina
// =========================================================

const $ = (selector, parent = document) => parent.querySelector(selector);
const $$ = (selector, parent = document) => Array.from(parent.querySelectorAll(selector));

const nav = $('#nav');
window.addEventListener('scroll', () => {
  if (!nav) return;
  nav.classList.toggle('scrolled', window.pageYOffset > 50);
});

const navToggle = $('#navToggle');
const mobileMenu = $('#mobileMenu');

if (navToggle && mobileMenu) {
  navToggle.addEventListener('click', () => {
    navToggle.classList.toggle('open');
    mobileMenu.classList.toggle('open');
  });

  $$('#mobileMenu a, #mobileMenu button').forEach((el) => {
    el.addEventListener('click', () => {
      navToggle.classList.remove('open');
      mobileMenu.classList.remove('open');
    });
  });
}

// Reveal on scroll
const observer = new IntersectionObserver((entries) => {
  entries.forEach((entry) => {
    if (entry.isIntersecting) {
      entry.target.classList.add('visible');
      observer.unobserve(entry.target);
    }
  });
}, { threshold: 0.12, rootMargin: '0px 0px -80px 0px' });

$$('.reveal').forEach((el, index) => {
  el.style.transitionDelay = `${Math.min(index * 0.04, 0.24)}s`;
  observer.observe(el);
});

// Parallax aurora
const auroraBlobs = $$('.aurora-blob');
window.addEventListener('mousemove', (e) => {
  if (!auroraBlobs.length) return;
  const x = (e.clientX / window.innerWidth - 0.5) * 16;
  const y = (e.clientY / window.innerHeight - 0.5) * 16;
  auroraBlobs.forEach((blob, i) => {
    const speed = (i + 1) * 0.35;
    blob.style.transform = `translate(${x * speed}px, ${y * speed}px)`;
  });
});

// =========================================================
// MOTEXBOT — presupuesto inteligente
// =========================================================

const CHATBOT = {
  TELEGRAM: 'https://t.me/MotexBot',
  EMAIL: 'mailto:contacto@aimotex.com'
};

const cb = $('#chatbot');
const cbFab = $('#chatbotFab');
const cbPanel = $('#chatbotPanel');
const cbClose = $('#chatbotClose');
const cbMessages = $('#chatbotMessages');
const cbQuick = $('#chatbotQuickReplies');
const cbForm = $('#chatbotForm');
const cbInput = $('#chatbotInput');

let chatOpenedOnce = false;

const budget = {
  active: false,
  step: 0,
  answers: {
    area: '',
    volume: '',
    tools: '',
    complexity: '',
    urgency: ''
  },
  estimate: null
};

const budgetQuestions = [
  {
    key: 'area',
    text: 'Perfecto. Empezamos el diagnóstico rápido. ¿Qué quieres automatizar primero?',
    quick: ['Atención al cliente', 'Correos', 'Reservas', 'Facturación', 'Informes', 'Redes sociales']
  },
  {
    key: 'volume',
    text: '¿Qué volumen aproximado tiene ese proceso?',
    quick: ['Bajo: 1-20 al día', 'Medio: 20-100 al día', 'Alto: +100 al día', 'No lo sé']
  },
  {
    key: 'tools',
    text: '¿Cuántas herramientas habría que conectar?',
    quick: ['1 herramienta', '2-3 herramientas', '4-6 herramientas', '+6 herramientas']
  },
  {
    key: 'complexity',
    text: '¿Qué nivel de complejidad imaginas?',
    quick: ['Simple', 'Intermedio', 'Avanzado', 'No lo sé']
  },
  {
    key: 'urgency',
    text: '¿Cuándo te gustaría tenerlo funcionando?',
    quick: ['Cuanto antes', 'Este mes', '1-2 meses', 'Estoy explorando']
  }
];

function openChatbot({ fullscreen = false, startBudget = false } = {}) {
  if (!cb) return;
  cb.classList.add('open');
  cb.classList.toggle('fullscreen', fullscreen || startBudget);
  document.body.classList.toggle('chatbot-modal-open', fullscreen || startBudget);
  cbFab?.setAttribute('aria-expanded', 'true');
  cbPanel?.setAttribute('aria-hidden', 'false');

  if (!chatOpenedOnce) {
    chatOpenedOnce = true;
    addBotMessage('¡Hola! Soy <strong>MotexBot</strong>. Puedo calcular un presupuesto aproximado, explicarte servicios o llevarte a contacto.');
    renderQuickReplies(['Presupuesto rápido', 'Servicios', 'Cursos', 'Telegram']);
  }

  if (startBudget) startBudgetFlow();

  setTimeout(() => cbInput?.focus(), 250);
}

function closeChatbot() {
  if (!cb) return;
  cb.classList.remove('open', 'fullscreen');
  document.body.classList.remove('chatbot-modal-open');
  cbFab?.setAttribute('aria-expanded', 'false');
  cbPanel?.setAttribute('aria-hidden', 'true');
}

function scrollMessagesToBottom() {
  if (cbMessages) cbMessages.scrollTop = cbMessages.scrollHeight;
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

function renderQuickReplies(items = []) {
  if (!cbQuick) return;
  cbQuick.innerHTML = '';
  items.forEach((item) => {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'quick-reply';
    btn.textContent = item;
    btn.addEventListener('click', () => handleUserInput(item));
    cbQuick.appendChild(btn);
  });
}

function normalize(text) {
  return String(text || '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[¿¡?!.,;:]/g, '')
    .trim();
}

function startBudgetFlow() {
  if (cbMessages) cbMessages.innerHTML = '';
  if (cbQuick) cbQuick.innerHTML = '';
  budget.active = true;
  budget.step = 0;
  budget.answers = { area: '', volume: '', tools: '', complexity: '', urgency: '' };
  budget.estimate = null;
  addUserMessage('Presupuesto rápido');
  askBudgetQuestion();
}

function askBudgetQuestion() {
  const q = budgetQuestions[budget.step];
  if (!q) return finishBudget();
  setTimeout(() => {
    addBotMessage(q.text);
    renderQuickReplies(q.quick);
  }, 250);
}

function saveBudgetAnswer(text) {
  const q = budgetQuestions[budget.step];
  if (!q) return;
  budget.answers[q.key] = text;
  budget.step += 1;
  if (budget.step >= budgetQuestions.length) finishBudget();
  else askBudgetQuestion();
}

function scoreText(text, words) {
  const clean = normalize(text);
  return words.some((w) => clean.includes(normalize(w))) ? 1 : 0;
}

function calculateBudget() {
  const a = budget.answers;
  let setup = 290;
  let monthly = 49;
  let label = 'Automatización inicial';

  if (scoreText(a.area, ['atencion', 'cliente', 'bot', 'chat'])) {
    setup += 120; monthly += 30; label = 'Asistente de atención al cliente';
  }
  if (scoreText(a.area, ['facturacion', 'factura', 'presupuesto', 'cobro'])) {
    setup += 180; monthly += 45; label = 'Sistema administrativo automatizado';
  }
  if (scoreText(a.area, ['informe', 'datos', 'analisis', 'reporte'])) {
    setup += 160; monthly += 35; label = 'Informes automáticos';
  }
  if (scoreText(a.area, ['redes', 'marketing', 'contenido'])) {
    setup += 90; monthly += 25; label = 'Automatización de contenido';
  }
  if (scoreText(a.area, ['reserva', 'cita', 'agenda'])) {
    setup += 140; monthly += 30; label = 'Reservas y agenda inteligente';
  }

  if (scoreText(a.volume, ['medio', '20-100'])) { setup += 130; monthly += 35; }
  if (scoreText(a.volume, ['alto', '+100', '100'])) { setup += 290; monthly += 75; }

  if (scoreText(a.tools, ['2-3', '2', '3'])) { setup += 120; monthly += 25; }
  if (scoreText(a.tools, ['4-6', '4', '5', '6'])) { setup += 260; monthly += 55; }
  if (scoreText(a.tools, ['+6', 'mas de 6', '7'])) { setup += 420; monthly += 95; }

  if (scoreText(a.complexity, ['intermedio'])) { setup += 170; monthly += 35; }
  if (scoreText(a.complexity, ['avanzado'])) { setup += 360; monthly += 85; }

  if (scoreText(a.urgency, ['cuanto antes'])) { setup += 120; }
  if (scoreText(a.urgency, ['este mes'])) { setup += 60; }

  const setupMin = Math.round((setup * 0.85) / 10) * 10;
  const setupMax = Math.round((setup * 1.25) / 10) * 10;
  const monthlyMin = Math.round((monthly * 0.85) / 10) * 10;
  const monthlyMax = Math.round((monthly * 1.25) / 10) * 10;

  return { label, setupMin, setupMax, monthlyMin, monthlyMax };
}

function finishBudget() {
  budget.active = false;
  budget.estimate = calculateBudget();
  const e = budget.estimate;
  const summary = `
    <div class="chat-budget-result">
      <span class="chat-budget-kicker">Estimación MotexBot</span>
      <h3>${e.label}</h3>
      <div class="chat-budget-numbers">
        <div><span>Setup aproximado</span><strong>${e.setupMin} € - ${e.setupMax} €</strong></div>
        <div><span>Mantenimiento</span><strong>${e.monthlyMin} € - ${e.monthlyMax} €/mes</strong></div>
      </div>
      <p>Esta horquilla es orientativa. El precio cerrado depende de accesos, herramientas, seguridad, volumen real y nivel de personalización.</p>
      <ul>
        <li><strong>Proceso:</strong> ${budget.answers.area}</li>
        <li><strong>Volumen:</strong> ${budget.answers.volume}</li>
        <li><strong>Herramientas:</strong> ${budget.answers.tools}</li>
        <li><strong>Complejidad:</strong> ${budget.answers.complexity}</li>
        <li><strong>Urgencia:</strong> ${budget.answers.urgency}</li>
      </ul>
    </div>
  `;
  addBotMessage(summary);
  renderQuickReplies(['Enviar resumen al equipo', 'Repetir estimación', 'Telegram', 'Email clásico']);
}

function sendQuoteSummary() {
  const form = $('#chatQuoteForm');
  if (!form || !budget.estimate) {
    addBotMessage(`Puedes escribir directamente a <a href="${CHATBOT.EMAIL}">contacto@aimotex.com</a>.`);
    return;
  }

  const e = budget.estimate;
  const summary = [
    `Tipo: ${e.label}`,
    `Setup: ${e.setupMin} € - ${e.setupMax} €`,
    `Mensual: ${e.monthlyMin} € - ${e.monthlyMax} €/mes`,
    `Proceso: ${budget.answers.area}`,
    `Volumen: ${budget.answers.volume}`,
    `Herramientas: ${budget.answers.tools}`,
    `Complejidad: ${budget.answers.complexity}`,
    `Urgencia: ${budget.answers.urgency}`
  ].join('\n');

  $('#chatQuoteSummary').value = summary;
  $('#chatQuoteSetup').value = `${e.setupMin} € - ${e.setupMax} €`;
  $('#chatQuoteMonthly').value = `${e.monthlyMin} € - ${e.monthlyMax} €/mes`;

  form.submit();
  addBotMessage('Resumen enviado al equipo. Para completar el contacto, escríbenos tu nombre, empresa y teléfono o usa el email que aparece abajo.');
  renderQuickReplies(['Email clásico', 'Telegram', 'Repetir estimación']);
}

function answerGeneral(text) {
  const clean = normalize(text);

  if (clean.includes('presupuesto') || clean.includes('diagnostico') || clean.includes('calcular')) {
    startBudgetFlow();
    return;
  }
  if (clean.includes('servicio')) {
    addBotMessage('Motex automatiza atención al cliente, correo, reservas, facturación, informes, marketing y procesos internos. Puedes verlo en la página de Servicios.');
    renderQuickReplies(['Presupuesto rápido', 'Cursos', 'Telegram']);
    return;
  }
  if (clean.includes('curso') || clean.includes('formacion')) {
    addBotMessage('Los cursos de Motex son personalizados, con práctica real, plataforma adaptada y mentoría semanal. Hay programas para PYMEs, n8n y equipos.');
    renderQuickReplies(['Presupuesto rápido', 'Email clásico', 'Telegram']);
    return;
  }
  if (clean.includes('telegram')) {
    addBotMessage(`Puedes hablar por Telegram aquí: <a href="${CHATBOT.TELEGRAM}" target="_blank" rel="noopener">@MotexBot</a>`);
    window.open(CHATBOT.TELEGRAM, '_blank', 'noopener');
    return;
  }
  if (clean.includes('email') || clean.includes('correo')) {
    addBotMessage(`Puedes escribirnos a <a href="${CHATBOT.EMAIL}">contacto@aimotex.com</a>.`);
    window.location.href = CHATBOT.EMAIL;
    return;
  }

  addBotMessage('Puedo ayudarte con presupuesto rápido, servicios, cursos o contacto. ¿Qué prefieres?');
  renderQuickReplies(['Presupuesto rápido', 'Servicios', 'Cursos', 'Telegram']);
}

function handleUserInput(text) {
  const value = String(text || '').trim();
  if (!value) return;

  addUserMessage(value);
  if (cbInput) cbInput.value = '';

  const clean = normalize(value);
  if (clean.includes('enviar resumen')) {
    sendQuoteSummary();
    return;
  }
  if (clean.includes('repetir')) {
    startBudgetFlow();
    return;
  }
  if (clean.includes('email clasico')) {
    window.location.href = CHATBOT.EMAIL;
    addBotMessage(`Abriendo email. Dirección: <a href="${CHATBOT.EMAIL}">contacto@aimotex.com</a>`);
    return;
  }
  if (clean.includes('telegram')) {
    window.open(CHATBOT.TELEGRAM, '_blank', 'noopener');
    addBotMessage(`Abriendo Telegram. También puedes entrar aquí: <a href="${CHATBOT.TELEGRAM}" target="_blank" rel="noopener">@MotexBot</a>`);
    return;
  }

  if (budget.active) {
    saveBudgetAnswer(value);
    return;
  }

  answerGeneral(value);
}

cbFab?.addEventListener('click', () => {
  if (cb?.classList.contains('open')) closeChatbot();
  else openChatbot();
});

cbClose?.addEventListener('click', closeChatbot);

cbForm?.addEventListener('submit', (event) => {
  event.preventDefault();
  handleUserInput(cbInput?.value || '');
});

$$('[data-budget-start]').forEach((btn) => {
  btn.addEventListener('click', (event) => {
    event.preventDefault();
    openChatbot({ fullscreen: true, startBudget: true });
  });
});

document.addEventListener('keydown', (event) => {
  if (event.key === 'Escape') closeChatbot();
});
