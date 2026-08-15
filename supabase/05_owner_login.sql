-- =====================================================================
-- DO INGLEWOOD — Owner Login + Dashboard setup
-- Run in Supabase → SQL Editor → New query → Run.
-- (Also do the 3 dashboard steps in the chat: bucket + auth redirect URL.)
-- =====================================================================

-- 1) Claim detail columns (so claim submissions save fully)
alter table di_claims add column if not exists contact_first_name text;
alter table di_claims add column if not exists contact_last_name  text;
alter table di_claims add column if not exists role text;
alter table di_claims add column if not exists attested boolean;

-- 2) Let a signed-in OWNER update ONLY their own business
--    (admin sets claimed_by = the owner's user id when approving a claim)
drop policy if exists di_businesses_owner_update on di_businesses;
create policy di_businesses_owner_update on di_businesses for update
  using (claimed_by = auth.uid())
  with check (claimed_by = auth.uid());

-- 3) Storage policies for owner photo uploads.
--    FIRST create a PUBLIC bucket named  business-photos  in Storage,
--    THEN run these (public read; only signed-in users can upload).
drop policy if exists "biz photos read"   on storage.objects;
drop policy if exists "biz photos upload" on storage.objects;
drop policy if exists "biz photos update" on storage.objects;
create policy "biz photos read"   on storage.objects for select using (bucket_id = 'business-photos');
create policy "biz photos upload" on storage.objects for insert to authenticated with check (bucket_id = 'business-photos');
create policy "biz photos update" on storage.objects for update to authenticated using (bucket_id = 'business-photos');
