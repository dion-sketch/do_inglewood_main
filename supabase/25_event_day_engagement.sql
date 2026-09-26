-- =====================================================================
-- DO INGLEWOOD — Event-day engagement (deals, shared plans, activity,
-- push subscriptions, "popping" score)
--
-- STATUS: APPROVED (Sep 26). Run after the prerequisites below.
--
-- PREREQUISITE: production is missing migrations 12, 14, 16, 17 and
-- 20–24. Run supabase/turn_on_all.sql, then 20, 21, 22 and 24 first.
-- (19 re-fetches photos and 23 is a note — neither is needed here.)
-- The check in section 0 stops this script if they haven't been run.
--
-- Run in Supabase → SQL Editor → New query → Run. Safe to re-run.
-- Every object keeps the di_ prefix like the rest of the schema.
-- =====================================================================


-- 0) PREREQUISITE CHECK ----------------------------------------------
do $$
begin
  if not exists (select 1 from information_schema.columns
                 where table_schema='public' and table_name='di_businesses' and column_name='featured')
  or not exists (select 1 from information_schema.columns
                 where table_schema='public' and table_name='di_businesses' and column_name='stripe_customer')
  or not exists (select 1 from information_schema.columns
                 where table_schema='public' and table_name='di_events' and column_name='latitude') then
    raise exception 'Run supabase/turn_on_all.sql and 20–24 first (featured / stripe / latitude columns missing).';
  end if;
end $$;


-- 1) ADMINS ------------------------------------------------------------
-- Today "admin" = whoever pastes the service key into tools/admin.html.
-- This adds a real admin role so RLS can say "admins only". Add yourself
-- once (SQL Editor, after signing in to the app with your email):
--   insert into di_admins (auth_id)
--   select id from auth.users where email = '<your email>';
create table if not exists di_admins (
  auth_id    uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz default now()
);
alter table di_admins enable row level security;
-- No policies on purpose: only the SQL Editor / service key can add admins.

create or replace function di_is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from di_admins where auth_id = auth.uid());
$$;


-- 2) SETTINGS (tunable numbers, e.g. the "Popping now" threshold) -----
create table if not exists di_settings (
  key        text primary key,
  value      jsonb not null,
  updated_at timestamptz default now()
);
alter table di_settings enable row level security;
drop policy if exists di_settings_public_read on di_settings;
create policy di_settings_public_read on di_settings for select using (true);
drop policy if exists di_settings_admin_write on di_settings;
create policy di_settings_admin_write on di_settings for all
  using (di_is_admin()) with check (di_is_admin());

insert into di_settings (key, value) values
  ('popping_threshold',      '8'),    -- weighted score needed for 🔥
  ('popping_min_sessions',   '3'),    -- distinct visitors needed for 🔥
  ('popping_window_minutes', '120')   -- look-back window (2 hours)
on conflict (key) do nothing;


-- 3) VENUES + event helpers ------------------------------------------
-- di_events.venue is free text and includes "SoFi Stadium Tours" /
-- "Intuit Dome Tours". Exact name matching links real shows to a venue
-- and leaves tours out, so tours never trigger Event Day.
create table if not exists di_venues (
  id               text primary key,
  name             text not null,
  match_name       text not null unique,  -- lower(di_events.venue)
  latitude         double precision,
  longitude        double precision,
  event_day_anchor boolean not null default true  -- auto-selects Event Day
);
alter table di_venues enable row level security;
drop policy if exists di_venues_public_read on di_venues;
create policy di_venues_public_read on di_venues for select using (true);
drop policy if exists di_venues_admin_write on di_venues;
create policy di_venues_admin_write on di_venues for all
  using (di_is_admin()) with check (di_is_admin());

-- Same coordinates as VENUE_COORDS in site/index.html.
insert into di_venues (id, name, match_name, latitude, longitude, event_day_anchor) values
  ('sofi',            'SoFi Stadium',    'sofi stadium',    33.9535, -118.3392, true),
  ('kia_forum',       'Kia Forum',       'kia forum',       33.9581, -118.3419, true),
  ('intuit_dome',     'Intuit Dome',     'intuit dome',     33.9560, -118.3436, true),
  ('youtube_theater', 'YouTube Theater', 'youtube theater', 33.9537, -118.3398, true)
on conflict (id) do update set event_day_anchor = excluded.event_day_anchor;

