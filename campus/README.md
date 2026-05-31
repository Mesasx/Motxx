# Motex Campus

Plataforma de formación de Motex: registro de alumnos, verificación por
correo, acceso a una primera clase gratuita y compra de cursos con pago en
línea (tarjeta, Apple Pay y PayPal). Es **independiente** del resto de la web
(`/campus/`) y reutiliza su mismo diseño.

Está construida como sitio estático (igual que el resto de aimotex.com) sobre
**Supabase** (autenticación + base de datos) y **Stripe** (cobros).

```
campus/
├── index.html              Panel / catálogo (consciente de la sesión)
├── acceder/                Iniciar sesión (usuario o correo)
├── registro/              Crear cuenta (2 pasos + contraseña segura)
├── verificar/             Pantalla de verificación de correo
├── curso/                 Reproductor de curso con temario y candados
├── pago/                  Pantalla de pago (tarjeta / Apple Pay / PayPal)
├── campus.css            Estilos propios del campus
├── config.js             URL + anon key de Supabase  ← EDITAR
├── lib/app.js            Núcleo de cliente (sesión, perfil, guardas)
└── supabase/
    ├── schema.sql        Tablas, RLS, cursos y clases de ejemplo
    └── functions/        Edge Functions de Stripe (checkout + webhook)
```

## Puesta en marcha

### 1. Base de datos (Supabase)

1. Crea un proyecto en [supabase.com](https://supabase.com) (o reutiliza el de
   StudyFlow: el esquema es independiente y no interfiere).
2. Abre **SQL Editor** y ejecuta `supabase/schema.sql`. Esto crea las tablas
   (`campus_profiles`, `courses`, `lessons`, `enrollments`, `payments`), las
   políticas de seguridad (RLS) y carga los **3 cursos** con sus clases (la
   primera clase del curso de iniciación queda como **gratuita**).
3. En **Authentication → Providers → Email**, deja activada la opción
   *"Confirm email"* para que se exija la verificación por correo.
4. En **Authentication → URL Configuration**, añade como *Redirect URL*:
   `https://aimotex.com/campus/verificar/`.

### 2. Conectar el front-end

Edita `campus/config.js` con los datos de tu proyecto
(**Project Settings → API**):

```js
window.MOTEX_CAMPUS_CONFIG = {
  SUPABASE_URL: "https://xxxx.supabase.co",
  SUPABASE_ANON_KEY: "eyJhbGc...",   // la anon key es pública, no pasa nada
  SITE_URL: "https://aimotex.com"
};
```

Con esto el campus ya permite **registrarse, verificar el correo, iniciar
sesión y ver la primera clase gratis**.

### 3. Crear tu cuenta de moderador (usuario "Mesas")

Por seguridad, **las contraseñas no se guardan en el código**. Para ser el
administrador del campus:

1. Entra en `https://aimotex.com/campus/registro/` y créate la cuenta con el
   usuario **`Mesas`** y tus datos.
2. Verifica el correo.
3. En el SQL Editor de Supabase, ejecuta una sola vez:

   ```sql
   update public.campus_profiles set role = 'admin' where username = 'Mesas';
   ```

A partir de ahí tendrás acceso a todo el contenido y podrás crear más
moderadores:

```sql
update public.campus_profiles set role = 'moderator' where username = '<usuario>';
```

### 4. Pagos (Stripe) — opcional hasta que quieras cobrar

El catálogo, el registro y la clase gratuita funcionan sin Stripe. Para
**cobrar los cursos** despliega las Edge Functions:

```bash
supabase functions deploy create-checkout
supabase functions deploy stripe-webhook --no-verify-jwt

supabase secrets set STRIPE_SECRET_KEY=sk_live_...
supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_...
```

En el panel de Stripe:

- Activa **Apple Pay** (verifica el dominio `aimotex.com`) y **PayPal** como
  métodos de pago. La tarjeta está activa por defecto.
- Crea un **webhook** que apunte a
  `https://<tu-proyecto>.supabase.co/functions/v1/stripe-webhook` y escuche el
  evento `checkout.session.completed`.

Cuando un alumno paga, el webhook crea su matrícula (`enrollments`) y
desbloquea automáticamente todas las clases del curso.

## Cómo funciona el acceso

| Estado del usuario            | Qué puede ver                                  |
|-------------------------------|------------------------------------------------|
| Sin cuenta                    | Catálogo de cursos y precios                    |
| Registrado y verificado       | Primera clase gratis del curso de iniciación    |
| Ha pagado un curso            | Todas las clases de ese curso                   |
| Moderador / admin (`Mesas`)   | Todo el contenido + gestión                     |

La barra de "Pagar ahora" permanece visible en todo momento mientras el alumno
no haya comprado ningún curso. Toda la seguridad real se aplica con **políticas
RLS** en la base de datos: un usuario no puede leer el contenido de una clase de
pago aunque manipule el navegador.

## Subir los vídeos de las clases

Cada clase (`lessons.video_url`) admite una URL de vídeo embebida (YouTube/Vimeo
en modo privado, etc.). Edítalas desde el panel de Supabase o, en el futuro,
desde el panel de moderador.
