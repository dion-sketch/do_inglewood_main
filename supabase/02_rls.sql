-- =====================================================================
-- DO INGLEWOOD — Milestone 1: Row Level Security (RLS)
-- Run this AFTER 01_schema.sql.
--
-- Plain-English: RLS is a locked door on every table — by default no one
-- can read or write a row unless a policy below explicitly says they may,
-- so users can only see/touch their own data and the public can only
-- read business listings.
-- =====================================================================

-- Turn the locks ON for all five tables.
alter table di_businesses  enable row level security;
alter table di_users       enable row level security;
alter table di_saved_plans enable row level security;
alter table di_starred     enable row level security;
alter table di_claims      enable row level security;

-- 1) BUSINESSES: anyone (even logged-out) can READ. -------------------
drop policy if exists di_businesses_public_read on di_businesses;
create policy di_businesses_public_read
  on di_businesses for select
  using (true);

-- Writes to di_businesses are intentionally NOT opened here. The seed
-- script uses the service_role key (which bypasses RLS), and the
-- business-dashboard edit policy is added in a later milestone.

-- 2) USERS: a person can read/insert/update only their own row. -------
drop policy if exists di_users_self_read on di_users;
create policy di_users_self_read
  on di_users for select
  using (auth.uid() = auth_id);

drop policy if exists di_users_self_insert on di_users;
create policy di_users_self_insert
  on di_users for insert
  with check (auth.uid() = auth_id);

drop policy if exists di_users_self_update on di_users;
create policy di_users_self_update
  on di_users for update
  using (auth.uid() = auth_id);

-- 3) SAVED PLANS: only the owner can see/add/change/delete. -----------
drop policy if exists di_saved_plans_owner_all on di_saved_plans;
create policy di_saved_plans_owner_all
  on di_saved_plans for all
  using (
    user_id in (select id from di_users where auth_id = auth.uid())
  )
  with check (
    user_id in (select id from di_users where auth_id = auth.uid())
  );

-- 4) STARRED: only the owner can see/add/remove their stars. ----------
drop policy if exists di_starred_owner_all on di_starred;
create policy di_starred_owner_all
  on di_starred for all
  using (
    user_id in (select id from di_users where auth_id = auth.uid())
  )
  with check (
    user_id in (select id from di_users where auth_id = auth.uid())
  );

-- 5) CLAIMS: anyone may submit a claim; an owner can read their own. --
drop policy if exists di_claims_anyone_insert on di_claims;
create policy di_claims_anyone_insert
  on di_claims for insert
  with check (true);

drop policy if exists di_claims_owner_read on di_claims;
create policy di_claims_owner_read
  on di_claims for select
  using (
    user_id in (select id from di_users where auth_id = auth.uid())
  );
