# Do Inglewood — Handoff Brief (READ THIS FIRST)

> If you are a Claude/AI session picking up this project: read this file **and**
> `docs/HOW_DO_INGLEWOOD_WORKS.md` before doing anything. This file is the human
> layer — the owner's vision, standing preferences, where we left off, and how he
> wants to work. The other file is the technical/system manual.
>
> **Last updated:** 2026-09-14 (build `2026.09.14-vegas2`)

---

## 0. Who and what

- **Owner:** Dion (dionrambo@gmail.com). Building **Do Inglewood**, a mobile-first
  local business directory + reservations web app for **Inglewood, CA —
  "California's Entertainment City."** Tagline: **Eat. Play. Stay.**
- **The pitch is NOT just tourism — it's local economic traffic:** visitors for
  SoFi/Intuit Dome/Kia Forum events **plus** regional locals (Hawthorne, Culver City,
  South LA, Gardena) discovering and booking Inglewood spots — breakfast, family
  activities, appointments, nightlife, all of it.
- Core loop is reactive: *I'm here → what's good today → book it → get notified.*
  No itinerary builder, no budgeting (removed on purpose).

## 0.5 TOP PRIORITIES Dion keeps asking for (do these — don't lose them)

1. **REAL photos of the main locations.** Dion wants actual photographs of the real
   venues/spots — SoFi Stadium, Kia Forum, Intuit Dome, Hollywood Park Casino, Dulan's,
   Two Hommés, and the other headline spots. The designed "Vegas" cards are ONLY a
   fallback for places without a real photo — they are **not** the goal. Get real,
   freely-licensed images of the actual places, put them in the repo (e.g. `site/assets/`)
   or Supabase Storage, wire them so the real photo wins, and **screenshot each one to
   prove it shows.** Since you (local session) have internet, you can actually do this.
2. **The per-business SPECIAL is the #1 differentiator vs Yelp.** Every business should
   be able to add "something special" — a deal, an offer, a members-only perk — and it
   must be **visible and prominent on the business page and in Today's Specials.** Make
   the affordance obvious (how an owner adds one) and make a business with a special feel
   clearly different from a plain listing. Data fields exist (`special`, `mdeal`); the
   product emphasis and visibility are what Dion feels is missing.

## 0.6 "Today's Deal" — the Specials system (locked wording + plan)

The per-business Special is delivered as **one featured "Today's Deal"** per business.
One switch for the owner powers the badge, the feed, and the notifications.

**LIT vs DIM rule:**
- **LIT** = business is premium/paying (treat `tier >= 2` as paid) **AND** has a deal set
  (the `special` field). → glowing gold, clickable.
- **DIM** = no deal, or not premium. → faded, unclickable.

**Exact copy:**
- Business page, LIT: gold button **`SEE TODAY'S DEAL →`**
- Business page, DIM: faded unclickable pill **`No deal today`**
- Card in a list, LIT: small gold flag **`🎟 TODAY'S DEAL`**; DIM: nothing.
- Reveal on tap:
  `🎟 Today's Deal — [Business]` / `[the deal]` / `Valid today · Show this screen when you order`
- Owner (My Business), premium + no deal:
  `Your deal slot is dark. Light it up to land in Today's Deals →  [Add Today's Deal]`

**Why it matters:** the dim slot is the built-in upsell — customers learn to look for the
gold one; businesses see the dark slot and want to light it up. It's the #1 Yelp
differentiator.

