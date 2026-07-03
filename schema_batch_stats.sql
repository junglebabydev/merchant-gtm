-- Historical per-batch email stats (aggregate numbers from Resend dashboard).
-- Used for KPI metrics on the outreach dashboard.
-- email_events (webhook) feeds per-merchant engagement; this table feeds the headline numbers.

CREATE TABLE IF NOT EXISTS public.email_batch_stats (
  id           serial      primary key,
  stage        text        not null,       -- 'day_0', 'day_3', 'day_7', 'day_10', 'day_12'
  sent_at      date        not null,
  sent_count   integer     not null default 0,
  delivered    integer     not null default 0,
  opened       integer     not null default 0,
  clicked      integer     not null default 0,
  notes        text,
  created_at   timestamptz          default now()
);

ALTER TABLE public.email_batch_stats ENABLE ROW LEVEL SECURITY;
CREATE POLICY "anon_select" ON public.email_batch_stats
  FOR SELECT TO anon USING (true);

-- Example: fill in numbers you read from Resend → Emails dashboard.
-- INSERT INTO public.email_batch_stats (stage, sent_at, sent_count, delivered, opened, clicked)
-- VALUES
--   ('day_0', '2026-06-XX', 69, XX, XX, XX),
--   ('day_3', '2026-06-XX', XX, XX, XX, XX);
