// Do Inglewood — import & enrich Inglewood-area businesses from Google Places.
//
// Two modes (choose with ?mode=):
//   • mode=import   (default) — sweep place types around Inglewood and INSERT new
//                    businesses (name, category, address, rating, price) + pull each
//                    one's details & photos.
//   • mode=backfill — go through businesses you ALREADY have that are missing photos
//                    and fill in photos + website + hours + phone. Runs in batches;
//                    call it repeatedly until it reports remaining:0 (the Admin
//                    button loops this for you).
//
// SAFE: it never touches a claimed/paid business (tier >= 2), and it only fills a
// field that is currently empty — it never overwrites an owner's edits. New places
// are matched by Google place_id so nothing is ever duplicated.
//
// Photos are downloaded on the SERVER and stored in your own Supabase Storage
// ("business-photos" bucket). The public site serves YOUR copies — your Google API
// key never appears on the public site.
//
// Deploy: Supabase Dashboard → Edge Functions → "import-businesses" → paste → Deploy.
// Secret: GOOGLE_PLACES_API_KEY = your key with "Places API" enabled.
//   (SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are provided automatically.)
// Bucket: make sure a PUBLIC Storage bucket named "business-photos" exists.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const KEY    = Deno.env.get("GOOGLE_PLACES_API_KEY") || "";
const SB_URL = Deno.env.get("SUPABASE_URL")!;
const SB_SVC = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const admin  = createClient(SB_URL, SB_SVC);

// Inglewood center + ~4.5km radius covers SoFi / Intuit Dome / Kia Forum & the city.
const LAT = 33.9617, LNG = -118.3531, RADIUS = 4500;
const BUCKET = "business-photos";     // must be a PUBLIC storage bucket
const MAX_PHOTOS = 3;                 // photos to store per business (cost control)
const BACKFILL_BATCH = 25;            // businesses enriched per backfill call (time budget)

// Google place type -> our category.
// [google place type, our category, optional keyword]. Use a keyword when Google
// has no dedicated place type (tattoo, photography). All of these are bookable
// categories in the app, so imported spots land ready for the appointment flow.
const SWEEPS: [string, string, string?][] = [
  // Food & nightlife
  ["restaurant", "Restaurant"], ["meal_takeaway", "Restaurant"],
  ["bar", "Lounge"], ["night_club", "Lounge"],
  ["cafe", "Coffee"], ["bakery", "Dessert"],
  ["lodging", "Hotels"], ["casino", "Casino"],
  // Self-care & appointment economy (barbers, salons, nails, spas, fitness)
  ["hair_care", "Salon"], ["beauty_salon", "Beauty"], ["spa", "Spa"], ["gym", "Fitness"],
  // No Google place type — search by keyword
  ["", "Barbershop", "barbershop"], ["", "Nails", "nail salon"],
  ["", "Tattoo", "tattoo"], ["", "Photography", "photography studio"],
  // Optional utility appointments — uncomment to include (may dilute the
  // entertainment/lifestyle feel of the directory):
  // ["dentist", "Dental"], ["doctor", "Medical"], ["car_repair", "Auto"],
];

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));
const priceStr = (n: number | undefined) => (n && n > 0 ? "$".repeat(Math.min(n, 4)) : "$$");

// If a business's website IS a known booking system, treat it as a booking link
// so the app shows "Book on X" (the reliable link-out lane) automatically.
const BOOKING_HOSTS: [string, string][] = [
  ["booksy.", "Booksy"], ["opentable.", "OpenTable"], ["resy.", "Resy"],
  ["squareup.com/appointments", "Square"], ["square.site", "Square"], ["book.squareup", "Square"],
  ["vagaro.", "Vagaro"], ["calendly.", "Calendly"], ["getsquire.", "Squire"],
  ["acuityscheduling.", "Acuity"], ["schedulicity.", "Schedulicity"], ["setmore.", "Setmore"],
  ["fresha.", "Fresha"], ["mindbodyonline.", "Mindbody"], ["yelp.com/reservations", "Yelp Reservations"],
];
function detectBooking(website?: string): { booking_url?: string; reservation_provider?: string } {
  if (!website) return {};
  const w = website.toLowerCase();
  for (const [host, name] of BOOKING_HOSTS) if (w.includes(host)) return { booking_url: website, reservation_provider: name };
  return {};
}

