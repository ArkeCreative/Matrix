-- =============================================================================
-- Organisation tab — explicit reporting line + shared canvas layout
-- Applied to tpxabhqsjngalilbznhz on 2026-07-29.
-- =============================================================================

-- An explicit reporting line that overrides the derived default. null = fall
-- back to: active team lead of the person's department -> the exec.
alter table public.app_users
  add column manager_id uuid references public.app_users(id) on delete set null;
alter table public.app_users
  add constraint app_users_manager_not_self check (manager_id is null or manager_id <> id);

-- Saved card positions. Shared, not per-viewer: the chart is a company-wide
-- artefact, not a personal scratchpad.
create table public.org_chart_layout (
  user_id     uuid primary key references public.app_users(id) on delete cascade,
  org_id      uuid not null references public.organisations(id),
  x           integer not null,
  y           integer not null,
  updated_at  timestamptz not null default now(),
  updated_by  uuid references public.app_users(id)
);

-- P0-2 lesson, applied rather than repeated: org_id + the org trigger + RLS.
alter table public.org_chart_layout enable row level security;
create trigger trg_org_chart_layout_set_org before insert on public.org_chart_layout
  for each row execute function public.set_org_id_on_insert();

create policy "layout readable in org" on public.org_chart_layout for select
  using (org_id = current_org_id());
create policy "seniors write layout" on public.org_chart_layout for all
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

-- ⚠ P0-2's field guard MUST cover manager_id, or a contributor could re-parent
-- themselves on the chart by forging a single request. Flagged when the org tab
-- was folded into the plan; applied here with the tab itself.
create or replace function public.enforce_app_user_field_guard()
returns trigger language plpgsql security definer set search_path to 'public'
as $function$
declare
    actor_is_senior boolean;
begin
    if auth.uid() is null then
        return new;
    end if;
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
         or new.department   is distinct from old.department
         or new.manager_id   is distinct from old.manager_id) then
        raise exception 'only an active senior in your organisation may change role, department, team lead, active or reporting line';
    end if;
    return new;
end;
$function$;

revoke execute on function public.enforce_app_user_field_guard() from public, anon, authenticated;

-- =============================================================================
-- Verification recorded 2026-07-29
-- =============================================================================
-- The tree + layout logic was unit-tested against the real 13 active users
-- (scratch harness replaying the component's own functions). 10/10:
--   exec resolves to Tom Staples (senior, no department);
--   no vacancy cards — every department currently has a lead, so the
--     screenshots in the handoff (four vacancies) reflect its invented data;
--   exactly one root; every node reaches the exec — no orphans, no cycles;
--   leads sit directly under the exec, ordered CG, GB, JO, MAB, PA;
--   Carlos (pm lead) carries his four team members; Priya carries Felix;
--   no two cards overlap on any row;
--   each parent is centred over its children;
--   an injected CG<->AA cycle is broken rather than hanging.
--
-- The centring test FAILED first time and caught a real defect: parents were
-- centred over their allocated block rather than over their first and last
-- child card. With an asymmetric subtree the two differ and the parent sits
-- visibly off-centre. Fixed to the standard tidy-layout form.
