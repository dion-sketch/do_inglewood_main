-- =====================================================================
-- DO INGLEWOOD — Hide private business fields from the public API
--
-- RUN ONLY AFTER the new site (Phase 1+) is deployed to Netlify.
-- The old site loads every column with select('*'); after this runs,
-- that old version would fail to load listings.
--
-- What it does:
--  1) The public (anon + signed-in users) can no longer read owner
--     contact fields, Stripe ids or drafts. Everything the app shows
--     stays readable.
--  2) Paused and not-yet-approved listings are hidden from the public
--     (today they are only hidden by the app, not the database).
--  3) An owner reads their OWN full listing through di_my_business().
--
-- Service-key tools (admin.html, Edge Functions) are not affected.
-- Safe to re-run. Run in Supabase → SQL Editor → New query → Run.
-- =====================================================================

-- 1) Column-level read access ------------------------------------------
-- NOTE: a column added later is NOT publicly readable until it is added
-- to this list (re-run the grant with the new column name).
revoke select on di_businesses from anon, authenticated;
grant select (
  id, name, category, tags, address, phone, website, google_place_id,
  rating, rating_count, price_level, avg_per_person, hours, review_quote,
  tier, special, member_deal, booking_url, reservation_provider,
  featured, game_day_special, claimed_by, photo_url, photos, menu,
  latitude, longitude, is_active, approved, is_inglewood, is_large, created_at
) on di_businesses to anon, authenticated;
-- Hidden: notify_email, notify_phone, stripe_customer, stripe_subscription,
--         paid_since, draft.

-- 2) Public sees only live listings; an owner also sees their own ------
drop policy if exists di_businesses_public_read on di_businesses;
create policy di_businesses_public_read on di_businesses for select using (
  (coalesce(approved, true) and coalesce(is_active, true))
  or claimed_by = auth.uid()
);

-- 3) Owner's own full row (including notify_email) ---------------------
create or replace function di_my_business() returns setof di_businesses
language sql stable security definer set search_path = public as $$
  select * from di_businesses
  where auth.uid() is not null and claimed_by = auth.uid();
$$;
revoke execute on function di_my_business() from public, anon;
grant execute on function di_my_business() to authenticated;

-- ROLLBACK:
--   grant select on di_businesses to anon, authenticated;
--   drop policy if exists di_businesses_public_read on di_businesses;
--   create policy di_businesses_public_read on di_businesses for select using (true);
--   drop function if exists di_my_business();
