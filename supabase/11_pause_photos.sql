-- =====================================================================
-- DO INGLEWOOD — pause switch + multiple photos
-- Run in Supabase → SQL Editor → New query → Run.
-- =====================================================================

-- Pause = hide a business from the app without deleting it. Existing rows
-- default to active (true).
alter table di_businesses add column if not exists is_active boolean default true;

-- Extra photos (gallery). The main photo stays in photo_url; these are additional.
alter table di_businesses add column if not exists photos text[];
