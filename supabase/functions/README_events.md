# Automatic events feed — setup (do once)

This makes the calendar fill itself with every SoFi / Intuit Dome / Kia Forum /
YouTube Theater game & concert, pulled from Ticketmaster.

## 1) Get a free Ticketmaster key (2 minutes)
1. Go to **developer.ticketmaster.com** → **Sign up** (free).
2. After you confirm your email, open **My Apps** → your default app.
3. Copy the **Consumer Key** (a long string). That's your API key.

## 2) Create the function in Supabase
1. Supabase → **Edge Functions** → **Create a function** → name it exactly
   `refresh-events`.
2. Paste the contents of `functions/refresh-events/index.ts` → **Deploy**.

## 3) Add the key as a secret
Supabase → **Edge Functions** → **Manage secrets**:
- `TICKETMASTER_API_KEY` = the Consumer Key from step 1.

`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are provided automatically.

## 4) Pull events now
Open **admin.html** on your computer → **Events** tab → **↻ Refresh from
Ticketmaster**. Within a few seconds it says "Imported N events" and the calendar
is populated. (Re-running is safe — it updates existing events instead of duplicating.)

## 5) Keep it fresh automatically (optional but recommended)
So you never have to press the button, schedule it daily. In Supabase → **SQL Editor**, run:

```sql
-- enable the scheduler + HTTP (one time)
create extension if not exists pg_cron;
create extension if not exists pg_net;

-- run refresh-events every day at 8:00 AM UTC (~1 AM Pacific)
select cron.schedule(
  'refresh-events-daily',
  '0 8 * * *',
  $$
  select net.http_post(
    url := 'https://YOUR-PROJECT.supabase.co/functions/v1/refresh-events',
    headers := jsonb_build_object('Authorization', 'Bearer YOUR-SERVICE-ROLE-KEY')
  );
  $$
);
```
Replace `YOUR-PROJECT` and `YOUR-SERVICE-ROLE-KEY` (Project Settings → API →
service_role). That's it — the calendar refreshes itself every day.

> Notes: the feed keeps events at the Inglewood venues only. Prices/times/images
> come straight from Ticketmaster. Sports games and concerts both come through and
> get the right icon automatically in the app.
