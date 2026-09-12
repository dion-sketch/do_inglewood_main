// Do Inglewood — bulk import Inglewood-area businesses from Google Places.
//
// Sweeps several place types around Inglewood and inserts NEW businesses into
// di_businesses. It is ADDITIVE and SAFE: existing rows (including claimed /
// paid / edited ones) are never touched — new places are skipped if their
// google place_id is already present.
//
// Deploy: Supabase Dashboard → Edge Functions → "import-businesses" → paste → Deploy.
// Secret: GOOGLE_PLACES_API_KEY = your key with "Places API" enabled.
// Run it on demand:  POST .../functions/v1/import-businesses  (Bearer = your
//   service_role key)  — or from the Admin page with a button (ask me to add one).
//
// Notes: photos are left blank on import (the app shows a branded category tile);
// owners add real photos when they claim. Phone/website need Place Details calls,
// which this keeps optional to stay within quota — flip DETAILS=true to fetch them.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const KEY   = Deno.env.get("GOOGLE_PLACES_API_KEY") || "";
const SB_URL = Deno.env.get("SUPABASE_URL")!;
const SB_SVC = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const admin = createClient(SB_URL, SB_SVC);

// Inglewood center + ~4km radius covers SoFi / Intuit Dome / Kia Forum & the city.
const LAT = 33.9617, LNG = -118.3531, RADIUS = 4500;
const DETAILS = false; // set true to also pull phone + website (uses extra quota)

// Google place type -> our category.
const SWEEPS: [string, string][] = [
  ["restaurant", "Restaurant"], ["meal_takeaway", "Restaurant"],
  ["bar", "Lounge"], ["night_club", "Lounge"],
  ["cafe", "Coffee"], ["bakery", "Dessert"],
  ["lodging", "Hotels"], ["casino", "Casino"],
];

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));
const priceStr = (n: number | undefined) => (n && n > 0 ? "$".repeat(Math.min(n, 4)) : "$$");

async function nearby(type: string): Promise<any[]> {
  let out: any[] = [], token = "";
  for (let page = 0; page < 3; page++) { // up to 60 results per type
    let url = `https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=${LAT},${LNG}&radius=${RADIUS}&type=${type}&key=${KEY}`;
    if (token) url += `&pagetoken=${token}`;
    const r = await fetch(url);
    const j = await r.json();
    if (j.results) out = out.concat(j.results);
    if (!j.next_page_token) break;
    token = j.next_page_token;
    await sleep(2100); // Google requires a short delay before the page token is valid
  }
  return out;
}

async function details(placeId: string): Promise<{ phone?: string; website?: string }> {
  try {
    const url = `https://maps.googleapis.com/maps/api/place/details/json?place_id=${placeId}&fields=formatted_phone_number,website&key=${KEY}`;
    const j = await (await fetch(url)).json();
    return { phone: j.result?.formatted_phone_number, website: j.result?.website };
  } catch { return {}; }
}

Deno.serve(async () => {
  if (!KEY) return new Response("GOOGLE_PLACES_API_KEY not set", { status: 200 });
  try {
    // Which place_ids do we already have? (so we never overwrite existing rows)
    const have = new Set<string>();
    const { data: existing } = await admin.from("di_businesses").select("google_place_id");
    (existing || []).forEach((r: any) => r.google_place_id && have.add(r.google_place_id));

    const byId = new Map<string, any>();
    for (const [type, category] of SWEEPS) {
      const results = await nearby(type);
      for (const p of results) {
        const pid = p.place_id;
        if (!pid || have.has(pid) || byId.has(pid)) continue;
        if (p.business_status && p.business_status !== "OPERATIONAL") continue;
        let phone = "", website = "";
        if (DETAILS) { const d = await details(pid); phone = d.phone || ""; website = d.website || ""; }
        byId.set(pid, {
          id: pid,                     // dedupe key = the Google place id
          google_place_id: pid,
          name: p.name,
          category,
          tags: [category],
          address: p.vicinity || p.formatted_address || "",
          rating: p.rating ?? null,
          rating_count: p.user_ratings_total ?? null,
          price_level: priceStr(p.price_level),
          phone, website,
          tier: 1, approved: true, is_active: true, is_large: false,
        });
      }
    }

    const rows = Array.from(byId.values());
    if (!rows.length) return new Response("no new businesses found", { status: 200 });

    // ignoreDuplicates: never clobber an existing row (claimed / paid / edited).
    let added = 0;
    for (let i = 0; i < rows.length; i += 200) {
      const chunk = rows.slice(i, i + 200);
      const { error } = await admin.from("di_businesses").upsert(chunk, { onConflict: "id", ignoreDuplicates: true });
      if (!error) added += chunk.length;
    }
    return new Response(`imported ${added} new Inglewood-area businesses (${have.size} already present)`, { status: 200 });
  } catch (e) {
    return new Response("error: " + (e as Error).message, { status: 500 });
  }
});
