# Motex

Web estática multipágina para Motex: automatización, cursos de IA, servicios y calculadora de ahorro.

## Estructura

- `index.html`
- `cursos/index.html`
- `servicios/index.html`
- `automatizaciones/index.html`
- `nosotros/index.html`
- `contacto/index.html`
- `styles.css`
- `script.js`
- `favicon.svg`
- `sitemap.xml`
- `robots.txt`
- `vercel.json`

## Publicación

Sube todo a GitHub y conecta el repositorio con Vercel.

```bash
git add .
git commit -m "Subir web completa Motex"
git push
```

## Nota de pagos

La ventana de pago es visual. Para cobrar realmente hay que conectar Stripe, PayPal Checkout o una pasarela bancaria.


## Activar pagos reales
La ventana de pago ya está preparada. Para cobrar de verdad, abre `script.js` y rellena `PAYMENT_LINKS` con tus enlaces reales:

- `card`, `apple` y `google`: normalmente un Stripe Payment Link del curso.
- `paypal`: enlace de PayPal Payment Link o botón de PayPal.
- `bizum`: enlace de tu pasarela bancaria si la tienes.
- `transfer`: puede quedarse como `mailto:` con instrucciones.

Sin esos enlaces, la web no puede cobrar dinero real porque no debe inventarse una cuenta PayPal/Stripe.
