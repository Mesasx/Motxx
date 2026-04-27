# AIMOTEX

Sitio web oficial de **AIMOTEX** — Automatización con inteligencia artificial y formación para PYMEs y autónomos en España.

## Sobre el proyecto

AIMOTEX ayuda a empresas a transformar sus operaciones mediante la implantación de soluciones de IA a medida y la formación de sus equipos.

## Servicios

- Atención al cliente inteligente con IA
- Gestión automática de correo electrónico
- Contenido para redes sociales
- Reservas y agenda automatizadas
- Facturación y presupuestos inteligentes
- Informes y análisis con IA
- **Formación**: cursos de IA para PYMEs, n8n + IA, y programas in-company

## Tecnologías que usamos

- **IA**: Claude (Anthropic), ChatGPT (OpenAI), Copilot (Microsoft)
- **Orquestación**: n8n, Make, Zapier
- **Integraciones**: WhatsApp, Gmail, Google Calendar, CRMs

## Stack técnico del sitio

Web estática en HTML, CSS y JavaScript vanilla. Sin frameworks, sin dependencias, sin build. Desplegable en cualquier hosting estático (Vercel, Netlify, Cloudflare Pages).

## Estructura

```
aimotex-web/
├── index.html      Estructura principal
├── styles.css      Estilos e identidad visual
├── script.js       Interacciones y animaciones
├── favicon.svg     Icono del sitio
└── .gitignore      Archivos ignorados por Git
```

## Contacto

- Web: [aimotex.com](https://aimotex.com)
- Email: [contacto@aimotex.com](mailto:contacto@aimotex.com)
- Telegram: [@AimotexBot](https://t.me/AimotexBot)

## Funcionalidades de la web

- **Chatbot flotante** por reglas (esquina inferior derecha). Responde FAQs sobre servicios, cursos, precios, pagos, contacto, RGPD y plazos. Si no entiende, ofrece abrir el formulario de contacto o derivar a Telegram.
- **Modal de checkout** profesional para inscripción a cursos, con flujo en 3 pasos: datos personales → datos de empresa (tamaño, sector, público objetivo, facturación) → selección de método de pago (tarjeta, Apple Pay, Google Pay, PayPal, transferencia). Pantalla de éxito al completar.
- **Modal de contacto** para consultas generales, info de cursos y solicitudes de presupuesto, con los campos de empresa necesarios para calificar el lead.
- **Formularios conectados a FormSubmit** — los datos llegan a `contacto@aimotex.com` formateados en tabla HTML. Sin backend, sin API keys, 50 envíos/mes gratis.
- **Canales de contacto**: formulario, Telegram (@AimotexBot) y email. WhatsApp desactivado temporalmente (se añadirá en el futuro).


## Rediseño Next Level incluido

Esta versión mantiene la estética AIMOTEX y añade una capa más interactiva:

- Hero renovado con mini panel “AIMOTEX OS” y métricas visuales.
- Página interna de **Cursos** al pulsar `#cursos`, centrada solo en formación.
- Laboratorio interactivo de automatizaciones: atención al cliente, correo, redes e informes.
- Calculadora de ahorro mensual para estimar horas y coste recuperable.
- Ruta de aprendizaje para explicar mejor los cursos.
- Chatbot mejorado con accesos rápidos a cursos, diagnóstico, calculadora, formulario, Telegram y email.
- Todo sigue en HTML, CSS y JavaScript vanilla, sin build ni dependencias externas.


## Configuración pendiente

Ver `PUBLICAR.md` → sección *"Configurar formularios, pagos y bot de Telegram"* para los pasos de:

1. Activar FormSubmit (confirmar `contacto@aimotex.com` una sola vez).
2. Crear el bot `@AimotexBot` en Telegram con @BotFather.
3. (Cuando llegue el momento) Conectar un pago automático real con Stripe y reactivar WhatsApp.


## Actualización: AimotexBot presupuestador

La web incluye un flujo guiado dentro del chatbot para calcular un presupuesto aproximado en 4 preguntas: tipo de automatización, volumen, integraciones y complejidad. El resultado muestra una horquilla de setup y mantenimiento mensual, y deriva a formulario, Telegram o email.

Precios de lanzamiento actualizados:
- IA para PYMEs y autónomos: 197 €.
- Automatiza tu negocio con n8n + IA: 397 €.
- Formación in-company: desde 690 € para equipos pequeños.

## Actualización: AimotexBot presupuesto inteligente fullscreen

Esta versión sustituye el flujo principal de formularios para presupuestos por un chatbot casi a pantalla completa. El usuario responde en modo conversación y AimotexBot calcula una estimación aproximada de setup y mantenimiento mensual.

### Qué hace ahora AimotexBot

- Abre un chat inmersivo en vez de un formulario cuando el usuario pide diagnóstico, consulta o presupuesto.
- Pregunta por tipo de automatización, volumen, integraciones, complejidad y urgencia.
- Acepta botones rápidos o texto libre del usuario.
- Interpreta respuestas con palabras clave: WhatsApp, correos, reservas, facturas, CRM, informes, redes, etc.
- Genera un presupuesto aproximado competitivo.
- Permite enviar el resumen al equipo por FormSubmit sin hacer rellenar un formulario largo.
- Mantiene como opción secundaria el formulario clásico por email.

### Nota

Sigue siendo una web estática sin backend. El envío del resumen del chat se realiza con FormSubmit mediante un formulario oculto. Para una versión con IA real conectada a API habría que crear una función serverless.
