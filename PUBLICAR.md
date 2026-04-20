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

## Si algo falla

| Problema | Solución |
|----------|----------|
| La web no carga en motxx.es | Espera más tiempo a la propagación DNS (hasta 24h) |
| Aparece la tienda antigua de Shopify | Comprueba que has cambiado el registro A |
| El correo deja de funcionar | Revisa que los MX de ImprovMX siguen intactos en Shopify |
| Los cambios no se reflejan | Asegúrate de haber hecho git push |
