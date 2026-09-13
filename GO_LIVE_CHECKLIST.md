# Do Inglewood — Go‑Live Checklist

**The short version:** you are LIVE after Steps 1–2. Everything after that is polish
you can add the same day or later. All SQL is safe to re‑run ("if not exists").

---

## 🟢 REQUIRED to be live today (~15 min)

### 1. Deploy the app
- **Netlify** → drag‑drop the latest `site/index.html`.
- Hard‑refresh your site. That's the app — browse, search, business pages,
  favorites, events, Today's Specials, the daily greeter, and booking all work.

### 2. Set up the database (one paste)
- **Supabase → SQL Editor → New query** → paste **all of `supabase/turn_on_all.sql`**
  → Run. (Covers everything: schema, RLS, events, reservations, menus, member
  deals, Stripe columns, and the booking `note`.)
- **Storage:** confirm a **Public** bucket named `business-photos` exists.
- **Authentication → URL Configuration:** Site URL = your Netlify URL; add
  `https://YOUR-SITE.netlify.app/**` to Redirect URLs (so magic‑link sign‑in works).

**✅ You're live.** The app is public and functional.

---

## ⭐ Strongly recommended today (~15 min) — makes it look real

### 3. Load real photos
- Supabase → Edge Functions → deploy `import-businesses` (paste
  `supabase/functions/import-businesses/index.ts`). Secret `GOOGLE_PLACES_API_KEY`.
- Open `tools/admin.html` (on your computer — never upload it) → **📷 Add photos &
  details**. Keep the tab open till it says Finished.
- Result: real photos, websites and hours instead of letter tiles.

### 4. Smoke test (5 min, in a private/incognito window)
1. Menu → **Sign In** → open the magic link → signed in.
2. Open a business → if it's yours, **Claim it** → **My Business**.
3. On that claimed business, tap **Book a Table** → send a request.
4. **My Business** → **Accept** the request → the customer page reads **Confirmed ✓**.
✅ If that works, the whole product works.

---

## 🔵 This week (not needed to launch)

### 5. Reservation emails (Resend)
Follow `supabase/functions/README_email.md`: Resend key → deploy the
`reservation-email` function (Verify JWT OFF) → add `RESEND_API_KEY` + `RESEND_FROM`.
Booking works without this; email is the upgrade that reaches people who left the app.

### 6. Money — Stripe (only when you want to charge businesses)
Create the **$69** and **$169** Stripe payment links → send them to me → I paste them
in → flip Stripe to **Live**. Until then it stays in test mode (no real charges).

---

## ⚪ Later (roadmap)
Game‑day push notifications, the Morning/Midday/Evening + day picker (the preference
model is already built for it), and deep Square booking integration.

---
**Order that matters: 1 → 2 (live) → 3 → 4. Everything else is optional.**
