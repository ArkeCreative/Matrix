-- =============================================================================
-- P0-2 — cross-organisation containment (go-live blocker)
-- Applied to tpxabhqsjngalilbznhz on 2026-07-29. Verification at the bottom.
-- =============================================================================
--
-- The fan-out helpers selected "all active seniors" with no organisation
-- predicate. Invisible with one org; the moment a real `arke` org exists,
-- dawlish test activity notifies real Arke seniors and vice versa.
--
-- SCOPE WIDENED beyond the plan's original P0-2 after inspecting the live
-- policy set. Two further routes would have made a second org unsafe on their
-- own, regardless of the helpers — sections 4 and 5 below. Section 5 in
-- particular is exploitable *today*, with one org.

-- 1. project_audience: seniors of the PROJECT'S org, not of every org --------
create or replace function public.project_audience(p_project uuid)
returns setof uuid
language sql
security definer
set search_path to 'public'
as $function$
  select distinct u from (
    select unnest(array[
        p.owner_user_id, p.pre_con_lead_user_id, p.designer_user_id,
        p.technical_designer_user_id, p.furniture_consultant_user_id, p.project_manager_user_id
    ]) as u
    from public.projects p where p.id = p_project
    union
    select a.id
      from public.app_users a
      join public.projects p2 on p2.id = p_project
     where a.role = 'senior' and a.active and a.org_id = p2.org_id
  ) s where u is not null;
$function$;

-- 2. record_activity: same defect in the null-project branch -----------------
create or replace function public.record_activity(
    p_org uuid, p_entity_type text, p_entity_id uuid, p_project uuid,
    p_event text, p_category text, p_summary text, p_changes jsonb,
    p_notify boolean default true)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
    r uuid;
    payload jsonb;
begin
    insert into public.audit_log(org_id, actor_user_id, entity_type, entity_id, project_id, event, category, summary, changes)
    values (p_org, auth.uid(), p_entity_type, p_entity_id, p_project, p_event, p_category, p_summary, coalesce(p_changes, '{}'::jsonb));

    if not p_notify then
        return;
    end if;
    payload := jsonb_build_object(
        'actor', public.actor_name(), 'actor_id', auth.uid(),
        'project_id', p_project, 'target', p_summary
    ) || coalesce(p_changes, '{}'::jsonb);

    if p_project is not null then
        for r in select public.project_audience(p_project) loop
            perform public.notify_user(p_org, r, p_event, payload);
        end loop;
    else
        for r in select a.id from public.app_users a
                  where a.role = 'senior' and a.active and a.org_id = p_org loop
            perform public.notify_user(p_org, r, p_event, payload);
        end loop;
    end if;
end;
$function$;

-- 3. notifications RLS: belt and braces on the read side ---------------------
drop policy if exists "own notifications read"   on public.notifications;
drop policy if exists "own notifications update" on public.notifications;
create policy "own notifications read" on public.notifications for select
  using (user_id = auth.uid() and org_id = current_org_id());
create policy "own notifications update" on public.notifications for update
  using (user_id = auth.uid() and org_id = current_org_id())
  with check (user_id = auth.uid() and org_id = current_org_id());

-- 4. Creation must land in the caller's own org ------------------------------
-- set_org_id_on_insert only fills org_id when it is NULL, so an explicit
-- org_id in the request body passed straight through on these two tables.
-- Every other org-scoped table already carries org_id = current_org_id() in
-- its INSERT check; projects and meetings were the outliers. (WITH CHECK is
-- evaluated after BEFORE triggers, so the app's org_id-less inserts still
-- pass — the trigger has filled it by then.)
drop policy if exists "seniors create projects" on public.projects;
create policy "seniors create projects" on public.projects for insert
  with check (
    org_id = current_org_id()
    and exists (select 1 from public.app_users
                 where app_users.id = auth.uid() and app_users.role = 'senior' and app_users.active)
  );
drop policy if exists "seniors create meetings" on public.meetings;
create policy "seniors create meetings" on public.meetings for insert
  with check (
    org_id = current_org_id()
    and exists (select 1 from public.app_users
                 where app_users.id = auth.uid() and app_users.role = 'senior' and app_users.active)
  );

