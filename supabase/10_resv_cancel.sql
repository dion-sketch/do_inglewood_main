-- =====================================================================
-- DO INGLEWOOD — let a customer cancel their OWN reservation
-- Run in Supabase → SQL Editor → New query → Run.
-- The requester may update their own row, but ONLY to status 'cancelled'
-- (they can't self-confirm). Owner accept/decline is unchanged.
-- =====================================================================

drop policy if exists di_resv_requester_cancel on di_reservations;
create policy di_resv_requester_cancel on di_reservations for update
  using  (user_id = auth.uid())
  with check (user_id = auth.uid() and status = 'cancelled');
