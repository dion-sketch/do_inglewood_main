-- =====================================================================
-- DO INGLEWOOD — Featured placement + Game Day Special flag
-- Run in Supabase → SQL Editor → New query → Run.
--
-- `featured`: an admin-only paid-placement flag. Featured businesses get
-- top placement across lists plus a clearly-labeled "Featured" badge, so
-- guests always know it's promoted. No payment flow yet — toggled by hand
-- in tools/admin.html until billing is wired up.
--
-- `game_day_special`: an owner-settable flag on their existing `special`
-- offer, marking it as a game-day deal so it's highlighted on event/
-- game-day planner pages near SoFi, Kia Forum, and Intuit Dome.
-- =====================================================================
alter table di_businesses add column if not exists featured boolean default false;
alter table di_businesses add column if not exists game_day_special boolean default false;
