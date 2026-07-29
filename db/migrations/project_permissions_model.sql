-- =============================================================================
-- Project permissions — default-visible, exclusion-based (Tom's decision)
-- Applied to tpxabhqsjngalilbznhz on 2026-07-29. Verification in
-- p0_4b_project_visibility_policies.sql, which is the other half of this batch.
-- =============================================================================
-- Visibility does NOT derive from team assignment. The six team FK columns
-- record who is *currently appointed* — a snapshot, not a history — so deriving
-- from them would hide projects from the people who did the early work (Marcus
-- converts a landlord drawing when a job arrives; someone else is later
-- formally appointed).
--
-- Model: every project is visible to the whole organisation unless someone says
-- otherwise, and exclusions are subtractive — a whole department, or named
-- individuals. `default true` means all 30 existing projects are unaffected.

alter table public.projects
  add column visible_to_all boolean not null default true;

create table public.project_visibility_exclusions (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid not null references public.organisations(id),
  project_id  uuid not null references public.projects(id) on delete cascade,
  department  text null,
  user_id     uuid null references public.app_users(id) on delete cascade,
  created_by  uuid references public.app_users(id),
  created_at  timestamptz not null default now(),
  constraint one_target_per_row check (num_nonnulls(department, user_id) = 1)
);
create unique index pve_project_department on public.project_visibility_exclusions (project_id, department) where department is not null;
create unique index pve_project_user       on public.project_visibility_exclusions (project_id, user_id)    where user_id is not null;
create index        pve_project            on public.project_visibility_exclusions (project_id);

-- P0-2 lesson: a new table gets org_id, the org trigger and RLS from birth.
alter table public.project_visibility_exclusions enable row level security;
create trigger trg_pve_set_org before insert on public.project_visibility_exclusions
  for each row execute function public.set_org_id_on_insert();

-- Senior-only, read included: knowing which projects exclude you is itself a
-- disclosure, and the Permissions tab is senior-only to edit anyway.
create policy "seniors manage exclusions" on public.project_visibility_exclusions for all
  using (
    org_id = current_org_id()
    and exists (select 1 from public.app_users
                 where app_users.id = auth.uid() and app_users.role = 'senior' and app_users.active)
  )
  with check (
    (org_id = current_org_id() or org_id is null)
    and exists (select 1 from public.app_users
                 where app_users.id = auth.uid() and app_users.role = 'senior' and app_users.active)
  );

-- The one predicate every policy calls. SECURITY DEFINER both because it must
-- read projects/app_users past RLS, and because calling it from inside the
-- projects policy would otherwise recurse.
create or replace function public.user_can_see_project(p_user uuid, p_project uuid)
returns boolean language sql stable security definer set search_path to 'public'
as $function$
  select exists (
    select 1
      from public.projects p
      join public.app_users me on me.id = p_user
     where p.id = p_project
       and (
            me.role = 'senior'                       -- decision 2: seniors are exempt
         or p.visible_to_all                         -- nothing is restricted here
         or coalesce(me.id = any(array[              -- decision 3: appointment beats exclusion
              p.owner_user_id, p.pre_con_lead_user_id, p.designer_user_id,
              p.technical_designer_user_id, p.furniture_consultant_user_id,
              p.project_manager_user_id]), false)
         or not exists (                             -- decision 1: department rule persists
              select 1 from public.project_visibility_exclusions x
               where x.project_id = p.id
                 and (x.user_id = me.id
                      or (x.department is not null and x.department = me.department))
            )
       )
  );
$function$;

create or replace function public.user_can_see_project(p_project uuid)
returns boolean language sql stable security definer set search_path to 'public'
as $function$ select public.user_can_see_project(auth.uid(), p_project); $function$;

-- Decision 3, made permanent: appointing someone clears an individual exclusion
-- outright, so it does not come back if they are later unappointed. A
-- *department* exclusion is deliberately not deleted — that would un-hide the
-- project for the whole team — the helper's appointment branch covers them
-- while they hold the role.
create or replace function public.drop_exclusion_on_appointment()
returns trigger language plpgsql security definer set search_path to 'public'
as $function$
begin
  delete from public.project_visibility_exclusions x
   where x.project_id = new.id
     and x.user_id is not null
     and x.user_id = any(array[
           new.owner_user_id, new.pre_con_lead_user_id, new.designer_user_id,
           new.technical_designer_user_id, new.furniture_consultant_user_id,
           new.project_manager_user_id]);
  return null;
end;
$function$;

create trigger trg_projects_appointment_beats_exclusion
  after insert or update of owner_user_id, pre_con_lead_user_id, designer_user_id,
       technical_designer_user_id, furniture_consultant_user_id, project_manager_user_id
  on public.projects for each row execute function public.drop_exclusion_on_appointment();

-- Fan-out must respect visibility, or an excluded person is notified about a
-- project they cannot open. Same helper P0-2 org-scoped.
create or replace function public.project_audience(p_project uuid)
returns setof uuid language sql security definer set search_path to 'public'
as $function$
  select distinct u from (
    select unnest(array[
        p.owner_user_id, p.pre_con_lead_user_id, p.designer_user_id,
        p.technical_designer_user_id, p.furniture_consultant_user_id, p.project_manager_user_id
    ]) as u
    from public.projects p where p.id = p_project
    union
    select a.id from public.app_users a
      join public.projects p2 on p2.id = p_project
     where a.role = 'senior' and a.active and a.org_id = p2.org_id
  ) s
  where u is not null and public.user_can_see_project(u, p_project);
$function$;

-- P0-1 lesson: no PUBLIC execute. NOTE the one deliberate exception granted in
-- the companion migration — see its header.
revoke execute on function public.user_can_see_project(uuid,uuid)   from public, anon, authenticated;
revoke execute on function public.user_can_see_project(uuid)        from public, anon, authenticated;
revoke execute on function public.drop_exclusion_on_appointment()   from public, anon, authenticated;
revoke execute on function public.project_audience(uuid)            from public, anon, authenticated;
