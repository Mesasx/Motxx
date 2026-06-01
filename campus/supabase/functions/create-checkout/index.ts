// ============================================================
// Motex Campus · Supabase Edge Function: create-checkout
// Crea una sesion de pago en Stripe (tarjeta, Apple Pay o PayPal)
// y devuelve la URL de checkout. El acceso al curso se concede
// despues, desde el webhook, cuando Stripe confirma el cobro.
//
// Desplegar:
//   supabase functions deploy create-checkout --no-verify-jwt
// Secretos necesarios:
//   supabase secrets set STRIPE_SECRET_KEY=sk_live_...
//   (SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY ya existen por defecto)
// ============================================================
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Stripe from "https://esm.sh/stripe@14?target=deno";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY") ?? "", {
  apiVersion: "2023-10-16",
  httpClient: Stripe.createFetchHttpClient(),
});

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Stripe activa Apple Pay automaticamente dentro del metodo "card" si el
// dominio esta verificado. PayPal es su propio metodo de pago.
function paymentMethods(method: string): string[] {
  if (method === "paypal") return ["paypal"];
  return ["card"]; // tarjeta y Apple Pay
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Identificamos al usuario a partir de su token.
    const token = authHeader.replace("Bearer ", "");
    const { data: userData, error: userErr } = await supabase.auth.getUser(token);
    if (userErr || !userData.user) {
      return json({ error: "No autenticado." }, 401);
    }
    const user = userData.user;

    const body = await req.json();
    const { course_id, method, slug } = body;

    // URLs de retorno construidas SIEMPRE en el servidor (evita open redirect).
    const SITE_URL = Deno.env.get("SITE_URL") ?? "https://aimotex.com";
    const safeSlug = String(slug ?? "").replace(/[^a-z0-9_-]/gi, "");
    const success_url = `${SITE_URL}/campus/pago/?slug=${safeSlug}&success=1`;
    const cancel_url = `${SITE_URL}/campus/pago/?slug=${safeSlug}&canceled=1`;

    // Leemos el precio real desde la base de datos (nunca del cliente).
    const { data: course, error: cErr } = await supabase
      .from("courses").select("*").eq("id", course_id).single();
    if (cErr || !course) return json({ error: "Curso no encontrado." }, 404);

    // Evita pagos duplicados si ya esta matriculado.
    const { data: enr } = await supabase
      .from("enrollments").select("id").eq("user_id", user.id)
      .eq("course_id", course_id).eq("status", "active").maybeSingle();
    if (enr) return json({ error: "Ya tienes acceso a este curso." }, 409);

    // Registro de pago pendiente (trazabilidad).
    const { data: payment } = await supabase.from("payments").insert({
      user_id: user.id,
      course_id: course.id,
      amount_cents: course.price_cents,
      currency: course.currency,
      method,
      provider: "stripe",
      status: "pending",
    }).select("id").single();

    const checkout = await stripe.checkout.sessions.create({
      mode: "payment",
      payment_method_types: paymentMethods(method) as any,
      customer_email: user.email,
      line_items: [{
        price_data: {
          currency: (course.currency ?? "EUR").toLowerCase(),
          unit_amount: course.price_cents,
          product_data: { name: course.title, description: course.subtitle ?? undefined },
        },
        quantity: 1,
      }],
      success_url,
      cancel_url,
      metadata: {
        user_id: user.id,
        course_id: course.id,
        payment_id: payment?.id ?? "",
        method,
      },
    });

    if (payment) {
      await supabase.from("payments").update({ provider_ref: checkout.id }).eq("id", payment.id);
    }

    return json({ url: checkout.url });
  } catch (e) {
    return json({ error: (e as Error).message }, 500);
  }
});

function json(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
