-- =====================================================================
-- DO INGLEWOOD — run the game-day push sender every 15 minutes
--
-- Run AFTER the send-event-pushes Edge Function is deployed and its
-- secrets are set (see supabase/functions/README_push.md).
--
-- The cron secret is kept in Supabase Vault, not in this file or in the
-- cron job text. Before running this, store it ONCE in the SQL Editor
-- (use the same value as the function's PUSH_CRON_SECRET):
--   select vault.create_secret('<the same long random value>', 'push_cron_secret');
--
-- Safe to re-run (it replaces the job).
-- =====================================================================

create extension if not exists pg_cron;
create extension if not exists pg_net;

select cron.unschedule('send-event-pushes')
where exists (select 1 from cron.job where jobname = 'send-event-pushes');

select cron.schedule(
  'send-event-pushes',
  '*/15 * * * *',
  $$
  select net.http_post(
    url     := 'https://eojlkqxnwzoelwvrxgzc.supabase.co/functions/v1/send-event-pushes',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'push_cron_secret')
    ),
    body    := '{}'::jsonb
  );
  $$
);

-- Optional housekeeping: keep only 30 days of anonymous activity.
select cron.unschedule('trim-activity')
where exists (select 1 from cron.job where jobname = 'trim-activity');
select cron.schedule(
  'trim-activity',
  '15 9 * * *',   -- daily, ~2 AM Pacific
  $$ delete from di_activity_events where created_at < now() - interval '30 days'; $$
);

-- Check: select jobname, schedule, active from cron.job;
-- Recent runs: select * from cron.job_run_details order by start_time desc limit 10;
