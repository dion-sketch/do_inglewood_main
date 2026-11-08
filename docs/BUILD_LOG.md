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

---

## Phase 3 — Location (while the app is open)

**What changed** (`site/index.html`)
- A short explainer sheet ("What's close to you?") comes before the browser's own permission prompt.
  - It says plainly that location stays on the phone and is never sent or saved.
  - It appears only when someone taps **📍 Near me** in Explore, or when Event Day opens (once per visit).
  - "Not now" isn't asked again that day.
- If the browser already allowed location, it's read quietly with no sheet.
- The position lives only in memory for the current visit. It's never written to storage and never included in any request to Supabase (checked: the only thing stored is the "not now" date).
- With location on:
  - Event Day cards show "**9 min walk from you**" to the venue.
  - Cards and Explore rows show "8 min walk" (or miles when farther than 1.5 mi).
  - Home's "Open now near you" and "After the show" sort closest first.
  - **Near me** in Explore sorts by distance.
- Without location, everything still works: the Show Your Ticket banner and pregame lists already sort by distance to the venue.

**Decisions**
- Walk time is based on 3 mph; above 1.5 mi, miles are shown instead.
- Spots with no coordinates keep their normal order after the ones that can be measured, and show no distance rather than a guess.

**Needs your call (costs money):** only **3 businesses have coordinates** right now, so walk times to spots are mostly missing. **Admin → "Add photos & details"** fills coordinates (and photos/hours) from Google. For ~1,500 rows that's a few thousand paid Google Places requests (Place Details + photos), roughly tens of dollars depending on your Google billing tier. Check Google Cloud billing before running it. Deploy the updated `import-businesses` function first (it's the version that also fills `is_inglewood` and no longer blanks photos).

**What to test**
1. Open on a phone on a show day in Event Day: the explainer shows, then the browser prompt. The event card shows your walk time.
2. Tap "Not now", reload: not asked again today.
3. Explore → 📍 Near me: closest spots first.

---

## Phase 4 — Shareability

**What changed** (`site/index.html`)
- **Share links now open the app** at the right place:
  - `?spot=<id>` opens a listing.
  - `?deal=<id>` opens the listing and scrolls to the deal.
  - `?plan=<code>` opens a crew plan.
  - Someone arriving from a friend's link sees that content first; the mode picker waits until their next visit. The link is cleaned from the address bar after opening.
- **Bring a Friend deals:** the card shows the basic offer plus "Share with a friend to unlock: …". **Share to unlock** uses the phone's share sheet (or copies the link). Once shared, the better offer is unlocked on that phone and is what "Show to staff" shows. Every deal card also has a **Share** button. Shares log `share`.
- **Story card:** a new **📸 Story** button on every listing makes a 1080×1920 image.
  - Content: the spot's real photo, the Do Inglewood logo, "PREGAMING AT [Spot] before [Event] 🎤" (or "After the show at…" once the show is over, or "Out in Inglewood at…" on non-event days), plus the site address.
  - Phones get the share sheet (straight to Instagram/Snap/TikTok stories); desktops download the image.
  - If a photo can't be used for security reasons, the card is drawn without it instead of failing.
- **Send plan to my crew:** a button on Event Day Home and on every event page.
  - Pick a pregame spot (top 4, deals and closest to the venue first), see the show, pick an after-show spot (top 4, nightlife first).
  - **Send to my crew** saves the plan to `di_shared_plans` (IDs only) and shares a short link.
  - The crew sees a 3-step timeline; each stop opens its page, with buttons for the game-day plan and re-sharing.
- The listing Share button now includes a real link (it used to be text only).

**Decisions**
- Unlocking happens on the sharer's phone once the share sheet completes (or the link is copied). Browsers can't confirm a message was actually sent, so it's on trust. That's fine for a friend deal.
- Plans can't be edited after sending, so a link never changes under the crew. Send a new one instead.
- Story images are made on the phone; nothing is uploaded.

**What to test** (on a phone)
1. Open a Bring a Friend deal → Share to unlock → pick a chat. The card flips to the better offer.
2. Listing → 📸 Story → share to your Instagram story (or save it).
3. Event Day → Send plan to my crew → send it to yourself → open the link.

---

## Phase 5 — Popping + notifications

