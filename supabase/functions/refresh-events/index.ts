// Do Inglewood — automatic events feed
// Pulls upcoming events at the Inglewood venues from the Ticketmaster Discovery
// API and upserts them into di_events, so the calendar fills itself.
//
// Deploy: Supabase Dashboard → Edge Functions → "refresh-events" → paste → Deploy.
// Secret needed: TICKETMASTER_API_KEY (free at developer.ticketmaster.com).
// Trigger it: the "Refresh events" button in admin.html, and/or a daily schedule.
//
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided automatically.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const TM_KEY       = Deno.env.get("TICKETMASTER_API_KEY") || "";

// Inglewood entertainment district — pull everything within a few miles.
const LATLONG = "33.9576,-118.3392";   // ~SoFi / Hollywood Park
const RADIUS  = "4";
const UNIT    = "miles";

// Only keep events at the Inglewood venues (guards against nearby-LA drift).
const KEEP_VENUES = ["sofi", "intuit dome", "kia forum", "the forum", "youtube theater", "hollywood park"];

const admin = createClient(SUPABASE_URL, SERVICE_KEY);

// "20:00:00" -> "8:00 PM"
function fmtTime(t: string | undefined): string | null {
  if (!t) return null;
  const m = String(t).match(/^(\d{1,2}):(\d{2})/);
  if (!m) return null;
  let h = parseInt(m[1], 10);
  const min = m[2];
  const ampm = h >= 12 ? "PM" : "AM";
  h = h % 12; if (h === 0) h = 12;
  return `${h}:${min} ${ampm}`;
}

// Map a Ticketmaster classification to our category words.
function categoryOf(ev: any): string {
  const c = (ev.classifications && ev.classifications[0]) || {};
  const seg = (c.segment && c.segment.name || "").toLowerCase();
  const genre = (c.genre && c.genre.name || "").toLowerCase();
  if (seg === "sports") return "Sports";
  if (seg === "music") return "Concert";
  if (seg.includes("arts")) return genre.includes("comedy") ? "Comedy" : "Community";
  if (seg === "film") return "Special";
  return genre.includes("comedy") ? "Comedy" : "Special";
}

function bestImage(ev: any): string | null {
  const imgs = ev.images || [];
  // prefer a wide 16:9 around 1024px
  const wide = imgs.filter((i: any) => i.ratio === "16_9").sort((a: any, b: any) => (b.width || 0) - (a.width || 0));
  return (wide[0] && wide[0].url) || (imgs[0] && imgs[0].url) || null;
}

async function fetchPage(page: number) {
  const url = new URL("https://app.ticketmaster.com/discovery/v2/events.json");
  url.searchParams.set("apikey", TM_KEY);
  url.searchParams.set("latlong", LATLONG);
  url.searchParams.set("radius", RADIUS);
  url.searchParams.set("unit", UNIT);
  url.searchParams.set("size", "100");
  url.searchParams.set("page", String(page));
  url.searchParams.set("sort", "date,asc");
  url.searchParams.set("startDateTime", new Date().toISOString().slice(0, 19) + "Z");
  const r = await fetch(url.toString());
  if (!r.ok) throw new Error("Ticketmaster " + r.status + ": " + (await r.text()).slice(0, 200));
  return await r.json();
}

Deno.serve(async () => {
  try {
    if (!TM_KEY) return new Response(JSON.stringify({ error: "TICKETMASTER_API_KEY not set" }), { status: 200, headers: { "Content-Type": "application/json" } });

    const rows: any[] = [];
    const seen = new Set<string>();
    for (let page = 0; page < 5; page++) {   // up to ~500 events
      const data = await fetchPage(page);
      const events = (data._embedded && data._embedded.events) || [];
      for (const ev of events) {
        const venue = (ev._embedded && ev._embedded.venues && ev._embedded.venues[0]) || {};
        const vname = String(venue.name || "");
        if (!KEEP_VENUES.some((k) => vname.toLowerCase().includes(k))) continue;
        const date = ev.dates && ev.dates.start && ev.dates.start.localDate;
        if (!date) continue;
        const id = "tm_" + ev.id;
        if (seen.has(id)) continue;
        seen.add(id);
        const price = (ev.priceRanges && ev.priceRanges[0] && ev.priceRanges[0].min) ?? null;
        rows.push({
          id,
          title: ev.name,
          venue: vname,
          category: categoryOf(ev),
          source: "ticketmaster",
          event_date: date,
          start_time: fmtTime(ev.dates.start.localTime),
          price_from: price,
          url: ev.url || null,
          image_url: bestImage(ev),
          status: "live",
        });
      }
      const totalPages = (data.page && data.page.totalPages) || 1;
      if (page + 1 >= totalPages) break;
    }

    if (rows.length) {
      const { error } = await admin.from("di_events").upsert(rows, { onConflict: "id" });
      if (error) throw error;
    }
    return new Response(JSON.stringify({ ok: true, imported: rows.length }), {
      status: 200, headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: (e as Error).message }), {
      status: 500, headers: { "Content-Type": "application/json" },
    });
  }
});
