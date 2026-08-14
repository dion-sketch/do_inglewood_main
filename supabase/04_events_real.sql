-- =====================================================================
-- DO INGLEWOOD — Real events schedule (from owner's spreadsheet)
-- Replaces the old placeholder events with the real Inglewood lineup.
-- Run in Supabase: SQL Editor -> New query -> paste -> Run.
-- No site re-deploy needed — the calendar reads di_events live.
-- =====================================================================

-- Clear the old placeholder events first
delete from di_events;

-- Load the real schedule (Mystère runs daily Aug 17–22, so it appears each day)
insert into di_events (id,title,venue,category,source,event_date,start_time,url,status) values
('ev_melaniemartinez_20260814','Melanie Martinez','Kia Forum','Concert','ticketmaster','2026-08-14','8:00 PM','https://www.ticketmaster.com/kia-forum-tickets-inglewood/venue/73750','live'),
('ev_yeat_20260815','Yeat','Intuit Dome','Concert','ticketmaster','2026-08-15','7:00 PM','https://www.ticketmaster.com/intuit-dome-tickets-inglewood/venue/74834','live'),
('ev_pumptrack_20260815','Inglewood Pumptrack Skate','Inglewood Pumptrack','Sports','city','2026-08-15','5:00 PM',null,'live'),
('ev_moviesinpark_20260815','Movies in the Park','Edward Vincent Jr. Park','Community','city','2026-08-15','6:00 PM',null,'live'),
('ev_calicoco_20260815','CaliCoCo 2026 ft D''Yani','Savoy Entertainment Center','Nightlife','venue','2026-08-15','9:00 PM',null,'live'),
('ev_senegal_20260815','One Weekend in Senegal LA','The Tribe Entertainment Center','Nightlife','venue','2026-08-15','9:00 PM',null,'live'),
('ev_karolg_20260816','Karol G — Tropitour','SoFi Stadium','Concert','ticketmaster','2026-08-16','7:00 PM','https://www.ticketmaster.com/sofi-stadium-tickets-inglewood/venue/82789','live'),
('ev_mystere_20260817','Mystère by Cirque du Soleil','Cosm Los Angeles','Show','venue','2026-08-17','Varies (Daily)',null,'live'),
('ev_mystere_20260818','Mystère by Cirque du Soleil','Cosm Los Angeles','Show','venue','2026-08-18','Varies (Daily)',null,'live'),
('ev_mystere_20260819','Mystère by Cirque du Soleil','Cosm Los Angeles','Show','venue','2026-08-19','Varies (Daily)',null,'live'),
('ev_mystere_20260820','Mystère by Cirque du Soleil','Cosm Los Angeles','Show','venue','2026-08-20','Varies (Daily)',null,'live'),
('ev_mystere_20260821','Mystère by Cirque du Soleil','Cosm Los Angeles','Show','venue','2026-08-21','Varies (Daily)',null,'live'),
('ev_mystere_20260822','Mystère by Cirque du Soleil','Cosm Los Angeles','Show','venue','2026-08-22','Varies (Daily)',null,'live'),
('ev_sippaint_20260818','Sip & Paint Taco Tuesday','The Tribe Entertainment Center','Social','venue','2026-08-18','7:00 PM',null,'live'),
('ev_iusdboard_20260819','IUSD Board Meeting','Dr. Ernest Shaw Board Room','Civic','city','2026-08-19','5:00 PM',null,'live'),
('ev_idle_20260819','I-dle World Tour: Syncopation','Kia Forum','Concert','ticketmaster','2026-08-19','Evening','https://www.ticketmaster.com/kia-forum-tickets-inglewood/venue/73750','live'),
('ev_matrix_20260821','The Matrix in Shared Reality','Cosm Los Angeles','Show','venue','2026-08-21','9:30 PM',null,'live'),
('ev_rnbfever_20260822','R&B Fever','The Tribe Entertainment Center','Nightlife','venue','2026-08-22','10:00 PM',null,'live');
