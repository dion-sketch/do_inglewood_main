# How Do Inglewood Works — System & Flow Manual

> The single source of truth for what Do Inglewood is, how each person uses it,
> and how the system behaves behind them. Read this before touching the code.

**Last updated:** 2026-09-12 · **Status key:** ✅ Built · 🟡 Partial · ⬜ Planned

---

## 0. North Star (read this first)

Do Inglewood is **a clean Yelp for Inglewood, CA — "California's Entertainment City" —
built around reservations and notifications.** Its power is three things:

1. **The venues** — SoFi Stadium, Intuit Dome, Kia Forum. People come to the city for
   games and shows, and they need to know what's around them.
2. **The spots** — every restaurant, lounge, hotel, café, casino in the directory.
3. **Booking + being told what happened** — reserve a table and get a confirmation.

The core loop is **reactive, not planned**: *I'm here → what's good → book it → get
notified.* There is **no itinerary builder, no budgeting, no before/after-the-game
planning** — those were removed on purpose because people don't behave that way.

**The business model is plugin-based enhancement.** Every location in the city is in
the directory for free (imported). We then *enhance* each one individually: pull in its
real photos and details, let the owner claim and manage it, plug in its existing booking
system, and — for the ones without one — give it our own reservation + email/calendar +
notification system. Paid tiers and campaigns are how enhanced locations get promoted.

---

## 1. Architecture at a glance (the coder's map)

| Layer | What it is |
|---|---|
| **Front end** | One static file: `site/index.html`. All HTML + CSS + one inline `<script>`. No framework, no build step. Mobile-first, dark neon theme (gold `#f5c542` + hot pink `#ff2e7e`). |
| **Backend** | **Supabase**: Postgres (with Row-Level Security), Auth (magic-link email, no passwords), Storage (`business-photos` bucket), Edge Functions (Deno), pg_cron. |
| **Hosting** | **Netlify** static hosting. Canonical URL: `elegant-centaur-570653.netlify.app`. Deploy = drag `index.html` (or the folder) onto Netlify Drop. |
| **Payments** | **Stripe** payment links + a `stripe-webhook` edge function that auto-activates the paid tier. |
| **Data enrichment** | **Google Places** — `import-businesses` edge function (import new spots + backfill photos/website/hours, server-side). |
| **Events** | **Ticketmaster + City of Inglewood calendar** feed into `di_events` (with a built-in fallback list). |
| **Admin tool** | `tools/admin.html` — a **local-only** page (never deployed) for approving claims, importing, backfilling photos, refreshing events. Secrets are pasted at runtime, never stored in a public file. |

### Data model (Postgres tables)

- **`di_businesses`** — every location. Key columns:
  `id`, `google_place_id`, `name`, `category`, `tags[]`, `address`, `phone`, `website`,
  `hours`, `rating`, `rating_count`, `price_level` (`$`/`$$`/`$$$`), `avg_per_person`,
  `review_quote`, `photo_url` (hero), `photos[]` (gallery), `menu` (json),
  `tier` (1=Free, 2=Verified, 3=Premium), `approved`, `is_active`, `is_large`,
  `special` (text), `member_deal` (text), `booking_url`, `reservation_provider`,
  `stripe_customer`, `stripe_subscription`, `paid_since`.
- **`di_reservations`** — native (in-app) table requests:
  `id`, `business_id`, `user_id`, `customer_name`, `customer_phone`, `customer_email`,
  `party_size`, `resv_date`, `resv_time`, `status` (`requested`/`confirmed`/`declined`/`cancelled`).
- **`di_events`** — `id`, `title`, `venue`, `category`, `source`, `event_date`,
  `start_time`, `price_from`, `url`, `image_url`, `business_id`, `status`.

### 🔒 Security invariants (never break these)

- The **service_role** key and any **Stripe secret** (`sk_…` / `sb_secret_…`) must
  **never** appear in `index.html` or any deployed/public file. They live only in the
  local `admin.html` (pasted at runtime) and in Supabase Edge Function secrets.
- The **Google Places key** is a Supabase secret only. Photos are fetched **server-side**
  and stored in our Storage bucket — the key never touches the public site.
- Tables are protected with **RLS**: the public can read approved/active businesses and
  live events; a signed-in user can read/write only their own reservations; owners manage
  only the business they've claimed.

---

## 2. The People (personas) — start to finish

### 2a. The Consumer (app user) ✅

