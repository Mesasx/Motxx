// ============================================================
// Motex Campus · Supabase Edge Function: stripe-webhook
// Recibe los eventos de Stripe y concede el acceso al curso
// (crea la matricula) cuando el pago se confirma.
//
// Desplegar:
//   supabase functions deploy stripe-webhook --no-verify-jwt
// Secretos necesarios:
//   supabase secrets set STRIPE_SECRET_KEY=sk_live_...
//   supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_...
//
// En el panel de Stripe, crea un endpoint que apunte a:
//   https://<tu-proyecto>.supabase.co/functions/v1/stripe-webhook
// y escucha el evento "checkout.session.completed".
// ============================================================
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Stripe from "https://esm.sh/stripe@14?target=deno";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY") ?? "", {
  apiVersion: "2023-10-16",
  httpClient: Stripe.createFetchHttpClient(),
});
const cryptoProvider = Stripe.createSubtleCryptoProvider();

Deno.serve(async (req) => {
  const signature = req.headers.get("stripe-signature");
  const body = await req.text();

  let event: Stripe.Event;
  try {
    event = await stripe.webhooks.constructEventAsync(
      body,
      signature!,
      Deno.env.get("STRIPE_WEBHOOK_SECRET")!,
      undefined,
      cryptoProvider,
    );
  } catch (err) {
    return new Response(`Webhook inválido: ${(err as Error).message}`, { status: 400 });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  if (event.type === "checkout.session.completed") {
    const session = event.data.object as Stripe.Checkout.Session;
    const md = session.metadata ?? {};

    if (md.user_id && md.course_id) {
      // Concede el acceso al curso.
      await supabase.from("enrollments").upsert(
        { user_id: md.user_id, course_id: md.course_id, status: "active" },
        { onConflict: "user_id,course_id" },
      );
      // Marca el pago como completado.
      if (md.payment_id) {
        await supabase.from("payments")
          .update({ status: "paid", provider_ref: session.id })
          .eq("id", md.payment_id);
      }
    }
  }

  return new Response(JSON.stringify({ received: true }), {
    headers: { "Content-Type": "application/json" },
  });
});