**What changed**
- `site/index.html`
  - **Activity logging** (anonymous device id only):
    - `view` when a listing opens.
    - `save` when a spot is hearted.
    - `share` for listing, deal, story and crew-plan shares.
    - `deal_open` when a deal is revealed or opened from a link.
    - `redeem` on Show to staff.
    - Repeats of the same spot/action are sent at most every 30 minutes.
  - **🔥 Popping now** badge on cards, Explore rows and the planner when `di_popping_scores()` says a spot is hot.
    - Hot spots lead "What's Popping", and live activity lifts spots in every "Popular right now" list.
    - Refreshes every 5 minutes.
  - **Save events:** a 🔔 Save button on every event page. Saved events show under **Your events** in the Saved tab.
  - **Game-day alerts (opt-in):** saving an event offers alerts (max 2 per event, explained up front).
    - iPhone users who haven't added the app to their Home Screen are shown how, instead of a prompt that can't work.
    - The alerts link can turn alerts off.
    - Alert taps open the event (`?event=`) or After Hours (`?mode=after`).
- `site/sw.js` (new): shows push alerts and opens the right page when tapped. It doesn't cache anything, so it can never serve an old version of the app.
- `supabase/functions/send-event-pushes/` (new):
  - Every 15 minutes it sends the **pregame** alert ~3–4 hrs before doors (lead: Show Your Ticket deals near the venue) and the **after-hours** alert ~3.5 hrs after start.
  - Only to people who saved that event.
  - The database refuses a second copy of the same alert.
  - Dead subscriptions are switched off.
  - `?dry=1` shows what it would send.
  - Setup: `supabase/functions/README_push.md`.
- `supabase/28_push_schedule.sql` (new): schedules the sender every 15 minutes (the secret comes from Supabase Vault, not the file), and trims activity older than 30 days.
- `tools/admin.html`: the 🔥 badge settings (score, different visitors, look-back minutes) can be changed in the Deals tab.
- `docs/NATIVE_GEOFENCING.md` (new): what a native "you're near X" alert would take (Capacitor wrap, geofences, store accounts, ~1–2 weeks).

**Decisions**
- "Doors" is assumed to be 1 hour before the listed start. Events with "TBD" times get no alerts.
- Each visitor counts once per action per spot, and 🔥 also needs 3 different visitors, so one person tapping repeatedly can't make a spot "pop".
- Activity is kept 30 days (enough for trends, nothing personal in it anyway).

---

## Left for Rambo (stop list: production SQL, deploys, keys, costs)