**Who:** someone in or heading to Inglewood — a game/show attendee, a local, a visitor.

**What they see, in order:**
1. **Onboarding** — 3 branded welcome screens (Explore → the city → get started). Shown once.
2. **Home** — big logo, "Eat. Play. Stay.", a "Today's Specials" hero, two quick actions
   (🔍 Explore Inglewood / 🎲 Surprise Me), "Happening This Week" (events), "What's
   Popping" (top spots), "Near the Venues," "Offers Tonight."
3. **Explore** — searchable, filterable directory. Category tiles (Food, Lounges, Casino,
   Hotels, Coffee & Dessert, Seafood, Brunch, All). Browsing shows spots **with photos**;
   search finds every spot.
4. **Business page** (the heart of the app) — hero photo + swipeable **photo gallery**,
   name, rating, price, "Open now / Takes reservations," tags, action row
   (**Directions · Call · Website · Share**), **Active Special / Member deal**, details
   (category, address, hours, phone, website, review quote), **map**, **menu**, and a
   sticky **Reserve a Table** button.
5. **Reserve** — see §3 (the plugin reservation model).
6. **Saved** — favorite spots (tap the ♥ on any place).
7. **Events** — calendar of games/concerts at the venues, with ticket links.
8. **Do / Today's Specials** — the bottom-center button: every special + member deal in
   the city on one page, plus **Surprise Me** (a random great spot).

**How the system works behind them:** on load, the app pulls all businesses from
`di_businesses` (paged 1000 at a time) and events from `di_events`. Auth is a magic link
(email → one-tap sign-in, no password). Favorites are stored on-device. A business with
no photo shows a **branded category tile** so a card is never blank.

---

### 2b. The Business Owner ✅ (tiers) / 🟡 (some features)

Every business is already listed (free, imported). The owner journey is **claim → manage
→ get booked → promote.**

**Step 1 — Claim (free).** On their business page they tap "Own this business? Claim it."
They fill a short form; an **admin approves** it (within ~72h) to confirm they own it.
Once approved, the business appears in their "My Business" dashboard.

**Step 2 — Manage (by tier):**

| Tier | Price | What they get |
|---|---|---|
| **Free** ✅ | $0 | The listing exists; basic info; one photo; can be claimed. Shows an "Imported" badge until claimed. |
| **Verified** ✅ | $69/mo | Manage all info, hours, **menu**, **photo gallery (up to 7)**, turn on **reservations**, post a **special**. "Verified" badge. |
| **Premium** ✅ | $169/mo | Everything in Verified **+ Sponsored placement** (surfaces to the top of Home/Explore/Specials) **+ Member deals** (offers only signed-in members see). |
| **Enterprise** 🟡 | $500 / $800 | Large venues/chains (`is_large`). Billed by your team — no self-serve link. |

**Step 3 — Get booked.** Reservation requests land in their dashboard with a **pending
badge**. They tap **Accept** or **Decline**; the guest's status updates instantly, and a
confirmed table offers a **calendar link**. (See §3.)

**Step 4 — Promote / pay.** From the dashboard they start an upgrade → Stripe checkout →
the `stripe-webhook` **auto-activates** the tier (no manual admin step). Cancelling a
subscription drops them back to Free automatically.

---

### 2c. The Admin (you) ✅

**Who:** you / your team. Works from the **local** `tools/admin.html` (never deployed).

**What you do:**
- **Approve claims** — confirm an owner really owns a business before they can manage it.
- **Import businesses** — pull new Inglewood-area spots from Google Places (additive, safe).
- **Add photos & details** — backfill real photos/website/hours onto imported spots (§5).
- **Curate** — feature spots, fix data, pause a listing.
- **Refresh events** — pull the latest games/shows.
- **Approve campaigns/specials** 🟡 — review a paid promotion before it goes live (§4).

---

## 3. Reservations — the plugin model (the important part) ✅

This is the heart of the "plugin-based enhancement" idea. When a user taps **Reserve**,
the system branches:

**A) The business already has a booking system (plugin).** If the business has a
`booking_url` (OpenTable, Resy, Booksy, Yelp Reservations, or their own website), Reserve
**opens that** in a new tab. We don't reinvent it — we plug into what they use.

**B) The business has NO booking system (our fallback).** This is the value-add for the
many local spots with nothing:
1. The guest signs in (so we can track status), then fills a short request: name, phone,
   email, party size, date, time.