**The notification engine (the Groupon-style daily draw):** the one featured deal feeds:
1. The gold button + card flag on the business.
2. Home **"Today's Deals"** (curated top few).
3. Notifications — **the Daily Dose** (a daily push, e.g. 11am: "Today in Inglewood:
   15% off at Two Hommés · free cobbler at Dulan's…") and **the Post-Game Blast** (when a
   SoFi/Kia Forum/Intuit event lets out, push nearby deals: "Game's over — 6 deals near
   SoFi right now"). Live and local, not prepaid vouchers — drives real walk-in traffic.

**Build order:** Wave 1 = LIT/DIM button + card flag + Today's Deals feed + owner
"Add Today's Deal" (buildable now, no push infra). Wave 2 = the notification engine
(needs installed-PWA push + game end-times; the morning/midday/evening + day-of-week
preference model is already built for it).

## 1. Design north star (do not lose this)

- **Premium, high-end, "Las Vegas" aesthetic.** Dion says this repeatedly. When in
  doubt, make it look luxe and intentional, never cheap or placeholder-y.
- **All-day, NOT night-only.** Never frame things as "tonight." People want breakfast,
  brunch, family activities, daytime too. Copy stays day-neutral ("today," "all day,
  breakfast to last call").
- **Mobile-first.** It must look right at phone width first.
- **No dead ends, ever.** No dead buttons, no blank images, no letter-tiles as a final
  state — every business shows a real or attractive image; every action goes somewhere.

## 2. Dion's standing preferences (the notes that kept getting missed)

- **Photos on EVERY business**, especially the marquee venues (SoFi Stadium, Kia Forum,
  Intuit Dome) and local favorites (Dulan's, Two Hommés). Real photo if we have one;
  otherwise an attractive category image; marquee venues use designed cinematic cards.
- **Onboarding:** keep the same button on the slides, high-end art (he liked the
  "EXPLORE INGLEWOOD" gold/pink art button), and enter the app directly — no dead
  third screen. Don't quietly change the button he approved.
- **Specials** live as a colored/gradient **bottom-nav tab** ("Specials") to grab
  attention, plus "Today's Specials" on home. Integrated into the flow, not a popup.
- **Reservations matter a lot** (the mayor specifically asked about them). Model: use
  the business's own booking link if it has one (OpenTable/Resy/Booksy/Square), else a
  native in-app request (for claimed businesses), else "Call to book." Covers dining
  **and** the appointment economy (barbershops, salons, spas, tattoo, fitness).
- **Verify before claiming done.** Dion was burned by stale deploys and by being told
  things were finished when they weren't. There is a **visible build stamp** in the ☰
  menu (currently `2026.09.14-vegas2`) so the live version is always verifiable.
- He wants **big/early problems caught proactively** ("audit and catch"), not surfaced
  late after he hits them.

## 3. Hard rules (non-negotiable)

- **Secrets:** NEVER put `service_role`, Stripe secret (`sk_`/`sb_secret_`), or the
  Google Places key in `site/index.html` or any Netlify/public file. Only the Supabase
  **publishable** key belongs in the app. `service_role` is pasted at runtime into local
  `tools/admin.html` only; Google Places key lives only as a Supabase secret.
- **Git:** develop and push only to branch `claude/do-inglewood-backend-t5n03v`.
- **Never open a pull request unless Dion explicitly asks.**
- End commit messages with:
  `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`
- Do not put any model/assistant identifier into commits, PRs, code comments, or
  anything pushed to the repo.

## 4. How the app is built (quick map — full detail in HOW_DO_INGLEWOOD_WORKS.md)

- **One file:** `site/index.html` (~0.6MB, one inline `<script>` + embedded brand art).
  Deployed to **Netlify** (live: https://elegant-centaur-570653.netlify.app).
- **Backend:** Supabase (Postgres + RLS, Auth magic-link, Storage bucket
  `business-photos` [public], Edge Functions in `supabase/functions/`).
- **Image logic in index.html:** `pickImg()` → real photo (`photo_url` starting http)
  wins; marquee venues get a designed card via `MARQUEE`/`heroCard()`/`marqueeCard()`;
  otherwise `catImg(category, name, tags)` returns an attractive category photo.
  `bgLayers()` layers the image over a guaranteed category fallback. `realImg()` treats
  both `http` URLs and inline `data:image` cards as displayable. `findBiz()` resolves
  marquee spots by name after the DB load re-keys everything by UUID.
- **Admin:** `tools/admin.html` (run locally, never deploy) triggers the photo backfill
  and approve/claim/promote actions.

## 5. Where we left off (state as of this brief)

Done recently:
- Every business shows a real image (real photo, else category photo) — no letter tiles.
- Category images are name/tag-aware (an auto shop or tattoo studio filed under the
  generic "Services" category no longer shows a food photo).
- Designed cinematic "Vegas" hero cards for marquee venues (SoFi, Kia Forum, Intuit
  Dome, YouTube Theater, Hollywood Park Casino), applied everywhere including the
  detail hero and home cards.
- Photo backfill now enriches unclaimed venues regardless of tier (so stadiums get
  real photos too) — `supabase/functions/import-businesses`.
- Booking: 3-lane reserve CTA; reservation email function (`reservation-email`).

## 6. Open items / what Dion is still seeing (do a visual pass)

- **Bottom-center nav badge (the "Do"/Specials button) renders as a SQUARE — it should
  be a CIRCLE.** Fix in `site/index.html` CSS and verify with a screenshot.
- **Full visual QA sweep:** load the app, screenshot Home, Explore, a listing, Today's
  Specials, Events, Saved; list everything that looks off (shapes, alignment, spacing,
  wrong images, dead buttons) and fix one at a time with before/after screenshots.
- Consider category browse rows after "The Stadium District" on Home.
- Later (owner-managed): Stripe live links, Resend email, the morning/midday/evening +
  day-of-week notification preferences (the data model is already built for it).

## 7. How to work with Dion (this is important to him)

- **You can now SEE the site — use it.** Before saying anything is "done," open the site
  in a headless browser (Playwright/Chromium) and screenshot it. Verify fixes against the
  **local** `site/index.html` (the live Netlify URL only changes when he deploys).
- **Be honest about verification.** Say "verified in a browser screenshot" vs. "should
  look right — confirm on your screen." Don't overstate.
- **Catch big issues early**, proactively, rather than letting him hit them.
- **He speaks in plain English, not code.** Translate "the dude at the bottom is a square"
  into the actual CSS fix. Point-and-fix.
- **Deploying:** fixes are local until deployed. Batch a few, then he deploys (drag
  `index.html` into Netlify, or set up Netlify auto-deploy from the branch — offer this).
