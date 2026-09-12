# Auto-activate paid tiers with Stripe (do once)

When a business pays, their tier flips automatically (Free → Verified/Premium).
No manual admin step. A cancelled subscription drops them back to Free.

## 1) Run the SQL
Supabase → SQL Editor → run `supabase/17_stripe.sql` (or the whole `turn_on_all.sql`).
Adds `stripe_customer`, `stripe_subscription`, `paid_since` to `di_businesses`.

## 2) Deploy the function (JWT verification OFF)
Stripe can't send a Supabase login token, so this one function must skip JWT
verification — we verify Stripe's own signature instead (that's the real security).
- Dashboard: Edge Functions → Create function → name it exactly `stripe-webhook`
  → paste `functions/stripe-webhook/index.ts` → Deploy → open its settings and
  turn **Verify JWT = OFF**.
- CLI equivalent: `supabase functions deploy stripe-webhook --no-verify-jwt`

## 3) Add secrets
Edge Functions → Manage secrets:
- `STRIPE_SECRET_KEY`     = your `sk_live_…` (or `sk_test_…` while testing)
- `STRIPE_WEBHOOK_SECRET` = the `whsec_…` from step 4
(`SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY` are provided automatically.)

## 4) Create the webhook in Stripe
Stripe → Developers → Webhooks → Add endpoint:
- URL: `https://<your-project>.supabase.co/functions/v1/stripe-webhook`
- Events: `checkout.session.completed` and `customer.subscription.deleted`
- Save, then copy the **Signing secret** (`whsec_…`) into the secret above.

## 5) Use REAL payment links
In `site/index.html`, `STRIPE_LINKS` still points at TEST links. Replace them with
your live Payment Links for $69 (tier 2) and $169 (tier 3). The app already passes
`client_reference_id = "<business_id>|<tier>"`, which the webhook reads to set the
right tier (it also falls back to the amount if that's missing).

## Test
Use a Stripe test card on the test link → within seconds the business's `tier`
becomes 2 or 3 in `di_businesses`. Check Edge Functions → Logs if not.

> Enterprise ($500/$800) is still billed by your team — those aren't self-serve links.
