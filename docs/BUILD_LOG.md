# Build log — Event Day / Sticky & Shareable

Running notes for the phased build started Sep 26, 2026. Newest phase at the bottom.
Each phase says what changed, the decisions made (and why), and what to test.

---

## Phase 0 — Audit + database plan

**What I did**
- Mapped the app (`site/index.html`), Supabase tables, Edge Functions, admin tool, importers and Netlify setup.
- Wrote `supabase/25_event_day_engagement.sql` (new tables for deals, shared plans, activity, push, the popping score, plus the owner guard).

**What I found**
- Production is missing migrations 12, 14, 16, 17 and 20–24. You're running `turn_on_all.sql` + 20, 21, 22, 24 (skipping 19).
- Owners could make themselves Premium or Featured for free. Fixed by section 10 of migration 25 (approved).
- Owner emails and Stripe ids were publicly readable. Fixed by `26_hide_private_columns.sql` (Phase 1, see below).
- Your Google key is inside ~1,160 public photo URLs. Check it's restricted to your Netlify domain in Google Cloud Console.
- `di_ads` exists in the live database, but nothing in this repo creates or uses it. Left untouched.

**Decisions (approved by Rambo)**
- YouTube Theater counts as an Event Day venue (4 venues total).
- Keep the owner guard.

---

## Phase 1 — Mode picker + fixes

**What changed**
- `site/index.html`
  - The opening screen is now a **mode picker**: Event Day, Anytime, After Hours. If there's a show today, Event Day is marked "Tonight" and names the show.
  - A **mode switcher** sits at the top of Home. The chosen mode is saved on the device (`di_mode`).
  - **Event Day** turns on by itself when SoFi, Kia Forum, Intuit Dome or YouTube Theater has a show today. Home shows tonight's show(s) with the real venue photo, then pregame spots near the venue.
  - About **3.5 hours after the start**, Event Day shows a "letting out — keep the night going?" nudge to After Hours, and swaps the pregame list for after-show spots.
  - **Anytime** leads with live deals (or "Popular right now"), then "Open now".
  - **After Hours** shows lounges, bars and the casino open late, then late-night eats.
  - **No more empty states:**
    - The "No deal today" box is gone; spots with no deal simply show no box.
    - Specials, Explore search and Saved fall back to "Popular right now".
    - Empty game-day planner sections are hidden.
    - A calendar day with nothing on shows the next event day.
  - **Inglewood first:** non-Inglewood listings (about 276) are hidden by default.
    - A "+ Nearby cities" chip in Explore shows them, labeled "Nearby".
    - Typing a search still finds everything.
    - Map and directions no longer stick "Inglewood CA" onto Los Angeles addresses.
  - The app now asks Supabase only for the columns it shows. If some don't exist yet, it falls back to loading everything, so it works before and after the migrations.
  - The owner dashboard reads its own listing through `di_my_business()` once migration 26 is live, and falls back until then.
- `supabase/functions/import-businesses/index.ts`
  - Imports now record `is_inglewood` from Google's city field (no extra cost), and backfill fills it where it's missing.
  - **Bug fix:** backfill could blank out an existing photo when Google returned none. It no longer touches photos that exist.
- `supabase/26_hide_private_columns.sql` (new): hides owner contact fields, Stripe ids and drafts from the public, and hides paused or unapproved listings at the database level.
  - **Run it only after this new site is deployed.** The old site loads every column and would break.

**Decisions**
- Existing users see the mode picker once too, since modes are new. The picker replaced the old single welcome slide and its button: one tap picks a mode and enters the app.
- A mode picked today always wins. Otherwise a show day means Event Day.
- After Hours only lasts the night it was picked. The next daytime (5 AM–5 PM) opens on Anytime.
- Event times like "TBD" count as 7 PM for the after-show timing.
- The "Eat. Play. Stay." line on Home was replaced by the mode switcher, to keep the top uncluttered.
- Listings whose address has no city are treated as Inglewood (most are the original curated spots).
- "Popular" = rating weighted by number of reviews, with deals and Featured first. Phase 5 adds live activity.

**What to test**
1. Open in a private window: the mode picker shows, and tonight's show is named if there is one.
2. Pick Event Day: tonight's show card, then "Pregame near …". Tap the card to open the full game-day plan.
3. Switch modes with the bar at the top of Home.
4. Explore: no Los Angeles or Hawthorne spots until you tap "+ Nearby cities"; then they carry a purple "Nearby" tag.
5. Open a spot with no deal: there's no grey deal box.
6. Specials tab: shows "Popular right now" when no business has a live deal.

---

## Phase 2 — Show Your Ticket deals

**Database:** migration 25 is live (Rambo ran it along with turn_on_all + 20, 21, 22, 24 and set himself as admin).
Checked afterwards: 4 venues, 246 events linked to a venue, 1,248 Inglewood / 276 non-Inglewood / 57 no-city listings. Every column the owner guard compares exists, and none of the fields the owner dashboard saves is a guarded one, so owner edits keep working.

**What changed**
- `tools/admin.html` — new **Deals** tab:
  - Create, edit and schedule deals: merchant (type-ahead, shows the address so duplicate names can be told apart), type, offer, fine print, venue, before/after/all day, event days only, start/end dates, active.
  - The list lets you turn a deal on/off, edit or delete it, plus a **Delete sample deals** button.
- `site/index.html`
  - Loads deals from `di_deals`.
  - "Event days only" deals appear only when there's a show today, at their venue if one is set.
  - **Event Day banner** "Show Your Ticket — Deals Tonight" on Home and on every event's game-day page. Participating spots are listed closest to the venue first, each with a **Show** button.
  - **🎟 SHOW YOUR TICKET** badge on cards, Explore rows, Specials and the game-day planner. These spots sort just under Featured.
  - Listing pages show a deal card with **Show to staff**. That opens a full-screen view: deal, merchant, today's date and a live ticking clock (so a screenshot is easy to spot), and it keeps the screen awake. Each open logs a `redeem`.
  - Opening a listing logs a `view`. Activity uses a random device id only.
  - **Fix:** listings without coordinates were being placed at 0,0, which showed "7,820 mi" distances. Missing coordinates now just show no distance.
- `supabase/27_sample_deals.sql` (new, **needs to be run**): 5 sample Show Your Ticket deals, all marked `is_sample`, on Randy's Donuts, The Nile, 3 and Out, Dulan's and Six Seven Five. They're labeled "Sample" everywhere, and the Show to staff screen says "not a real offer yet".

**Decisions**
- A deal's before/after window is shown to the guest and staff but not enforced by the app. Staff decide at the counter; blocking a guest over a clock mismatch would be worse.
- Samples use the most-reviewed copy of each merchant.

**Found (not fixed — needs your call):** most businesses are listed twice, once from the curated seed and once from the Google import (e.g. "The Nile Restaurant and Bar" and "The Nile Restaurant & Bar" at the same address). Removing the duplicates means deleting rows, so I haven't touched them. A merge tool could be a follow-up.

**What to test**
1. Run `27_sample_deals.sql`. On a show day, Event Day Home shows the "Deals Tonight" banner.
2. Tap **Show**: the full-screen view with a ticking clock appears. Tap Done.
3. Admin → Deals: add a deal, turn it off, edit it, then **Delete sample deals**.
