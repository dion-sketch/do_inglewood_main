-- Optional one-time backfill for the three marquee anchors.
-- Run after 20_geolocation.sql; all other businesses are filled by the
-- import-businesses Edge Function in ?mode=backfill.
update di_businesses set latitude = 33.9535, longitude = -118.3392
  where lower(name) = 'sofi stadium' and latitude is null;
update di_businesses set latitude = 33.9581, longitude = -118.3419
  where lower(name) = 'kia forum' and latitude is null;
update di_businesses set latitude = 33.9560, longitude = -118.3436
  where lower(name) = 'intuit dome' and latitude is null;
