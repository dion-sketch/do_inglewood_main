-- Do Inglewood — let the marquee / civic venues get real photos.
--
-- Why: the photo backfill used to skip high-tier (featured) rows, so SoFi Stadium,
-- Kia Forum, Intuit Dome, YouTube Theater, landmarks and parks kept the generic
-- event fallback while ordinary businesses got real Google photos. The Edge Function
-- now enriches any UNCLAIMED row without a photo. If one of these venues was already
-- marked "tried" (photo_url = '') in an earlier run, this clears that mark so the next
-- backfill re-fetches it. Safe: it never touches a claimed/paid business.
--
-- Run this once in Supabase → SQL Editor, THEN run the photo backfill again
-- (tools/admin.html → "Add photos & details").

update di_businesses
set photo_url = null
where claimed_by is null
  and google_place_id is not null
  and coalesce(photo_url, '') = ''            -- null OR '' (tried, no photo)
  and (
        name ilike '%sofi%'
     or name ilike '%kia forum%'
     or name ilike '%the forum%'
     or name ilike '%intuit%'
     or name ilike '%youtube theater%'
     or name ilike '%hollywood park%'
     or category in ('Stadium','Landmark','Park','Event Space','Movie')
  );

-- See what will be re-fetched:
select name, category, tier, photo_url
from di_businesses
where claimed_by is null
  and google_place_id is not null
  and photo_url is null
  and (category in ('Stadium','Landmark','Park','Event Space','Movie')
       or name ilike '%sofi%' or name ilike '%forum%' or name ilike '%intuit%')
order by category, name;
