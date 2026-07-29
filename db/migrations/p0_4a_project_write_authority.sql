-- =============================================================================
-- P0-4a — write authority on the senior-owned records
-- Applied to tpxabhqsjngalilbznhz on 2026-07-29. Verification at the bottom.
-- =============================================================================
--
-- `members edit projects` was USING (org_id = current_org_id()) for UPDATE, so
-- ANY authenticated org member could update ANY project — status, name,
-- project_number, secured, and every team FK column.
--
-- ⚠ Correction to the plan, found while scoping this: P0-4 described these as
-- "enforced in JavaScript in a public single-page app". For the project name,
-- number and address inline fields on the Projects list, they were **not
-- enforced in JavaScript either** — `ProjectRow` uses `isSenior` exactly once,
-- to gate the status control. Any contributor could rename any project from
-- the Projects list, and it saved. So this was a live defect, not merely a
-- weak control.
--
-- `meetings` UPDATE had the same shape. Its only two write paths are close and
-- re-open, both chair actions, and a chair is necessarily a senior because
-- "seniors create meetings" is the only INSERT path — so senior-only UPDATE
-- costs nothing there.
--
-- SCOPE. This is P0-4a: WHO may write the project record. P0-4b — WHICH
-- projects a contributor may see and touch at all (the per-project visibility
-- join over key dates, contacts, flags and the checklist tables) — is the
-- Phase 6 piece, and still needs the `project_team` normalisation decision.
-- Those tables are deliberately untouched here: contributors legitimately
-- write flags, dates, directory rows and checklist answers, so the defect
-- there is missing project scoping, not missing role scoping.

drop policy if exists "members edit projects" on public.projects;
create policy "seniors edit projects" on public.projects for update
  using (
    org_id = current_org_id()
    and exists (select 1 from public.app_users
                 where app_users.id = auth.uid() and app_users.role = 'senior' and app_users.active)
  )
  with check (
    org_id = current_org_id()
    and exists (select 1 from public.app_users
                 where app_users.id = auth.uid() and app_users.role = 'senior' and app_users.active)
  );

drop policy if exists "members edit meetings" on public.meetings;
create policy "seniors edit meetings" on public.meetings for update
  using (
    org_id = current_org_id()
    and exists (select 1 from public.app_users
                 where app_users.id = auth.uid() and app_users.role = 'senior' and app_users.active)
  )
  with check (
    org_id = current_org_id()
    and exists (select 1 from public.app_users
                 where app_users.id = auth.uid() and app_users.role = 'senior' and app_users.active)
  );

-- =============================================================================
-- Verification recorded 2026-07-29
-- =============================================================================
--
-- Behavioural, under real JWTs for both roles, inside a self-aborting block
-- (`set local role authenticated` + `set_config('request.jwt.claims', …)`):
--
--   project = [Aldgate Point]
--   contributor rename ....... 0 row(s) updated      <- blocked
--   senior rename ............ 1 row(s) updated      <- still works
--
-- Rolled back; the project's name is unchanged.
--
-- ⚠ NOTE THE FAILURE MODE, which drove the app-side change in the same batch:
-- a policy-filtered UPDATE comes back from PostgREST as a SUCCESS WITH ZERO
-- ROWS, not as an error. `updateProjectField` / `updateProjectFields` only
-- threw on `error`, so a refused edit would have applied optimistically, shown
-- "saved", and silently reverted on the next reload. Both now `.select('id')`
-- and treat an empty result as a refusal: the optimistic edit is undone via
-- refreshProjects() and the user is told. `ProjectRow`'s name / number /
-- address inputs are also `readOnly` for non-seniors now, so contributors are
-- not shown editable boxes they cannot use.
--
-- STILL OPEN — P0-4b, the last P0 item:
--   * per-project visibility for contributors (read + write) on
--     project_key_dates, project_contacts, meeting_handoffs, project_checklists,
--     project_checklist_items, actions and meeting_entries;
--   * the `project_team` vs six-hardcoded-FKs decision, which determines what
--     that visibility join is written against;
--   * `actions` UPDATE/DELETE is still org-wide — narrowing it to
--     owner/creator/collaborator/senior belongs with 4b.
