-- =====================================================================
-- DO INGLEWOOD — Reservations (Phase 1: link-out to booking providers)
-- Run in Supabase → SQL Editor → New query → Run.
-- Adds a booking link + provider to businesses and to claim submissions.
-- No booking engine yet — the app just links to OpenTable/Resy/Booksy/website.
-- =====================================================================

-- Businesses: where "Reserve" / "Book Now" sends the customer.
alter table di_businesses add column if not exists booking_url          text;
alter table di_businesses add column if not exists reservation_provider text;  -- OpenTable | Resy | Booksy | ...

-- Claims: capture the owner's booking link + provider at claim time.
alter table di_claims     add column if not exists booking_url          text;
alter table di_claims     add column if not exists reservation_provider text;
