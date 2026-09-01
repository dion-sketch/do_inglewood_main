// Do Inglewood — reservation notifier
// Fires from a Supabase Database Webhook on INSERT into di_reservations.
// Emails the business owner a link to their dashboard to Accept/Decline.
//
// Deploy: Supabase Dashboard → Edge Functions → create "notify-reservation",
// paste this, Deploy. Then set the secrets (RESEND_API_KEY, NOTIFY_FROM, APP_URL)
// and create a Database Webhook (see README_notify.md).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const RESEND_KEY   = Deno.env.get("RESEND_API_KEY") || "";
// Until you verify your own domain in Resend, use their test sender:
const FROM    = Deno.env.get("NOTIFY_FROM") || "Do Inglewood <onboarding@resend.dev>";
const APP_URL = Deno.env.get("APP_URL")     || "https://elegant-centaur-570653.netlify.app";

const admin = createClient(SUPABASE_URL, SERVICE_KEY);

function esc(s: unknown): string {
  return String(s ?? "").replace(/[&<>"]/g, (c) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c] as string));
}

Deno.serve(async (req) => {
  try {
    const body = await req.json();
    // Supabase DB webhook payload shape: { type, table, record, old_record }
    if (body?.type !== "INSERT" || body?.table !== "di_reservations") {
      return new Response("ignored", { status: 200 });
    }
    const r = body.record ?? {};

    // Find the business + its owner's alert email.
    const { data: biz } = await admin
      .from("di_businesses")
      .select("name, claimed_by, notify_email")
      .eq("id", r.business_id)
      .maybeSingle();

    let to: string | null = biz?.notify_email || null;
    if (!to && biz?.claimed_by) {
      const { data: u } = await admin.auth.admin.getUserById(biz.claimed_by);
      to = u?.user?.email ?? null;
    }
    if (!to) return new Response("no owner email on file", { status: 200 });
    if (!RESEND_KEY) return new Response("RESEND_API_KEY not set", { status: 200 });

    const subject = `New reservation request — ${biz?.name || "your business"}`;
    const html = `
      <div style="font-family:Arial,Helvetica,sans-serif;max-width:520px">
        <h2 style="margin:0 0 6px">New table request 🎉</h2>
        <p style="font-size:16px;margin:0 0 2px"><b>${esc(r.customer_name || "Guest")}</b> · ${esc(r.party_size ?? "?")} people</p>
        <p style="color:#555;margin:0 0 2px">${esc(r.resv_date || "")} ${esc(r.resv_time || "")}</p>
        <p style="color:#555;margin:0 0 16px">Phone: ${esc(r.customer_phone || "")}</p>
        <a href="${esc(APP_URL)}" style="display:inline-block;background:#ff2e7e;color:#fff;
           text-decoration:none;font-weight:700;padding:12px 20px;border-radius:999px">
           Open my dashboard to Accept or Decline →</a>
        <p style="color:#999;font-size:12px;margin-top:20px">Do Inglewood · California's Entertainment City</p>
      </div>`;

    const resp = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${RESEND_KEY}`, "Content-Type": "application/json" },
      body: JSON.stringify({ from: FROM, to, subject, html }),
    });
    return new Response(await resp.text(), { status: resp.ok ? 200 : 502 });
  } catch (e) {
    return new Response("error: " + (e as Error).message, { status: 500 });
  }
});