-- venue_id: which anchor venue (null for tours, parks, clubs, etc.)
-- starts_at: real timestamp parsed from start_time ("7:30 PM"), in LA
--   time. Null when start_time is "TBD", "Evening", empty, etc.
--   Used for "event likely ends at start + 3.5h" and push timing.
alter table di_events add column if not exists venue_id  text references di_venues(id) on delete set null;
alter table di_events add column if not exists starts_at timestamptz;

create or replace function di_events_derive() returns trigger
language plpgsql set search_path = public as $$
begin
  new.venue_id := (select v.id from di_venues v where v.match_name = lower(trim(new.venue)));
  if new.event_date is not null
     and coalesce(new.start_time, '') ~* '^\s*\d{1,2}:\d{2}\s*[AP]M\s*$' then
    new.starts_at := to_timestamp(new.event_date::text || ' ' || upper(trim(new.start_time)),
                                  'YYYY-MM-DD HH12:MI AM')::timestamp
                     at time zone 'America/Los_Angeles';
  else
    new.starts_at := null;
  end if;
  return new;
end $$;

drop trigger if exists di_events_derive_trg on di_events;
create trigger di_events_derive_trg
  before insert or update of venue, event_date, start_time on di_events
  for each row execute function di_events_derive();

-- Backfill existing events (fires the trigger).
update di_events set venue = venue;

create index if not exists di_events_venue_date_idx on di_events (venue_id, event_date);


-- 4) INGLEWOOD FLAG on businesses ------------------------------------
-- true  = city in the address is Inglewood
-- false = address names another city (Los Angeles, Hawthorne, Lennox…)
-- null  = address has no city; the app treats these as Inglewood until
--         the importer (Phase 1) or lat/lng fills them in.
-- Matches the CITY after a comma, not the word anywhere: 68 listings
-- are on "Inglewood Ave", which runs through Hawthorne and Lawndale.
alter table di_businesses add column if not exists is_inglewood boolean;

update di_businesses set is_inglewood =
  case
    when address ~* ',\s*inglewood\M' then true
    when address ~ ','                then false
    else null
  end
where is_inglewood is null;


-- 5) DEALS -----------------------------------------------------------
-- New table. The existing di_businesses.special / member_deal /
-- game_day_special columns stay as they are (owner-written); this table
-- is admin-managed, schedulable, and can hold several deals per spot.
create table if not exists di_deals (
  id             uuid primary key default gen_random_uuid(),
  business_id    text not null references di_businesses(id) on delete cascade,
  deal_type      text not null default 'standard'
                   check (deal_type in ('standard','show_ticket','bring_friend')),
  title          text not null,          -- "15% off with your ticket"
  details        text,                   -- fine print
  friend_offer   text,                   -- bring_friend: better offer unlocked by sharing
  venue_id       text references di_venues(id) on delete set null,  -- null = any venue
  valid_window   text not null default 'all_day'
                   check (valid_window in ('pre','post','all_day')),
  event_day_only boolean not null default false,
  starts_on      date,                   -- null = already started
  ends_on        date,                   -- null = no end date
  is_active      boolean not null default true,
  is_sample      boolean not null default false,  -- seed data; delete with one query
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  check (starts_on is null or ends_on is null or ends_on >= starts_on),
  check (deal_type <> 'bring_friend' or friend_offer is not null)
);
create index if not exists di_deals_business_idx on di_deals (business_id);
create index if not exists di_deals_live_idx     on di_deals (is_active, ends_on);

create or replace function di_touch_updated_at() returns trigger
language plpgsql as $$ begin new.updated_at := now(); return new; end $$;
drop trigger if exists di_deals_touch on di_deals;
create trigger di_deals_touch before update on di_deals
  for each row execute function di_touch_updated_at();

alter table di_deals enable row level security;

-- Public sees active deals inside their date range (LA calendar date)
-- for listings that are approved and not paused.
drop policy if exists di_deals_public_read on di_deals;
create policy di_deals_public_read on di_deals for select using (
  is_active
  and (starts_on is null or starts_on <= (now() at time zone 'America/Los_Angeles')::date)
  and (ends_on   is null or ends_on   >= (now() at time zone 'America/Los_Angeles')::date)
  and exists (select 1 from di_businesses b
              where b.id = business_id
                and coalesce(b.is_active, true) and coalesce(b.approved, true))
);

-- Admins see and write everything (including scheduled/inactive).
drop policy if exists di_deals_admin_all on di_deals;
create policy di_deals_admin_all on di_deals for all
  using (di_is_admin()) with check (di_is_admin());