In this order:
1. **Run `supabase/27_sample_deals.sql`** (5 labeled sample deals).
2. **Deploy the whole `site/` folder** to Netlify, not just `index.html`: `sw.js` and `assets/` must go with it. Check ☰ menu → Build says `2026.09.26-eventday`.
3. **Then run `supabase/26_hide_private_columns.sql`** (only after step 2 — the old site would break).
4. **Deploy the updated `import-businesses` Edge Function** (sets `is_inglewood`, no longer blanks photos).
5. **Decide on the coordinates backfill** (Admin → Add photos & details). Paid Google calls for ~1,500 rows; needed for walk times to spots.
6. **Push alerts:** follow `supabase/functions/README_push.md` (VAPID keys, 5 secrets, deploy `send-event-pushes`, vault secret, run `28_push_schedule.sql`). Then send me the **public** VAPID key or paste it into `VAPID_PUBLIC_KEY` in `site/index.html`, and redeploy.
7. ~~Duplicate listings~~: corrected in Round 2. It's ~46 pairs, not "most spots", and the app now merges them without deleting anything.
8. Check the Google API key is restricted to your Netlify domain (it's inside ~1,160 public photo URLs).

---

## Round 2 — Phone feedback (Sep 26)

Rambo tested the preview on his iPhone. The gold "Tonight" card, "Plan my night" and "Pregame near [venue]" are confirmed as the core direction (added to CLAUDE.md as "Core DNA").

**What changed** (`site/index.html` unless noted)
- **Gold deal markers everywhere:** "🎟 Show Ticket" for Show Your Ticket deals, "★ Deal" for any other deal. Shown on Home rows, pregame, Explore and search results, Specials, similar spots, the game-day planner, crew plans and Surprise Me.
- **Finding things:**
  - A search bar sits at the top of Home in every mode, with quick chips: Food · Drinks · Coffee · Parking · Deals · Open Now.
  - Explore uses the same chips plus **Sort: Closest · Has Deal · Top Rated (15+ reviews) · Open Now**.
  - On show days, a **Near me / Near the venue** toggle sets where distances are measured from.
  - Result rows show distance, open/closed and the deal marker.
  - **Parking** opens a parking guide for each venue (tonight's first, plus Metro/rideshare tips), since no parking lots are listed.
  - "American" in a business name no longer counts as food (a mortgage company was showing under Food).
- **Images:**
  - Every stock "category" photo is gone. A spot shows its licensed venue photo, its own stored photo, or a **branded name card** (dark neon card with the business name and category).
  - Spots with real photos rank slightly ahead of name cards.
  - The Home banner only rotates venues with real photos.
  - **Hollywood Park Casino** shows its name card instead of a blank pink card; it has no licensed photo yet.
  - An automatic audit loaded all 151 images across every screen: none broken.
  - Added a browser-tab icon (`favicon.png`, from the existing app icon).
  - The listing Story button now uses a line icon like the others.
- **"IMPORTED" removed** from all public screens (admin still sees Free/Verified/Premium). Disclaimers reworded.
- **4th mode "Show Ticket"**: every live Show Your Ticket deal, closest to tonight's venue first. With none live it falls back to other deals, then pregame picks. The mode bar now shows icon-over-label so all 4 fit.
  - Note: this mode was **not** in the earlier spec; it's added now.
- **Duplicates merged in the app, not deleted:** 42 listing pairs (same address, names that start the same, e.g. "3 and Out Sports Bar" / "…& Lounge", the two Hollywood Park Casino rows) show as one card. The kept card is the one that's claimed, higher tier, has a real photo or deals, or whose category matches its name. The other id still works for links, favorites, deals and activity.
  - Correction: earlier I said "most businesses are listed twice". It's ~46 pairs.
- **iPhone layout:** the page now sizes to the visible screen, and the tab bar sits above Safari's toolbar and the home bar. Before, the "Specials" label was covered.
- Fixed a style clash that made the "+ Nearby cities" chip twice as tall as the others.

**Why most spots show name cards:** only ~180 businesses have a photo stored in Supabase. 1,162 only have Google Places photo links, which the app doesn't display: every view is billed by Google, and the link exposes the API key. Fixing that for real needs a decision (see "Left for Rambo").

**What to test**
1. Home: tap the search bar, type "tacos". Tap each quick chip.
2. Explore: switch sorts; on a show day, switch Near me / Near the venue.
3. Tap 🅿️ Parking: tonight's venue guide is first.
4. Switch to 🎟 Show Ticket mode (after running `27_sample_deals.sql`).
5. Open Hollywood Park Casino: branded card, no blank.
6. Nothing says "IMPORTED".

## 2026-11-08 — Home "Happening This Week" cards open the event
Fix (Rambo noticed on phone): tapping a concert/game in the home "Happening This Week"
row used to navigate to that day's calendar (`go('events');selectDay(date)`), so you
couldn't click into a specific concert to see its deals. Now each home event card opens
the event detail directly (`openEvent(id)`), which already shows the Show Your Ticket
deals, "Plan my game day," and nearby pregame spots. The Events-tab rows and the Event
Day banner card already used `openEvent`; this just makes the home cards consistent.
Decision: direct-to-event is right — it's the Event Day DNA (purposeful, deal-first),
fewer taps to the deals. One-line change in renderHomeEvents().

## 2026-11-08 — Stop calling everything a "game"
Rambo's note: not every event is a game — concerts, comedy, community events shouldn't
say "game day." Added evNoun(e): "game" for sports, "show" for concert/comedy, "event"
otherwise. Event detail now reads "Before the show / After the show" for a concert,
"Before the game" for sports, etc. Other interface copy made event-neutral: header
"Game Day"→"Event"; "Plan my game day"→"Plan my day"; push "Game-day alerts?"→"Event
alerts?"; For-Business "game-day specials"→"event specials"; owner toggle "Game Day
Special"→"Event Day Special"; parking tips "most games"/"on game days"→"most events"/
"on event days"; events filter chip "Games"→"Sports"; crew-plan button "Game-day plan"→
"Full plan". Left authentic business review/deal quotes (e.g. "Show your game ticket")
and internal ids/field names (game_day_special, #game-day-plan) unchanged.

## 2026-11-08 — Two-door entry ("Two ways in, one platform underneath")
Simplified the 4-card mode picker ("What's the move?") into two branded doors
("What brings you here today?"):
- 🎟 Game Day & Concert Deals → event-first ('event' mode; absorbs Event Day +
  Show Ticket + After Hours behavior).
- 🍽 Explore & Save Today → everyday ('anytime' mode).
Added a search bar under the doors (obSearchGo → enters everyday + runs the query) and,
on event days, a "Happening today" list of tonight's anchor events (obOpenEvent →
event-first + opens that event). Last choice stays remembered on-device (di_mode, no
account); the inside mode tabs remain so visitors can switch anytime (no dead ends).
Kept our neon gold/pink branding, not the plain mockup. The 4 modes still power the
content ranking underneath — this just simplifies the front door.

## 2026-11-08 — IDEA (planned): Event-day Parking Marketplace
Rambo's idea: let lot owners (churches, businesses, residents near the venues) list
parking for event days — de-escalate traffic, let visitors skip $60 venue lots, keep
the money local. The "Parking" one-tap need becomes a real feature.
- Phase 1 (simple, buildable): a parking LISTING. Host adds lot: location, total spots,
  price, walk time to venue, and an Available Yes/No toggle (or spots-left count). On
  event days, a Parking screen lists AVAILABLE lots near tonight's venue, sorted by
  closest/cheapest → tap for directions + call/reserve. Park & walk. No payments/shuttle.
  (Needs a Supabase table, e.g. di_parking — production SQL = Rambo's go-ahead per CLAUDE.md.)
- Phase 2+: reserve/prepay a spot (Stripe), live spots-left, park-&-ride shuttle (partner
  or venue tie-in).
- Design-for-later (not Phase 1 blockers): liability/insurance, payments & payout, local
  permit rules, lot verification/trust.

## 2026-11-08 — Parking marketplace + distance-on-everything (REFINED, Rambo prioritized)
Rambo prioritizes this NOW (not deferred). Strategy: event-day parking pulls cars off
the stadium into neighborhood lots → less congestion AND guests land in the community
with time to explore/spend. Fixes the two biggest merchant complaints at once.
Design (keep simple):
- Parking lots = a LISTING TYPE that reuses the existing business/sign-up system: a lot
  owner (church/shop/resident) signs up "like a regular business," category = Parking,
  with fields: spots, price, Available Yes/No toggle (off = "None"). HERO = walk time to
  the nearest venue. Some hosts have only ~5 spots — fine.
- Entry: a THIN "🅿️ Event Day Parking" bar UNDER the two main doors (small, not a third
  big box) → opens parking near tonight's venue, sorted by walk time: "$20 · 18 min walk
  to SoFi · 5 spots."
- DISTANCE ON EVERYTHING: every listing (businesses too) shows a small line —
  🚶 walk X · 🚗 drive X · distance from SoFi/Forum/Intuit. Reuse the existing walk-time /
  distance logic from the "Near me" feature; needs lat/lng on every spot (backfill from
  Google where missing).
Data go-ahead needed (CLAUDE.md stop list): a few columns (spots/available/price or a
Parking category) + coordinate backfill. Front-end/display can be built and shown first.
Later phases: reserve/prepay (Stripe), live spots-left, park-&-ride shuttle.

## 2026-11-08 — Parking marketplace + distance-on-everything (BUILT)
Rambo gave the go-ahead ("Design and build the system and database"). Shipped:
- DATABASE: `supabase/29_parking.sql` — new `di_parking` table + RLS that mirrors the
  business self-add trust model. Public sees only approved + active + available lots; a
  signed-in owner can add their own lot but ONLY as approved=false (can't self-approve —
  `revoke update (approved,is_active)`); owners read/update/delete their own rows. Walk/
  drive time is NEVER stored — it's computed in-app from lat/lng + VENUE_COORDS. Admin
  approves + geocodes later, exactly like self-added businesses. (Rambo runs this SQL in
  Supabase → SQL Editor when ready; nothing goes live until he does.)
- ENTRY: a thin "🅿️ Event Day Parking" bar sits UNDER the two doors (smaller, not a 3rd
  big box), as asked. Taps into the parking view (and the "Parking" quick chip now opens
  it too, instead of the old text filter).
- PARKING VIEW: lots sorted by walk time to tonight's venue (or SoFi by default). Each
  card leads with the HERO stat — "🚶 5 min walk to Intuit Dome" — then 🚗 drive · miles ·
  spots open · price (gold) · notes · address · Directions. Built-in SAMPLE lots (real
  coords near the venues) render even offline so it's never an empty state; live
  di_parking rows replace them.
- LIST YOUR PARKING: owner sign-up form (name, address, price, # spots, Available toggle,
  notes, email, certify) → inserts into di_parking as pending, same as business self-add.
  Sign-in gated.
- DISTANCE ON EVERYTHING: added `driveMins()`, `nearestVenue()`, `venueDistLine()`. Every
  business detail page now shows "From venue: 🚶 X min · 🚗 X min · X mi to <nearest venue>"
  (only when the spot has coords — degrades silently otherwise). Reuses the existing
  walk-time/haversine logic.
Verified with headless screenshots (entry bar, sorted lot list, CTA, sign-in gate) — no
page errors. Committed to claude/do-inglewood-backend-t5n03v. Not deployed yet (deploy the
whole site/ folder, never index.html alone). Later phases unchanged: reserve/prepay,
live spots-left, park-&-ride.

## 2026-11-08 — Parking: live status, follow-a-lot, going-fast/gone alerts (BUILT)
Rambo: owners need to toggle availability in REAL TIME (not just yes/no) — Available /
Going fast / Full — auto-on for game days, and people driving in from out of town should
be able to FOLLOW a lot (several) and get pinged the second it's going fast or gone, so
they don't head to a full lot in traffic. Built:
- 3-STATE LIVE STATUS on each lot: open / going / full. Owners flip it from a segmented
  toggle right on their lot card ("Your parking — flip it live on event day"). A Full lot
  still SHOWS (greyed, sunk to the bottom) so drivers know not to come. Status is only
  sticky for the day it's set (status_date) → on a new event day it AUTO-REVERTS to
  Available, which is the "they turn themselves on for game days" behavior, no cron needed.
- FOLLOW a lot (⭐, can follow many) — stored locally + synced onto the push subscription
  (parking_ids). Following offers alerts (reuses the event-push opt-in / iOS install flow).
- REAL-TIME in-app: Supabase realtime on di_parking — when an owner flips a lot while the
  app is open, the list updates live and a followed lot pings a toast ("🟠 Going fast" /
  "🔴 Gone for tonight"). Works the moment the app is open.
- CLOSED-APP PUSH (the en-route promise): new Edge Function `send-parking-pushes` + a
  3-minute cron (31_parking_push_cron.sql), mirroring send-event-pushes and reusing the
  SAME VAPID/secret setup. A followed lot going "going"/"full" fires one web push each per
  day ("Going fast — <lot>" / "Gone for tonight — <lot>", deep-links to ?park=<id>). Dedup
  via di_parking_push_log (per person/lot/day/kind).
DATA (Rambo's stop list — run in order when ready):
  1. supabase/30_parking_status.sql  (status columns, realtime, parking_ids on the push
     subscription, extends di_push_save, di_parking_push_log). REQUIRED for the toggle.
  2. Deploy Edge Function send-parking-pushes (Verify JWT OFF), same secrets as events.
  3. supabase/31_parking_push_cron.sql  (runs the sender; needs push_cron_secret in Vault,
     same one 28_push_schedule.sql uses).
Push (both events AND parking) only goes live once VAPID_PUBLIC_KEY is set in index.html +
the functions are deployed — that's the existing push go-live, now covers parking too. The
in-app realtime + the owner toggle work as soon as 30_parking_status.sql is run. Verified
with headless screenshots (owner toggle, follow buttons, status badges, full-lot greyed &
sunk) — no page errors. Committed to claude/do-inglewood-backend-t5n03v; not deployed.

## 2026-11-08 — Parking/distance: generic "the venues" label (consistency)
Rambo: don't name a specific venue on the walk/drive lines — someone may be headed to the
Forum, not the Dome, and two events can run at the same time, so a named destination can be
wrong. Changed all parking + business distance labels from "… to <nearest venue name>" to a
single consistent "… to the venues." Still compute distance to the NEAREST venue so the
number is sensible (the four venues cluster within ~0.5 mi), we just don't name it. Touched:
venueDistLine (business detail), the parking card walk line, and the parking intro.

## 2026-11-08 — Parking audit (findings + fixes)
Self-audit of the parking system. Fixed now:
- BUG: the "List your parking" form collected an email that submitParking never stored
  (di_parking has no email column) — dead/misleading field. Removed it; the lister is
  signed in, so we verify via their account email (shown on the form, reachable via
  claimed_by). Keeps email (PII) OFF the public/realtime-readable di_parking row.
- COPY: aligned leftover "the stadium" strings to "the venues" (parkbar, owner CTA, the
  two form helper lines) for the consistency Rambo asked for.
- DEFENSIVE: 30_parking_status.sql now explicitly grants update(status,status_date,
  status_updated_at) to authenticated, so owner status flips can't fail on a stricter
  grant setup (table-level grant already covered it; this documents intent).
Notes / by-design (no change):
- status_date uses the device's local day client-side and LA day server-side; owners/
  followers are local (LA) so they agree. Fine for this app.
- di_parking columns (incl. claimed_by) are publicly readable, same as di_businesses —
  no PII there now that email isn't stored. Could add a di_my_parking() RPC + column
  grants later for parity if we ever store private fields.
- Ordering dependency: the new front-end calls di_push_save with p_parking_ids, which
  only exists after 30_parking_status.sql runs. Harmless pre-push-go-live (push is gated
  on VAPID, so those calls never fire yet), but 30 must run before push goes live.
- Realtime delivery (postgres_changes on di_parking) should be verified on the live
  project once 30 runs; RLS SELECT (approved+active+available) governs what anon receives.

## 2026-11-08 — Parking: lot photos (parity with businesses)
Rambo asked if lot owners can add photos like other listings — they couldn't (di_parking
had no photo field at all). Added it, mirroring the business photo flow:
- di_parking.photo_url column (30_parking_status.sql), owner-updatable.
- Upload reuses the SAME Storage bucket as businesses (business-photos), path
  parking/<uid>/<lotid>_<ts>. Two ways in: a Photo picker on the "List your parking" form
  (held, uploaded after insert), and an "Add/Change photo" button on the owner's own lot
  card for later.
- Card shows a real photo as a top banner when present; no photo → clean text card (never
  a stock/generic image, per style rules). realImg() guards it.
Note: uploads go to the existing business-photos bucket. If that bucket's Storage policy
restricts write paths, parking uploads may need a one-line policy (or a parking-photos
bucket). Photo is optional + non-blocking, so a listing still submits if upload fails.
Verified with a headless screenshot (photo banner + owner Change-photo button) — no errors.

## 2026-11-08 — Home cleanup: 4 modes → 3, clearer names, no filler "Open now"
Rambo was confused by the home tabs/sections. Fixed the three he called out:
- "Show Ticket" read like a box office. Renamed the tab to "Ticket Deals" and the card
  badge to "🎟 Ticket Deal"; sharpened the banner: "got a same-day game or concert ticket?
  Flash it for a discount. You keep your ticket — this just unlocks the deal."
- "Anytime" and "After Hours" overlapped — nobody plans nightlife ahead. Removed After
  Hours as a 4th tab. Anytime is now time-aware: after dark (7 PM–4 AM) it surfaces
  "🌙 Out tonight" + "Late-night eats" on its own; daytime shows "Popular in Inglewood."
  Old saved 'after' mode + the after_hours push (?mode=after) now resolve to Anytime,
  which shows nightlife since it's late. Event-Day "letting out" nudge now points to
  Anytime ("See nightlife →").
- "Open now" surfaced 24h hotels/casino as filler. Dropped it; replaced with "Popular in
  Inglewood" (real local spots, deals first), hotels excluded from home popular rows
  (they stay in Explore/search for hotel guests).
Modes are now Event Day / Ticket Deals / Anytime. CLAUDE.md DNA updated (was "4 modes").
Verified with headless screenshots: 3 tabs, day rows (Deals + Popular), after-dark rows
(Deals + Out tonight + Late-night eats) — no page errors.

## 2026-11-08 — Supervisor cleanup sweep (consistency + home de-duplication)
Deep inspection in the spirit of Rambo's label/redundancy/filler feedback. Fixed:
- Stale push-overlay copy still named "After Hours" → now describes the real alerts
  (saved-event Show-Your-Ticket reminders + followed-parking "going fast/gone").
- Hero caption "1,100+ businesses near SoFi, Intuit Dome & the Forum" → "1,000+ Inglewood
  spots near the venues" (fresher count + the consistent "the venues" wording).
- Leftover internal comments naming the removed "After Hours" / old "Show Ticket" mode.
- Event push sender's after-hours message dropped the removed "After Hours" brand and
  points ?mode=anytime (which shows nightlife when late) instead of the dead ?mode=after.
- HOME DE-DUP (the big one): the Anytime home stacked "Today's Deals" THREE times (mode
  row + neon banner + a static "Today's Deals" section) and TWO popular rows ("Popular in
  Inglewood" + "What's Popping"). Now: one "Today's Deals" (the mode card row with See-all
  → Specials), one popular row ("What's Popping"). Removed the duplicate static Today's
  Deals section (buildHome hides it), the duplicate daytime popular row (anytimeHome), and
  retired the redundant "Today's Deals" neon banner (CSS). Verified all 3 modes render
  with no errors; home reads Deals → venue image → Explore/Surprise → What's Popping →
  Stadium District.
Left intentionally (flagged, not auto-changed): "Specials" (nav/page brand) vs "Deals"
(rows/chips) wording — a branding call; Member Deals section — monetization (stop list);
"Explore Inglewood" shown as both a button and a lower section — minor.

## 2026-11-08 — Rename "Event Day Parking" → "Parking"
Rambo: just call it "Parking." The app is already event-centric and the subtitle + live
status carry the moment, so the "Event Day" qualifier was redundant; also matches the
"Parking" quick chip. Renamed the thin bar (now "Parking · Live spots near the venues ·
or list yours" — "Live" leans into the real-time feel), the view header, and the sign-up
helper ("List your parking — free"). Internal comments/ids left as-is.

## 2026-11-08 — Parking P icon → real blue badge, subtitle wording
Rambo: the parking "P" was the powder-blue emoji (🅿️) and read "Live spots." Replaced the
emoji everywhere with a solid blue (#1273ff) rounded "P" badge (.pbadge / the bar's .pb-ic)
— bar, quick chip, venue-guide headers, "Your parking" and "Own a lot" headers. Bar
subtitle now "Available spots near venues · or list yours" (was "Live spots near the
venues"). No more washed-out emoji tile.

## 2026-11-08 — Entry-card icons: emoji tiles → clean custom icons + audit
Rambo didn't like the emoji "tiles." Following the blue-P fix, replaced the two entry-card
emoji (🎟️ / 🍽️) with clean stroked SVG icons in each card's theme color — a gold ticket for
"Game Day & Concert Deals", a pink fork & knife for "Explore & Save Today". Now the whole
entry screen is one icon system (gold ticket / pink dining / blue P), no washed-out emoji.
Audit pass: dropped the last user-facing "Event-day parking" (intro now "Parking near the
venues…"); confirmed zero 🅿️ emoji remain; smoke-tested Home/Explore/Events/Specials/Saved/
Parking — no console errors; quick-chip P renders as the blue badge.
Still emoji (left for review, can clean next if Rambo likes the direction): the mode-tab
icons (🏟️/🎟️/☀️) and the food/drink/coffee quick chips.

## 2026-11-08 — Owner tiers + business-license gate + parking split (DESIGN, Rambo)
Design decisions captured (NOT built yet — pricing is stop-list; L2 + prices still open):
- BUSINESS LICENSE REQUIRED to claim/list a business. Purpose: proves they're a real
  business (keeps out illegal spots / a home just selling parking) AND nudges owners to
  actually get a license, which helps the city economy. Phase-2 vision: a license-helper
  that lets them fill in the application in-app and print it to take to the city.
- PARKING SPLIT — two separate things:
  * A business's everyday customer parking → NOT tracked or shown (doesn't matter).
  * "Local Event-Day Parking" → the marketplace offering; a toggle on the business
    dashboard. When ON, the business's lot appears in the single "Parking" destination,
    tied to the business. Pure lot owners (no storefront) still use "List your parking."
- TIER LADDER (toggles, monthly subscription stepping up):
  * L1 Free: claim w/ business license + clean, complete listing.
  * L2: OPEN — Rambo to define what it unlocks (earlier: "paying monthly, or in good
    standing with the city" — basic paid tier vs city-verified/partner badge, TBD).
  * L3: Live Available/Not-available notifications + "Offer Local Event-Day Parking".
  * L4: Top-of-category placement; rotate/alternate randomly when multiple are on L4.
- NAMING: public destination stays "Parking"; business-side switch = "Offer Local
  Event-Day Parking". (Alt: rename destination "Event Parking" — Rambo's call.)
STILL NEEDED before building: (1) what L2 unlocks, (2) monthly prices per paid level.
Next step once those land: a clickable, non-charging mockup of the 4-level dashboard.
