# Turn it on & dive in — 2 steps

Everything built so far is on the branch `claude/do-inglewood-backend-t5n03v`.
Push/notifications and billing are **OFF** — nothing charges anyone until you say so.

## Step 1 — Run the database setup (once, ~1 minute)
1. Open **Supabase → SQL Editor → New query**.
2. Open `supabase/GO_LIVE_now.sql`, copy **all** of it, paste, and click **Run**.
   - This adds: the Parking marketplace + live status, the owner tiers (Free/Pro/Live/
     Premium), the business-license field, and the business→parking link.
   - It's safe to re-run (every step is "if not exists").

That's the whole database. (The push-alert cron, `31_parking_push_cron.sql`, is only for
when you later turn on phone notifications — skip it for now.)

## Step 2 — Deploy the site
Deploy the **whole `site/` folder** to Netlify (not just index.html, or the images break):
- Easiest: drag the `site/` folder onto your Netlify site's **Deploys** page.
- Or connect the GitHub branch so it deploys on push.

Then open the live URL and dive in.

## What works once those two are done
- Parking page (live status, follow a lot), the denser listing pages, the 3 home modes,
  and the owner dashboard with the 4 tiers + Live status toggle + business-license gate.

## Still OFF on purpose (flip later, your call)
- **Billing** — upgrade buttons say "we'll email you to activate"; they don't charge.
- **Phone push notifications** — needs your VAPID keys + the edge functions deployed +
  `31_parking_push_cron.sql`. In-app alerts already work without it.

## If something looks thin (e.g., name cards instead of photos)
That means those businesses have no real photo yet — tell me what you see live and I'll
check whether it's coverage (missing photos) or a display bug.