async function nearby(type: string, keyword?: string): Promise<any[]> {
  let out: any[] = [], token = "";
  for (let page = 0; page < 3; page++) { // up to 60 results per type
    let url = `https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=${LAT},${LNG}&radius=${RADIUS}&key=${KEY}`;
    if (type) url += `&type=${type}`;
    if (keyword) url += `&keyword=${encodeURIComponent(keyword)}`;
    if (token) url += `&pagetoken=${token}`;
    const j = await (await fetch(url)).json();
    if (j.results) out = out.concat(j.results);
    if (!j.next_page_token) break;
    token = j.next_page_token;
    await sleep(2100); // Google requires a short delay before the page token is valid
  }
  return out;
}

// Pull the rich details we show on a business page.
async function details(placeId: string): Promise<{
  phone?: string; website?: string; hours?: string; photoRefs: string[];
}> {
  try {
    const fields = "formatted_phone_number,website,opening_hours,photos";
    const url = `https://maps.googleapis.com/maps/api/place/details/json?place_id=${placeId}&fields=${fields}&key=${KEY}`;
    const j = (await (await fetch(url)).json()).result || {};
    const hours = j.opening_hours?.weekday_text?.join(" · ");
    const photoRefs = (j.photos || []).slice(0, MAX_PHOTOS).map((p: any) => p.photo_reference).filter(Boolean);
    return { phone: j.formatted_phone_number, website: j.website, hours, photoRefs };
  } catch { return { photoRefs: [] }; }
}

// Download one Google photo (server-side) and store it in our own bucket. Returns
// the PUBLIC URL of our copy, or null on failure.
async function storePhoto(placeId: string, ref: string, idx: number): Promise<string | null> {
  try {
    const gUrl = `https://maps.googleapis.com/maps/api/place/photo?maxwidth=1000&photo_reference=${ref}&key=${KEY}`;
    const resp = await fetch(gUrl); // follows the redirect to the actual image
    if (!resp.ok) return null;
    const ct = resp.headers.get("content-type") || "image/jpeg";
    const ext = ct.includes("png") ? "png" : "jpg";
    const bytes = new Uint8Array(await resp.arrayBuffer());
    const path = `imported/${placeId}/${idx}.${ext}`;
    const up = await admin.storage.from(BUCKET).upload(path, bytes, { contentType: ct, upsert: true });
    if (up.error) return null;
    return admin.storage.from(BUCKET).getPublicUrl(path).data.publicUrl || null;
  } catch { return null; }
}

async function fetchPhotos(placeId: string, refs: string[]): Promise<string[]> {
  const urls: string[] = [];
  for (let i = 0; i < refs.length; i++) {
    const u = await storePhoto(placeId, refs[i], i);
    if (u) urls.push(u);
  }
  return urls;
}

// Build a patch that ONLY fills fields the row is currently missing (never clobbers
// an owner's edits). Returns null if there is nothing to add.
function fillPatch(row: any, d: { phone?: string; website?: string; hours?: string }, photos: string[]) {
  const patch: any = {};
  if (photos.length) {
    if (!row.photo_url) patch.photo_url = photos[0];        // hero image
    if (!row.photos || !row.photos.length) patch.photos = photos; // gallery
  }
  if (d.website && !row.website) patch.website = d.website;
  if (d.phone && !row.phone) patch.phone = d.phone;
  if (d.hours && !row.hours) patch.hours = d.hours;
  // Auto-plug an existing booking system (Booksy/OpenTable/Square/etc.) if the
  // website is one — only when the business has no booking link yet.
  if (!row.booking_url) {
    const b = detectBooking(d.website);
    if (b.booking_url) { patch.booking_url = b.booking_url; patch.reservation_provider = b.reservation_provider; }
  }
  return Object.keys(patch).length ? patch : null;
}

