# Do Inglewood — Go‑Live Checklist (do once, in order)

Everything below is safe to run even if you already did some of it — the SQL uses
"if not exists" / "drop … if exists", so re‑running never breaks anything.

## A) Database — Supabase → SQL Editor → New query → paste → Run
Run these **in order** (one at a time; each should say "Success"):
1. `supabase/05_owner_login.sql`
2. `supabase/06_fix_claims_owner_link.sql`
3. `supabase/07_reservations.sql`
4. `supabase/08_reservations_native.sql`
5. `supabase/09_notify.sql`
6. `supabase/10_resv_cancel.sql`
7. `supabase/11_pause_photos.sql`

## B) Storage & Auth (one‑time — you likely did these already)
- **Storage → New bucket** named `business-photos`, **Public** ON. (Then the storage
  policies from 05 apply.)
- **Authentication → URL Configuration:** Site URL = your Netlify URL; add
  `https://YOUR-SITE.netlify.app/**` to Redirect URLs.

## C) Deploy
- **Netlify:** deploy the latest `site/index.html` (drag‑drop the newest file).
- **Your computer:** open the latest `tools/admin.html` (keep it on your computer —
  never upload it; it holds your admin key).

## D) Smoke test (5 minutes — do before launch)
1. Open the site in a **private/incognito** window.
2. Menu → **Sign In** → get the email link → sign in.
3. **Build** a plan (pick date + time) → open the itinerary.
4. Tap **Reserve** on a stop → send a request.
5. Claim that business (or use one you own) → **My Business** → **Accept** the request.
6. Back on the itinerary → it should read **Confirmed ✓**. Tap **Share**.
✅ If that works, the whole product works.

## E) Owner email alerts (optional — can do after launch)
Follow `supabase/functions/README_notify.md`: Resend key → deploy the
`notify-reservation` function → add secrets → Database Webhook on `di_reservations`.
The reservation loop works without this; email is the upgrade.

## F) Money — Stripe (only when you want to charge for real)
- Create the **$69** and **$169** payment links in Stripe.
- Send me the two links → I paste them in.
- Flip Stripe to **Live** mode.
(Until then it stays in test mode — no real charges.)

---
**Order that matters:** A → C → D. Everything else (E, F) can come later.
