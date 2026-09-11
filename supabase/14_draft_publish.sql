-- =====================================================================
-- DO INGLEWOOD — Draft edits vs. published listing
-- Run in Supabase → SQL Editor → New query → Run.
--
-- WHY: A claimed-but-unpaid owner can EDIT everything (photos, prices,
-- menu, hours) and SAVE it — but the public keeps seeing the original
-- listing until they pay (Verified $69+). Their pending edits live in
-- `draft`. When they upgrade, the app promotes `draft` into the live
-- columns automatically. Paid owners write straight to live (no draft).
-- =====================================================================

alter table di_businesses add column if not exists draft jsonb;