2. We insert a row into `di_reservations` with `status = 'requested'`.
3. The owner sees it in "My Business" with a **pending badge** and taps **Accept** or
   **Decline** (`status → confirmed / declined`).
4. The guest's page updates to **Requested… → Confirmed ✓** (or Declined / "try another
   time"), and a confirmed table shows an **Add to Google Calendar** link.
5. Duplicate protection: a guest can't fire a second request for the same spot while one
   is open.

**🟡 What still needs plugging in (email + calendar system):** today the status updates
live **inside the app** and offers a Google Calendar link. The **email** leg — emailing
the guest and the business when a request is made/confirmed — is the piece to add next
(recommended: **Resend** via an edge function, triggered on `di_reservations` insert/update).
That closes the loop for people who aren't staring at the app.

---

## 4. Money & campaigns — how promotion works ✅ / 🟡

**How a business pays.** From their dashboard they pick a tier → a Stripe **payment link**
opens, carrying `client_reference_id = "<business_id>|<tier>"`. On payment, the
`stripe-webhook` edge function reads that and sets the business's `tier`. Cancellation
(`customer.subscription.deleted`) drops them to Free. **This is automatic** — no admin step.
*(Note: the links in `index.html` are currently Stripe **test** links — swap for live links before launch.)*

**What a paid campaign looks like to app users:**
- **Sponsored (Premium / tier 3)** — the business **surfaces to the top** of "What's
  Popping," Explore results, and Today's Specials, with a ⭐ **Sponsored** badge.
- **Special (Verified+)** — a 🍸 **Special** chip on their card and a callout on their
  page; appears in **Today's Specials**.
- **Member deal (Premium)** — a deal only **signed-in members** can unlock (a download/
  sign-up magnet).

**🟡 The approval flow (to build).** Right now a Verified+ owner's special goes live when
they save it. The intended control: a paid campaign/special enters a **review queue**, the
**admin approves** it in `admin.html`, and only then does it surface to app users. Add a
`campaign_status` (`pending`/`approved`/`rejected`) column + an admin review list. This is
what "how do we approve that" refers to.

---

## 5. Data & photo pipeline ✅

- **Import** (`import-businesses?mode=import`) — sweeps restaurants, bars, lounges, cafés,
  bakeries, hotels, casinos within ~4.5km of Inglewood and inserts **new** spots (matched
  by Google `place_id`, never duplicated).
- **Backfill** (`import-businesses?mode=backfill`) — for spots you already have that are
  missing photos, pulls Google **Place Details** (photos, website, hours, phone). Photos
  are downloaded **server-side** and stored in the `business-photos` bucket; the app serves
  our copies. Runs in batches; the Admin "📷 Add photos & details" button loops it to done.
- **Safe by design:** never touches a claimed/paid business (`tier ≥ 2`); only fills empty
  fields; spots with no Google photo are stamped "tried" so they aren't re-billed.
- **Menus** are **not** auto-pulled (Google doesn't reliably have them) — owners add their
  menu when they claim. This is normal (even Yelp works this way).

---

## 6. Roadmap — what's built vs. next

**✅ Built:** directory + search/explore, business pages (gallery, menu, website, hours,
map, reviews), native reservations + Accept/Decline + calendar link, plugin booking
link-out, favorites, events calendar, specials + member deals, tiers, Stripe
auto-activation webhook, Google import + server-side photo backfill, admin tools.

**🟡 Needs finishing:** email notifications (Resend) for reservations; campaign/special
**approval gate**; swap Stripe **test → live** links; owner-added menus for imported spots.

**⬜ Vision / next:** push (pop-up) notifications for the installed app; deeper booking
integrations per provider; a campaign manager with the approval queue; owner analytics
(views, clicks, bookings); continued per-location enhancement across the whole city.

---

## 7. Glossary for the developer

- **Enhance / enhancement** — taking a bare imported listing and adding real photos,
  details, an owner, a booking method, and promotion. The core business activity.
- **Plugin (booking)** — a business's existing reservation system (OpenTable/Resy/etc.)
  that we link out to instead of replacing.
- **Native reservation** — our own in-app table request for spots with no booking system.
- **Tier** — 1 Free, 2 Verified, 3 Premium, plus Enterprise for large venues.
- **Sponsored** — a Premium business promoted to the top of listings.
- **Letter tile** — the branded category fallback image shown when a spot has no photo.
