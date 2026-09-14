// Do Inglewood — reservation emails (via Resend).
//
// Closes the booking loop for people who've left the app: emails the CUSTOMER when
// their request is sent / confirmed / declined, and emails the BUSINESS OWNER when a
// new request comes in. Best-effort — never blocks a booking.
//
// Deploy: Supabase → Edge Functions → "reservation-email" → paste → Deploy →
//   turn Verify JWT OFF (it's called with the anon key from the app, and it only
//   ever emails addresses already stored on the reservation — it can't be used to
//   spam arbitrary inboxes).
// Secrets:  RESEND_API_KEY = your Resend key.
//           RESEND_FROM    = "Do Inglewood <noreply@yourverifieddomain.com>"
//             (defaults to Resend's test sender, which only reaches your own inbox).
//   (SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are provided automatically.)
//
// Call it two ways (both supported):
//   • From the app:  POST { reservation_id, event }  event = requested|confirmed|declined
//   • Supabase DB webhook on di_reservations (insert+update): sends { type, record }.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const RESEND_KEY = Deno.env.get("RESEND_API_KEY") || "";
const FROM = Deno.env.get("RESEND_FROM") || "Do Inglewood <onboarding@resend.dev>";
const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

const esc = (s: unknown) => String(s ?? "").replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]!));

async function sendEmail(to: string, subject: string, html: string) {
  if (!RESEND_KEY || !to) return false;
  const r = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: `Bearer ${RESEND_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({ from: FROM, to, subject, html }),
  });
  return r.ok;
}

function shell(title: string, body: string) {
  return `<div style="font-family:-apple-system,Segoe UI,Arial,sans-serif;max-width:480px;margin:0 auto;padding:24px;color:#1c1720">
    <div style="font-weight:800;font-size:20px;letter-spacing:-.02em">Do <span style="color:#e01f6f">Inglewood</span></div>
    <h1 style="font-size:22px;margin:18px 0 6px">${title}</h1>${body}
    <p style="font-size:12px;color:#8b8490;margin-top:24px">California's Entertainment City · Eat. Play. Stay.</p>
  </div>`;
}
const line = (k: string, v: unknown) => v ? `<tr><td style="color:#8b8490;padding:3px 12px 3px 0">${k}</td><td style="font-weight:600">${esc(v)}</td></tr>` : "";

async function ownerEmail(claimedBy?: string): Promise<string | null> {
  if (!claimedBy) return null;
  try { const { data } = await admin.auth.admin.getUserById(claimedBy); return data?.user?.email || null; } catch { return null; }
}

const CORS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  try {
    const body = await req.json().catch(() => ({}));
    // Resolve the reservation + event from either call shape.
    let resv = body.record || null;
    let event: string = body.event || "";
    if (!resv && body.reservation_id) {
      const { data } = await admin.from("di_reservations").select("*").eq("id", body.reservation_id).maybeSingle();
      resv = data;
    }
    if (!resv) return new Response("no reservation", { status: 200 });
    if (!event) event = body.type === "INSERT" ? "requested" : (resv.status || "requested");

    const { data: biz } = await admin.from("di_businesses").select("name, claimed_by").eq("id", resv.business_id).maybeSingle();
    const bizName = biz?.name || "the business";
    const when = [resv.resv_date, resv.resv_time].filter(Boolean).join(" · ");
    const details = `<table style="font-size:14px;margin:10px 0 4px;border-collapse:collapse">
      ${line("Where", bizName)}${line("When", when)}${line("Party", resv.party_size)}${line("Name", resv.customer_name)}${line("Phone", resv.customer_phone)}${resv.note ? line("Note", resv.note) : ""}</table>`;

    if (event === "requested") {
      if (resv.customer_email)
        await sendEmail(resv.customer_email, `Request sent — ${bizName}`,
          shell("Your request is in 🎟️", `<p>We sent your request to <b>${esc(bizName)}</b>. They'll confirm shortly — we'll email you the moment they do.</p>${details}`));
      const oe = await ownerEmail(biz?.claimed_by);
      if (oe)
        await sendEmail(oe, `New booking request — ${bizName}`,
          shell("New booking request 📩", `<p>A customer requested a spot. Open <b>Do Inglewood → My Business</b> to accept or decline.</p>${details}`));
    } else if (event === "confirmed") {
      if (resv.customer_email)
        await sendEmail(resv.customer_email, `Confirmed ✓ — ${bizName}`,
          shell("You're confirmed ✅", `<p><b>${esc(bizName)}</b> confirmed your spot. See you there!</p>${details}`));
    } else if (event === "declined" || event === "cancelled") {
      if (resv.customer_email)
        await sendEmail(resv.customer_email, `Update on your request — ${bizName}`,
          shell("About your request", `<p><b>${esc(bizName)}</b> couldn't take this ${event === "cancelled" ? "reservation" : "time"}. Try another time, or find another great spot on Do Inglewood.</p>${details}`));
    }
    return new Response(JSON.stringify({ ok: true, event }), { status: 200, headers: { "content-type": "application/json" } });
  } catch (e) {
    return new Response("error: " + (e as Error).message, { status: 200 }); // 200 so a caller never blocks
  }
});
