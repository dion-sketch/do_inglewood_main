-- =====================================================================
-- DO INGLEWOOD — GO LIVE: run this ONCE in Supabase → SQL Editor → Run.
-- Bundles the parking + owner-tier migrations (29, 30, 32, 33).
-- Safe to re-run (every step is 'if not exists'). Push/billing stay OFF.
-- (Push cron 31_parking_push_cron.sql is separate — only when you turn on push.)
-- =====================================================================


-- ========== 29_parking.sql ==========

-- =====================================================================
-- DO INGLEWOOD — Event-day Parking Marketplace
-- Run in Supabase → SQL Editor → New query → Run (after the existing migrations).
--
-- WHY: Lot owners — churches, small businesses, residents near the venues —
-- list their event-day parking. It pulls cars off the stadium and into the
-- community (less congestion) and puts guests on foot near local spots.
-- Owners "sign up like a business": a signed-in user adds their own lot, it
-- starts HIDDEN (approved=false) and only goes public once you approve it in
-- the admin tool — same trust model as self-added businesses.
--
-- The walk/drive time to each venue is COMPUTED in the app from lat/lng +
-- VENUE_COORDS; it is never stored here.
-- =====================================================================

create table if not exists di_parking (
  id              uuid primary key default gen_random_uuid(),
  name            text not null,                 -- "First AME Church Lot"
  address         text,
  latitude        double precision,
  longitude       double precision,
  price           text,                          -- display price, e.g. "$20"
  spots_total     int,                           -- how many spots the lot has
  spots_available int,                           -- open spots right now (optional)
  available       boolean default true,          -- owner master on/off (off = "None")
  notes           text,                          -- "Cash or Venmo · gated lot"
  claimed_by      uuid references auth.users(id) on delete set null,
  approved        boolean default false,         -- admin-gated, like businesses
  is_active       boolean default true,
  created_at      timestamptz default now()
);

create index if not exists di_parking_location_idx
  on di_parking (latitude, longitude)
  where latitude is not null and longitude is not null;

alter table di_parking enable row level security;

-- Public sees only approved, active, available lots.
drop policy if exists di_parking_public_read on di_parking;
create policy di_parking_public_read on di_parking for select
  using (approved = true and is_active = true and available = true);

-- A signed-in owner can add their own lot — but only as pending (approved=false).
-- They cannot self-approve (see the column revoke below).
drop policy if exists di_parking_self_add on di_parking;
create policy di_parking_self_add on di_parking for insert to authenticated
  with check (claimed_by = auth.uid() and approved = false);

-- Owners can read + manage their own lots (even before approval).
drop policy if exists di_parking_owner_read on di_parking;
create policy di_parking_owner_read on di_parking for select to authenticated
  using (claimed_by = auth.uid());

drop policy if exists di_parking_owner_update on di_parking;
create policy di_parking_owner_update on di_parking for update to authenticated
  using (claimed_by = auth.uid()) with check (claimed_by = auth.uid());

drop policy if exists di_parking_owner_delete on di_parking;
create policy di_parking_owner_delete on di_parking for delete to authenticated
  using (claimed_by = auth.uid());

-- Owners manage name/price/spots/availability, but NOT approval or active status —
-- those stay admin-only (service_role bypasses RLS in the admin tool).
revoke update (approved, is_active) on di_parking from authenticated, anon;

-- ========== 30_parking_status.sql ==========

-- =====================================================================
-- DO INGLEWOOD — Parking: live daily status + "follow a lot" alerts
-- Run in Supabase → SQL Editor → New query → Run (after 29_parking.sql).
--
-- WHY: Event-day parking fills up fast. Owners flip a lot's status in real
-- time — Available → Going fast → Full — and people driving in from out of
-- town can FOLLOW a lot (or several) and get told the moment it's going fast
-- or gone, so they're not stuck in traffic heading to a lot that's already
-- full. On a new event day a lot auto-starts as Available (the status is
-- only "sticky" for the day it was set — see status_date), so owners don't
-- have to remember to switch it back on.
--
-- Walk/drive time is still COMPUTED in the app from lat/lng + VENUE_COORDS.
-- =====================================================================

-- 1) Daily real-time status on each lot --------------------------------
alter table di_parking add column if not exists status text default 'open';   -- 'open' | 'going' | 'full'
alter table di_parking add column if not exists status_date date;             -- Los Angeles day the status was last set
alter table di_parking add column if not exists status_updated_at timestamptz;
-- A real photo of the lot (like businesses) — public URL in the business-photos
-- Storage bucket. Owners can add/change it; builds trust ("this is the gated church lot").
alter table di_parking add column if not exists photo_url text;

alter table di_parking drop constraint if exists di_parking_status_chk;
alter table di_parking add constraint di_parking_status_chk
  check (status is null or status in ('open','going','full'));

