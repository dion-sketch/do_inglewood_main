-- =====================================================================
-- DO INGLEWOOD — business menu (dishes + prices)
-- Run in Supabase → SQL Editor → New query → Run.
-- Stored as JSON: [{"name":"Jerk Chicken","price":"$18"}, ...]
-- =====================================================================
alter table di_businesses add column if not exists menu jsonb;
