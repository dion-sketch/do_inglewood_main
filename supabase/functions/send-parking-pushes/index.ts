// Do Inglewood — parking "follow a lot" alerts.
//
// Runs every few minutes (pg_cron → 31_parking_push_cron.sql). For every lot an
// owner has flipped TODAY to "Going fast" or "Full", it notifies only the people
// who FOLLOWED that lot and turned alerts on:
//   • "going" — "🅿️ Going fast — <lot>. Grab it before it's gone."
//   • "full"  — "🅿️ Gone for tonight — <lot>. Here are the closest lots still open."
// So someone driving in from out of town hears it fill BEFORE they get there.
//
// di_parking_push_log's primary key (subscription, lot, day, kind) makes a second
// send of the same alert impossible, so a follower gets at most one "going fast"
// and one "gone" per lot per day — and the same lot can alert again next event day.
//
// Deploy: Supabase → Edge Functions → "send-parking-pushes" → paste → Deploy,
//         with "Verify JWT" OFF (it checks its own PUSH_CRON_SECRET instead).
// Secrets: reuses the SAME ones as send-event-pushes —
//          VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY, VAPID_SUBJECT (mailto:you@…),
//          PUSH_CRON_SECRET, APP_URL (your Netlify URL).
//          SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are provided automatically.
// Test without sending: POST …/send-parking-pushes?dry=1 (same secret header).

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

const laToday = () => new Date().toLocaleDateString("en-CA", { timeZone: "America/Los_Angeles" }); // YYYY-MM-DD

function message(lot: any, kind: "going" | "full") {
  if (kind === "going") {
    return {
      title: `Going fast 🅿️ ${lot.name}`,
      body: `A lot you're following is filling up${lot.price ? ` (${lot.price})` : ""}. Grab it before it's gone.`,
      url: `${APP_URL}?park=${encodeURIComponent(lot.id)}`,
      tag: `park-going-${lot.id}`,
    };
  }
  return {
    title: `Gone for tonight 🅿️ ${lot.name}`,
    body: `This lot just filled up. Tap for the closest lots still open near the venue.`,
    url: `${APP_URL}?park=${encodeURIComponent(lot.id)}`,
    tag: `park-full-${lot.id}`,
  };
}

async function run(dry: boolean) {
  const today = laToday();
  // Lots an owner actively set TODAY to going/full, and that are live & available.
  const { data: lots, error } = await admin.from("di_parking")
    .select("id, name, price, status, status_date, approved, is_active, available")
    .in("status", ["going", "full"]).eq("status_date", today)
    .eq("approved", true).eq("is_active", true).eq("available", true);
  if (error) throw error;

  const report: any[] = [];
  for (const lot of lots || []) {
    const kind = lot.status as "going" | "full";
    const { data: subs } = await admin.from("di_push_subscriptions")
      .select("id, subscription").eq("opted_in", true).contains("parking_ids", [lot.id]);
    const msg = message(lot, kind);
    let sent = 0, skipped = 0, expired = 0, failed = 0;
    for (const s of subs || []) {
      if (dry) { sent++; continue; }
      // Claim (person, lot, day, kind) first — a duplicate key means it already went out.
      const { error: dup } = await admin.from("di_parking_push_log")
        .insert({ subscription_id: s.id, parking_id: lot.id, day: today, kind });
      if (dup) { skipped++; continue; }
      try {
        await webpush.sendNotification(s.subscription, JSON.stringify(msg), { TTL: 2 * 3600 });
        sent++;
      } catch (e: any) {
        if (e?.statusCode === 404 || e?.statusCode === 410) {   // phone unsubscribed / expired
          expired++;
          await admin.from("di_push_subscriptions").update({ opted_in: false }).eq("id", s.id);
        } else {
          failed++;   // let the next run retry
          await admin.from("di_parking_push_log").delete().match({ subscription_id: s.id, parking_id: lot.id, day: today, kind });
        }
      }
    }
    report.push({ lot: lot.id, name: lot.name, kind, followers: (subs || []).length, sent, skipped, expired, failed });
  }
  return { dry, at: new Date().toISOString(), day: today, report };
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
