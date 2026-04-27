// =========================================================
// MOTEX — interacción principal + MotexBot Ahorro Empresarial
// =========================================================

const nav = document.getElementById('nav');
if (nav) {
  window.addEventListener('scroll', () => {
    nav.classList.toggle('scrolled', window.pageYOffset > 50);
  });
}

const navToggle = document.getElementById('navToggle');
const mobileMenu = document.getElementById('mobileMenu');
if (navToggle && mobileMenu) {
  navToggle.addEventListener('click', () => {
    navToggle.classList.toggle('open');
    mobileMenu.classList.toggle('open');
  });
  mobileMenu.querySelectorAll('a, button').forEach(el => {
    el.addEventListener('click', () => {
      navToggle.classList.remove('open');
      mobileMenu.classList.remove('open');
    });
  });
}

// Animaciones reveal
const observer = 'IntersectionObserver' in window
  ? new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          entry.target.classList.add('visible');
          observer.unobserve(entry.target);
        }
      });
    }, { threshold: 0.1, rootMargin: '0px 0px -80px 0px' })
  : null;

document.querySelectorAll('.reveal').forEach((el, i) => {
  el.style.transitionDelay = `${Math.min(i * 0.04, 0.32)}s`;
  if (observer) observer.observe(el);
  else el.classList.add('visible');
});

// Botones de programa si existen
function openProgramFromHash() {
  const id = (window.location.hash || '').replace('#', '');
  if (!id) return;
  const target = document.getElementById(id);
  if (!target) return;
  target.classList.add('open');
  const body = target.querySelector('.program-body, .course-program-body');
  if (body) body.style.maxHeight = body.scrollHeight + 'px';
  setTimeout(() => target.scrollIntoView({ behavior: 'smooth', block: 'center' }), 120);
}

document.addEventListener('click', (e) => {
  const t = e.target.closest('[data-program-toggle]');
  if (!t) return;
  const selector = t.getAttribute('data-program-toggle');
  const target = selector ? document.querySelector(selector) : t.closest('.program-card, .course-card');
  if (!target) return;
  target.classList.toggle('open');
  const body = target.querySelector('.program-body, .course-program-body');
  if (body) body.style.maxHeight = target.classList.contains('open') ? body.scrollHeight + 'px' : '0px';
});

window.addEventListener('hashchange', openProgramFromHash);
openProgramFromHash();

// =========================================================
// MOTEXBOT · AHORRO EMPRESARIAL
// =========================================================
const CHATBOT = {
  TELEGRAM: 'https://t.me/MotexBot',
  EMAIL: 'mailto:contacto@aimotex.com',
  AVG_HOURLY_COST: 26.51,     // INE ETCL 4T 2025: coste por hora efectiva
  EMPLOYER_MULTIPLIER: 1.3065, // aprox. cotizaciones empresa: CC + desempleo + Fogasa + FP + MEI
  MONTHLY_HOURS: 160,
  WEEKS_PER_MONTH: 4.33
};

const cb         = document.getElementById('chatbot');
const cbFab      = document.getElementById('chatbotFab');
const cbPanel    = document.getElementById('chatbotPanel');
const cbClose    = document.getElementById('chatbotClose');
const cbMessages = document.getElementById('chatbotMessages');
const cbQuick    = document.getElementById('chatbotQuickReplies');
const cbForm     = document.getElementById('chatbotForm');
const cbInput    = document.getElementById('chatbotInput');
const cbTitle    = document.getElementById('chatbotTitle');

let cbOpened = false;
let savingsFlow = null;
let lastSavingsResult = null;

