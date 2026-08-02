-- ============================================================================
-- Step 3 / lifecycle Move 1 — canonical status vocabulary, enforced
-- ============================================================================
-- Applied 2026-07-31. Verification at the bottom, per the P0-1 discipline.
--
-- WHY
-- Actions were closed as `status: 'completed'` on one code path
-- (markActionComplete, app.jsx ~1446) and `status: 'closed'` on every other —
-- and several views filter on `status === 'closed'`, so a 'completed' row was
-- silently missed. There was even a `.neq('status','complete')` filter (a third
-- spelling) that matched nothing. The app-side writer and filter are fixed in
-- the same PR (to 'closed'); these CHECK constraints make any future wrong
-- spelling fail loudly at the database instead of drifting silently.
--
-- SAFE AGAINST EXISTING DATA (verified before applying): actions are all
-- open/closed, flags open/acknowledged, queries open/resolved. Zero rows are
-- rejected. The one divergent writer is corrected in app.jsx in this same batch,
-- so no live path can hit the constraint after deploy.
--
-- Overdue / in-query / escalated / slipped are render-time OVERLAYS, never
-- stored statuses (the lifecycle contract) — so they are deliberately NOT in
-- these value sets. Key dates use a boolean `completed`, not a status column,
-- so they need no constraint here.
-- ============================================================================

alter table public.actions          drop constraint if exists actions_status_ck;
alter table public.actions          add  constraint actions_status_ck
  check (status in ('open','closed'));

alter table public.meeting_handoffs  drop constraint if exists meeting_handoffs_status_ck;
alter table public.meeting_handoffs  add  constraint meeting_handoffs_status_ck
  check (status in ('open','acknowledged','converted'));

alter table public.queries           drop constraint if exists queries_status_ck;
alter table public.queries           add  constraint queries_status_ck
  check (status in ('open','resolved'));

-- ============================================================================
-- VERIFICATION — 2026-07-31, self-aborting DO block, rolled back.
--   action closed ok=1 | action completed=blocked(check)
--   flag ackd=blocked(check) | flag converted ok=1
--   query escalated=blocked(check) | query resolved ok=1
-- Canonical words write; every off-vocabulary spelling fails at the DB.
-- app.jsx writer (markActionComplete ~1446: 'completed' → 'closed') and the
-- cause-picker filter (~7239: .neq('complete') → .neq('closed')) fixed in the
-- same batch, so no live path can hit these constraints after deploy.
-- ============================================================================
