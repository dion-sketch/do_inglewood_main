# Import & photo/detail backfill for Inglewood businesses (Google Places)

Two jobs, one function:

1. **Import** new local businesses into `di_businesses` (additive & safe — matched by
   Google `place_id`, never duplicated).
2. **Backfill** real **photos + website + hours + phone** onto businesses you already
   have but that came in bare.

Both are **safe**: they never touch a claimed/paid business (`tier >= 2`) and only
fill a field that is currently empty — an owner's edits are never overwritten.

Photos are downloaded **on the server** and stored in **your** Supabase Storage, so
the public site serves your copies and your Google key never touches `index.html`.

## 1) Google key
Google Cloud Console → enable **Places API** → create an API key.

## 2) Public storage bucket
Supabase → Storage → confirm a **public** bucket named **`business-photos`** exists
(it's the same bucket owners upload to). If it's private, photos won't display.

## 3) Deploy the function
Supabase → Edge Functions → `import-businesses` → paste
`functions/import-businesses/index.ts` → Deploy.

## 4) Secret
Edge Functions → Manage secrets → `GOOGLE_PLACES_API_KEY` = your key.
(`SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY` are provided automatically.)

## 5) Run it — from the Admin page (easiest)
Open `tools/admin.html` → **Businesses** tab:
- **↻ Import new businesses** — pulls new spots (with their photos & details).
- **📷 Add photos & details** — backfills every existing spot that's missing photos.
  It runs in small batches and loops automatically; **keep the tab open** until it
  says *Finished*. Then hard-refresh the app — real photos, galleries, websites and
  hours appear on the business pages.

### Or call it directly
```
POST .../functions/v1/import-businesses?mode=import      # find & add new places
POST .../functions/v1/import-businesses?mode=backfill&limit=25   # enrich 25 existing
```
`mode=backfill` returns `{enriched, remaining}` — call it until `remaining` is 0.
Header: `Authorization: Bearer <service_role key>`.

## Cost (one-time)
Google bills per Place **Details** call (~$0.017) and per **Photo** fetched
(~$0.007). Up to **3 photos** are stored per business (`MAX_PHOTOS` at the top of
`index.ts`). So ~1,000 businesses ≈ **$30–45 one-time**, plus a little Storage. Set
`MAX_PHOTOS = 1` to roughly halve the photo cost. Re-running the backfill later only
touches spots still missing photos, so it won't re-bill ones already done.

## Categories swept
Food & nightlife (restaurants, bars, lounges, cafés, bakeries, hotels, casinos)
**plus the appointment economy**: barbershops, salons, nails, spas, fitness,
tattoo and photography — so booking-ready businesses land in the directory. Edit
`SWEEPS` at the top of `index.ts` to add/remove. Medical, dental and auto-repair
are included but **commented out** (uncomment if you want them — they can dilute
the entertainment/lifestyle feel). Types Google doesn't have (tattoo, photography,
barbershop, nails) are pulled by keyword instead.

## Notes
- **Menus** are not pulled — Google doesn't reliably have them. Owners add their menu
  when they claim (that's the norm, even on Yelp).
- Spots with no Google photo are stamped as "tried" so the backfill skips them next
  time (they keep the branded category tile until an owner uploads a photo).
- Tune `RADIUS`, `SWEEPS`, `MAX_PHOTOS`, `BACKFILL_BATCH` at the top of `index.ts`.
