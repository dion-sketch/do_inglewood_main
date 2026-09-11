-- =====================================================================
-- DO INGLEWOOD — Member deals (the customer download magnet)
-- Run in Supabase → SQL Editor → New query → Run.
--
-- A Verified+ business can post a members-only deal (e.g. "10% off for
-- Do Inglewood members"). It shows in the app with a member badge and in
-- the "Member Deals" section — the reason everyday people install & keep it.
-- =====================================================================
alter table di_businesses add column if not exists member_deal text;
