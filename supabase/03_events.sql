-- =====================================================================
-- DO INGLEWOOD — Live Events table (di_events)
-- Run this in Supabase: SQL Editor -> New query -> paste -> Run.
-- Your website already looks for this table; once it exists and has
-- rows, the Events calendar loads live from here and you can add/edit
-- events in the Table Editor just like businesses.
-- =====================================================================

-- 1) TABLE ------------------------------------------------------------
-- Columns match exactly what the site reads (event_date, start_time,
-- price_from, image_url, etc.). status='live' = shown on the calendar.
create table if not exists di_events (
  id          text primary key,          -- e.g. 'tm_karolg_20260814'
  title       text not null,             -- "Karol G — Mañana Será Bonito"
  venue       text,                       -- "SoFi Stadium"
  category    text,                       -- Concert | Sports | Community | Comedy | Special
  source      text,                       -- ticketmaster | city | business
  event_date  date,                       -- 2026-08-14
  start_time  text,                       -- "8:00 PM"
  price_from  numeric,                    -- lowest ticket price (nullable)
  url         text,                       -- link to tickets / info
  image_url   text,                       -- optional event photo
  business_id text references di_businesses(id) on delete set null,
  status      text default 'live',        -- live | draft | cancelled
  created_at  timestamptz default now()
);

-- 2) SECURITY ---------------------------------------------------------
-- Public can READ live events only. Writes happen via the dashboard /
-- service key, same pattern as di_businesses.
alter table di_events enable row level security;
drop policy if exists di_events_public_read on di_events;
create policy di_events_public_read
  on di_events for select
  using (status = 'live');

-- 3) SEED — real Inglewood events -------------------------------------
-- Safe to re-run: ON CONFLICT DO NOTHING skips rows that already exist.
insert into di_events (id,title,venue,category,source,event_date,start_time,url,status) values
 ('tm_ivetour_20260801','IVE World Tour — Show What I Am','Kia Forum','Concert','ticketmaster','2026-08-01','8:00 PM','https://www.ticketmaster.com/kia-forum-tickets-inglewood/venue/73750','live'),
 ('tm_rufusdusol_20260806','RÜFÜS DU SOL','Kia Forum','Concert','ticketmaster','2026-08-06','7:30 PM','https://www.ticketmaster.com/kia-forum-tickets-inglewood/venue/73750','live'),
 ('tm_rufusdusol_20260807','RÜFÜS DU SOL','Kia Forum','Concert','ticketmaster','2026-08-07','7:30 PM','https://www.ticketmaster.com/kia-forum-tickets-inglewood/venue/73750','live'),
 ('tm_grupofrontera_20260807','Grupo Frontera','Intuit Dome','Concert','ticketmaster','2026-08-07','8:00 PM','https://www.ticketmaster.com/intuit-dome-tickets-inglewood/venue/74834','live'),
 ('tm_edsheeran_20260808','Ed Sheeran','SoFi Stadium','Concert','ticketmaster','2026-08-08','7:00 PM','https://www.ticketmaster.com/sofi-stadium-tickets-inglewood/venue/82789','live'),
 ('tm_lionelrichie_20260809','Lionel Richie + Earth, Wind & Fire','Intuit Dome','Concert','ticketmaster','2026-08-09','7:30 PM','https://www.ticketmaster.com/intuit-dome-tickets-inglewood/venue/74834','live'),
 ('tm_karolg_20260814','Karol G — Mañana Será Bonito','SoFi Stadium','Concert','ticketmaster','2026-08-14','8:00 PM','https://www.ticketmaster.com/sofi-stadium-tickets-inglewood/venue/82789','live'),
 ('tm_karolg_20260815','Karol G — Mañana Será Bonito','SoFi Stadium','Concert','ticketmaster','2026-08-15','8:00 PM','https://www.ticketmaster.com/sofi-stadium-tickets-inglewood/venue/82789','live'),
 ('tm_karolg_20260816','Karol G — Mañana Será Bonito','SoFi Stadium','Concert','ticketmaster','2026-08-16','8:00 PM','https://www.ticketmaster.com/sofi-stadium-tickets-inglewood/venue/82789','live'),
 ('city_northpark_20260815','North Park Community Night','North Park','Community','city','2026-08-15','4:00 PM','https://www.cityofinglewood.org/calendar.aspx?CID=14','live'),
 ('tm_yeat_20260815','Yeat','Intuit Dome','Concert','ticketmaster','2026-08-15','7:30 PM','https://www.ticketmaster.com/intuit-dome-tickets-inglewood/venue/74834','live'),
 ('tm_neyoakon_20260821','Ne-Yo & Akon — Nights Like This','Intuit Dome','Concert','ticketmaster','2026-08-21','8:00 PM','https://www.ticketmaster.com/intuit-dome-tickets-inglewood/venue/74834','live'),
 ('tm_zayn_20260828','ZAYN','Intuit Dome','Concert','ticketmaster','2026-08-28','8:00 PM','https://www.ticketmaster.com/intuit-dome-tickets-inglewood/venue/74834','live')
on conflict (id) do nothing;
