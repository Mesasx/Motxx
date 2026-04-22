# Guía para publicar Motxx IA

Guía rápida para poner la web online en menos de 30 minutos.

## Opción recomendada: Vercel (gratis, fácil)

### 1. Sube los archivos a GitHub

Desde la terminal de VS Code, en la carpeta de tu proyecto:

```bash
git add .
git commit -m "Versión final de la web"
git push
```

### 2. Crea cuenta en Vercel

1. Ve a [vercel.com](https://vercel.com) y regístrate **con tu cuenta de GitHub** (botón "Continue with GitHub")
2. Autoriza a Vercel a acceder a tus repositorios

### 3. Importa el repositorio

1. Dashboard de Vercel → botón **"Add New Project"**
2. Busca tu repositorio `motxx-web` en la lista
3. Dale a **Import**
4. Framework preset: **Other** (es HTML puro, no necesita build)
5. Todo lo demás déjalo por defecto
6. Dale a **Deploy**

Vercel detectará que es una web estática y en 30-60 segundos tu web estará online en una URL tipo:

```
https://motxx-web.vercel.app
```

### 4. Conecta tu dominio motxx.es

1. En Vercel, entra a tu proyecto → pestaña **Settings** → **Domains**
2. Añade `motxx.es` y también `www.motxx.es`
3. Vercel te mostrará los registros DNS que necesitas añadir

En paralelo, ve a **Shopify** → **Settings** → **Domains** → **motxx.es** → **DNS settings**:

Tendrás que **cambiar** los registros actuales. Importante:
- **Cambia el registro A** de `23.227.38.69` (IP de Shopify) por la IP que te dé Vercel (típicamente `76.76.21.21`)
- **Añade un CNAME** para `www` apuntando a `cname.vercel-dns.com`

⚠️ **Los registros MX y TXT de ImprovMX NO los toques.** Son del correo y deben quedarse.

### 5. Espera la propagación DNS

Entre 5 minutos y 24 horas. Normalmente en 15-30 minutos ya funciona.

Cuando te aparezca el tick verde en Vercel al lado de `motxx.es`, tu web está online en tu dominio.

## Cada vez que quieras actualizar la web

Simplemente:

```bash
git add .
git commit -m "Descripción del cambio"
git push
```

Y Vercel detecta el cambio en GitHub y publica la nueva versión automáticamente en menos de 1 minuto. Sin tocar nada más.

## Enlaces útiles

- Dashboard Vercel: [vercel.com/dashboard](https://vercel.com/dashboard)
- Estado del dominio: en la pestaña "Domains" de tu proyecto en Vercel
- Correo: [mail.google.com](https://mail.google.com) (recibes en tu Gmail)
- ImprovMX: [app.improvmx.com](https://app.improvmx.com)

---

# Configurar formularios, pagos y bot de Telegram

La web tiene **dos formularios**: el de contacto (consultas, info, presupuestos) y el de checkout (inscripción a cursos). Los dos envían los datos a tu email `contacto@motxx.es` a través de FormSubmit — sin backend, sin API keys.

## 1. Activar FormSubmit (2 minutos, imprescindible)

FormSubmit es el servicio que convierte los `<form>` de la web en emails automáticos a tu bandeja. Gratis hasta 50 envíos/mes.

### Pasos

1. Sube la web a Vercel como se explica arriba y **haz una primera prueba** enviando el formulario de contacto desde [motxx.es](https://motxx.es) con un email de prueba tuyo.
2. Revisa la bandeja de **contacto@motxx.es** (y la de spam, por si acaso). Recibirás un email de FormSubmit con asunto *"Please Confirm your Email"*. Dentro hay un botón **"Confirm Email"** — púlsalo.
3. A partir de ese momento, todos los envíos llegan automáticamente a tu bandeja formateados en tabla HTML con todos los campos del formulario.

Sin este paso, **nadie que rellene el formulario te llegará** y FormSubmit devuelve error.

### Cómo se ven los emails

Cuando alguien compra un curso, recibirás un email con asunto *"Nueva inscripción a curso — Motxx IA"* y una tabla con:

| Campo | Ejemplo |
|-------|---------|
| Curso | Automatiza tu negocio con n8n + IA |
| Precio | 597 € |
| Metodo_de_pago | Apple Pay |
| Nombre | María |
| Apellidos | García López |
| Email | maria@empresa.com |
| Telefono | +34 600 000 000 |
| Pais | España |
| Empresa | Consultora Alfa S.L. |
| CIF | B12345678 |
| Cargo | CEO |
| Tamano_empresa | 2-10 empleados |
| Sector | Servicios profesionales |
| Facturacion | 100 k – 500 k € |
| Publico_objetivo | Despachos de abogados y notarías en Madrid |
| Objetivo | Automatizar la gestión de documentación |
| Acepta_terminos | on |

### Cerrar el pago manualmente (flujo actual)

Con el esquema de FormSubmit, el proceso de cobro es:

1. Cliente rellena formulario + elige método de pago → FormSubmit te manda el email.
2. Tú, desde tu bandeja, contestas al cliente con **el link de pago** correspondiente al método que eligió:
   - **Tarjeta / Apple Pay / Google Pay** → Stripe Payment Link (ver punto 2).
   - **PayPal** → link de PayPal.Me o factura desde el dashboard de PayPal.
   - **Transferencia** → IBAN y concepto de tu cuenta.
3. Cliente paga, tú confirmas la plaza y le mandas los accesos al curso.

Este flujo es **100% funcional desde el día 1** y te da control total sobre cada inscripción. Más adelante, cuando quieras automatizarlo, hay explicación abajo (punto 3).

## 2. Stripe Payment Links para cobros reales

Aunque el formulario recoge los datos, el pago efectivo lo haces con Stripe. Un Stripe Payment Link ya cubre **Apple Pay, Google Pay, Visa, Mastercard y American Express** en la misma URL.

### Crear los Payment Links (5 minutos)

1. Regístrate en [stripe.com](https://stripe.com) con los datos de tu actividad (autónomo o empresa).
2. Dashboard → **Products** → **Add product**:
   - *"IA para PYMEs y autónomos"* — precio `297 €` — pago único (one-time).
   - *"Automatiza tu negocio con n8n + IA"* — precio `597 €` — pago único.
3. Para cada producto: **Payment links** → **Create payment link** → copia la URL.

Guarda las dos URLs: las usarás cuando respondas a cada cliente por email. Te las copias y pegas.

### Cuenta PayPal

Crea un [PayPal.Me](https://paypal.me) con tu usuario de negocio. Te da un link personalizado tipo `https://paypal.me/MotxxIA/597` que va directo al pago con el importe pre-rellenado.

### Cuenta bancaria para transferencias

Prepara una plantilla de email con tu IBAN, titular y el formato del concepto que pides (ej. *"MOTXX-N8N-[NombreApellidos]"*) para responder rápido a las solicitudes de transferencia.

## 3. Crear el bot de Telegram @MotxxBot

El código de la web ya enlaza a `https://t.me/MotxxBot`. Para que el enlace funcione tienes que registrar el bot.

### Pasos (2 minutos)

1. Abre Telegram y busca **@BotFather** (el oficial, con tick azul).
2. Envíale `/newbot`.
3. Te pedirá un **nombre** (lo que verá el usuario, ej. *"Motxx IA"*).
4. Luego un **username** — escribe `MotxxBot` (debe acabar en "bot"). Si está cogido, prueba `MotxxIABot`, `MotxxIAOficialBot` o similar. **Importante**: si usas uno distinto a `MotxxBot`, tienes que cambiar las referencias en `index.html` y `script.js` (busca y reemplaza `MotxxBot` → `TuNuevoUsername`).
5. BotFather te devuelve un mensaje con un **token** (tipo `123456:ABCdef...`). **Guárdalo en sitio seguro** — es como una contraseña.
6. Opcional: `/setdescription` y `/setuserpic` para personalizar el bot con tu logo.

A partir de aquí, el enlace `t.me/MotxxBot` ya funciona: abre el chat con tu bot y la gente te puede escribir. Los mensajes los lees tú entrando al bot desde tu propio Telegram.

### Opción A (fácil): bot manual

Sin hacer nada más, entras al chat del bot desde tu Telegram y lees los mensajes. Respondes tú a mano. Suficiente para empezar y muy profesional si respondes rápido.

### Opción B: conectar el bot a Claude (respuestas automáticas)

Si quieres que el bot responda solo con IA, necesitas un pequeño servidor. Ejemplo mínimo en Node.js:

```javascript
// telegram-bot.js
import TelegramBot from 'node-telegram-bot-api';
import Anthropic from '@anthropic-ai/sdk';

const bot = new TelegramBot(process.env.TELEGRAM_TOKEN, { polling: true });
const claude = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

const SYSTEM = `Eres el asistente de Motxx IA, empresa española de automatización con IA y formación.
Servicios: atención al cliente con chatbots, correo automático, contenido en redes, reservas, facturación, informes.
Cursos: IA para PYMEs (297€, 8h), n8n+IA (597€, 16h), in-company a medida.
Contacto: formulario en motxx.es, email contacto@motxx.es.
Responde breve, en español, tono profesional y cercano. Si no sabes algo, redirige al formulario de motxx.es.`;

bot.on('message', async (msg) => {
  if (!msg.text) return;
  try {
    const r = await claude.messages.create({
      model: 'claude-sonnet-4-5',
      max_tokens: 500,
      system: SYSTEM,
      messages: [{ role: 'user', content: msg.text }]
    });
    bot.sendMessage(msg.chat.id, r.content[0].text);
  } catch (e) {
    bot.sendMessage(msg.chat.id, 'Tengo un problema técnico. Escríbenos al formulario de motxx.es o a contacto@motxx.es.');
  }
});
```

Lo despliegas gratis en [Railway](https://railway.app) o [Render](https://render.com) con las variables `TELEGRAM_TOKEN` y `ANTHROPIC_API_KEY`. Coste: 0-5 €/mes.

## 4. Upgrades futuros

### Cobro automático real (backend con Stripe)

Cuando quieras que el formulario no solo recoja datos sino que **redirija directamente a Stripe Checkout** con los datos rellenados:

1. Crea una función serverless en Vercel (`/api/create-checkout.js`) que use tu clave secreta de Stripe y reciba los datos del formulario.
2. La función crea una sesión de Stripe con `metadata` que contiene los datos de empresa.
3. Modifica `script.js` para que al enviar el formulario llame a `/api/create-checkout` y redirija al usuario a la URL devuelta por Stripe.
4. En Vercel Dashboard → Settings → Environment Variables añade `STRIPE_SECRET_KEY`.

Con esto, el pago es automático. Los datos de empresa quedan en el evento de pago de Stripe y puedes consultarlos desde su dashboard.

### Reactivar WhatsApp

Cuando decidas volver a mostrar tu número de WhatsApp, los sitios donde hay que añadirlo son:

- `index.html` línea ~38 (nav CTA) y línea ~51 (menú móvil): añadir un enlace `<a href="https://wa.me/34XXXXXXXXX">`.
- Sección del CTA final: añadir un cuarto botón junto a "Agendar consulta gratuita" / "Telegram" / "Email".
- `index.html` footer: añadir una línea más en el bloque de contacto con el icono y el número.
- `script.js` objeto `CHATBOT`: añadir `WHATSAPP: 'https://wa.me/34XXXXXXXXX'` y opcionalmente un nuevo intent en el chatbot.

Dime cuándo quieres reactivarlo y te lo hago en un par de ediciones rápidas.

### Chatbot de la web con IA

El chatbot actual es por reglas (gratis, rápido, limitado). Para que responda con Claude:

1. Crea función serverless `/api/chat.js` que llame a la API de Claude con `process.env.ANTHROPIC_API_KEY`.
2. Modifica `script.js` para que en lugar de matchear contra `INTENTS` haga `fetch('/api/chat', { method: 'POST', body: JSON.stringify({ message: text }) })`.
3. Mantén las reglas como fallback si la API falla.

Coste: céntimos por conversación.

## Si algo falla

| Problema | Solución |
|----------|----------|
| La web no carga en motxx.es | Espera más tiempo a la propagación DNS (hasta 24h) |
| Aparece la tienda antigua de Shopify | Comprueba que has cambiado el registro A |
| El correo deja de funcionar | Revisa que los MX de ImprovMX siguen intactos en Shopify |
| Los cambios no se reflejan | Asegúrate de haber hecho git push |
