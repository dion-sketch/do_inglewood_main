# Pull in more Inglewood-area businesses (Google Places)

Bulk-adds local businesses to `di_businesses`. **Additive and safe** — it never
edits or overwrites existing rows (claimed, paid, or hand-edited); it only inserts
places you don't already have (matched by Google `place_id`).

## 1) Get a Google key
Google Cloud Console → enable **Places API** → create an API key.

## 2) Deploy the function
Supabase → Edge Functions → Create function → name it `import-businesses` →
paste `functions/import-businesses/index.ts` → Deploy.

## 3) Add the secret
Edge Functions → Manage secrets → `GOOGLE_PLACES_API_KEY` = your key.

## 4) Run it (on demand)
`POST https://<your-project>.supabase.co/functions/v1/import-businesses`
with header `Authorization: Bearer <your service_role key>`.
(Or ask me to add a "↻ Import Inglewood businesses" button to the Admin page.)

It sweeps restaurants, bars, lounges, cafes, bakeries, hotels and casinos within
~4.5km of Inglewood and inserts the new ones as **Free/approved** listings, ready
for owners to claim. Re-run anytime — already-imported places are skipped.

## Options (top of index.ts)
- `RADIUS` — widen/narrow the search area.
- `SWEEPS` — add/remove place types → category mappings.
- `DETAILS = true` — also fetch phone + website per place (more Google quota).

> Photos are left blank on import; the app shows a branded category tile until the
> owner uploads real photos. That keeps your Google key off the public site.
