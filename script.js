
(() => {
  const $ = (s, r=document)=>r.querySelector(s); const $$ = (s,r=document)=>Array.from(r.querySelectorAll(s));
  const active=document.body.dataset.active; $$(`.nav-links a[data-nav="${active}"]`).forEach(a=>a.classList.add('active'));
  $('#navToggle')?.addEventListener('click',()=>$('#mobileMenu')?.classList.toggle('open'));

  const promo=$('#promoModal');
  if(promo && !sessionStorage.getItem('motexPromoClosed')) setTimeout(()=>promo.classList.add('open'),700);
  $$('[data-close-promo]').forEach(b=>b.addEventListener('click',()=>{promo?.classList.remove('open');sessionStorage.setItem('motexPromoClosed','1')}));

  $$('.service-accordion .accordion-trigger').forEach(btn=>btn.addEventListener('click',()=>btn.closest('.service-accordion').classList.toggle('open')));
  $$('[data-program-target]').forEach(btn=>btn.addEventListener('click',()=>{
    const id='program-'+btn.dataset.programTarget; const panel=document.getElementById(id); if(!panel)return; panel.classList.toggle('open'); if(panel.classList.contains('open')) panel.scrollIntoView({behavior:'smooth',block:'nearest'});
  }));
  if(location.hash && location.hash.startsWith('#programa-')){ const card=$(location.hash); const panel=card?.querySelector('.program-panel'); if(panel){panel.classList.add('open');setTimeout(()=>card.scrollIntoView({behavior:'smooth',block:'center'}),250)} }

  const payment=$('#paymentModal');
  $$('[data-payment]').forEach(btn=>btn.addEventListener('click',()=>{ $('#paymentTitle').textContent='Inscripción · '+btn.dataset.course; $('#paymentCourse').textContent=btn.dataset.course; $('#paymentPrice').textContent=btn.dataset.price; $('#paymentStatus').textContent='Pago seguro pendiente de conectar a pasarela real.'; payment?.classList.add('open'); }));
  $$('[data-close-payment]').forEach(b=>b.addEventListener('click',()=>payment?.classList.remove('open')));
  $('#paymentContinue')?.addEventListener('click',()=>$('#paymentStatus').textContent='Perfecto. El siguiente paso sería conectar Stripe/PayPal para procesar el pago real.');

  const chat=$('#savingsBot'), body=$('#chatBody'), quick=$('#chatQuick'), form=$('#chatForm'), input=$('#chatInput');
  const DEFAULT_HOURLY = 26.51; let state={step:0, employees:null, tasks:'', hours:null, hourly:null, percent:null};
  const questions=[
    {key:'employees', text:'Vamos a calcular cuánto dinero se puede ahorrar tu empresa. ¿Cuántos empleados participan en tareas repetitivas?', quick:['1','3','5','10','20+']},
    {key:'tasks', text:'¿Qué tareas repetitivas quieres reducir? Por ejemplo: correos, facturas, informes, reservas, atención al cliente, redes sociales…', quick:['Correos','Facturas','Reservas','Informes','Atención al cliente','Redes sociales']},
    {key:'hours', text:'¿Cuántas horas repetitivas pierde cada empleado a la semana aproximadamente?', quick:['2 h','5 h','10 h','15 h','20 h']},
    {key:'hourly', text:'¿Sabes el coste por hora aproximado? Si no lo sabes, escribo la media de referencia: 26,51 €/h.', quick:['Usar media','18 €/h','25 €/h','35 €/h','50 €/h']},
    {key:'percent', text:'¿Qué porcentaje de esas tareas crees que podríamos automatizar o reducir?', quick:['30%','50%','70%','80%']}
  ];
  function openChat(){ chat?.classList.add('open'); start(); setTimeout(()=>input?.focus(),100); }
  function closeChat(){ chat?.classList.remove('open'); }
  $$('[data-savings-start],[data-budget-start]').forEach(b=>b.addEventListener('click',openChat));
  $$('[data-close-chat]').forEach(b=>b.addEventListener('click',closeChat));
  function add(text, who='bot'){ const d=document.createElement('div'); d.className='msg '+who; d.innerHTML=text; body.appendChild(d); body.scrollTop=body.scrollHeight; }
  function setQuick(items=[]){ quick.innerHTML=''; items.forEach(t=>{const b=document.createElement('button'); b.type='button'; b.textContent=t; b.addEventListener('click',()=>handle(t)); quick.appendChild(b);}); }
  function start(){ state={step:0, employees:null, tasks:'', hours:null, hourly:null, percent:null}; body.innerHTML=''; add('Hola, soy MotexBot. Te haré unas preguntas rápidas y calcularé una estimación de ahorro mensual y anual.'); ask(); }
  function ask(){ const q=questions[state.step]; add(q.text); setQuick(q.quick); }
  function numberFrom(text){ const m=String(text).replace(',','.').match(/\d+(\.\d+)?/); return m?parseFloat(m[0]):null; }
  function handle(text){ if(!text) return; add(text,'user'); const q=questions[state.step]; let val=numberFrom(text);
    if(q.key==='employees') state.employees = val || (String(text).includes('+')?20:1);
    if(q.key==='tasks') state.tasks = text;
    if(q.key==='hours') state.hours = val || 5;
    if(q.key==='hourly') state.hourly = /media|no sé|no se/i.test(text) ? DEFAULT_HOURLY : (val || DEFAULT_HOURLY);
    if(q.key==='percent') state.percent = val || 50;
    state.step++; if(state.step < questions.length){ setTimeout(ask,300); } else { setQuick(['Recalcular','Hablar por Telegram','Ver cursos']); setTimeout(result,300); }
  }
  function euro(n){ return new Intl.NumberFormat('es-ES',{style:'currency',currency:'EUR',maximumFractionDigits:0}).format(n); }
  function result(){ const hoursMonth=state.employees*state.hours*4.33; const recovered=hoursMonth*(state.percent/100); const monthly=recovered*state.hourly; const annual=monthly*12; const setup= monthly<900?690:monthly<2500?1200:2200; const maint= monthly<900?89:monthly<2500?149:249; const roi=Math.max(0.3, setup/Math.max(monthly-maint,1));
    add(`<div class="result-card"><strong>Estimación de ahorro Motex</strong><p>Para ${state.employees} empleado(s), tareas como <b>${state.tasks}</b>, ${state.hours} h/semana por persona y ${state.percent}% automatizable.</p><div class="result-grid"><div><span>Horas recuperables/mes</span><strong>${Math.round(recovered)} h</strong></div><div><span>Ahorro mensual</span><strong>${euro(monthly)}</strong></div><div><span>Ahorro anual</span><strong>${euro(annual)}</strong></div><div><span>Retorno estimado</span><strong>${roi.toFixed(1)} meses</strong></div></div><p class="muted">Inversión orientativa desde ${euro(setup)} + mantenimiento desde ${euro(maint)}/mes. La cifra se ajusta con un diagnóstico real de procesos.</p></div>`);
  }
  form?.addEventListener('submit',e=>{ e.preventDefault(); const t=input.value.trim(); input.value=''; if(!t)return; if(t.toLowerCase().includes('telegram')){add('Puedes escribirnos aquí: <a href="https://t.me/MotexBot" target="_blank">@MotexBot</a>');return} if(t.toLowerCase().includes('curso')){add('Puedes ver los cursos aquí: <a href="/cursos/">Cursos Motex</a>');return} if(t.toLowerCase().includes('recalcular')){start();return} handle(t); });
})();
