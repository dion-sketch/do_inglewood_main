// Do Inglewood — game-day push alerts.
//
// Runs every 15 minutes (pg_cron → 28_push_schedule.sql). For each show today at
// SoFi / Kia Forum / Intuit Dome / YouTube Theater it sends, only to people who
// saved that event and turned alerts on:
//   • "pregame"     — ~3–4 hrs before doors (doors ≈ 1 hr before the listed start),
//                     leading with Show Your Ticket deals near the venue.
//   • "after_hours" — around when the show likely ends (start + ~3.5 hrs).
// di_push_log's primary key (subscription, event, kind) makes a second send of the
// same alert impossible, so nobody gets more than 2 pushes per event.
//
// Deploy: Supabase → Edge Functions → "send-event-pushes" → paste → Deploy,
//         with "Verify JWT" OFF (it checks its own PUSH_CRON_SECRET instead).
// Secrets: VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY, VAPID_SUBJECT (mailto:you@…),
//          PUSH_CRON_SECRET, APP_URL (your Netlify URL).
//          SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are provided automatically.
// Test without sending anything: POST …/send-event-pushes?dry=1 (same secret header).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import webpush from "npm:web-push@3.6.7";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const VAPID_PUBLIC  = Deno.env.get("VAPID_PUBLIC_KEY") || "";
const VAPID_PRIVATE = Deno.env.get("VAPID_PRIVATE_KEY") || "";
const VAPID_SUBJECT = Deno.env.get("VAPID_SUBJECT") || "";
const CRON_SECRET   = Deno.env.get("PUSH_CRON_SECRET") || "";
const APP_URL       = (Deno.env.get("APP_URL") || "").replace(/\/?$/, "/");

const admin = createClient(SUPABASE_URL, SERVICE_KEY);

// Send windows in minutes relative to the listed start time. Each is an hour wide
// so a 15-minute schedule always lands inside it, even if one run is missed.
const WINDOWS = {
  pregame:     { from: -300, to: -240 },  // 5–4 hrs before start ≈ 4–3 hrs before doors
  after_hours: { from: 195,  to: 255 },   // ~start + 3.5 hrs, give or take 30 min
} as const;
type Kind = keyof typeof WINDOWS;

function kindFor(startsAt: string, now: number): Kind | null {
  const mins = (now - new Date(startsAt).getTime()) / 60000;
  for (const k of Object.keys(WINDOWS) as Kind[]) {
    if (mins >= WINDOWS[k].from && mins < WINDOWS[k].to) return k;
  }
  return null;
}

async function showTicketDealCount(venueId: string): Promise<number> {
  const today = new Date().toLocaleDateString("en-CA", { timeZone: "America/Los_Angeles" }); // YYYY-MM-DD
  const { data } = await admin.from("di_deals").select("id, venue_id, starts_on, ends_on")
    .eq("deal_type", "show_ticket").eq("is_active", true);
  return (data || []).filter((d: any) =>
    (!d.venue_id || d.venue_id === venueId) &&
    (!d.starts_on || d.starts_on <= today) && (!d.ends_on || d.ends_on >= today)).length;
}

async function message(ev: any, kind: Kind) {
  if (kind === "pregame") {
    const n = await showTicketDealCount(ev.venue_id);
    return {
      title: `Tonight: ${ev.title} 🎟️`,
      body: n
        ? `${n} spot${n === 1 ? "" : "s"} near ${ev.venue} have Show Your Ticket deals. Plan your pregame.`
        : `Pregame spots near ${ev.venue} — plan your night and skip the lines.`,
      url: `${APP_URL}?event=${encodeURIComponent(ev.id)}`,
      tag: `pre-${ev.id}`,
    };
  }
  return {
    title: `${ev.title} is letting out 🌙`,
    body: `After Hours near ${ev.venue}: lounges, late-night eats and the casino.`,
    url: `${APP_URL}?mode=after`,
    tag: `after-${ev.id}`,
  };
}

async function run(dry: boolean) {
  const now = Date.now();
  const lo = new Date(now - 5 * 3600e3).toISOString(), hi = new Date(now + 5 * 3600e3).toISOString();
  const { data: events, error } = await admin.from("di_events")
    .select("id, title, venue, venue_id, starts_at")
    .eq("status", "live").not("venue_id", "is", null).not("starts_at", "is", null)
    .gte("starts_at", lo).lte("starts_at", hi);
  if (error) throw error;

  const report: any[] = [];
  for (const ev of events || []) {
    const kind = kindFor(ev.starts_at, now);
    if (!kind) continue;
    const { data: subs } = await admin.from("di_push_subscriptions")
      .select("id, subscription").eq("opted_in", true).contains("event_ids", [ev.id]);
    const msg = await message(ev, kind);
    let sent = 0, skipped = 0, expired = 0, failed = 0;
    for (const s of subs || []) {
      if (dry) { sent++; continue; }
      // Claim this (person, event, kind) first — a duplicate key means it was already sent.
      const { error: dup } = await admin.from("di_push_log").insert({ subscription_id: s.id, event_id: ev.id, kind });
      if (dup) { skipped++; continue; }
      try {
        await webpush.sendNotification(s.subscription, JSON.stringify(msg), { TTL: 3 * 3600 });
        sent++;
      } catch (e: any) {
        if (e?.statusCode === 404 || e?.statusCode === 410) {   // phone unsubscribed / expired
          expired++;
          await admin.from("di_push_subscriptions").update({ opted_in: false }).eq("id", s.id);
        } else {
          failed++;   // let the next run retry inside the window
          await admin.from("di_push_log").delete().match({ subscription_id: s.id, event_id: ev.id, kind });
        }
      }
    }
    report.push({ event: ev.id, title: ev.title, kind, subscribers: (subs || []).length, sent, skipped, expired, failed, message: msg });
  }
  return { dry, at: new Date(now).toISOString(), report };
}

Deno.serve(async (req) => {
  const JH = { "content-type": "application/json" };
  if (!CRON_SECRET || req.headers.get("x-cron-secret") !== CRON_SECRET) {
    return new Response(JSON.stringify({ error: "unauthorized" }), { status: 401, headers: JH });
  }
  if (!VAPID_PUBLIC || !VAPID_PRIVATE || !VAPID_SUBJECT || !APP_URL) {
    return new Response(JSON.stringify({ error: "VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY, VAPID_SUBJECT and APP_URL must be set" }), { status: 500, headers: JH });
  }
  webpush.setVapidDetails(VAPID_SUBJECT, VAPID_PUBLIC, VAPID_PRIVATE);
  try {
    const dry = new URL(req.url).searchParams.get("dry") === "1";
    return new Response(JSON.stringify(await run(dry)), { status: 200, headers: JH });
  } catch (e) {
    return new Response(JSON.stringify({ error: (e as Error).message }), { status: 500, headers: JH });
  }
});
