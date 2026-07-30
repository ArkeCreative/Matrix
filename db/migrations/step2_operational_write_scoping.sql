-- ============================================================================
-- Step 2 — Operational write scoping (the last piece of P0-4)
-- ============================================================================
-- Applied 2026-07-30. Verification recorded at the bottom, per the P0-1 discipline.
--
-- THE HOLE
-- Visibility (P0-4b) is solved; *who may change what* was not. Every write
-- policy on the operational tables was org-wide: any member who could SEE a
-- project could edit or delete any of its actions and flags, and manage any
-- action's collaborators. The "senior only" / "team lead only" rules the app
-- shows are JavaScript conventions, not controls — the P0-4 pattern.
--
-- WHAT THIS NARROWS
--   actions          UPDATE → owner / creator / collaborator / senior
--                    DELETE → creator / senior only (deleting is more
--                             destructive than editing; an assignee completes
--                             or declines an action, they don't delete it)
--   meeting_handoffs  the single blanket ALL policy is split into four; the
--                    acknowledge/convert path (UPDATE) is keyed to the target
--                    department's LEAD, a senior, or the raiser — NOT to
--                    role='senior' alone, because two of the five team leads are
--                    contributors (Grace/furniture, Jen/pre-con) and a
--                    senior-only rule would lock them out of their own flags.
--   action_assignees  the blanket ALL is split; managing collaborators now
--                    requires the same authority as editing the parent action.
--
-- WHY is_team_lead, NOT the meeting chair
-- The app gated acknowledge/convert on the meeting CHAIR. A database policy
-- cannot reproduce "chair of the meeting I am currently acting from" — a flag
-- is not bound to the meeting you act on it from, so the row carries no such
-- fact. The accountable owner of a flag that *is* on the row is its target
-- department; its lead is the honest DB-checkable authority. The app's
-- meeting-pane gate is realigned to the same predicate in the same batch, so UI
-- and database agree and there is no "looked saved then silently reverted".
--
-- A policy-filtered UPDATE returns from PostgREST as success with ZERO ROWS,
-- not an error — hence the app-side alignment matters as much as the policy.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Authority helpers
-- ---------------------------------------------------------------------------
-- SECURITY DEFINER so the self-lookup bypasses app_users RLS reliably, exactly
-- as current_org_id() and user_can_see_project() do. Both return only a boolean
-- about the CALLER'S OWN authority — they reveal nothing about anyone else — so,
-- like those two, they are the accepted class of policy-helper that stays
-- executable by anon/authenticated and shows in get_advisors. P0-1 lesson
-- applied: the ambiguous PUBLIC grant is revoked and the two roles that
-- actually evaluate policies are granted explicitly.

create or replace function public.is_active_senior()
returns boolean language sql stable security definer set search_path to 'public' as $$
  select exists (
    select 1 from public.app_users a
     where a.id = auth.uid() and a.role = 'senior' and a.active
  );
$$;

create or replace function public.is_dept_lead(p_dept text)
returns boolean language sql stable security definer set search_path to 'public' as $$
  select exists (
    select 1 from public.app_users a
     where a.id = auth.uid() and a.is_team_lead and a.active
       and a.department = p_dept
  );
$$;

-- "Am I a collaborator on this action?" MUST be SECURITY DEFINER: it reads
-- action_assignees, and a policy ON action_assignees that sub-queries
-- action_assignees directly re-enters RLS and Postgres aborts with
-- "infinite recursion detected in policy" (found in verification). Reading the
-- table as the definer bypasses RLS and breaks the cycle. Same use in the
-- actions UPDATE policy, for consistency.
create or replace function public.is_action_collaborator(p_action uuid)
returns boolean language sql stable security definer set search_path to 'public' as $$
  select exists (
    select 1 from public.action_assignees aa
     where aa.action_id = p_action and aa.user_id = auth.uid()
  );
$$;

revoke execute on function public.is_active_senior()          from public;
revoke execute on function public.is_dept_lead(text)          from public;
revoke execute on function public.is_action_collaborator(uuid) from public;
grant  execute on function public.is_active_senior()          to anon, authenticated;
grant  execute on function public.is_dept_lead(text)          to anon, authenticated;
grant  execute on function public.is_action_collaborator(uuid) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. actions — narrow UPDATE and DELETE (SELECT / INSERT unchanged)
-- ---------------------------------------------------------------------------
-- USING gates whether you may touch the row; WITH CHECK only keeps the result
-- in-org and project-visible. The ownership test is deliberately NOT repeated
-- in WITH CHECK, so an authorised writer may reassign owner_user_id.

drop policy if exists "members edit actions" on public.actions;
create policy "write actions if owner creator collaborator or senior"
  on public.actions for update
  using (
    org_id = current_org_id()
    and (project_id is null or user_can_see_project(project_id))
    and (
      owner_user_id = auth.uid()
      or created_by = auth.uid()
      or is_active_senior()
      or is_action_collaborator(actions.id)
    )
  )
  with check (
    org_id = current_org_id()
    and (project_id is null or user_can_see_project(project_id))
  );

drop policy if exists "members delete actions" on public.actions;
create policy "delete actions if creator or senior"
  on public.actions for delete
  using (
    org_id = current_org_id()
    and (project_id is null or user_can_see_project(project_id))
    and (created_by = auth.uid() or is_active_senior())
  );

-- ---------------------------------------------------------------------------
-- 3. meeting_handoffs — split the blanket ALL into four
-- ---------------------------------------------------------------------------
-- Raising a flag stays open to any member who can see the project; acting on it
-- (acknowledge/convert = UPDATE) is the target dept's lead, a senior, or the
-- raiser; deleting it is the raiser or a senior.

drop policy if exists "handoffs rw" on public.meeting_handoffs;

create policy "handoffs read" on public.meeting_handoffs for select
  using (org_id = current_org_id() and user_can_see_project(project_id));

create policy "handoffs create" on public.meeting_handoffs for insert
  with check (
    (org_id = current_org_id() or org_id is null)
    and user_can_see_project(project_id)
  );

create policy "handoffs act if dept lead senior or raiser"
  on public.meeting_handoffs for update
  using (
    org_id = current_org_id() and user_can_see_project(project_id)
    and (is_active_senior() or is_dept_lead(to_department) or created_by = auth.uid())
  )
  with check (org_id = current_org_id() and user_can_see_project(project_id));

create policy "handoffs delete if raiser or senior"
  on public.meeting_handoffs for delete
  using (
    org_id = current_org_id() and user_can_see_project(project_id)
    and (is_active_senior() or created_by = auth.uid())
  );

-- ---------------------------------------------------------------------------
-- 4. action_assignees — managing collaborators needs parent-action authority
-- ---------------------------------------------------------------------------
-- Read is scoped to a visible parent action. Managing (insert/update/delete)
-- requires the SAME authority as editing that action — owner / creator /
-- collaborator / senior — so nobody who can already edit an action is newly
-- refused (the app's collaborator reconcile swallows write errors, so a new
-- refusal would revert silently). Split into explicit commands, NOT one ALL
-- policy, so the manage predicate's subquery against action_assignees is
-- evaluated only under the read policy and cannot recurse.

drop policy if exists "assignees rw" on public.action_assignees;

create policy "assignees read" on public.action_assignees for select
  using (
    org_id = current_org_id()
    and exists (
      select 1 from public.actions a
       where a.id = action_id
         and a.org_id = current_org_id()
         and (a.project_id is null or user_can_see_project(a.project_id))
    )
  );

-- Reused by insert/update/delete below. Expressed inline (policies can't call a
-- parameterless "for this row" helper cleanly), so the same shape is repeated.
-- Manage authority = same as editing the parent action (owner/creator/
-- collaborator/senior). The collaborator arm goes through is_action_collaborator
-- (SECURITY DEFINER) so this policy never sub-queries its own table.
create policy "assignees insert if can edit action"
  on public.action_assignees for insert
  with check (
    (org_id = current_org_id() or org_id is null)
    and (
      is_active_senior()
      or is_action_collaborator(action_id)
      or exists (select 1 from public.actions a
                  where a.id = action_id
                    and (a.owner_user_id = auth.uid() or a.created_by = auth.uid()))
    )
  );

create policy "assignees update if can edit action"
  on public.action_assignees for update
  using (
    org_id = current_org_id()
    and (
      is_active_senior()
      or is_action_collaborator(action_id)
      or exists (select 1 from public.actions a
                  where a.id = action_id
                    and (a.owner_user_id = auth.uid() or a.created_by = auth.uid()))
    )
  )
  with check (
    org_id = current_org_id()
    and (
      is_active_senior()
      or is_action_collaborator(action_id)
      or exists (select 1 from public.actions a
                  where a.id = action_id
                    and (a.owner_user_id = auth.uid() or a.created_by = auth.uid()))
    )
  );

create policy "assignees delete if can edit action"
  on public.action_assignees for delete
  using (
    org_id = current_org_id()
    and (
      is_active_senior()
      or is_action_collaborator(action_id)
      or exists (select 1 from public.actions a
                  where a.id = action_id
                    and (a.owner_user_id = auth.uid() or a.created_by = auth.uid()))
    )
  );

-- ============================================================================
-- VERIFICATION — 2026-07-30, against the live database
-- ============================================================================
-- Behavioural, in self-aborting DO blocks under real JWTs (set local role
-- authenticated + set_config('request.jwt.claims', …)), ending in raise
-- exception so nothing committed. Results quoted verbatim.
--
-- DEFECT FOUND AND FIXED DURING VERIFICATION. The first cut had the
-- action_assignees manage policies sub-query action_assignees directly for the
-- collaborator check. A policy ON a table that reads that same table re-enters
-- RLS: "ERROR: infinite recursion detected in policy for relation
-- action_assignees" on the first assignee insert. Fixed with
-- is_action_collaborator() (SECURITY DEFINER), which reads the table as the
-- definer and breaks the cycle; the actions UPDATE policy uses it too.
--
-- 1. ACTIONS — update authority (action owned by Aisha, raised by Jen, on a
--    visible project), one UPDATE attempt per actor:
--      UPDATE random=0  owner=1  creator=1  senior=1
--    A policy-filtered UPDATE returns 0 rows (not an error) — the unrelated
--    contributor is refused; owner, creator and senior all pass.
--
-- 2. ACTION_ASSIGNEES — collaborator management:
--      assignee-insert random=blocked(42501)   (a hard WITH CHECK error)
--      assignee-insert creator=1                (the action's creator may add)
--      UPDATE-by-collaborator=1                 (once added, the collaborator
--                                                can edit the parent action)
--
-- 3. ACTIONS — delete is narrower than edit:
--      DELETE owner=0   collaborator=0   creator=1
--    An owner or collaborator cannot delete; the creator (and, separately
--    verified, a senior) can.
--
-- 4. MEETING_HANDOFFS — acknowledge/convert (UPDATE) authority, on a furniture
--    flag RAISED BY A CONTRIBUTOR so the raiser and senior arms are independent:
--      ACT random=0
--      ACT furniture-lead(contributor)=1   <- the load-bearing case: a
--                                             CONTRIBUTOR team lead can act on
--                                             their department's flag. A
--                                             senior-only rule would have
--                                             returned 0 here and broken the
--                                             flag ladder.
--      ACT raiser=1
--      ACT senior(of another dept)=1
--    Delete authority (raiser or senior only):
--      DELETE furniture-lead=0   (a dept lead who didn't raise it cannot delete)
--      DELETE senior=1
--
-- 5. NOTHING COMMITTED. After every block: actions 37 (test action still
--    present — its delete rolled back), action_assignees 8 (test collaborator
--    gone), meeting_handoffs 14 (no TEST rows), 4 policies on each of actions /
--    meeting_handoffs / action_assignees.
--
-- 6. get_advisors(security): the three helpers (is_active_senior, is_dept_lead,
--    is_action_collaborator) show as anon/authenticated-executable SECURITY
--    DEFINER — the SAME accepted class as current_org_id and
--    user_can_see_project. They are policy helpers (the roles that evaluate
--    policies must be able to call them) and return only a boolean about the
--    CALLER'S OWN authority, leaking nothing about anyone else. No new
--    problematic lint; no table left without a policy. The pre-existing
--    baseline_programme / reset_password_to_temporary /
--    auth_leaked_password_protection entries are unchanged.
--
-- NOT VERIFIED FROM THE SANDBOX: the browser paths. The meeting-pane
-- acknowledge/convert gate was realigned in app.jsx (from meeting-chair to the
-- same {senior · target-dept lead · raiser} predicate) in this batch; that it
-- behaves on the deployed app is Tom's check — see the PR test list.
