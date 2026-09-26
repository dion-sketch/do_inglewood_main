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
