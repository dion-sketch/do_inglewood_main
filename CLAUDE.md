# Do Inglewood — How to work with Rambo

## The goal
Do Inglewood is the go-to app for Inglewood, CA. Win on event day (SoFi, Kia Forum, Intuit Dome, YouTube Theater), not by copying Yelp. Make it sticky (reasons to open often) and shareable (organic growth).

## Core DNA (confirmed on Rambo's phone, Sep 26)
The gold "Tonight" event card, "Plan my night," and "Pregame near [venue]" are exactly right. This is the direction: purposeful days, events, Show Your Ticket, and anything that keeps visitors spending in Inglewood. Every new feature should push people toward a plan, a deal, or a local spot — not endless browsing.

## Core features
- 4 modes: Event Day, Show Ticket (every Show Your Ticket deal), Anytime (visitors/hotel guests, specials first), Adults After Hours (after the show)
- Show Your Ticket deals are the headline of Event Day
- Growth loop: event day → deal → share → friend joins
- No Inglewood Passport / check-in rewards

## Style
- Keep it simple. Fewer taps, fewer choices, no clutter.
- Dark theme, neon pink/gold, bold and premium. Mobile-first.
- Real photos of real places. No stock or generic images — if a spot has no real photo, show the branded name card.
- Any card with a deal shows the gold marker: "🎟 Show Ticket" or "★ Deal".
- "Imported" is admin-only; the public never sees it.
- Never show empty states ("No deal today"). Fall back to something useful.
- Inglewood first: non-Inglewood listings are hidden or labeled "Nearby."

## How to decide
- When unsure, pick the simpler option that helps event-day users and local merchants, and note the decision in docs/BUILD_LOG.md.
- Don't ask me about small UI, naming, or code choices. Decide and log it.
- Ask me only about the stop list: production SQL, deletes, deploys, secrets, costs.

## Rules
- Never commit secrets. Use env vars.
- Never store precise user location.
- Commit after each working step with a clear message.
- Rambo prefers short, plain-English summaries.
