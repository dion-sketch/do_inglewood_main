# Owner reservation alerts — setup (do once)

When a customer requests a table, the business owner gets an email with a link to
Accept/Decline. This needs one free email service + one Supabase function + one webhook.

## 1) Get a free email key (Resend)
1. Go to **resend.com** → sign up (free).
2. **API Keys** → **Create API Key** → copy it (starts with `re_`).
3. (Optional, later) verify your own domain so email comes from `you@doinglewood.com`.
   Until then it sends from Resend's test address, which is fine for testing.

## 2) Create the function in Supabase
1. Supabase → **Edge Functions** → **Create a function** → name it exactly
   `notify-reservation`.
2. Paste the contents of `functions/notify-reservation/index.ts` → **Deploy**.

## 3) Add the secrets
Supabase → **Edge Functions** → **Manage secrets** (or Project Settings → Edge Functions):
- `RESEND_API_KEY` = the `re_...` key from step 1
- `APP_URL` = your live site, e.g. `https://elegant-centaur-570653.netlify.app`
- (optional) `NOTIFY_FROM` = `Do Inglewood <onboarding@resend.dev>` (change once your domain is verified)

`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are provided automatically — don't add them.

## 4) Fire it on every new reservation (Database Webhook)
Supabase → **Database** → **Webhooks** → **Create a new hook**:
- Table: **di_reservations**
- Events: **Insert**
- Type: **Supabase Edge Function** → choose **notify-reservation**
- Save.

## 5) Test
Send a table request in the app for a business you own → within a few seconds the
owner's alert email should arrive. If not, check Edge Functions → Logs.

> Owners can change where alerts go in **My Business → "Reservation alerts to (email)"**.
> If left blank, alerts go to the email they signed in with.
