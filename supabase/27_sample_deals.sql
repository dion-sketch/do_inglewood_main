-- =====================================================================
-- DO INGLEWOOD — 5 SAMPLE "Show Your Ticket" deals (for testing)
--
-- Run AFTER 25_event_day_engagement.sql.
-- These are made-up offers on real Inglewood spots so you can see the
-- Event Day banner, badges and "Show to staff" screen working. The app
-- labels them "Sample" everywhere. Delete them before telling merchants
-- or the public about deals:
--   tools/admin.html → Deals → "Delete sample deals"
--   or:  delete from di_deals where is_sample;
--
-- Each merchant is matched by name; when a spot is listed twice, the
-- copy with the most reviews is used. Safe to re-run (no duplicates).
-- =====================================================================

insert into di_deals (business_id, deal_type, title, details, venue_id, valid_window, event_day_only, is_sample)
select b.id, 'show_ticket', v.title, v.details, v.venue_id, v.win, v.event_only, true
from (values
  ('Randy''s Donuts',                 'Free glazed donut with any coffee',       'Show a same-day ticket. One per ticket.',        null,   'pre',     false),
  ('The Nile Restaurant and Bar',     '15% off food before the show',             'Dine-in. Show a same-day ticket.',               null,   'pre',     true),
  ('3 and Out Sports Bar & Lounge',   '$2 off draft beer after the game',         'Show your SoFi ticket from today. 21+.',         'sofi', 'post',    true),
  ('Dulan''s Soul Food Kitchen',      'Free peach cobbler with any plate',        'Show a same-day ticket. One per ticket.',        null,   'all_day', false),
  ('Six Seven Five Lounge',           'Skip the cover after the show',            'Show a same-day ticket at the door. 21+.',       null,   'post',    true)
) as v(biz_name, title, details, venue_id, win, event_only)
cross join lateral (
  select id from di_businesses
  where lower(name) = lower(v.biz_name)
    and coalesce(is_active, true) and coalesce(approved, true)
  order by rating_count desc nulls last
  limit 1
) b
where not exists (select 1 from di_deals d where d.is_sample and d.business_id = b.id);

-- Check what was added:
select b.name, d.title, d.valid_window, d.event_day_only, d.venue_id
from di_deals d join di_businesses b on b.id = d.business_id
where d.is_sample
order by b.name;
