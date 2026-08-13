-- =====================================================================
-- DO INGLEWOOD — Milestone 1: Tables
-- Run this in Supabase: SQL Editor -> New query -> paste -> Run.
-- Every table is prefixed di_ so it can NEVER collide with or touch
-- your existing tables. This script only CREATES; it never drops or
-- alters anything that isn't di_.
-- =====================================================================

-- 1) BUSINESSES -------------------------------------------------------
-- The 56 real Inglewood spots. id is TEXT and matches the "k" key in
-- the prototype (e.g. 'twohommes') so the front-end keeps working.
create table if not exists di_businesses (
  id              text primary key,                 -- matches "k" (e.g. 'twohommes')
  name            text not null,                    -- "n"
  category        text,                             -- "cat"
  tags            text[],                           -- "tags"
  address         text,                             -- "addr"
  phone           text,                             -- "ph"
  website         text,                             -- "web"
  google_place_id text,                             -- "pid"
  rating          numeric,                          -- "r"
  rating_count    int,                              -- "rc"
  price_level     text,                             -- "price" ($, $$, $$$)
  avg_per_person  int,                              -- "cpp"
  hours           text,                             -- "hrs"
  review_quote    text,                             -- "q"
  tier            int default 1,                    -- 1=Free 2=Verified 3=Spotlight
  special         text,                             -- "special"
  claimed_by      uuid,                             -- di_users.id of the owner once approved
  photo_url       text,                             -- uploaded / Google photo
  created_at      timestamptz default now()
);

-- 2) USERS ------------------------------------------------------------
-- One row per signed-in person. auth_id links to Supabase's built-in
-- auth.users so we know which login owns this profile.
create table if not exists di_users (
  id           uuid primary key default gen_random_uuid(),
  auth_id      uuid,                                -- = auth.uid()
  email        text,
  display_name text,
  is_business  boolean default false,
  created_at   timestamptz default now()
);

-- 3) SAVED PLANS ------------------------------------------------------
-- A user's saved Do Plan. "stops" holds the itinerary as JSON.
create table if not exists di_saved_plans (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid references di_users(id) on delete cascade,
  plan_type  text,
  budget     text,
  people     text,
  food       text,
  stops      jsonb,
  est_total  int,
  created_at timestamptz default now()
);

-- 4) STARRED ----------------------------------------------------------
-- A user "favoriting" a business.
create table if not exists di_starred (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid references di_users(id) on delete cascade,
  business_id text references di_businesses(id) on delete cascade,
  created_at  timestamptz default now()
);

-- 5) CLAIMS -----------------------------------------------------------
-- A business owner requesting control of a listing (starts 'pending').
create table if not exists di_claims (
  id             uuid primary key default gen_random_uuid(),
  business_id    text references di_businesses(id) on delete cascade,
  user_id        uuid references di_users(id) on delete set null,
  requested_tier int,
  status         text default 'pending',           -- pending | approved | rejected
  contact_email  text,
  contact_phone  text,
  created_at     timestamptz default now()
);
