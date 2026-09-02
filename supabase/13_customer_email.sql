-- =====================================================================
-- DO INGLEWOOD — customer email on reservations (for confirmation emails)
-- Run in Supabase → SQL Editor → New query → Run.
-- =====================================================================
alter table di_reservations add column if not exists customer_email text;
