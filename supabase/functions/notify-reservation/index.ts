// Do Inglewood — reservation notifier
// Fires from a Supabase Database Webhook on di_reservations.
//  - INSERT  -> email the business OWNER (a new request came in)
//  - UPDATE  -> email the CUSTOMER when the owner confirms/declines
//
// Deploy: Supabase Dashboard → Edge Functions → "notify-reservation" → paste → Deploy.
// Secrets: RESEND_API_KEY, NOTIFY_FROM, APP_URL. Webhook: fire on INSERT and UPDATE.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const RESEND_KEY   = Deno.env.get("RESEND_API_KEY") || "";
const FROM    = Deno.env.get("NOTIFY_FROM") || "Do Inglewood <onboarding@resend.dev>";
const APP_URL = Deno.env.get("APP_URL")     || "https://elegant-centaur-570653.netlify.app";

const admin = createClient(SUPABASE_URL, SERVICE_KEY);

function esc(s: unknown): string {
  return String(s ?? "").replace(/[&<>"]/g, (c) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c] as string));
}
async function sendEmail(to: string, subject: string, html: string) {
  if (!RESEND_KEY) return new Response("RESEND_API_KEY not set", { status: 200 });
  const resp = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: `Bearer ${RESEND_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({ from: FROM, to, subject, html }),
  });
  return new Response(await resp.text(), { status: resp.ok ? 200 : 502 });
}

Deno.serve(async (req) => {
  try {
    const body = await req.json();
    if (body?.table !== "di_reservations") return new Response("ignored", { status: 200 });
    const r = body.record ?? {};

    // ----- NEW REQUEST -> notify the OWNER -----
    if (body.type === "INSERT") {
      const { data: biz } = await admin
        .from("di_businesses").select("name, claimed_by, notify_email")
        .eq("id", r.business_id).maybeSingle();
      let to: string | null = biz?.notify_email || null;
      if (!to && biz?.claimed_by) {
        const { data: u } = await admin.auth.admin.getUserById(biz.claimed_by);
        to = u?.user?.email ?? null;
      }
      if (!to) return new Response("no owner email on file", { status: 200 });
      const html = `
        <div style="font-family:Arial,Helvetica,sans-serif;max-width:520px">
          <h2 style="margin:0 0 6px">New table request 🎉</h2>
          <p style="font-size:16px;margin:0 0 2px"><b>${esc(r.customer_name || "Guest")}</b> · ${esc(r.party_size ?? "?")} people</p>
          <p style="color:#555;margin:0 0 2px">${esc(r.resv_date || "")} ${esc(r.resv_time || "")}</p>
          <p style="color:#555;margin:0 0 16px">Phone: ${esc(r.customer_phone || "")}</p>
          <a href="${esc(APP_URL)}" style="display:inline-block;background:#ff2e7e;color:#fff;text-decoration:none;font-weight:700;padding:12px 20px;border-radius:999px">Open my dashboard to Accept or Decline →</a>
        </div>`;
      return await sendEmail(to, `New reservation request — ${biz?.name || "your business"}`, html);
    }

    // ----- OWNER CONFIRMED / DECLINED -> notify the CUSTOMER -----
    if (body.type === "UPDATE") {
      const st = r.status;
      if ((st === "confirmed" || st === "declined") && r.customer_email) {
        const { data: biz } = await admin
          .from("di_businesses").select("name").eq("id", r.business_id).maybeSingle();
        const bn = biz?.name || "the restaurant";
        const when = `${esc(r.resv_date || "")} ${esc(r.resv_time || "")} · ${esc(r.party_size ?? "?")} people`;
        const html = st === "confirmed"
          ? `<div style="font-family:Arial,Helvetica,sans-serif;max-width:520px">
               <h2 style="margin:0 0 6px">You're booked! ✅</h2>
               <p style="font-size:16px"><b>${esc(bn)}</b> confirmed your table.</p>
               <p style="color:#555">${when}</p>
               <a href="${esc(APP_URL)}" style="display:inline-block;background:#ff2e7e;color:#fff;text-decoration:none;font-weight:700;padding:12px 20px;border-radius:999px">See it in Do Inglewood →</a>
             </div>`
          : `<div style="font-family:Arial,Helvetica,sans-serif;max-width:520px">
               <h2 style="margin:0 0 6px">Reservation update</h2>
               <p><b>${esc(bn)}</b> couldn't confirm that time. Open Do Inglewood to try another time.</p>
               <a href="${esc(APP_URL)}" style="display:inline-block;background:#ff2e7e;color:#fff;text-decoration:none;font-weight:700;padding:12px 20px;border-radius:999px">Try another time →</a>
             </div>`;
        return await sendEmail(r.customer_email, st === "confirmed" ? `Reservation confirmed — ${bn}` : `Reservation update — ${bn}`, html);
      }
      return new Response("no customer email / not a confirm-decline", { status: 200 });
    }

    return new Response("ignored", { status: 200 });
  } catch (e) {
    return new Response("error: " + (e as Error).message, { status: 500 });
  }
});
