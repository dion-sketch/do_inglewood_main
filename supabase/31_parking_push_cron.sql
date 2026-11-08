-- =====================================================================
-- DO INGLEWOOD — run the parking "follow a lot" push sender every 3 minutes
--
-- Run AFTER the send-parking-pushes Edge Function is deployed and its
-- secrets are set (it reuses the SAME secrets as send-event-pushes —
-- see supabase/functions/README_push.md and 28_push_schedule.sql).
--
-- Parking fills up fast, so this runs more often than the 15-minute event
-- sender — a follower should hear "going fast / gone" within a couple of
-- minutes of the owner flipping the lot, while they're still en route.
--
-- The cron secret is the SAME one 28_push_schedule.sql stored in Vault
-- (push_cron_secret). If you already ran that file, it's there. Safe to re-run.
-- =====================================================================

create extension if not exists pg_cron;
create extension if not exists pg_net;

select cron.unschedule('send-parking-pushes')
where exists (select 1 from cron.job where jobname = 'send-parking-pushes');

select cron.schedule(
  'send-parking-pushes',
  '*/3 * * * *',
  $$
  select net.http_post(
    url     := 'https://eojlkqxnwzoelwvrxgzc.supabase.co/functions/v1/send-parking-pushes',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'push_cron_secret')
    ),
    body    := '{}'::jsonb
  );
  $$
);

-- Housekeeping: keep only 14 days of parking push dedup rows.
select cron.unschedule('trim-parking-log')
where exists (select 1 from cron.job where jobname = 'trim-parking-log');
select cron.schedule(
  'trim-parking-log',
  '20 9 * * *',   -- daily, ~1 AM Pacific
  $$ delete from di_parking_push_log where day < (current_date - 14); $$
);

-- Check: select jobname, schedule, active from cron.job;
