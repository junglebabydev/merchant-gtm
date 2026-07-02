-- Merchant outreach dashboard — event capture table
-- Run this once in the Supabase SQL editor (Dashboard → SQL → New query → paste → Run).
-- Safe to re-run: uses IF NOT EXISTS / idempotent policy drops.

create table if not exists public.email_events (
  id              bigint generated always as identity primary key,
  resend_email_id text,
  event_type      text        not null,   -- email.sent | email.delivered | email.opened | email.clicked | email.bounced | email.complained | email.delivery_delayed
  recipient       text,                   -- the "to" address; joined to merchant_crm.email in the dashboard
  subject         text,
  clicked_url     text,                    -- populated for email.clicked
  occurred_at     timestamptz not null,   -- event time reported by Resend
  raw             jsonb,                   -- full webhook payload, for anything not columnized
  created_at      timestamptz not null default now()
);

create index if not exists email_events_recipient_idx  on public.email_events (lower(recipient));
create index if not exists email_events_type_idx        on public.email_events (event_type);
create index if not exists email_events_email_id_idx     on public.email_events (resend_email_id);
create index if not exists email_events_occurred_at_idx  on public.email_events (occurred_at desc);

-- De-dupe guard: Resend can retry a webhook. One row per (email_id, event_type, occurred_at).
create unique index if not exists email_events_dedupe_idx
  on public.email_events (resend_email_id, event_type, occurred_at);

-- RLS: the local dashboard reads with the anon key; only the Edge Function (service_role) writes.
alter table public.email_events enable row level security;

drop policy if exists "anon can read email_events" on public.email_events;
create policy "anon can read email_events"
  on public.email_events for select
  to anon
  using (true);

-- No insert/update/delete policy for anon → the anon key cannot write.
-- The Edge Function uses the service_role key, which bypasses RLS.
