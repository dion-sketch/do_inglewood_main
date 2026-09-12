-- =====================================================================
-- DO INGLEWOOD — Stripe subscription linkage (auto-activate paid tiers)
-- Run in Supabase → SQL Editor → New query → Run. Safe to re-run.
--
-- The stripe-webhook edge function writes these when a payment clears, so
-- a business's tier flips automatically (no manual admin step), and a
-- cancelled subscription can drop it back to Free.
-- =====================================================================
alter table di_businesses add column if not exists stripe_customer     text;
alter table di_businesses add column if not exists stripe_subscription text;
alter table di_businesses add column if not exists paid_since          timestamptz;
