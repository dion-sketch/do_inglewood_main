-- =====================================================================
-- DO INGLEWOOD — Owner reservation alerts
-- Run in Supabase → SQL Editor → New query → Run.
-- Adds where reservation alerts are sent. Defaults to the owner's login
-- email inside the edge function if this is left blank.
-- =====================================================================

alter table di_businesses add column if not exists notify_email text;
alter table di_businesses add column if not exists notify_phone text;  -- reserved for SMS later
