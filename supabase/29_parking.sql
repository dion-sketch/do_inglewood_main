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
