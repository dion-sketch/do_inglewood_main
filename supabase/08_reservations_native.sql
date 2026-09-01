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
