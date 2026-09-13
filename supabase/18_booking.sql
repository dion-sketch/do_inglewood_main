-- Do Inglewood — booking system columns (run once in Supabase → SQL Editor)
--
-- Adds the customer "note" field to reservation requests (e.g. "fade with Mike,
-- window table, ~2pm"). Safe to run more than once.

alter table if exists di_reservations
  add column if not exists note text;

-- booking_url / reservation_provider already exist on di_businesses (owner form).
-- This just makes sure they're there for the link-out lane.
alter table if exists di_businesses
  add column if not exists booking_url text,
  add column if not exists reservation_provider text;
