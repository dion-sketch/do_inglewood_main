-- =====================================================================
-- DO INGLEWOOD — Owner plan tiers + live status + business license
-- Run in Supabase → SQL Editor → New query → Run.
--
-- Tiers (the `tier` int already exists on di_businesses; no change needed):
--   1 Free · 2 Pro ($69) · 3 Live ($99) · 4 Premium ($149)
-- Billing is NOT turned on here — upgrade buttons don't charge until Rambo says go.
-- =====================================================================

-- Business license on file. PRIVATE: it is NOT added to the public column grant
-- from 26_hide_private_columns.sql, so anon/authenticated cannot read it. The owner
-- still sees their own via di_my_business() (security definer, selects *).
alter table di_businesses add column if not exists business_license text;

-- Live real-time status customers can see (Live tier +). Public-readable.
alter table di_businesses add column if not exists live_status text;      -- 'open' | 'busy' | 'closed' (null = not using it)
alter table di_businesses add column if not exists live_status_date date; -- LA day it was set (the app auto-clears it next day)

alter table di_businesses drop constraint if exists di_biz_live_status_chk;
alter table di_businesses add constraint di_biz_live_status_chk
  check (live_status is null or live_status in ('open','busy','closed'));

-- Public can read the live status (shown on the listing). business_license stays private.
grant select (live_status, live_status_date) on di_businesses to anon, authenticated;

-- Owner can write these on their OWN row (RLS owner policy already limits the row;
-- the di_businesses_guard trigger still blocks tier/approved/stripe self-changes).
grant update (live_status, live_status_date, business_license) on di_businesses to authenticated;

-- ROLLBACK:
--   alter table di_businesses
--     drop column if exists live_status,
--     drop column if exists live_status_date,
--     drop column if exists business_license;