function normalize(text) {
  return String(text || '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[¿¡?!,;:]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function formatEUR(n) {
  return Math.round(n).toLocaleString('es-ES') + ' €';
}

function formatHours(n) {
  return Math.round(n).toLocaleString('es-ES') + ' h';
}

function extractNumbers(text) {
  const clean = normalize(text).replace(/(\d),(\d)/g, '$1.$2');
  const matches = clean.match(/\d+(?:\.\d+)?/g) || [];
  return matches.map(Number).filter(n => !Number.isNaN(n));
}

function averageRange(text) {
  const nums = extractNumbers(text);
  if (nums.length >= 2 && /-|a|hasta|entre/.test(normalize(text))) return (nums[0] + nums[1]) / 2;
  return nums[0];
}

const TASK_CATALOG = [
  { id: 'email', label: 'Correos', patterns: ['correo', 'email', 'gmail', 'outlook', 'bandeja', 'responder correos'], rate: 0.68 },
  { id: 'support', label: 'Atención al cliente', patterns: ['cliente', 'soporte', 'atencion', 'whatsapp', 'telegram', 'chat', 'consultas', 'llamadas'], rate: 0.62 },
  { id: 'booking', label: 'Reservas y agenda', patterns: ['reserva', 'agenda', 'cita', 'calendario', 'recordatorio', 'horario'], rate: 0.72 },
  { id: 'billing', label: 'Facturación y presupuestos', patterns: ['factura', 'facturacion', 'presupuesto', 'cobro', 'albaran', 'pago'], rate: 0.58 },
  { id: 'reports', label: 'Informes y análisis', patterns: ['informe', 'reporte', 'dashboard', 'excel', 'analisis', 'datos', 'kpi'], rate: 0.70 },
  { id: 'marketing', label: 'Contenido y marketing', patterns: ['redes', 'marketing', 'contenido', 'publicacion', 'instagram', 'tiktok', 'linkedin', 'newsletter'], rate: 0.52 },
  { id: 'crm', label: 'CRM y seguimiento comercial', patterns: ['lead', 'leads', 'crm', 'seguimiento', 'ventas', 'comercial', 'prospecto'], rate: 0.66 },
  { id: 'admin', label: 'Administración interna', patterns: ['administracion', 'documento', 'archivo', 'copiar', 'pegar', 'formularios', 'manual'], rate: 0.61 }
];

function detectTasks(text) {
  const clean = normalize(text);
  const found = TASK_CATALOG.filter(task => task.patterns.some(p => clean.includes(normalize(p))));
  if (found.length) return found;
  if (clean.includes('todo') || clean.includes('varias') || clean.includes('muchas')) {
    return [TASK_CATALOG[0], TASK_CATALOG[1], TASK_CATALOG[3], TASK_CATALOG[4]];
  }
  return [];
}

function parseEmployees(text) {
  const clean = normalize(text);
  if (clean.includes('autonomo') || clean.includes('solo yo') || clean === 'yo') return 1;
  const avg = averageRange(text);
  if (avg && avg > 0) return Math.max(1, Math.round(avg));
  return null;
}

function parseHoursWeek(text) {
  const clean = normalize(text);
  const nums = extractNumbers(text);
  if (!nums.length) return null;
  let val = nums[0];
  if (nums.length >= 2 && /-|a|entre/.test(clean)) val = (nums[0] + nums[1]) / 2;
  if (clean.includes('dia') || clean.includes('/dia') || clean.includes('al dia')) val *= 5;
  if (clean.includes('mes') || clean.includes('/mes') || clean.includes('al mes')) val = val / CHATBOT.WEEKS_PER_MONTH;
  return Math.max(0.25, Math.min(val, 60));
}

function parseHourlyCost(text) {
  const clean = normalize(text);
  if (clean.includes('media') || clean.includes('no se') || clean.includes('no lo se') || clean.includes('ine')) {
    return { hourly: CHATBOT.AVG_HOURLY_COST, source: 'Media España INE' };
  }
  const nums = extractNumbers(text);
  if (!nums.length) return null;
  let n = nums[0];
  if (n < 120) return { hourly: n, source: 'Coste/hora indicado' };
  const hourly = (n * CHATBOT.EMPLOYER_MULTIPLIER) / CHATBOT.MONTHLY_HOURS;
  return { hourly, source: 'Salario mensual + cotizaciones empresa aprox.' };
}

function parseAutomationRate(text, tasks) {
  const clean = normalize(text);
  if (clean.includes('baja') || clean.includes('poco') || clean.includes('simple')) return 0.40;
  if (clean.includes('media') || clean.includes('moderada') || clean.includes('normal')) return 0.58;
  if (clean.includes('alta') || clean.includes('bastante')) return 0.70;
  if (clean.includes('muy alta') || clean.includes('maxima') || clean.includes('casi todo')) return 0.82;
  if (clean.includes('%')) {
    const n = extractNumbers(text)[0];
    if (n) return Math.max(0.15, Math.min(n / 100, 0.9));
  }
  if (clean.includes('no se') || clean.includes('no lo se') || clean.includes('depende')) return null;
  const n = extractNumbers(text)[0];
  if (n && n <= 100) return Math.max(0.15, Math.min(n / 100, 0.9));
  return null;
}

function defaultRateForTasks(tasks) {
  if (!tasks || !tasks.length) return 0.62;
  return tasks.reduce((sum, t) => sum + t.rate, 0) / tasks.length;
}

function newSavingsFlow() {
  savingsFlow = {
    step: 'employees',
    employees: null,
    tasks: [],
    hoursWeek: null,
    hourlyCost: null,
    hourlySource: null,
    automationRate: null,
    notes: []
  };
}

function addBotMessage(html, extraClass = '') {
  if (!cbMessages) return;
  const div = document.createElement('div');
  div.className = `chat-msg chat-msg-bot ${extraClass}`.trim();
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
  if (!cbMessages) return;
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
  (labels || []).forEach(label => {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'quick-reply';
    btn.textContent = label.text || label;
    btn.addEventListener('click', () => {
      const value = typeof label === 'object' ? (label.value || label.text) : label;
      if (String(value).startsWith('__')) return runSpecialAction(value, btn.textContent);
      handleUserMessage(value, btn.textContent);
    });
    cbQuick.appendChild(btn);
  });
}

function startSavingsFlow(source = 'manual') {
  toggleChatbot(true);
  newSavingsFlow();
  if (cbTitle) cbTitle.textContent = 'MotexBot · calculadora de ahorro';
  setTimeout(() => {
    addBotMessage(`
      <strong>Vamos a calcular cuánto dinero puede recuperar tu empresa.</strong><br><br>
      Te haré pocas preguntas, pero puedes responder como quieras: “somos 8”, “unas 3 horas al día”, “facturas y correos”, “no sé, usa la media”…<br><br>
      Uso como referencia el coste laboral por hora efectiva publicado por el INE y, si me das salario mensual, añado cotizaciones empresariales aproximadas.`);
    askSavingsQuestion();
  }, source === 'autoload' ? 500 : 180);
}

function askSavingsQuestion() {
  if (!savingsFlow) return;
  switch (savingsFlow.step) {
    case 'employees':
      addBotMessage('Primero: <strong>¿cuántas personas hacen tareas repetitivas</strong> que podrían automatizarse?');
      renderQuickReplies(['Solo yo', '2-5 personas', '6-10 personas', '11-25 personas', '+25 personas']);
      break;
    case 'tasks':
      addBotMessage('¿Qué trabajos repetitivos se repiten más dentro de la empresa? Puedes escribir varios.');
      renderQuickReplies(['Correos y respuestas', 'Atención al cliente', 'Reservas y agenda', 'Facturas y presupuestos', 'Informes y Excel', 'Redes sociales']);
      break;
    case 'hours':
      addBotMessage('Aproximadamente, <strong>¿cuántas horas por persona a la semana</strong> se van en esas tareas?');
      renderQuickReplies(['1-3 h/semana', '4-6 h/semana', '7-10 h/semana', '2 h al día', 'No lo sé']);
      break;
    case 'cost':
      addBotMessage('¿Sabes el <strong>coste por hora</strong> o el salario bruto mensual aproximado de esas personas? Si no, uso la media española.');
      renderQuickReplies(['Usar media INE 26,51 €/h', 'Salario 1.500 €/mes', 'Salario 2.000 €/mes', 'Salario 2.500 €/mes']);
      break;
    case 'rate':
      addBotMessage('Última: ¿qué parte de esas tareas crees que podríamos automatizar?');
      renderQuickReplies(['No lo sé, calcula tú', 'Automatización media', 'Alta automatización', 'Casi todo el proceso', 'Solo una parte']);
      break;
    default:
      renderSavingsResult();
  }
}

function handleSavingsAnswer(text) {
  const flow = savingsFlow;
  if (!flow) return false;

  if (flow.step === 'employees') {
    const emp = parseEmployees(text);
    if (!emp) {
      addBotMessage('No he podido sacar el número. Escríbeme algo como “5 personas”, “somos 12” o “solo yo”.');
      renderQuickReplies(['Solo yo', '4 personas', '8 personas', '15 personas']);
      return true;
    }
    flow.employees = emp;
    flow.step = 'tasks';
    askSavingsQuestion();
    return true;
  }

  if (flow.step === 'tasks') {
    let tasks = detectTasks(text);
    if (!tasks.length) {
      tasks = [TASK_CATALOG[7]];
      flow.notes.push('No se detectó una categoría concreta; se estimó como administración interna.');
    }
    flow.tasks = tasks;
    flow.step = 'hours';
    askSavingsQuestion();
    return true;
  }

  if (flow.step === 'hours') {
    let h = parseHoursWeek(text);
    if (!h || normalize(text).includes('no se')) {
      h = 5;
      flow.notes.push('Como no se indicó tiempo exacto, se usaron 5 h/semana por persona como escenario prudente.');
    }
    flow.hoursWeek = h;
    flow.step = 'cost';
    askSavingsQuestion();
    return true;
  }

  if (flow.step === 'cost') {
    let parsed = parseHourlyCost(text);
    if (!parsed) {
      parsed = { hourly: CHATBOT.AVG_HOURLY_COST, source: 'Media España INE' };
      flow.notes.push('Se usó el coste laboral medio por hora efectiva de España publicado por el INE.');
    }
    flow.hourlyCost = parsed.hourly;
    flow.hourlySource = parsed.source;
    flow.step = 'rate';
    askSavingsQuestion();
    return true;
  }

  if (flow.step === 'rate') {
    let rate = parseAutomationRate(text, flow.tasks);
    if (!rate) {
      rate = defaultRateForTasks(flow.tasks);
      flow.notes.push('El porcentaje automatizable se estimó según el tipo de tareas indicado.');
    }
    flow.automationRate = rate;
    flow.step = 'result';
    renderSavingsResult();
    return true;
  }

  return false;
}

function computeSavings(flow) {
  const employees = flow.employees || 1;
  const hoursWeek = flow.hoursWeek || 5;
  const rate = flow.automationRate || defaultRateForTasks(flow.tasks);
  const hourly = flow.hourlyCost || CHATBOT.AVG_HOURLY_COST;
  const weeklyHoursSaved = employees * hoursWeek * rate;
  const monthlyHoursSaved = weeklyHoursSaved * CHATBOT.WEEKS_PER_MONTH;
  const monthlySavings = monthlyHoursSaved * hourly;
  const annualSavings = monthlySavings * 12;
  const complexity = (flow.tasks?.length || 1) + (employees > 10 ? 1 : 0) + (hoursWeek > 8 ? 1 : 0);
  let setupLow = 690, setupHigh = 1490, maintenance = 120;
  if (complexity >= 3) { setupLow = 1200; setupHigh = 2900; maintenance = 190; }
  if (complexity >= 5) { setupLow = 2400; setupHigh = 5200; maintenance = 290; }
  if (employees >= 25) { setupLow += 1200; setupHigh += 2500; maintenance += 180; }
  const paybackMonthsLow = monthlySavings > 0 ? setupLow / monthlySavings : Infinity;
  const paybackMonthsHigh = monthlySavings > 0 ? setupHigh / monthlySavings : Infinity;
  return { employees, hoursWeek, rate, hourly, weeklyHoursSaved, monthlyHoursSaved, monthlySavings, annualSavings, setupLow, setupHigh, maintenance, paybackMonthsLow, paybackMonthsHigh };
}

function renderSavingsResult() {
  const flow = savingsFlow;
  const result = computeSavings(flow);
  lastSavingsResult = { flow, result };
  const taskLabels = (flow.tasks || []).map(t => t.label).join(', ') || 'Tareas repetitivas';
  const roiWidth = Math.max(8, Math.min(100, (result.monthlySavings / Math.max(result.setupLow, 1)) * 70));
  addBotMessage(`
    <div class="savings-result-card">
      <div class="savings-progress">
        <div class="savings-progress-label"><span>Impacto estimado</span><span>${Math.round(result.rate * 100)}% automatizable</span></div>
        <div class="savings-progress-bar"><i style="--w:${Math.round(result.rate * 100)}%"></i></div>
      </div>
      <div class="savings-result-main">
        <div class="savings-result-tile hot"><span>Ahorro potencial al año</span><strong>${formatEUR(result.annualSavings)}</strong></div>
        <div class="savings-result-tile"><span>Ahorro potencial al mes</span><strong>${formatEUR(result.monthlySavings)}</strong></div>
        <div class="savings-result-tile"><span>Horas recuperadas al mes</span><strong>${formatHours(result.monthlyHoursSaved)}</strong></div>
        <div class="savings-result-tile"><span>Inversión orientativa</span><strong>${formatEUR(result.setupLow)} - ${formatEUR(result.setupHigh)}</strong></div>
      </div>
      <ul class="savings-result-list">
        <li>Personas implicadas: <strong>${result.employees}</strong></li>
        <li>Tareas detectadas: <strong>${taskLabels}</strong></li>
        <li>Tiempo repetitivo: <strong>${result.hoursWeek.toFixed(1).replace('.', ',')} h/persona/semana</strong></li>
        <li>Coste usado: <strong>${result.hourly.toFixed(2).replace('.', ',')} €/h</strong> (${flow.hourlySource || 'estimación'})</li>
        <li>Mantenimiento recomendado: desde <strong>${formatEUR(result.maintenance)}/mes</strong></li>
        <li>Retorno orientativo: entre <strong>${result.paybackMonthsLow.toFixed(1).replace('.', ',')}</strong> y <strong>${result.paybackMonthsHigh.toFixed(1).replace('.', ',')}</strong> meses si el escenario se confirma.</li>
      </ul>
      <p class="savings-source-note">Esto no es un presupuesto cerrado: es una estimación inicial basada en coste laboral medio, horas repetitivas y porcentaje automatizable. En una auditoría real se ajusta por sector, herramientas, volumen y complejidad.</p>
    </div>
  `, 'chat-msg-savings');
  renderQuickReplies([
    { text: 'Enviar resumen a Motex', value: '__send_savings__' },
    { text: 'Calcular otro escenario', value: '__restart_savings__' },
    { text: 'Hablar por Telegram', value: '__telegram__' },
    { text: 'Email', value: '__email__' }
  ]);
}

function resultSummaryText() {
  if (!lastSavingsResult) return '';
  const { flow, result } = lastSavingsResult;
  const taskLabels = (flow.tasks || []).map(t => t.label).join(', ') || 'Tareas repetitivas';
  return `Estimación de ahorro MotexBot\n` +
    `Personas implicadas: ${result.employees}\n` +
    `Tareas: ${taskLabels}\n` +
    `Horas repetitivas por persona/semana: ${result.hoursWeek.toFixed(1)}\n` +
    `Porcentaje automatizable: ${Math.round(result.rate * 100)}%\n` +
    `Coste/hora usado: ${result.hourly.toFixed(2)} €/h (${flow.hourlySource || 'estimación'})\n` +
    `Horas recuperables/mes: ${Math.round(result.monthlyHoursSaved)}\n` +
    `Ahorro potencial/mes: ${Math.round(result.monthlySavings)} €\n` +
    `Ahorro potencial/año: ${Math.round(result.annualSavings)} €\n` +
    `Inversión orientativa: ${Math.round(result.setupLow)}-${Math.round(result.setupHigh)} €\n` +
    `Mantenimiento recomendado: desde ${Math.round(result.maintenance)} €/mes`;
}

function runSpecialAction(key, label) {
  if (key === '__restart_savings__') {
    addUserMessage(label || 'Calcular otro escenario');
    newSavingsFlow();
    askSavingsQuestion();
    return true;
  }
  if (key === '__send_savings__') {
    addUserMessage(label || 'Enviar resumen a Motex');
    const form = document.getElementById('chatQuoteForm');
    const summary = document.getElementById('chatQuoteSummary');
    const setup = document.getElementById('chatQuoteSetup');
    const monthly = document.getElementById('chatQuoteMonthly');
    if (summary) summary.value = resultSummaryText();
    if (setup && lastSavingsResult) setup.value = `${formatEUR(lastSavingsResult.result.setupLow)} - ${formatEUR(lastSavingsResult.result.setupHigh)}`;
    if (monthly && lastSavingsResult) monthly.value = `${formatEUR(lastSavingsResult.result.monthlySavings)}/mes de ahorro potencial`;
    if (form) form.submit();
    addBotMessage('Perfecto. He enviado el resumen al equipo de Motex. También puedes escribirnos por Telegram o email si quieres avanzar más rápido.');
    renderQuickReplies([{ text: 'Telegram', value: '__telegram__' }, { text: 'Email', value: '__email__' }, { text: 'Nuevo cálculo', value: '__restart_savings__' }]);
    return true;
  }
  if (key === '__telegram__') {
    addUserMessage(label || 'Telegram');
    window.open(CHATBOT.TELEGRAM, '_blank', 'noopener');
    addBotMessage(`Te abro Telegram. También puedes buscar <a href="${CHATBOT.TELEGRAM}" target="_blank" rel="noopener">@MotexBot</a>.`);
    return true;
  }
  if (key === '__email__') {
    addUserMessage(label || 'Email');
    window.location.href = CHATBOT.EMAIL;
    addBotMessage(`Te abro el correo. La dirección es <a href="${CHATBOT.EMAIL}">contacto@aimotex.com</a>.`);
    return true;
  }
  if (key === '__start_savings__') {
    addUserMessage(label || 'Calcular ahorro');
    startSavingsFlow();
    return true;
  }
  return false;
}

function handleGeneralIntent(text) {
  const clean = normalize(text);
  if (clean.includes('ahorro') || clean.includes('dinero') || clean.includes('automatizar') || clean.includes('presupuesto') || clean.includes('empleado') || clean.includes('horas')) {
    startSavingsFlow();
    return;
  }
  if (clean.includes('curso') || clean.includes('formacion')) {
    addBotMessage('Tenemos cursos para principiantes, PYMEs, automatización premium con n8n y formación a medida para empresas. Si quieres, también puedo calcular cuánto dinero podrías ahorrar antes de decidir qué curso o automatización te conviene.');
    renderQuickReplies([{ text: 'Calcular ahorro', value: '__start_savings__' }, 'Ver cursos']);
    return;
  }
  if (clean.includes('telegram')) return runSpecialAction('__telegram__', 'Telegram');
  if (clean.includes('email') || clean.includes('correo')) return runSpecialAction('__email__', 'Email');
  addBotMessage('Puedo ayudarte a estimar ahorro económico, horas recuperables, automatizaciones posibles o cursos. Lo más llamativo es la calculadora de ahorro: en menos de 2 minutos te da una cifra aproximada.');
  renderQuickReplies([{ text: 'Calcular ahorro', value: '__start_savings__' }, 'Cursos', { text: 'Telegram', value: '__telegram__' }]);
}

function handleUserMessage(rawText, displayText) {
  const text = String(rawText || '').trim();
  if (!text) return;
  addUserMessage(displayText || text);
  renderQuickReplies([]);
  showTyping();
  setTimeout(() => {
    hideTyping();
    if (savingsFlow && savingsFlow.step !== 'result') {
      handleSavingsAnswer(text);
    } else {
      handleGeneralIntent(text);
    }
  }, 420 + Math.random() * 260);
}

function toggleChatbot(force) {
  if (!cb || !cbFab || !cbPanel) return;
  const open = typeof force === 'boolean' ? force : !cb.classList.contains('open');
  cb.classList.toggle('open', open);
  cbFab.setAttribute('aria-expanded', String(open));
  cbPanel.setAttribute('aria-hidden', String(!open));
  document.body.classList.toggle('modal-open', open);

  if (open && !cbOpened) {
    cbOpened = true;
    setTimeout(() => {
      if (cbTitle) cbTitle.textContent = 'MotexBot · calculadora de ahorro';
      addBotMessage('Hola 👋 Soy MotexBot. Puedo calcular <strong>cuánto dinero y cuántas horas podrías ahorrar</strong> automatizando tareas repetitivas de tu empresa.');
      renderQuickReplies([{ text: 'Calcular ahorro ahora', value: '__start_savings__' }, 'Cursos', { text: 'Telegram', value: '__telegram__' }]);
    }, 220);
  }
  if (open) setTimeout(() => cbInput && cbInput.focus(), 260);
}

if (cb && cbFab && cbPanel) {
  cbFab.addEventListener('click', () => toggleChatbot());
  if (cbClose) cbClose.addEventListener('click', () => toggleChatbot(false));
  if (cbForm) cbForm.addEventListener('submit', (e) => {
    e.preventDefault();
    const value = cbInput.value.trim();
    if (!value) return;
    cbInput.value = '';
    handleUserMessage(value);
  });
}

document.addEventListener('click', (e) => {
  const savingsBtn = e.target.closest('[data-budget-start], [data-savings-start]');
  if (savingsBtn) {
    e.preventDefault();
    startSavingsFlow();
  }
});

// Botones de pago/curso: abre una ventana de checkout visual
const courseCheckoutButtons = document.querySelectorAll('[data-course-checkout]');
const paymentModal = document.getElementById('paymentModal');
const paymentCourseTitle = document.getElementById('paymentCourseTitle');
const paymentCoursePrice = document.getElementById('paymentCoursePrice');

function openPaymentModal(title, price) {
  if (!paymentModal) {
    toggleChatbot(true);
    setTimeout(() => {
      addBotMessage(`Para reservar <strong>${title}</strong> (${price}), escríbenos y dejamos preparada la inscripción.`);
      renderQuickReplies([{ text: 'Email', value: '__email__' }, { text: 'Telegram', value: '__telegram__' }]);
    }, 160);
    return;
  }
  if (paymentCourseTitle) paymentCourseTitle.textContent = title || 'Curso Motex';
  if (paymentCoursePrice) paymentCoursePrice.textContent = price || 'Precio a consultar';
  paymentModal.classList.add('open');
  paymentModal.setAttribute('aria-hidden', 'false');
  document.body.classList.add('modal-open');
}

function closePaymentModal() {
  if (!paymentModal) return;
  paymentModal.classList.remove('open');
  paymentModal.setAttribute('aria-hidden', 'true');
  document.body.classList.remove('modal-open');
}

courseCheckoutButtons.forEach(btn => {
  btn.addEventListener('click', (e) => {
    e.preventDefault();
    openPaymentModal(btn.getAttribute('data-course-title'), btn.getAttribute('data-course-price'));
  });
});

document.querySelectorAll('[data-payment-close]').forEach(btn => btn.addEventListener('click', closePaymentModal));
const paymentSubmit = document.getElementById('paymentSubmit');
if (paymentSubmit) {
  paymentSubmit.addEventListener('click', () => {
    paymentSubmit.textContent = 'Pasarela pendiente de conexión';
    setTimeout(() => { paymentSubmit.textContent = 'Continuar con el pago'; }, 1800);
  });
}

// Promo de cursos en la home
const promoModal = document.getElementById('promoModal');
function closePromoModal() {
  if (!promoModal) return;
  promoModal.classList.remove('open');
  promoModal.setAttribute('aria-hidden', 'true');
  try { localStorage.setItem('motexPromoSeen', '1'); } catch (_) {}
}
if (promoModal) {
  let seen = false;
  try { seen = localStorage.getItem('motexPromoSeen') === '1'; } catch (_) {}
  if (!seen) {
    setTimeout(() => {
      promoModal.classList.add('open');
      promoModal.setAttribute('aria-hidden', 'false');
    }, 900);
  }
  promoModal.querySelectorAll('[data-promo-close]').forEach(btn => btn.addEventListener('click', closePromoModal));
}

// Tarjetas de servicio desplegables si existen
function setupExpandableServices() {
  document.querySelectorAll('.service-expand-card, .automation-service-card').forEach((card, index) => {
    const head = card.querySelector('.service-expand-head, .automation-service-head') || card;
    const body = card.querySelector('.service-expand-body, .automation-service-body');
    if (!body) return;
    if (index === 0) {
      card.classList.add('open');
      body.style.maxHeight = body.scrollHeight + 'px';
    }
    head.addEventListener('click', () => {
      card.classList.toggle('open');
      body.style.maxHeight = card.classList.contains('open') ? body.scrollHeight + 'px' : '0px';
    });
  });
}
setupExpandableServices();
