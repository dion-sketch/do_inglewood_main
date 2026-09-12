// Do Inglewood — Stripe webhook: auto-activate paid tiers on payment.
//
// Flow: the app opens a Stripe Payment Link with
//   client_reference_id = "<business_id>|<tier>"   (see startUpgrade in index.html)
// When the payment clears, Stripe calls this function and we set
//   di_businesses.tier = 2 (Verified) or 3 (Premium).
// If the subscription is later cancelled, we drop the business back to Free.
//
// Deploy: Supabase Dashboard → Edge Functions → "stripe-webhook" → paste → Deploy.
// IMPORTANT: disable Supabase's JWT verification for THIS function (Stripe can't
//   send a Supabase JWT). CLI: `supabase functions deploy stripe-webhook --no-verify-jwt`
//   Dashboard: the function's settings → turn "Verify JWT" OFF. We verify Stripe's
//   own signature instead, which is the real security boundary.
// Secrets (Edge Functions → Manage secrets):
//   STRIPE_SECRET_KEY       = sk_live_... (or sk_test_...)
//   STRIPE_WEBHOOK_SECRET   = whsec_...   (from the webhook you create in Stripe)
//   SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are provided automatically.
//
// In Stripe: Developers → Webhooks → Add endpoint →
//   URL = https://<your-project>.supabase.co/functions/v1/stripe-webhook
//   Events: checkout.session.completed, customer.subscription.deleted

import Stripe from "https://esm.sh/stripe@16?target=deno";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const STRIPE_KEY  = Deno.env.get("STRIPE_SECRET_KEY") || "";
const WH_SECRET   = Deno.env.get("STRIPE_WEBHOOK_SECRET") || "";
const SB_URL      = Deno.env.get("SUPABASE_URL")!;
const SB_SERVICE  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const stripe = new Stripe(STRIPE_KEY, { apiVersion: "2024-06-20" });
const admin  = createClient(SB_URL, SB_SERVICE);
const cryptoProvider = Stripe.createSubtleCryptoProvider();

// Price → tier fallback (cents), if client_reference_id doesn't carry the tier.
function tierFromAmount(cents: number | null | undefined): number | null {
  if (cents == null) return null;
  if (cents >= 16900 && cents < 50000) return 3; // Premium $169
  if (cents >= 6900  && cents < 16900) return 2; // Verified $69
  if (cents >= 80000) return 3;                   // Enterprise Premium $800
  if (cents >= 50000) return 2;                   // Enterprise Verified $500
  return null;
}

Deno.serve(async (req) => {
  const sig = req.headers.get("stripe-signature");
  if (!sig || !WH_SECRET) return new Response("missing signature/secret", { status: 400 });

  let event: Stripe.Event;
  try {
    const body = await req.text();
    event = await stripe.webhooks.constructEventAsync(body, sig, WH_SECRET, undefined, cryptoProvider);
  } catch (e) {
    return new Response("bad signature: " + (e as Error).message, { status: 400 });
  }

  try {
    if (event.type === "checkout.session.completed") {
      const s = event.data.object as Stripe.Checkout.Session;
      const ref = s.client_reference_id || "";
      const [bizId, tierStr] = ref.split("|");
      let tier = parseInt(tierStr || "", 10);
      if (!tier || (tier !== 2 && tier !== 3)) tier = tierFromAmount(s.amount_total) ?? 0;
      if (bizId && (tier === 2 || tier === 3)) {
        await admin.from("di_businesses").update({
          tier,
          stripe_customer: (s.customer as string) || null,
          stripe_subscription: (s.subscription as string) || null,
          paid_since: new Date().toISOString(),
        }).eq("id", bizId);
        return new Response("activated tier " + tier + " for " + bizId, { status: 200 });
      }
      return new Response("no business/tier in client_reference_id", { status: 200 });
    }

    if (event.type === "customer.subscription.deleted") {
      const sub = event.data.object as Stripe.Subscription;
      // Drop the linked business back to Free when the subscription ends.
      const { data } = await admin
        .from("di_businesses").select("id").eq("stripe_subscription", sub.id).maybeSingle();
      if (data?.id) {
        await admin.from("di_businesses").update({ tier: 1 }).eq("id", data.id);
        return new Response("downgraded " + data.id, { status: 200 });
      }
      return new Response("no matching business", { status: 200 });
    }

    return new Response("ignored " + event.type, { status: 200 });
  } catch (e) {
    return new Response("handler error: " + (e as Error).message, { status: 500 });
  }
});
