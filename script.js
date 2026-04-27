
(() => {
  const $ = (s, r=document)=>r.querySelector(s);
  const $$ = (s,r=document)=>Array.from(r.querySelectorAll(s));
  const active=document.body.dataset.active;
  $$(`.nav-links a[data-nav="${active}"]`).forEach(a=>a.classList.add('active'));
  $('#navToggle')?.addEventListener('click',()=>$('#mobileMenu')?.classList.toggle('open'));

  // Restauramos un logo textual y lo dejamos vivo con un pulso sutil, sin cambiar la identidad.
  $$('.nav-logo,.footer-logo').forEach(logo => logo.setAttribute('data-logo-ready','true'));

  // Interacción visual: tarjetas con tilt, brillo y entrada progresiva.
  const dynamicSelectors = '.hero-panel,.banner-card,.calculator-preview,.info-card,.price-card,.course-card,.service-accordion,.mini-card,.contact-card,.step-grid div,.automated-node';
  $$(dynamicSelectors).forEach(card=>{
    card.classList.add('motion-card');
    card.addEventListener('pointermove', e=>{
      const r=card.getBoundingClientRect();
      const x=(e.clientX-r.left)/r.width, y=(e.clientY-r.top)/r.height;
      card.style.setProperty('--mx', `${(x*100).toFixed(1)}%`);
      card.style.setProperty('--my', `${(y*100).toFixed(1)}%`);
      card.style.setProperty('--rx', `${((0.5-y)*7).toFixed(2)}deg`);
      card.style.setProperty('--ry', `${((x-0.5)*7).toFixed(2)}deg`);
    });
    card.addEventListener('pointerleave',()=>{card.style.setProperty('--rx','0deg');card.style.setProperty('--ry','0deg');});
  });
  const revealObs = 'IntersectionObserver' in window ? new IntersectionObserver(entries=>{
    entries.forEach(entry=>{ if(entry.isIntersecting){ entry.target.classList.add('is-visible'); revealObs.unobserve(entry.target); } });
  },{threshold:.12}) : null;
  $$('.section,.course-card,.info-card,.service-accordion,.price-card,.hero-panel,.banner-card').forEach(el=>{el.classList.add('reveal'); revealObs?.observe(el);});

  // Línea de automatización animada añadida al hero si existe.
  const heroPanel = $('.hero-panel');
  if(heroPanel && !$('.automation-ticker', heroPanel)){
    const ticker=document.createElement('div');
    ticker.className='automation-ticker';
    ticker.innerHTML='<span>Lead recibido</span><i></i><span>IA clasifica</span><i></i><span>CRM actualizado</span><i></i><span>Aviso enviado</span>';
    heroPanel.appendChild(ticker);
  }

  const promo=$('#promoModal');
  if(promo && !sessionStorage.getItem('motexPromoClosed')) setTimeout(()=>promo.classList.add('open'),900);
  $$('[data-close-promo]').forEach(b=>b.addEventListener('click',()=>{promo?.classList.remove('open');sessionStorage.setItem('motexPromoClosed','1')}));

  $$('.service-accordion .accordion-trigger').forEach(btn=>btn.addEventListener('click',()=>{
    const card=btn.closest('.service-accordion');
    card.classList.toggle('open');
    card.animate([{transform:'scale(.995)'},{transform:'scale(1)'}],{duration:180,easing:'ease-out'});
  }));
  $$('[data-program-target]').forEach(btn=>btn.addEventListener('click',()=>{
    const id='program-'+btn.dataset.programTarget;
    const panel=document.getElementById(id);
    if(!panel)return;
    panel.classList.toggle('open');
    btn.textContent = panel.classList.contains('open') ? 'Ocultar programa' : 'Ver programa';
    if(panel.classList.contains('open')) panel.scrollIntoView({behavior:'smooth',block:'nearest'});
  }));
  if(location.hash && location.hash.startsWith('#programa-')){
    const card=$(location.hash); const panel=card?.querySelector('.program-panel'); const btn=card?.querySelector('[data-program-target]');
    if(panel){panel.classList.add('open'); if(btn) btn.textContent='Ocultar programa'; setTimeout(()=>card.scrollIntoView({behavior:'smooth',block:'center'}),250)}
  }

  // Pagos. Sustituye estos enlaces por tus links reales de Stripe/PayPal/Bizum.
  // Stripe Payment Links permite tarjeta, Apple Pay y Google Pay si está activado en tu cuenta.
  const PAYMENT_LINKS = {
    'IA para PYMEs y autónomos': {
      card: '', paypal: '', apple: '', google: '', bizum: '', transfer: 'mailto:contacto@aimotex.com?subject=Pago%20curso%20IA%20para%20PYMEs%20y%20autonomos'
    },
    'Automatiza tu negocio con n8n': {
      card: '', paypal: '', apple: '', google: '', bizum: '', transfer: 'mailto:contacto@aimotex.com?subject=Pago%20curso%20Automatiza%20con%20n8n'
    },
    'Formación in-company': {
      card: '', paypal: '', apple: '', google: '', bizum: '', transfer: 'mailto:contacto@aimotex.com?subject=Propuesta%20formacion%20in-company'
    }
  };
  const payment=$('#paymentModal');
  let paymentState={course:'Curso Motex', price:'', method:'card'};
  function updatePaymentButtons(){
    $$('.payment-methods button').forEach(b=>b.classList.toggle('selected', b.dataset.payMethod===paymentState.method));
    const status=$('#paymentStatus');
    if(status){
      const links = PAYMENT_LINKS[paymentState.course] || {};
      status.textContent = links[paymentState.method]
        ? `Método seleccionado: ${labelMethod(paymentState.method)}. Pulsa continuar para abrir la pasarela.`
        : `Método seleccionado: ${labelMethod(paymentState.method)}. Falta pegar el enlace real de cobro en script.js.`;
    }
  }
  function labelMethod(m){ return ({card:'Tarjeta',paypal:'PayPal',apple:'Apple Pay',google:'Google Pay',bizum:'Bizum',transfer:'Transferencia'})[m] || m; }
  $$('[data-payment]').forEach(btn=>btn.addEventListener('click',()=>{
    paymentState={course:btn.dataset.course, price:btn.dataset.price, method:'card'};
    $('#paymentTitle').textContent='Inscripción · '+paymentState.course;
    $('#paymentCourse').textContent=paymentState.course;
    $('#paymentPrice').textContent=paymentState.price;
    payment?.classList.add('open');
    updatePaymentButtons();
  }));
  $$('[data-close-payment]').forEach(b=>b.addEventListener('click',()=>payment?.classList.remove('open')));
  $$('.payment-methods button').forEach(b=>b.addEventListener('click',()=>{paymentState.method=b.dataset.payMethod; updatePaymentButtons();}));
  $('#paymentContinue')?.addEventListener('click',()=>{
    const links = PAYMENT_LINKS[paymentState.course] || {};
    const url = links[paymentState.method];
    if(url){ window.open(url, '_blank', 'noopener'); return; }
    const status=$('#paymentStatus');
    if(status) status.innerHTML = `Para activar <b>${labelMethod(paymentState.method)}</b>, pega el enlace real en <code>PAYMENT_LINKS</code> dentro de <code>script.js</code>. Mientras tanto, usa Transferencia o escríbenos a <a href="mailto:contacto@aimotex.com">contacto@aimotex.com</a>.`;
  });

  // ===== Bot 1: calculadora de ahorro =====
  const chat=$('#savingsBot'), body=$('#chatBody'), quick=$('#chatQuick'), form=$('#chatForm'), input=$('#chatInput');
  const DEFAULT_HOURLY = 26.51; let state={step:0, employees:null, tasks:'', hours:null, hourly:null, percent:null};
  const questions=[
    {key:'employees', text:'Vamos a calcular cuánto dinero se puede ahorrar tu empresa. ¿Cuántos empleados participan en tareas repetitivas?', quick:['1','3','5','10','20+']},
    {key:'tasks', text:'¿Qué tareas repetitivas quieres reducir? Por ejemplo: correos, facturas, informes, reservas, atención al cliente, redes sociales…', quick:['Correos','Facturas','Reservas','Informes','Atención al cliente','Redes sociales']},
    {key:'hours', text:'¿Cuántas horas repetitivas pierde cada empleado a la semana aproximadamente?', quick:['2 h','5 h','10 h','15 h','20 h']},
    {key:'hourly', text:'¿Sabes el coste por hora aproximado? Si no lo sabes, uso la media de referencia: 26,51 €/h.', quick:['Usar media','18 €/h','25 €/h','35 €/h','50 €/h']},
    {key:'percent', text:'¿Qué porcentaje de esas tareas crees que podríamos automatizar o reducir?', quick:['30%','50%','70%','80%']}
  ];
  function openSavings(){ chat?.classList.add('open'); startSavings(); setTimeout(()=>input?.focus(),100); }
  function closeSavings(){ chat?.classList.remove('open'); }
  $$('[data-savings-start]').forEach(b=>b.addEventListener('click',openSavings));
  $$('[data-close-chat]').forEach(b=>b.addEventListener('click',closeSavings));
  function addSavings(text, who='bot'){ const d=document.createElement('div'); d.className='msg '+who; d.innerHTML=text; body.appendChild(d); body.scrollTop=body.scrollHeight; }
  function setSavingsQuick(items=[]){ quick.innerHTML=''; items.forEach(t=>{const b=document.createElement('button'); b.type='button'; b.textContent=t; b.addEventListener('click',()=>{ if(state.step>=questions.length){ if(/recalcular/i.test(t)){startSavings();return;} if(/presupuesto/i.test(t)){closeSavings();openBudget();return;} if(/curso/i.test(t)){location.href='/cursos/';return;} } handleSavings(t); }); quick.appendChild(b);}); }
  function startSavings(){ state={step:0, employees:null, tasks:'', hours:null, hourly:null, percent:null}; body.innerHTML=''; addSavings('Hola, soy MotexBot. Te haré unas preguntas rápidas y calcularé una estimación de ahorro mensual y anual.'); askSavings(); }
  function askSavings(){ const q=questions[state.step]; addSavings(q.text); setSavingsQuick(q.quick); }
  function numberFrom(text){ const m=String(text).replace(',','.').match(/\d+(\.\d+)?/); return m?parseFloat(m[0]):null; }
  function handleSavings(text){ if(!text) return; addSavings(text,'user'); const q=questions[state.step]; let val=numberFrom(text);
    if(q.key==='employees') state.employees = val || (String(text).includes('+')?20:1);
    if(q.key==='tasks') state.tasks = text;
    if(q.key==='hours') state.hours = val || 5;
    if(q.key==='hourly') state.hourly = /media|no sé|no se/i.test(text) ? DEFAULT_HOURLY : (val || DEFAULT_HOURLY);
    if(q.key==='percent') state.percent = val || 50;
    state.step++; if(state.step < questions.length){ setTimeout(askSavings,260); } else { setSavingsQuick(['Recalcular','Presupuesto rápido','Ver cursos']); setTimeout(resultSavings,260); }
  }
  function euro(n){ return new Intl.NumberFormat('es-ES',{style:'currency',currency:'EUR',maximumFractionDigits:0}).format(n); }
  function resultSavings(){ const hoursMonth=state.employees*state.hours*4.33; const recovered=hoursMonth*(state.percent/100); const monthly=recovered*state.hourly; const annual=monthly*12; const setup= monthly<900?690:monthly<2500?1200:2200; const maint= monthly<900?89:monthly<2500?149:249; const roi=Math.max(0.3, setup/Math.max(monthly-maint,1));
    addSavings(`<div class="result-card"><strong>Estimación de ahorro Motex</strong><p>Para ${state.employees} empleado(s), tareas como <b>${state.tasks}</b>, ${state.hours} h/semana por persona y ${state.percent}% automatizable.</p><div class="result-grid"><div><span>Horas recuperables/mes</span><strong>${Math.round(recovered)} h</strong></div><div><span>Ahorro mensual</span><strong>${euro(monthly)}</strong></div><div><span>Ahorro anual</span><strong>${euro(annual)}</strong></div><div><span>Retorno estimado</span><strong>${roi.toFixed(1)} meses</strong></div></div><p class="muted">Inversión orientativa desde ${euro(setup)} + mantenimiento desde ${euro(maint)}/mes. La cifra se ajusta con un diagnóstico real de procesos.</p></div>`);
  }
  form?.addEventListener('submit',e=>{ e.preventDefault(); const t=input.value.trim(); input.value=''; if(!t)return; if(/presupuesto/i.test(t)){closeSavings(); openBudget(); return;} if(/curso/i.test(t)){addSavings('Puedes ver los cursos aquí: <a href="/cursos/">Cursos Motex</a>');return} if(/recalcular/i.test(t)){startSavings();return} handleSavings(t); });

  // ===== Bot 2: presupuesto rápido =====
  const budget=$('#budgetBot'), budgetBody=$('#budgetBody'), budgetQuick=$('#budgetQuick'), budgetForm=$('#budgetForm'), budgetInput=$('#budgetInput');
  let bState={step:0,type:'',size:'',volume:'',tools:'',complexity:'',urgency:''};
  const bQuestions=[
    {key:'type', text:'¿Qué quieres automatizar primero? Puedes escribirlo libremente o elegir una opción.', quick:['Atención al cliente','Correos','Reservas','Facturación','Informes','Redes sociales','Todo un flujo']},
    {key:'size', text:'¿De qué tamaño es la empresa o equipo que usará la automatización?', quick:['Autónomo','2-5 personas','6-15 personas','16-50 personas','+50 personas']},
    {key:'volume', text:'¿Qué volumen aproximado tendrá? Ejemplo: 30 correos/día, 100 leads/mes, 15 reservas/semana…', quick:['Bajo','Medio','Alto','Muy alto']},
    {key:'tools', text:'¿Qué herramientas habría que conectar? Gmail, Sheets, WhatsApp, web, CRM, Notion, calendario, Holded, Shopify…', quick:['Email + Sheets','Web + Telegram','CRM + Email','Calendario + WhatsApp','Muchas herramientas']},
    {key:'complexity', text:'¿Qué nivel necesitas? Algo sencillo, un flujo completo o un agente con IA que tome decisiones guiadas.', quick:['Sencillo','Flujo completo','Agente con IA','Sistema avanzado']},
    {key:'urgency', text:'¿Cuándo te gustaría tenerlo funcionando?', quick:['Esta semana','Este mes','Sin prisa']}
  ];
  function openBudget(){ budget?.classList.add('open'); startBudget(); setTimeout(()=>budgetInput?.focus(),120); }
  function closeBudget(){ budget?.classList.remove('open'); }
  $$('[data-budget-start]').forEach(b=>b.addEventListener('click',openBudget));
  $$('[data-close-budget]').forEach(b=>b.addEventListener('click',closeBudget));
  function addBudget(text, who='bot'){ const d=document.createElement('div'); d.className='msg '+who; d.innerHTML=text; budgetBody.appendChild(d); budgetBody.scrollTop=budgetBody.scrollHeight; }
  function setBudgetQuick(items=[]){ budgetQuick.innerHTML=''; items.forEach(t=>{const b=document.createElement('button'); b.type='button'; b.textContent=t; b.addEventListener('click',()=>{ if(bState.step>=bQuestions.length){ if(/otro|recalcular/i.test(t)){startBudget();return;} if(/ahorro/i.test(t)){closeBudget();openSavings();return;} if(/email|correo/i.test(t)){addBudget('Puedes escribirnos a <a href="mailto:contacto@aimotex.com">contacto@aimotex.com</a>.');return;} if(/telegram/i.test(t)){window.open('https://t.me/MotexBot','_blank','noopener');return;} } handleBudget(t); }); budgetQuick.appendChild(b);}); }
  function startBudget(){ bState={step:0,type:'',size:'',volume:'',tools:'',complexity:'',urgency:''}; budgetBody.innerHTML=''; addBudget('Hola, soy MotexBot. En menos de un minuto te doy un presupuesto orientativo de automatización.'); askBudget(); }
  function askBudget(){ const q=bQuestions[bState.step]; addBudget(q.text); setBudgetQuick(q.quick); }
  function scoreText(t){
    t=String(t).toLowerCase(); let score=0;
    if(/atenci|cliente|chat|bot|soporte|whatsapp/.test(t)) score+=2;
    if(/factur|presupuesto|cobro|document|pedido/.test(t)) score+=2;
    if(/crm|api|shopify|holded|erp|integraci|base de datos/.test(t)) score+=3;
    if(/agente|decide|clasifica|responde|ia|inteligente/.test(t)) score+=3;
    if(/alto|much|ciento|miles|diario|cada día|cada dia|urgente/.test(t)) score+=2;
    return score;
  }
  function handleBudget(text){ if(!text) return; addBudget(text,'user'); const q=bQuestions[bState.step]; bState[q.key]=text; bState.step++; if(bState.step<bQuestions.length){ setTimeout(askBudget,260); } else { setBudgetQuick(['Calcular otro','Calcular ahorro','Contactar por email','Telegram']); setTimeout(resultBudget,260); } }
  function resultBudget(){
    const all = Object.values(bState).join(' '); let score=scoreText(all);
    if(/autónomo|autonomo|2-5/.test(bState.size.toLowerCase())) score+=0;
    else if(/6-15|16-50/.test(bState.size.toLowerCase())) score+=2;
    else if(/\+50|50/.test(bState.size.toLowerCase())) score+=4;
    if(/alto|muy alto/.test(bState.volume.toLowerCase())) score+=3;
    if(/sencillo/.test(bState.complexity.toLowerCase())) score-=1;
    if(/avanzado/.test(bState.complexity.toLowerCase())) score+=4;
    let setup, monthly, label;
    if(score<=4){ setup=[490,890]; monthly=[59,119]; label='Automatización inicial'; }
    else if(score<=9){ setup=[900,1800]; monthly=[120,220]; label='Flujo conectado con IA'; }
    else if(score<=14){ setup=[1800,3500]; monthly=[220,390]; label='Sistema completo multi-herramienta'; }
    else { setup=[3500,6500]; monthly=[390,690]; label='Proyecto avanzado con agentes IA'; }
    if(/esta semana|urgente/.test(bState.urgency.toLowerCase())){ setup=[Math.round(setup[0]*1.15), Math.round(setup[1]*1.15)]; }
    addBudget(`<div class="result-card budget-result"><span class="result-kicker">${label}</span><strong>Presupuesto orientativo Motex</strong><p>Según lo que has indicado: <b>${bState.type}</b>, equipo <b>${bState.size}</b>, volumen <b>${bState.volume}</b> y herramientas como <b>${bState.tools}</b>.</p><div class="result-grid"><div><span>Setup inicial</span><strong>${euro(setup[0])} - ${euro(setup[1])}</strong></div><div><span>Mantenimiento</span><strong>${euro(monthly[0])} - ${euro(monthly[1])}/mes</strong></div><div><span>Complejidad</span><strong>${label}</strong></div><div><span>Plazo típico</span><strong>7-21 días</strong></div></div><p class="muted">Incluye análisis del proceso, construcción del flujo, pruebas y ajustes iniciales. El precio cerrado depende de accesos, herramientas y volumen real.</p><div class="result-actions"><a class="btn btn-primary" href="mailto:contacto@aimotex.com?subject=Presupuesto%20orientativo%20Motex&body=Hola,%20quiero%20revisar%20este%20presupuesto%20orientativo.%0A%0ATipo:%20${encodeURIComponent(bState.type)}%0AEquipo:%20${encodeURIComponent(bState.size)}%0AVolumen:%20${encodeURIComponent(bState.volume)}%0AHerramientas:%20${encodeURIComponent(bState.tools)}%0AComplejidad:%20${encodeURIComponent(bState.complexity)}%0AUrgencia:%20${encodeURIComponent(bState.urgency)}">Enviar resumen por email</a><a class="btn btn-secondary" href="https://t.me/MotexBot" target="_blank" rel="noopener">Telegram</a></div></div>`);
  }
  budgetForm?.addEventListener('submit',e=>{ e.preventDefault(); const t=budgetInput.value.trim(); budgetInput.value=''; if(!t)return; if(/ahorro/i.test(t)){closeBudget(); openSavings(); return;} if(/telegram/i.test(t)){addBudget('Puedes escribirnos aquí: <a href="https://t.me/MotexBot" target="_blank">@MotexBot</a>');return} if(/email|correo/i.test(t)){addBudget('Puedes enviar el resumen a <a href="mailto:contacto@aimotex.com">contacto@aimotex.com</a>.');return} if(/otro|recalcular|calcular otro/i.test(t)){startBudget();return} handleBudget(t); });

  // Cierre con escape y click fuera.
  document.addEventListener('keydown', e=>{ if(e.key==='Escape'){ closeBudget(); closeSavings(); payment?.classList.remove('open'); promo?.classList.remove('open'); } });
  [budget, chat, payment, promo].forEach(modal=>modal?.addEventListener('click', e=>{ if(e.target===modal) modal.classList.remove('open'); }));
})();
