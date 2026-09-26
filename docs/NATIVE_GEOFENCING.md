# Later: "You're near X" alerts (native app)

The web app can only use location **while it's open**. Alerts like "You're 2 minutes from
Randy's — show your ticket for a free donut" need the phone to notice location **in the
background**. Only a native app can do that. The shortest path from this code base:

## What it takes
1. **Wrap the existing site with Capacitor** (keeps `site/` as the app; no rewrite).
   Publishing needs an Apple Developer account ($99/yr) and a Google Play account ($25 once).
2. **Region monitoring (geofences), not constant tracking.**
   - iOS allows about **20** watched regions per app and Android about **100**.
   - Watch the few that matter today: the tonight venue plus the closest Show Your Ticket spots, refreshed when Event Day starts.
   - This is battery-friendly because the OS does the watching.
   - Plugin options: `@capacitor-community/background-geolocation` or a geofencing plugin such as `@transistorsoft/capacitor-background-geolocation` (paid license).
3. **Permissions:** "Always" location on iOS, plus background location on Android.
   - Both stores review this closely.
   - The app must explain the benefit on screen first (the same explainer style as the web version), and work fine if the user says no.
4. **Local notifications**, fired on the phone when a region is entered (`@capacitor/local-notifications`).
   - No server round trip, so the user's location still never leaves the phone. That matches the current rule: never store precise location.
5. **Rules to keep it welcome:**
   - At most 1 "you're near" alert per event.
   - Only on event days.
   - Only for spots with a live deal.
   - An off switch in Saved.

## What stays the same
- Deals, venues and events come from the same Supabase tables (`di_deals`, `di_venues`, `di_events`).
- Push for "doors in 3 hours" keeps using `send-event-pushes`. Native push can reuse it by adding APNs/FCM tokens to `di_push_subscriptions`.

## Rough effort
About 1–2 weeks for the wrap, geofencing, store listings and review, plus store review time.