// ---- mode=backfill : enrich existing UNCLAIMED rows that have no photo yet ----
// Guard on claimed_by (never touch a claimed/paid business's curated photo) rather
// than on tier — so high-tier civic/marquee venues (SoFi, Kia Forum, Intuit Dome,
// landmarks, parks) that were seeded as featured still get their real Google photos.
async function backfill(limit: number) {
  // How many still need enriching (unclaimed + no hero photo + has a google id)?
  const { count } = await admin.from("di_businesses")
    .select("id", { count: "exact", head: true })
    .is("claimed_by", null).is("photo_url", null).not("google_place_id", "is", null);

  const { data: rows } = await admin.from("di_businesses")
    .select("id, google_place_id, tier, photo_url, photos, website, phone, hours, booking_url")
    .is("claimed_by", null).is("photo_url", null).not("google_place_id", "is", null)
    .limit(limit);

  let enriched = 0;
  for (const row of (rows || [])) {
    const d = await details(row.google_place_id);
    const photos = d.photoRefs.length ? await fetchPhotos(row.google_place_id, d.photoRefs) : [];
    const patch = fillPatch(row, d, photos) || {};
    // If Google had no photo for this place, stamp photo_url = "" so the row is
    // marked as "tried" and won't be picked up again (the app shows its tile).
    if (!photos.length && !patch.photo_url) patch.photo_url = "";
    const { error } = await admin.from("di_businesses").update(patch).eq("id", row.id);
    if (!error) enriched++;
  }
  const remaining = Math.max(0, (count || 0) - enriched);
  return { mode: "backfill", enriched, remaining };
}

// ---- mode=import : find NEW places around Inglewood and insert them enriched ----
async function importNew() {
  const have = new Set<string>();
  const { data: existing } = await admin.from("di_businesses").select("google_place_id");
  (existing || []).forEach((r: any) => r.google_place_id && have.add(r.google_place_id));

  const byId = new Map<string, any>();
  for (const [type, category, keyword] of SWEEPS) {
    for (const p of await nearby(type, keyword)) {
      const pid = p.place_id;
      if (!pid || have.has(pid) || byId.has(pid)) continue;
      if (p.business_status && p.business_status !== "OPERATIONAL") continue;
      byId.set(pid, { p, category });
    }
  }

  const places = Array.from(byId.values());
  let added = 0;
  for (const { p, category } of places) {
    const pid = p.place_id;
    const d = await details(pid);
    const photos = d.photoRefs.length ? await fetchPhotos(pid, d.photoRefs) : [];
    const row: any = {
      id: pid, google_place_id: pid, name: p.name, category, tags: [category],
      address: p.vicinity || p.formatted_address || "",
      rating: p.rating ?? null, rating_count: p.user_ratings_total ?? null,
      price_level: priceStr(p.price_level),
      phone: d.phone || "", website: d.website || null, hours: d.hours || null,
      photo_url: photos[0] || null, photos: photos.length ? photos : null,
      ...detectBooking(d.website),   // auto-plug an existing booking system if found
      tier: 1, approved: true, is_active: true, is_large: false,
    };
    const { error } = await admin.from("di_businesses").upsert(row, { onConflict: "id", ignoreDuplicates: true });
    if (!error) added++;
  }
  return { mode: "import", added, scanned: places.length, alreadyHad: have.size };
}

// CORS — so the Admin page (opened as a local file / on Netlify) can call this.
const CORS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  const JH = { ...CORS, "content-type": "application/json" };
  if (!KEY) return new Response("GOOGLE_PLACES_API_KEY not set", { status: 200, headers: CORS });
  try {
    const url = new URL(req.url);
    const mode = url.searchParams.get("mode") || "import";
    const limit = Math.min(+(url.searchParams.get("limit") || BACKFILL_BATCH) || BACKFILL_BATCH, 60);
    const result = mode === "backfill" ? await backfill(limit) : await importNew();
    return new Response(JSON.stringify(result), { status: 200, headers: JH });
  } catch (e) {
    return new Response("error: " + (e as Error).message, { status: 500, headers: CORS });
  }
});
