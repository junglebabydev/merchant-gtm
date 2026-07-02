// Supabase Edge Function: resend-webhook
// Receives Resend webhook events and writes them to public.email_events.
//
// Deploy (CLI):   supabase functions deploy resend-webhook --no-verify-jwt
// Only ONE secret to set yourself:
//   RESEND_WEBHOOK_SECRET   = the "Signing Secret" Resend shows when you create the webhook (starts with "whsec_")
//
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are injected automatically by Supabase into every
// Edge Function — they always reflect the current keys, so rotating service_role won't break this.
//
// --no-verify-jwt is required because Resend calls this with a Svix signature, not a Supabase JWT.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { Webhook } from "https://esm.sh/svix@1.24.0";

const WEBHOOK_SECRET = Deno.env.get("RESEND_WEBHOOK_SECRET")!;
const SB_URL = Deno.env.get("SUPABASE_URL")!;
const SB_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const supabase = createClient(SB_URL, SB_SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("method not allowed", { status: 405 });

  const payload = await req.text();
  const headers = {
    "svix-id": req.headers.get("svix-id") ?? "",
    "svix-timestamp": req.headers.get("svix-timestamp") ?? "",
    "svix-signature": req.headers.get("svix-signature") ?? "",
  };

  // Verify the signature — rejects anything not actually from Resend.
  let evt: any;
  try {
    evt = new Webhook(WEBHOOK_SECRET).verify(payload, headers);
  } catch (_e) {
    return new Response("invalid signature", { status: 401 });
  }

  const type = evt?.type as string; // e.g. "email.opened"
  const data = evt?.data ?? {};
  const to = Array.isArray(data.to) ? data.to[0] : data.to;

  const row = {
    resend_email_id: data.email_id ?? data.id ?? null,
    event_type: type,
    recipient: to ?? null,
    subject: data.subject ?? null,
    clicked_url: data?.click?.link ?? null,
    occurred_at: evt?.created_at ?? data?.created_at ?? new Date().toISOString(),
    raw: evt,
  };

  // Idempotent insert — ignore duplicates from webhook retries.
  const { error } = await supabase
    .from("email_events")
    .upsert(row, { onConflict: "resend_email_id,event_type,occurred_at", ignoreDuplicates: true });

  if (error) {
    console.error("insert failed", error, row);
    return new Response("db error", { status: 500 });
  }

  return new Response("ok", { status: 200 });
});
