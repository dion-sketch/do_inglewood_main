# Game-day push alerts (send-event-pushes)

People who **save an event** in the app can turn on alerts. They get **at most two** per
event:

1. **Pregame**, about 3–4 hours before doors: "Tonight: [show] 🎟️ — N spots near [venue]
   have Show Your Ticket deals." Tapping it opens that event's game-day page.
2. **After Hours**, around when the show lets out: "[show] is letting out 🌙". Tapping it
   opens the app in After Hours mode.

The database enforces the two-alert limit (`di_push_log`), so a double run can't spam anyone.

## One-time setup (≈10 minutes)

1. **Make a VAPID key pair** (identifies your app to Apple/Google push services). On
   your computer:
   ```
   npx web-push generate-vapid-keys
   ```
   You get a **public** key and a **private** key.
2. **Supabase → Edge Functions → Secrets.** Add:
   - `VAPID_PUBLIC_KEY`: the public key
   - `VAPID_PRIVATE_KEY`: the private key (never put this anywhere else)
   - `VAPID_SUBJECT`: `mailto:` plus an email you read (push services contact it if something goes wrong)
   - `PUSH_CRON_SECRET`: any long random string (e.g. from a password manager)
   - `APP_URL`: your live site, e.g. `https://elegant-centaur-570653.netlify.app/`
3. **Deploy the function.** Edge Functions → New → name `send-event-pushes` → paste
   `index.ts` → turn **Verify JWT OFF** → Deploy.
4. **Test it without sending anything.** Call it with `?dry=1` and the header
   `x-cron-secret: <your PUSH_CRON_SECRET>`. The reply lists which events are in a send
   window and how many people would get each alert.
5. **Schedule it.** SQL Editor:
   ```sql
   select vault.create_secret('<same PUSH_CRON_SECRET>', 'push_cron_secret');
   ```
   Then run `supabase/28_push_schedule.sql`. That also trims anonymous activity older than 30 days.
6. **Turn it on in the app.** Put the **public** key in `site/index.html` →
   `var VAPID_PUBLIC_KEY=''`, then deploy the whole `site/` folder so `sw.js` goes live
   next to `index.html`. The public key is safe to publish.

Until step 6 the app still lets people save events; it just doesn't offer alerts.

## Notes
- **iPhone:** web push only works when Do Inglewood is added to the Home Screen
  (iOS 16.4+). The app explains this instead of asking for permission in Safari.
- Events with no real start time ("TBD") get no alerts, because the timing would be a guess.
- Timing lives in `WINDOWS` at the top of `index.ts`, in minutes from the listed start.
