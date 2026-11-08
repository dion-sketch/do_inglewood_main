# Do Inglewood — How to work with Rambo

## The goal
Do Inglewood is the go-to app for Inglewood, CA. Win on event day (SoFi, Kia Forum, Intuit Dome, YouTube Theater), not by copying Yelp. Make it sticky (reasons to open often) and shareable (organic growth).

## Core DNA (confirmed on Rambo's phone, Sep 26; expanded Nov 8)
The gold "Tonight" event card, "Plan my night," and "Pregame near [venue]" are exactly right. This is the direction: purposeful days, events, Show Your Ticket, and anything that keeps visitors spending in Inglewood. Every new feature should push people toward a plan, a deal, or a local spot — not endless browsing.

- 3 modes: Event Day, Ticket Deals (every Show Your Ticket discount — flash your game/concert ticket, save; NOT a box office), Anytime (visitors/hotel guests, deals + best local spots; nightlife/late-night surfaces on its own after dark — no separate "After Hours" mode, since nobody plans a club ahead)
- Show Your Ticket deals are the headline of Event Day
- Growth loop: event day → deal → share → friend joins
- No Inglewood Passport / check-in rewards
- Business license required to claim/list ANY business — it proves they're real (keeps out illegal spots / a home just selling parking) and nudges owners to get licensed, which helps the city's economy. Phase 2: an in-app helper to fill in & print the license application to take to the city.
- Parking (the "Parking" surface): an event-day parking marketplace for reputable, license-gated lots. Hero stat = walk time to the venues. Live status the owner flips — Available / Going fast / Full — which auto-resets to Available each new event day. People follow lots and get "going fast / gone" alerts (in-app now; web push once push goes live). Tiny 2-space home driveways aren't the target (Inglewood needs thousands of spaces) — the license gate + economics self-select real operators (close lots stack cars, pay staff, charge more). A business offers parking from its dashboard (Premium tier); it then shows up in the one Parking surface.
- Distance on everything: every listing shows walk / drive / distance to the venues.

## Owner plans (tiers — locked Nov 8; billing stays OFF until Rambo says go)
Each step up is a monthly subscription; higher tiers include everything below. Charge for reach, booking, and event-day income — NOT for the deals themselves (deals are the app's fuel and stay free).
- Free (forever): verified with business license, basic listing (name/hours/photo/map), post a deal / Show Your Ticket, walk & drive time to the venues.
- Pro — $69/mo: featured deal (glows in Today's Deals), photo gallery, menu, Do Member deal. This is the tier the CITY discounts / can cover year 1.
- Live — $99/mo: reservations & table requests + real-time Available / Not-available status customers can see. ("Live" = the real-time tier.)
- Premium — $149/mo: top of category (rotates randomly when several are Premium) + send promo notifications to followers + special ads + Offer Local Event-Day Parking.
- The owner dashboard is their control center: reservations their way (phone number / their own system like OpenTable, Resy, Booksy, website / the app's built-in table requests), live on/off toggles (Live tier), and all info/photos/menu/deals editable. Paid = more control, never less. Existing booking systems keep working — we route customers to them, we don't replace them.

## Style
- Keep it simple. Fewer taps, fewer choices, no clutter.
- Dark theme, neon pink/gold, bold and premium. Mobile-first.
- Real photos of real places. No stock or generic images — if a spot has no real photo, show the branded name card.
- Clean custom line-icons in theme colors (gold / pink / blue), not emoji "tiles." The Parking "P" is a solid blue badge, never the powder-blue emoji.
- Any card with a deal shows the gold marker: "🎟 Ticket Deal" or "★ Deal".
- Say "the venues" — never name a specific venue in walk/distance copy. People may be headed to a different one and two events can run at once, so compute distance to the nearest venue but don't name it.
- Walk/drive times are our own estimate (straight-line distance × pace), not a live Google API call.
- "Imported" is admin-only; the public never sees it.
- Never show empty states ("No deal today"). Fall back to something useful.
- Inglewood first: non-Inglewood listings are hidden or labeled "Nearby."

## How to decide
- When unsure, pick the simpler option that helps event-day users and local merchants, and note the decision in docs/BUILD_LOG.md.
- Don't ask me about small UI, naming, or code choices. Decide and log it.
- Ask me only about the stop list: production SQL, deletes, deploys, secrets, costs (pricing/billing).

## Rules
- Never commit secrets. Use env vars.
- Never store precise user location.
- Don't turn on billing or push notifications until Rambo explicitly says go.
- Deploy the whole site/ folder (never index.html alone, or asset images break).
- Commit after each working step with a clear message.
- Rambo prefers short, plain-English summaries.