-- `available` stays the owner's MASTER on/off (is this lot listed at all).
-- `status` is the DAILY state shown to everyone: a Full lot still appears,
-- greyed, so drivers know not to head there. Owners may update status (they
-- already have di_parking_owner_update); approval/active stay admin-only.

-- Make the owner's write access to the new columns explicit (defensive — the
-- table-level UPDATE grant already covers them, but this documents intent and
-- survives a stricter grant setup). approved/is_active stay revoked (29_parking).
grant update (status, status_date, status_updated_at, photo_url) on di_parking to authenticated;

-- 2) Realtime so followers see a flip live while the app is open -------
-- (Safe to re-run: ignore "already member of publication" if it errors.)
do $$
begin
  begin
    alter publication supabase_realtime add table di_parking;
  exception when duplicate_object then null;
           when others then null;
  end;
end $$;

-- 3) "Follow this lot" rides on the existing push subscription ---------
alter table di_push_subscriptions add column if not exists parking_ids text[] not null default '{}';
alter table di_push_subscriptions drop constraint if exists di_push_sub_parking_cap;
alter table di_push_subscriptions add constraint di_push_sub_parking_cap
  check (cardinality(parking_ids) <= 50);

-- Extend di_push_save to also store followed lots. p_parking_ids = NULL
-- means "don't touch" (so saving an event never wipes parking follows, and
-- vice-versa). The old 4-arg callers keep working via the default.
drop function if exists di_push_save(jsonb, uuid, text[], boolean);
create or replace function di_push_save(
  p_subscription jsonb, p_session uuid, p_event_ids text[],
  p_opted_in boolean default true, p_parking_ids text[] default null
) returns void
language plpgsql security definer set search_path = public as $$
begin
  insert into di_push_subscriptions (session_id, user_id, endpoint, subscription, event_ids, opted_in, parking_ids)
  values (p_session, auth.uid(), p_subscription->>'endpoint', p_subscription,
          coalesce(p_event_ids, '{}'), coalesce(p_opted_in, true), coalesce(p_parking_ids, '{}'))
  on conflict (endpoint) do update set
    session_id   = excluded.session_id,
    user_id      = coalesce(excluded.user_id, di_push_subscriptions.user_id),
    subscription = excluded.subscription,
    event_ids    = excluded.event_ids,
    opted_in     = excluded.opted_in,
    parking_ids  = case when p_parking_ids is null then di_push_subscriptions.parking_ids else p_parking_ids end,
    updated_at   = now();
end $$;
revoke execute on function di_push_save(jsonb, uuid, text[], boolean, text[]) from public;
grant  execute on function di_push_save(jsonb, uuid, text[], boolean, text[]) to anon, authenticated;

-- 4) Dedup log for parking pushes (separate from di_push_log, which is
--    foreign-keyed to di_events). One row per (person, lot, kind) per day,
--    so a lot can alert "going fast" once and "gone" once each event day,
--    and the same lot can alert again on the NEXT event day.
create table if not exists di_parking_push_log (
  subscription_id uuid not null references di_push_subscriptions(id) on delete cascade,
  parking_id      uuid not null references di_parking(id) on delete cascade,
  day             date not null,
  kind            text not null check (kind in ('going','full')),
  sent_at         timestamptz not null default now(),
  primary key (subscription_id, parking_id, day, kind)
);
alter table di_parking_push_log enable row level security;  -- service key only (Edge Function)

-- ROLLBACK:
--   drop table if exists di_parking_push_log;
--   alter table di_push_subscriptions drop column if exists parking_ids;
--   alter table di_parking drop column if exists status, drop column if exists status_date, drop column if exists status_updated_at;
--   drop function if exists di_push_save(jsonb, uuid, text[], boolean, text[]);
--   -- (restore the 4-arg di_push_save from 25_event_day_engagement.sql)

-- ========== 32_owner_tiers.sql ==========

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

-- ========== 33_biz_parking_link.sql ==========

-- =====================================================================
-- DO INGLEWOOD — Let a Premium business offer its lot in the Parking page
-- Run in Supabase → SQL Editor → New query → Run (after 30_parking_status.sql).
-- =====================================================================

-- Remember the owner's toggle on the business.
alter table di_businesses add column if not exists offers_parking boolean default false;
grant update (offers_parking) on di_businesses to authenticated;

-- Link a parking lot back to the business that offers it (so toggling off can find it,
-- and so we don't create duplicates). A business lot is otherwise a normal di_parking row
-- (owner inserts it as pending via the existing self-add policy; admin approves).
alter table di_parking add column if not exists business_id uuid references di_businesses(id) on delete cascade;
create index if not exists di_parking_business_idx on di_parking (business_id) where business_id is not null;

-- ROLLBACK:
--   alter table di_parking drop column if exists business_id;
--   alter table di_businesses drop column if exists offers_parking;
