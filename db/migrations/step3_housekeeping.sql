-- ============================================================================
-- Step 3 — housekeeping (DB parts)
-- ============================================================================
-- Applied 2026-07-31. Verification at the bottom.
--
-- 1. won → LTA. The app renders 'LTA' for the 'won' pipeline status from its
--    hardcoded STATUSES const (app.jsx ~245); org_statuses.label still read
--    'Won'. `org_statuses` is currently DEAD CONFIG — the app references it
--    nowhere (0 hits) — so this changes nothing observable today, but it keeps
--    the config table honest for the eventual org-configurable-statuses feature.
--    Zero functional risk.
--
-- DELIBERATELY NOT DONE HERE (with reasons):
-- - Dropping meeting_entries.flag (a genuinely dead column, no longer selected
--   by app.jsx as of this batch): DEFERRED to a post-deploy follow-up. Dropping
--   it now would break the CURRENTLY-DEPLOYED app, which still selects it, until
--   this PR merges and Pages redeploys. Safe order is: ship the select removal
--   (this batch) → deploy → then drop the column. Tracked in DEV_PLAN Step 3.
-- - org_meeting_types.group_field: same "dead shadow-config" situation as
--   org_statuses (the app uses its hardcoded MEETING_TYPES.groupField, reads the
--   DB column nowhere). Not dropped — retiring the shadow-config tables is a
--   go-live decision for Tom, not a one-liner. Recorded in DEV_PLAN.
-- ============================================================================

update public.org_statuses set label = 'LTA' where value = 'won';

-- VERIFICATION 2026-07-31: select value,label from org_statuses where value='won'
--   → { value: won, label: LTA }.  Applied to live DB.
