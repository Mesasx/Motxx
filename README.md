# Motxx IA

Sitio web oficial de **Motxx IA** — Automatización con inteligencia artificial y formación para PYMEs y autónomos en España.

## Sobre el proyecto

Motxx IA ayuda a empresas a transformar sus operaciones mediante la implantación de soluciones de IA a medida y la formación de sus equipos.

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
motxx-web/
├── index.html      Estructura principal
├── styles.css      Estilos e identidad visual
├── script.js       Interacciones y animaciones
├── favicon.svg     Icono del sitio
└── .gitignore      Archivos ignorados por Git
```

## Contacto

- Web: [motxx.es](https://motxx.es)
- Email: [contacto@motxx.es](mailto:contacto@motxx.es)
- Telegram: [@MotxxBot](https://t.me/MotxxBot)

## Funcionalidades de la web

- **Chatbot flotante** por reglas (esquina inferior derecha). Responde FAQs sobre servicios, cursos, precios, pagos, contacto, RGPD y plazos. Si no entiende, ofrece abrir el formulario de contacto o derivar a Telegram.
- **Modal de checkout** profesional para inscripción a cursos, con flujo en 3 pasos: datos personales → datos de empresa (tamaño, sector, público objetivo, facturación) → selección de método de pago (tarjeta, Apple Pay, Google Pay, PayPal, transferencia). Pantalla de éxito al completar.
- **Modal de contacto** para consultas generales, info de cursos y solicitudes de presupuesto, con los campos de empresa necesarios para calificar el lead.
- **Formularios conectados a FormSubmit** — los datos llegan a `contacto@motxx.es` formateados en tabla HTML. Sin backend, sin API keys, 50 envíos/mes gratis.
- **Canales de contacto**: formulario, Telegram (@MotxxBot) y email. WhatsApp desactivado temporalmente (se añadirá en el futuro).

## Configuración pendiente

Ver `PUBLICAR.md` → sección *"Configurar formularios, pagos y bot de Telegram"* para los pasos de:

1. Activar FormSubmit (confirmar `contacto@motxx.es` una sola vez).
2. Crear el bot `@MotxxBot` en Telegram con @BotFather.
3. (Cuando llegue el momento) Conectar un pago automático real con Stripe y reactivar WhatsApp.
