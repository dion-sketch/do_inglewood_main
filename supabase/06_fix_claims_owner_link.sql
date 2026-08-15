-- =====================================================================
-- DO INGLEWOOD — Fix: claim → owner linking (audit finding)
-- Run in Supabase → SQL Editor → New query → Run.
--
-- WHY: di_claims.user_id was set up to point at di_users(id), but the
-- website (and the owner-login system) stores the person's AUTH id there
-- (auth.uid()). Those are two different values, so every claim insert was
-- being REJECTED by the old foreign key — which meant new claims silently
-- never reached the Admin dashboard. This removes that wrong link so
-- claims save, and fixes the owner-can-read-own-claim rule to match.
-- =====================================================================

-- 1) Drop the incorrect foreign key so user_id can hold the auth id.
alter table di_claims drop constraint if exists di_claims_user_id_fkey;

-- 2) Owner can read their OWN claims (user_id now holds auth.uid()).
drop policy if exists di_claims_owner_read on di_claims;
create policy di_claims_owner_read
  on di_claims for select
  using (user_id = auth.uid());