-- 6) SHARED PLANS ("Send plan to my crew") ---------------------------
-- id is a short code for the share link: /?plan=<id>
-- stops holds IDs only, no free text:
--   [{"role":"pregame","business_id":"twohommes"},
--    {"role":"event","event_id":"tm_..."},
--    {"role":"after","business_id":"..."}]
create table if not exists di_shared_plans (
  id         text primary key default substr(md5(gen_random_uuid()::text), 1, 10),
  created_by uuid default auth.uid() references auth.users(id) on delete set null,
  event_id   text references di_events(id) on delete set null,
  stops      jsonb not null,
  created_at timestamptz not null default now(),
  check (jsonb_typeof(stops) = 'array' and jsonb_array_length(stops) between 1 and 8),
  check (pg_column_size(stops) < 8192)
);
alter table di_shared_plans enable row level security;

drop policy if exists di_shared_plans_public_read on di_shared_plans;
create policy di_shared_plans_public_read on di_shared_plans for select using (true);

-- Anyone can save a plan; a signed-in user can only stamp it as themselves.
drop policy if exists di_shared_plans_insert on di_shared_plans;
create policy di_shared_plans_insert on di_shared_plans for insert
  with check (created_by is null or created_by = auth.uid());
-- No update/delete policies: a shared link never changes under your crew.


-- 7) ACTIVITY EVENTS (anonymous) -------------------------------------
-- session_id = random UUID made in the browser (localStorage). No user
-- id, IP, or location is stored. Write-only for the public.
create table if not exists di_activity_events (
  id          bigint generated always as identity primary key,
  session_id  uuid not null,
  business_id text not null references di_businesses(id) on delete cascade,
  deal_id     uuid references di_deals(id) on delete set null,
  action      text not null
                check (action in ('view','save','share','deal_open','redeem')),
  created_at  timestamptz not null default now()
);
create index if not exists di_activity_recent_idx
  on di_activity_events (created_at desc, business_id);

alter table di_activity_events enable row level security;
drop policy if exists di_activity_insert on di_activity_events;
create policy di_activity_insert on di_activity_events for insert
  to anon, authenticated with check (true);

-- The public may only fill these four columns, so created_at can't be
-- back-dated to fake a spike. No read access (scores come from section 9).
revoke all on di_activity_events from anon, authenticated;
grant insert (session_id, business_id, deal_id, action)
  on di_activity_events to anon, authenticated;


-- 8) PUSH SUBSCRIPTIONS ----------------------------------------------
create table if not exists di_push_subscriptions (
  id           uuid primary key default gen_random_uuid(),
  session_id   uuid not null,
  user_id      uuid default auth.uid() references auth.users(id) on delete set null,
  endpoint     text not null unique,
  subscription jsonb not null,           -- PushSubscription.toJSON()
  event_ids    text[] not null default '{}',  -- events this person saved
  opted_in     boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  check (endpoint like 'https://%'),
  check (subscription->>'endpoint' = endpoint),
  check (cardinality(event_ids) <= 50)
);
alter table di_push_subscriptions enable row level security;

drop policy if exists di_push_insert on di_push_subscriptions;
create policy di_push_insert on di_push_subscriptions for insert
  with check (user_id is null or user_id = auth.uid());
-- No public read. Updates (new saved event, opt-out) go through
-- di_push_save below; knowing the endpoint URL (unguessable) is the proof
-- of ownership.

create or replace function di_push_save(
  p_subscription jsonb, p_session uuid, p_event_ids text[], p_opted_in boolean default true
) returns void
language plpgsql security definer set search_path = public as $$
begin
  insert into di_push_subscriptions (session_id, user_id, endpoint, subscription, event_ids, opted_in)
  values (p_session, auth.uid(), p_subscription->>'endpoint', p_subscription,
          coalesce(p_event_ids, '{}'), coalesce(p_opted_in, true))
  on conflict (endpoint) do update set
    session_id   = excluded.session_id,
    user_id      = coalesce(excluded.user_id, di_push_subscriptions.user_id),
    subscription = excluded.subscription,
    event_ids    = excluded.event_ids,
    opted_in     = excluded.opted_in,
    updated_at   = now();
end $$;

