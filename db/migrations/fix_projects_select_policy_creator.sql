-- ============================================================================
-- FIX — creating a project through the app failed with an RLS error
-- ============================================================================
-- Applied 2026-08-02 (via apply_migration). Verified below.
--
-- SYMPTOM: a senior creating a project in the UI got "new row violates
-- row-level security policy for table projects". It was NOT about the data
-- (address/postcode are never validated) — it was a genuine policy bug.
--
-- CAUSE: createProject does `.insert().select()` = INSERT ... RETURNING. For a
-- RETURNING row Postgres also applies the SELECT (USING) policy. That policy was
--     org_id = current_org_id() AND user_can_see_project(id)
-- and user_can_see_project() runs a SUBQUERY against `projects`. Mid-INSERT the
-- new row is not visible to that subquery's snapshot, so it returns false and the
-- RETURNING is rejected. (Existing projects were seeded server-side, bypassing
-- RLS, so nobody hit this until a project was created through the UI.)
--
-- FIX: a user must always be able to see a project they just created. Add a
-- direct `created_by = auth.uid()` term (a column reference on the NEW row — no
-- subquery, so it evaluates correctly during RETURNING). Seniors already see all
-- committed projects and only seniors can create, so this unblocks the
-- insert-returning path without broadening visibility of anything else.
-- ============================================================================

alter policy "projects scoped to org" on public.projects
  using (org_id = current_org_id() and (created_by = auth.uid() or user_can_see_project(id)));

-- VERIFICATION 2026-08-02 (self-aborting, role=authenticated as a senior):
--   INSERT INTO projects (...) RETURNING id  → SUCCEEDS (was BLOCKED before);
--   the same insert without the fix is BLOCKED; the full create flow
--   (projects insert + returning + project_visibility_exclusions) SUCCEEDS.
