-- =====================================================================
-- DO INGLEWOOD — Businesses can add themselves (approval-gated) + size class
-- Run in Supabase → SQL Editor → New query → Run.
--
-- WHY: A signed-in owner can submit a NEW business that isn't in the
-- directory yet. It is created HIDDEN (approved=false) and only appears
-- publicly once you approve it in the admin tool — that's how we assure
-- they're truly a business. `is_large` lets you price hotels & large
-- chains on the Enterprise plan; you set it when you approve them.
-- =====================================================================

-- New self-added businesses start hidden until you approve them.
alter table di_businesses add column if not exists approved boolean default true;
-- Enterprise pricing flag (hotels / large chains). You set this at approval.
alter table di_businesses add column if not exists is_large boolean default false;

-- Let a signed-in user submit a NEW business they own — but ONLY as a
-- pending (approved=false), free (tier 1), small (is_large=false) row.
-- They cannot self-approve, self-upgrade, or self-mark themselves large.
drop policy if exists di_businesses_self_add on di_businesses;
create policy di_businesses_self_add on di_businesses for insert to authenticated
  with check (
    claimed_by = auth.uid()
    and approved = false
    and coalesce(is_large,false) = false
    and coalesce(tier,1) = 1
  );
