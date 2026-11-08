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