-- Send log used by the Phase 5 Edge Function. The primary key allows at
-- most one 'pregame' and one 'after_hours' push per person per event,
-- which enforces "max 2 pushes per event" in the database itself.
create table if not exists di_push_log (
  subscription_id uuid not null references di_push_subscriptions(id) on delete cascade,
  event_id        text not null references di_events(id) on delete cascade,
  kind            text not null check (kind in ('pregame','after_hours')),
  sent_at         timestamptz not null default now(),
  primary key (subscription_id, event_id, kind)
);
alter table di_push_log enable row level security;  -- service key only


-- 9) POPPING SCORE ---------------------------------------------------
-- Weighted activity per listing over the last N minutes (default 120).
-- Each visitor counts once per action type, so one phone tapping "view"
-- 50 times adds 1, not 50. 🔥 needs both the score threshold AND a
-- minimum number of different visitors. All three numbers live in
-- di_settings, so they can be tuned without a deploy.
-- Weights: view 1 · deal_open 2 · save 3 · share 4 · redeem 5
create or replace function di_popping_scores()
returns table (business_id text, score int, sessions int, is_popping boolean)
language sql stable security definer set search_path = public as $$
  with cfg as (
    select
      coalesce((select (value #>> '{}')::int from di_settings where key = 'popping_threshold'), 8)        as threshold,
      coalesce((select (value #>> '{}')::int from di_settings where key = 'popping_min_sessions'), 3)     as min_sessions,
      coalesce((select (value #>> '{}')::int from di_settings where key = 'popping_window_minutes'), 120) as mins
  ),
  acts as (
    select distinct e.business_id, e.session_id, e.action
    from di_activity_events e, cfg
    where e.created_at > now() - make_interval(mins => cfg.mins)
  ),
  scored as (
    select a.business_id,
           sum(case a.action when 'view' then 1 when 'deal_open' then 2
                             when 'save' then 3 when 'share'     then 4
                             when 'redeem' then 5 end)::int as score,
           count(distinct a.session_id)::int                 as sessions
    from acts a
    group by a.business_id
  )
  select s.business_id, s.score, s.sessions,
         (s.score >= cfg.threshold and s.sessions >= cfg.min_sessions) as is_popping
  from scored s, cfg
  order by s.score desc;
$$;


-- 10) SECURITY FIX (recommended, pre-existing issue) ------------------
-- The owner update policy (05_owner_login.sql) lets a claimed owner
-- update ANY column on their own row, including tier, featured and
-- approved. With the publishable key from the site, an owner could make
-- themselves Premium or Featured without paying. This trigger blocks
-- those columns unless the change comes from an admin, the service key
-- (admin.html, stripe-webhook, import function) or the SQL Editor.
-- Owner edits the app makes today (name, hours, special, photos, …) are
-- not affected.
create or replace function di_businesses_guard() returns trigger
language plpgsql set search_path = public as $$
begin
  if current_user not in ('anon', 'authenticated') or di_is_admin() then
    return new;
  end if;
  if new.tier                is distinct from old.tier
  or new.featured            is distinct from old.featured
  or new.approved            is distinct from old.approved
  or new.is_large            is distinct from old.is_large
  or new.claimed_by          is distinct from old.claimed_by
  or new.is_inglewood        is distinct from old.is_inglewood
  or new.stripe_customer     is distinct from old.stripe_customer
  or new.stripe_subscription is distinct from old.stripe_subscription
  or new.paid_since          is distinct from old.paid_since then
    raise exception 'Only an admin can change tier, featured, approval, location or billing fields.';
  end if;
  return new;
end $$;

drop trigger if exists di_businesses_guard_trg on di_businesses;
create trigger di_businesses_guard_trg before update on di_businesses
  for each row execute function di_businesses_guard();


-- =====================================================================
-- ROLLBACK (only if needed) — removes everything above, in order:
--   drop trigger if exists di_businesses_guard_trg on di_businesses;
--   drop function if exists di_businesses_guard();
--   drop function if exists di_popping_scores();
--   drop table if exists di_push_log, di_push_subscriptions,
--                        di_activity_events, di_shared_plans, di_deals;
--   drop function if exists di_push_save(jsonb, uuid, text[], boolean);
--   drop function if exists di_touch_updated_at();
--   drop trigger if exists di_events_derive_trg on di_events;
--   drop function if exists di_events_derive();
--   alter table di_events drop column if exists venue_id, drop column if exists starts_at;
--   alter table di_businesses drop column if exists is_inglewood;
--   drop table if exists di_venues, di_settings, di_admins;
--   drop function if exists di_is_admin();
--
-- Delete sample deals (Phase 2):
--   delete from di_deals where is_sample;
-- =====================================================================