-- 5. app_users self-edit lockdown -------------------------------------------
-- THE SERIOUS ONE, and live today. "users edit self" was
-- USING/WITH CHECK (id = auth.uid()) with no column restriction, so any
-- authenticated user could update their OWN org_id — and current_org_id() is
-- literally `select org_id from app_users where id = auth.uid()`, so that is a
-- one-request move into another tenant, after which every org-scoped policy in
-- the database resolves to the new org. The same policy also allowed
-- self-promotion to role = 'senior', which works with a single org.
--
-- The app only ever sends display_name / initials / job_title for a self-edit
-- (ProfileModal), but that was a client-side convention enforced nowhere.
-- RLS cannot compare a new row against OLD, so the invariant is a trigger.
create or replace function public.enforce_app_user_field_guard()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
    actor_is_senior boolean;
begin
    -- No JWT means an admin/service_role context that has already bypassed RLS
    -- (anon satisfies neither UPDATE policy, so it can never reach this
    -- trigger). Migrations and seeds stay unimpeded.
    if auth.uid() is null then
        return new;
    end if;

    -- Tenancy is never mutable through the API, for anyone. Moving a user
    -- between organisations is an administrative act.
    if new.org_id is distinct from old.org_id then
        raise exception 'app_users.org_id cannot be changed through the API';
    end if;
    if new.id is distinct from old.id then
        raise exception 'app_users.id cannot be changed';
    end if;

    select exists (
        select 1 from public.app_users me
         where me.id = auth.uid() and me.role = 'senior' and me.active
           and me.org_id = old.org_id
    ) into actor_is_senior;

    if not actor_is_senior
       and (new.role         is distinct from old.role
         or new.is_team_lead is distinct from old.is_team_lead
         or new.active       is distinct from old.active
         or new.department   is distinct from old.department) then
        raise exception 'only an active senior in your organisation may change role, department, team lead or active';
    end if;

    return new;
end;
$function$;

drop trigger if exists trg_app_users_field_guard on public.app_users;
create trigger trg_app_users_field_guard
  before update on public.app_users
  for each row execute function public.enforce_app_user_field_guard();

-- 6. Keep P0-1 closed --------------------------------------------------------
-- CREATE OR REPLACE preserves a function's ACL, but this re-asserts the revoke
-- rather than trusting that, and appendix query A is re-run afterwards.
revoke execute on function public.project_audience(uuid) from public, anon, authenticated;
revoke execute on function public.record_activity(uuid,text,uuid,uuid,text,text,text,jsonb,boolean) from public, anon, authenticated;
revoke execute on function public.enforce_app_user_field_guard() from public, anon, authenticated;

-- =============================================================================
-- Verification recorded 2026-07-29 (per the plan's APPLIED discipline)
-- =============================================================================
--
-- Behavioural test, run inside a self-aborting DO block against the live DB.
-- It stood up a second organisation, moved an active senior (deliberately one
-- NOT on the project's team, so the all-seniors branch was their only route
-- into the audience) into it, and then set request.jwt.claims to a real
-- contributor's id to exercise the guard under an actual JWT:
--
--   audience 3 -> 2
--   foreign senior in audience:  before = t,  after = f      <- section 1 works
--   self org_id change ........  blocked                     <- section 5 works
--   self role escalation ......  blocked                     <- section 5 works
--   legitimate rename .........  saved ok                    <- guard not over-broad
--
-- Rolled back cleanly: organisations = "Dawlish Projects" only, seniors still
-- 2 in the dawlish org, 0 rows named "Legit Rename".
--
-- Static verification:
--   org filter in project_audience ....... present  (a.org_id = p2.org_id)
--   org filter in record_activity ........ present  (a.org_id = p_org)
--   notifications read/update policies ... (user_id = auth.uid()) AND (org_id = current_org_id())
--   projects/meetings INSERT checks ...... (org_id = current_org_id()) AND (senior exists)
--   trigger on app_users ................. trg_app_users_field_guard (+ trg_audit_app_user_change)
--
-- P0-1 re-verified still closed — proacl on project_audience, record_activity
-- and the new enforce_app_user_field_guard shows only
-- `postgres=X/postgres | service_role=X/postgres`, i.e. no `=X/postgres`
-- PUBLIC grant. get_advisors(security): only the two accepted current_org_id
-- lints plus the separate auth_leaked_password_protection toggle.
--
-- NOT closed by this migration: P0-4. Role enforcement on the *operational*
-- tables (projects, meeting_handoffs, project_key_dates, project_contacts, the
-- checklist tables) is still org-scoped only, so any org member can still
-- update any project in their own org. That is the Phase 6 rewrite.
