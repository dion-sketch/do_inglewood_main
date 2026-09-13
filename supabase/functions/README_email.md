# Reservation emails (Resend) — close the booking loop

Emails the **customer** when their request is sent / confirmed / declined, and the
**business owner** when a new request comes in. Best-effort — a mail failure never
blocks a booking.

## 1) Get a Resend key
[resend.com](https://resend.com) → create an API key. For real sending, add and
**verify your sending domain** (e.g. `doinglewood.com`). Without a verified domain,
Resend's test sender only reaches your own Resend account inbox — fine for testing.

## 2) Deploy the function (JWT verification OFF)
Supabase → Edge Functions → Create function → name it exactly `reservation-email`
→ paste `functions/reservation-email/index.ts` → Deploy → open its settings and set
**Verify JWT = OFF**. (The app calls it with the anon key, and it only ever emails
addresses already stored on the reservation — it can't be used to spam.)

## 3) Add secrets
Edge Functions → Manage secrets:
- `RESEND_API_KEY` = your Resend key
- `RESEND_FROM`    = `Do Inglewood <noreply@yourverifieddomain.com>`
  (defaults to `onboarding@resend.dev` — test-only, reaches just your inbox)

`SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY` are provided automatically.

## 3b) Owner emails need auth lookup
The business-owner email is read from the claiming user's account, so the function
uses the service role (already provided) to look it up — nothing to configure.

## How it fires
The app calls it automatically:
- Customer submits a request → emails the customer + the owner.
- Owner taps Accept / Decline → emails the customer.

### More reliable (optional): a database webhook
For emails that fire even if the app closes mid-write, add a Supabase **Database
Webhook** on `di_reservations` (Insert + Update) → HTTP POST to
`.../functions/v1/reservation-email`. The function already accepts the webhook
payload (`{ type, record }`), so no code change is needed.

## Test
Make a reservation on a **claimed** business with a real customer email → check the
inbox (and Edge Functions → Logs if nothing arrives — usually the domain isn't
verified yet, or `RESEND_FROM` isn't set).
