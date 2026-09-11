-- ============================================================
-- DO INGLEWOOD — TURN ON (all database changes, in order)
-- Paste ALL of this into Supabase SQL Editor and press Run.
-- Safe to run more than once.
-- ============================================================

-- ===== 05_owner_login.sql =====
-- =====================================================================
-- DO INGLEWOOD — Owner Login + Dashboard setup
-- Run in Supabase → SQL Editor → New query → Run.
-- (Also do the 3 dashboard steps in the chat: bucket + auth redirect URL.)
-- =====================================================================

-- 1) Claim detail columns (so claim submissions save fully)
alter table di_claims add column if not exists contact_first_name text;
alter table di_claims add column if not exists contact_last_name  text;
alter table di_claims add column if not exists role text;
alter table di_claims add column if not exists attested boolean;

-- 2) Let a signed-in OWNER update ONLY their own business
--    (admin sets claimed_by = the owner's user id when approving a claim)
drop policy if exists di_businesses_owner_update on di_businesses;
create policy di_businesses_owner_update on di_businesses for update
  using (claimed_by = auth.uid())
  with check (claimed_by = auth.uid());

-- 3) Storage policies for owner photo uploads.
--    FIRST create a PUBLIC bucket named  business-photos  in Storage,
--    THEN run these (public read; only signed-in users can upload).
drop policy if exists "biz photos read"   on storage.objects;
drop policy if exists "biz photos upload" on storage.objects;
drop policy if exists "biz photos update" on storage.objects;
create policy "biz photos read"   on storage.objects for select using (bucket_id = 'business-photos');
create policy "biz photos upload" on storage.objects for insert to authenticated with check (bucket_id = 'business-photos');
create policy "biz photos update" on storage.objects for update to authenticated using (bucket_id = 'business-photos');

-- ===== 06_fix_claims_owner_link.sql =====
-- =====================================================================
-- DO INGLEWOOD — Fix: claim → owner linking (audit finding)
-- Run in Supabase → SQL Editor → New query → Run.
--
-- WHY: di_claims.user_id was set up to point at di_users(id), but the
-- website (and the owner-login system) stores the person's AUTH id there
-- (auth.uid()). Those are two different values, so every claim insert was
-- being REJECTED by the old foreign key — which meant new claims silently
-- never reached the Admin dashboard. This removes that wrong link so
-- claims save, and fixes the owner-can-read-own-claim rule to match.
-- =====================================================================

-- 1) Drop the incorrect foreign key so user_id can hold the auth id.
alter table di_claims drop constraint if exists di_claims_user_id_fkey;

-- 2) Owner can read their OWN claims (user_id now holds auth.uid()).
drop policy if exists di_claims_owner_read on di_claims;
create policy di_claims_owner_read
  on di_claims for select
  using (user_id = auth.uid());

-- ===== 07_reservations.sql =====
-- =====================================================================
-- DO INGLEWOOD — Reservations (Phase 1: link-out to booking providers)
-- Run in Supabase → SQL Editor → New query → Run.
-- Adds a booking link + provider to businesses and to claim submissions.
-- No booking engine yet — the app just links to OpenTable/Resy/Booksy/website.
-- =====================================================================

-- Businesses: where "Reserve" / "Book Now" sends the customer.
alter table di_businesses add column if not exists booking_url          text;
alter table di_businesses add column if not exists reservation_provider text;  -- OpenTable | Resy | Booksy | ...

-- Claims: capture the owner's booking link + provider at claim time.
alter table di_claims     add column if not exists booking_url          text;
alter table di_claims     add column if not exists reservation_provider text;

-- ===== 08_reservations_native.sql =====
-- =====================================================================
-- DO INGLEWOOD — Native reservations (Phase 2)
-- Run in Supabase → SQL Editor → New query → Run.
-- For businesses NOT on OpenTable/Resy: a customer requests a table,
-- the owner accepts/declines it in their dashboard.
-- =====================================================================

create table if not exists di_reservations (
  id             uuid primary key default gen_random_uuid(),
  business_id    text references di_businesses(id) on delete cascade,
  user_id        uuid,                             -- requester's auth id (null for guests)
  customer_name  text,
  customer_phone text,
  party_size     int,
  resv_date      date,
  resv_time      text,
  status         text default 'requested',         -- requested | confirmed | declined | cancelled
  note           text,
  created_at     timestamptz default now()
);

alter table di_reservations enable row level security;

-- Anyone may request a table.
drop policy if exists di_resv_insert on di_reservations;
create policy di_resv_insert on di_reservations for insert with check (true);

-- You can read your own requests; a business owner reads requests for their business.
drop policy if exists di_resv_select on di_reservations;
create policy di_resv_select on di_reservations for select using (
  user_id = auth.uid()
  or business_id in (select id from di_businesses where claimed_by = auth.uid())
);

-- Only the business owner can confirm / decline.
drop policy if exists di_resv_owner_update on di_reservations;
create policy di_resv_owner_update on di_reservations for update using (
  business_id in (select id from di_businesses where claimed_by = auth.uid())
) with check (
  business_id in (select id from di_businesses where claimed_by = auth.uid())
);

-- ===== 09_notify.sql =====
-- =====================================================================
-- DO INGLEWOOD — Owner reservation alerts
-- Run in Supabase → SQL Editor → New query → Run.
-- Adds where reservation alerts are sent. Defaults to the owner's login
-- email inside the edge function if this is left blank.
-- =====================================================================

alter table di_businesses add column if not exists notify_email text;
alter table di_businesses add column if not exists notify_phone text;  -- reserved for SMS later

-- ===== 10_resv_cancel.sql =====
-- =====================================================================
-- DO INGLEWOOD — let a customer cancel their OWN reservation
-- Run in Supabase → SQL Editor → New query → Run.
-- The requester may update their own row, but ONLY to status 'cancelled'
-- (they can't self-confirm). Owner accept/decline is unchanged.
-- =====================================================================

drop policy if exists di_resv_requester_cancel on di_reservations;
create policy di_resv_requester_cancel on di_reservations for update
  using  (user_id = auth.uid())
  with check (user_id = auth.uid() and status = 'cancelled');

-- ===== 11_pause_photos.sql =====
-- =====================================================================
-- DO INGLEWOOD — pause switch + multiple photos
-- Run in Supabase → SQL Editor → New query → Run.
-- =====================================================================

-- Pause = hide a business from the app without deleting it. Existing rows
-- default to active (true).
alter table di_businesses add column if not exists is_active boolean default true;

-- Extra photos (gallery). The main photo stays in photo_url; these are additional.
alter table di_businesses add column if not exists photos text[];

-- ===== 12_menu.sql =====
-- Business menu (dishes + prices), stored as JSON: [{"name":..,"price":..}]
alter table di_businesses add column if not exists menu jsonb;

-- ===== 13_customer_email.sql =====
-- Customer email on reservations (so we can email the confirm/decline).
alter table di_reservations add column if not exists customer_email text;

-- ===== 14_draft_publish.sql =====
-- Draft column (kept for compatibility; premium extras staging).
alter table di_businesses add column if not exists draft jsonb;

-- ===== 15_self_add.sql =====
-- Businesses can add themselves (approval-gated) + size class for pricing.
alter table di_businesses add column if not exists approved boolean default true;
alter table di_businesses add column if not exists is_large boolean default false;
drop policy if exists di_businesses_self_add on di_businesses;
create policy di_businesses_self_add on di_businesses for insert to authenticated
  with check (
    claimed_by = auth.uid()
    and approved = false
    and coalesce(is_large,false) = false
    and coalesce(tier,1) = 1
  );
