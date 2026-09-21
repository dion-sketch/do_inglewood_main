-- DO INGLEWOOD — Geolocation for anchors, venues, and nearby sorting
-- Run in Supabase SQL Editor after the existing migrations.
-- Coordinates are populated server-side by the import/backfill function.

alter table di_businesses add column if not exists latitude double precision;
alter table di_businesses add column if not exists longitude double precision;
alter table di_events add column if not exists latitude double precision;
alter table di_events add column if not exists longitude double precision;

create index if not exists di_businesses_location_idx
  on di_businesses (latitude, longitude)
  where latitude is not null and longitude is not null;

create index if not exists di_events_location_idx
  on di_events (latitude, longitude)
  where latitude is not null and longitude is not null;
