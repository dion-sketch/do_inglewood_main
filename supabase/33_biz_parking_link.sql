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
