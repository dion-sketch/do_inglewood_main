-- Optional one-time event venue coordinate backfill.
-- Ticketmaster refreshes will also persist these exact venue anchors.
update di_events set latitude = 33.9535, longitude = -118.3392
  where lower(venue) = 'sofi stadium' and latitude is null;
update di_events set latitude = 33.9581, longitude = -118.3419
  where lower(venue) = 'kia forum' and latitude is null;
update di_events set latitude = 33.9560, longitude = -118.3436
  where lower(venue) = 'intuit dome' and latitude is null;
