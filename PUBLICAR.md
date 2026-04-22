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

# Configurar pagos y bot de Telegram

## 1. Stripe Payment Links (para los cursos)

Stripe Checkout soporta Apple Pay, Google Pay, Mastercard y Visa **automáticamente** en un solo link. Solo necesitas PayPal aparte (opcional).

### Crear los Payment Links (5 minutos)

1. Regístrate en [stripe.com](https://stripe.com) con tus datos de autónomo/empresa.
2. Dashboard → **Products** → **Add product**.
3. Crea dos productos:
   - **"IA para PYMEs y autónomos"** — precio `297 €` — pago único.
   - **"Automatiza tu negocio con n8n + IA"** — precio `597 €` — pago único.
4. Para cada producto: **Payment links** → **Create payment link** → copia la URL (formato `https://buy.stripe.com/XXXXXXXX`).

### Pegar los links en el código

Abre `script.js` y busca el bloque `STRIPE_LINKS` (alrededor de la línea 80). Reemplaza:

```javascript
const STRIPE_LINKS = {
  pyme: 'https://buy.stripe.com/REEMPLAZAR_LINK_CURSO_PYME',
  n8n:  'https://buy.stripe.com/REEMPLAZAR_LINK_CURSO_N8N'
};
```

por los tuyos:

```javascript
const STRIPE_LINKS = {
  pyme: 'https://buy.stripe.com/tu_link_real_del_curso_pyme',
  n8n:  'https://buy.stripe.com/tu_link_real_del_curso_n8n'
};
```

Commit, push, y Vercel publica solo. **Hasta que los cambies, los botones redirigen a WhatsApp con un mensaje pre-rellenado** (no se rompe nada).

### Sobre PayPal

Si quieres aceptar PayPal además de Stripe: crea un [PayPal.Me/MotxxIA](https://paypal.com/paypalme) y duplica los botones con esa URL, o integra el botón oficial de PayPal Checkout (requiere cuenta business). Stripe solo procesa tarjetas, Apple Pay y Google Pay — no PayPal.

Mientras no lo configures, el badge de PayPal aparece pero los pagos van todos por Stripe. Si alguien insiste en PayPal, te contactarán por WhatsApp y cobras manualmente.

## 2. Crear el bot de Telegram @MotxxBot

El código de la web ya enlaza a `https://t.me/MotxxBot`. Para que el enlace funcione, tienes que registrar el bot.

### Pasos (2 minutos)

1. Abre Telegram y busca **@BotFather** (el oficial, con tick azul).
2. Envíale `/newbot`.
3. Te pedirá un **nombre** (lo que verá el usuario, ej. *"Motxx IA"*).
4. Luego un **username** — escribe `MotxxBot` (debe acabar en "bot"). Si está cogido, prueba `MotxxIABot`, `MotxxIAOficialBot` o similar. **Importante: si usas uno distinto a `MotxxBot`, tienes que cambiar TODAS las referencias `t.me/MotxxBot` y `@MotxxBot` en `index.html` y `script.js`** (busca y reemplaza).
5. BotFather te devuelve un mensaje con un **token** (tipo `123456:ABCdef...`). **Guárdalo en sitio seguro** — es como una contraseña.
6. Opcional: `/setdescription` y `/setuserpic` para personalizar el bot.

A partir de aquí, el enlace `t.me/MotxxBot` **ya funciona**: abre el chat con tu bot y la gente te puede escribir. Los mensajes los lees tú entrando al bot desde tu propio Telegram (tendrás que administrarlo — más abajo explico cómo automatizarlo).

### Opción A (fácil): bot manual

Sin hacer nada más, entras al chat del bot desde tu Telegram y lees los mensajes que te manden. Respondes tú a mano. Suficiente para empezar.

### Opción B: conectar el bot a Claude (respuestas automáticas)

Si quieres que el bot responda solo con IA, necesitas un pequeño servidor. Ejemplo mínimo en Node.js con `node-telegram-bot-api` y la API de Claude:

```javascript
// telegram-bot.js
import TelegramBot from 'node-telegram-bot-api';
import Anthropic from '@anthropic-ai/sdk';

const bot = new TelegramBot(process.env.TELEGRAM_TOKEN, { polling: true });
const claude = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

const SYSTEM = `Eres el asistente de Motxx IA, empresa española de automatización con IA y formación. 
Servicios: atención al cliente con chatbots, correo automático, contenido en redes, reservas, facturación, informes.
Cursos: IA para PYMEs (297€, 8h), n8n+IA (597€, 16h), in-company a medida.
Contacto: WhatsApp +34 683 567 360, email contacto@motxx.es.
Responde breve, en español, tono profesional y cercano. Si no sabes algo, redirige a WhatsApp.`;

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
    bot.sendMessage(msg.chat.id, 'Tengo un problema técnico. Escríbenos por WhatsApp: +34 683 567 360');
  }
});
```

Lo despliegas gratis en [Railway](https://railway.app) o [Render](https://render.com) con las variables de entorno `TELEGRAM_TOKEN` y `ANTHROPIC_API_KEY`. Coste estimado: 0-5 €/mes según volumen.

## 3. (Opcional) Upgrade del chatbot de la web

El chatbot actual de la web es por **reglas** (gratis, rápido, limitado). Si algún día quieres que responda con Claude como el de Telegram:

1. Crea una función serverless en Vercel (`/api/chat.js`) que reciba el mensaje y llame a la API de Claude usando `process.env.ANTHROPIC_API_KEY`.
2. Modifica `script.js` para que en vez de matchear contra `INTENTS` haga `fetch('/api/chat', { method: 'POST', body: JSON.stringify({ message: text }) })`.
3. En Vercel Dashboard → Settings → Environment Variables, añade `ANTHROPIC_API_KEY`.

Coste estimado: céntimos por conversación. Puedes mantener el sistema de reglas como fallback si la API falla.

## Si algo falla

| Problema | Solución |
|----------|----------|
| La web no carga en motxx.es | Espera más tiempo a la propagación DNS (hasta 24h) |
| Aparece la tienda antigua de Shopify | Comprueba que has cambiado el registro A |
| El correo deja de funcionar | Revisa que los MX de ImprovMX siguen intactos en Shopify |
| Los cambios no se reflejan | Asegúrate de haber hecho git push |
