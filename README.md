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
- WhatsApp: +34 683 567 360
- Telegram: [@MotxxBot](https://t.me/MotxxBot)

## Funcionalidades de la web

- **Chatbot flotante** por reglas (esquina inferior derecha). Responde FAQs sobre servicios, cursos, precios, pagos, contacto, RGPD y plazos. Si no entiende, redirige a WhatsApp o Telegram.
- **Inscripción a cursos** con botones de pago (Stripe Checkout: Apple Pay, Google Pay, Mastercard, Visa + PayPal aparte). Mientras los Payment Links no estén configurados, los botones redirigen automáticamente a WhatsApp con un mensaje pre-rellenado.
- **Contacto multicanal**: WhatsApp con número visible, Telegram (@MotxxBot) y email en todos los CTAs principales.

## Configuración pendiente

Ver `PUBLICAR.md` → sección *"Configurar pagos y bot de Telegram"* para los pasos de:

1. Crear los Stripe Payment Links y pegarlos en `script.js` (objeto `STRIPE_LINKS`).
2. Crear el bot `@MotxxBot` en Telegram con @BotFather.
3. (Opcional) Conectar el bot a Claude para respuestas automáticas.
