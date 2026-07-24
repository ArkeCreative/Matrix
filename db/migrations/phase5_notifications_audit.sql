-- ============================================================
-- Phase 5 slice B — site-wide audit trail + notification fan-out
-- ============================================================
-- Records every change across the app to a complete audit_log, and fans each
-- event out to the eligible audience as per-user notifications (which power
-- the bell hub). Reuses the existing actor_name()/notify_user() conventions.
-- Idempotent: safe to re-run.
--
-- Scoping note (Phase 6 dependency): the notification audience is the project's
-- assigned team ∪ active seniors. True per-team project visibility lands in
-- Phase 6 and will tighten project_audience() automatically.

-- 1. Complete audit record — one row per event -----------------------------
create table if not exists public.audit_log (
    id           uuid primary key default gen_random_uuid(),
    org_id       uuid not null references public.organisations(id),
    actor_user_id uuid references public.app_users(id),
    entity_type  text not null,               -- 'project' | 'key_date' | 'meeting' | 'flag' | 'action' | ...
    entity_id    uuid,
    project_id   uuid references public.projects(id) on delete set null,
    event        text not null,               -- 'project-status-changed' | 'key-date-added' | ...
    category     text not null,               -- 'pipeline' | 'actions' | 'key-dates' | 'meetings' | 'flags'
    summary      text,
    changes      jsonb not null default '{}'::jsonb,
    created_at   timestamptz not null default now()
);
create index if not exists audit_log_org_created_idx on public.audit_log (org_id, created_at desc);
create index if not exists audit_log_project_idx on public.audit_log (project_id, created_at desc);
alter table public.audit_log enable row level security;
drop policy if exists "audit_log senior read" on public.audit_log;
create policy "audit_log senior read" on public.audit_log for select
  using (org_id = public.current_org_id() and exists (
     select 1 from public.app_users u where u.id = auth.uid() and u.role = 'senior' and u.active));

-- 2. Recipient audience for a project = assigned team ∪ active seniors ------
create or replace function public.project_audience(p_project uuid)
returns setof uuid language sql security definer set search_path = public as $$
  select distinct u from (
    select unnest(array[
        p.owner_user_id, p.pre_con_lead_user_id, p.designer_user_id,
        p.technical_designer_user_id, p.furniture_consultant_user_id, p.project_manager_user_id
    ]) as u
    from public.projects p where p.id = p_project
    union
    select a.id from public.app_users a where a.role = 'senior' and a.active
  ) s where u is not null;
$$;

-- 3. Record one event: write audit_log, optionally fan out notifications ----
create or replace function public.record_activity(
    p_org uuid, p_entity_type text, p_entity_id uuid, p_project uuid,
    p_event text, p_category text, p_summary text, p_changes jsonb,
    p_notify boolean default true)
returns void language plpgsql security definer set search_path = public as $$
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
            perform public.notify_user(p_org, r, p_event, payload);   -- notify_user skips the actor + nulls
        end loop;
    else
        -- project-less events (e.g. meetings span projects) → notify seniors
        for r in select a.id from public.app_users a where a.role = 'senior' and a.active loop
            perform public.notify_user(p_org, r, p_event, payload);
        end loop;
    end if;
end;
$$;

-- 4. Projects — every customisable field --------------------------------------
create or replace function public.audit_projects()
returns trigger language plpgsql security definer set search_path = public as $$
declare ch jsonb := '{}'::jsonb;
begin
    if TG_OP = 'INSERT' then
        perform public.record_activity(NEW.org_id, 'project', NEW.id, NEW.id, 'project-created', 'pipeline', NEW.name, jsonb_build_object('status', NEW.status));
        return NEW;
    end if;
    if NEW.status is distinct from OLD.status then
        perform public.record_activity(NEW.org_id, 'project', NEW.id, NEW.id, 'project-status-changed', 'pipeline', NEW.name, jsonb_build_object('status', NEW.status, 'from', OLD.status));
    end if;
    if NEW.site_start_date is distinct from OLD.site_start_date
       or NEW.projected_completion_date is distinct from OLD.projected_completion_date
       or NEW.contracted_completion_date is distinct from OLD.contracted_completion_date then
        perform public.record_activity(NEW.org_id, 'project', NEW.id, NEW.id, 'programme-changed', 'key-dates', NEW.name, '{}'::jsonb);
    end if;
    if NEW.owner_user_id is distinct from OLD.owner_user_id
       or NEW.pre_con_lead_user_id is distinct from OLD.pre_con_lead_user_id
       or NEW.designer_user_id is distinct from OLD.designer_user_id
       or NEW.technical_designer_user_id is distinct from OLD.technical_designer_user_id
       or NEW.furniture_consultant_user_id is distinct from OLD.furniture_consultant_user_id
       or NEW.project_manager_user_id is distinct from OLD.project_manager_user_id then
        perform public.record_activity(NEW.org_id, 'project', NEW.id, NEW.id, 'team-changed', 'pipeline', NEW.name, '{}'::jsonb);
    end if;
    -- remaining detail fields, collapsed into one 'project-updated'
    if NEW.name           is distinct from OLD.name           then ch := ch || jsonb_build_object('name',          jsonb_build_object('from', OLD.name,          'to', NEW.name)); end if;
    if NEW.project_number is distinct from OLD.project_number then ch := ch || jsonb_build_object('project_number',jsonb_build_object('from', OLD.project_number,'to', NEW.project_number)); end if;
    if NEW.address        is distinct from OLD.address        then ch := ch || jsonb_build_object('address',       jsonb_build_object('from', OLD.address,       'to', NEW.address)); end if;
    if NEW.secured        is distinct from OLD.secured        then ch := ch || jsonb_build_object('secured',       jsonb_build_object('from', OLD.secured,       'to', NEW.secured)); end if;
    if NEW.secured_note   is distinct from OLD.secured_note   then ch := ch || jsonb_build_object('secured_note',  jsonb_build_object('from', OLD.secured_note,  'to', NEW.secured_note)); end if;
    if NEW.site_area_m2   is distinct from OLD.site_area_m2   then ch := ch || jsonb_build_object('site_area_m2',  jsonb_build_object('from', OLD.site_area_m2,  'to', NEW.site_area_m2)); end if;
    if NEW.floor_level    is distinct from OLD.floor_level    then ch := ch || jsonb_build_object('floor_level',   jsonb_build_object('from', OLD.floor_level,   'to', NEW.floor_level)); end if;
    if NEW.whole_building is distinct from OLD.whole_building then ch := ch || jsonb_build_object('whole_building',jsonb_build_object('from', OLD.whole_building,'to', NEW.whole_building)); end if;
    if ch <> '{}'::jsonb then
        perform public.record_activity(NEW.org_id, 'project', NEW.id, NEW.id, 'project-updated', 'pipeline', 'project details', ch);
    end if;
    return NEW;
end;
$$;
drop trigger if exists trg_audit_projects on public.projects;
create trigger trg_audit_projects after insert or update on public.projects
    for each row execute function public.audit_projects();

-- 5. Key dates / programme ----------------------------------------------------
create or replace function public.audit_key_dates()
returns trigger language plpgsql security definer set search_path = public as $$
begin
    if TG_OP = 'INSERT' then
        perform public.record_activity(NEW.org_id, 'key_date', NEW.id, NEW.project_id, 'key-date-added', 'key-dates', NEW.event_name, jsonb_build_object('target_date', NEW.target_date));
    elsif TG_OP = 'UPDATE' then
        if NEW.completed is distinct from OLD.completed and NEW.completed then
            perform public.record_activity(NEW.org_id, 'key_date', NEW.id, NEW.project_id, 'key-date-completed', 'key-dates', NEW.event_name, '{}'::jsonb);
        elsif NEW.target_date is distinct from OLD.target_date then
            perform public.record_activity(NEW.org_id, 'key_date', NEW.id, NEW.project_id, 'programme-changed', 'key-dates', NEW.event_name, jsonb_build_object('from', OLD.target_date, 'to', NEW.target_date));
        end if;
    end if;
    return NEW;
end;
$$;
drop trigger if exists trg_audit_key_dates on public.project_key_dates;
create trigger trg_audit_key_dates after insert or update on public.project_key_dates
    for each row execute function public.audit_key_dates();

-- 6. Meetings (span projects → notify seniors) --------------------------------
create or replace function public.audit_meetings()
returns trigger language plpgsql security definer set search_path = public as $$
begin
    if TG_OP = 'INSERT' then
        perform public.record_activity(NEW.org_id, 'meeting', NEW.id, null, 'meeting-opened', 'meetings', null, jsonb_build_object('meeting_type', NEW.meeting_type));
    elsif TG_OP = 'UPDATE' and NEW.status is distinct from OLD.status then
        if NEW.status = 'closed' then
            perform public.record_activity(NEW.org_id, 'meeting', NEW.id, null, 'meeting-closed', 'meetings', null, jsonb_build_object('meeting_type', NEW.meeting_type));
        elsif NEW.status = 'in-progress' and OLD.status = 'closed' then
            perform public.record_activity(NEW.org_id, 'meeting', NEW.id, null, 'meeting-reopened', 'meetings', null, jsonb_build_object('meeting_type', NEW.meeting_type));
        end if;
    end if;
    return NEW;
end;
$$;
drop trigger if exists trg_audit_meetings on public.meetings;
create trigger trg_audit_meetings after insert or update on public.meetings
    for each row execute function public.audit_meetings();

-- 7. Flags (meeting_handoffs) -------------------------------------------------
create or replace function public.audit_flags()
returns trigger language plpgsql security definer set search_path = public as $$
begin
    if TG_OP = 'INSERT' then
        perform public.record_activity(NEW.org_id, 'flag', NEW.id, NEW.project_id, 'flag-raised', 'flags', left(NEW.note, 140), jsonb_build_object('to_department', NEW.to_department));
    elsif TG_OP = 'UPDATE' and NEW.status is distinct from OLD.status and NEW.status = 'acknowledged' then
        if NEW.resulting_action_id is not null then
            perform public.record_activity(NEW.org_id, 'flag', NEW.id, NEW.project_id, 'flag-converted', 'flags', left(NEW.note, 140), '{}'::jsonb);
        else
            perform public.record_activity(NEW.org_id, 'flag', NEW.id, NEW.project_id, 'flag-acknowledged', 'flags', left(NEW.note, 140), '{}'::jsonb);
        end if;
    end if;
    return NEW;
end;
$$;
drop trigger if exists trg_audit_flags on public.meeting_handoffs;
create trigger trg_audit_flags after insert or update on public.meeting_handoffs
    for each row execute function public.audit_flags();

-- 8. Actions — audit for completeness; broadcast completion to the team -------
--    (Personal 'action-assigned' to the owner stays with the existing
--     notify_action_owner trigger; we don't duplicate that fan-out here.)
create or replace function public.audit_actions()
returns trigger language plpgsql security definer set search_path = public as $$
begin
    if TG_OP = 'INSERT' then
        perform public.record_activity(NEW.org_id, 'action', NEW.id, NEW.project_id, 'action-created', 'actions', left(NEW.description, 140), '{}'::jsonb, false);
    elsif TG_OP = 'UPDATE' and NEW.status is distinct from OLD.status and NEW.status = 'completed' then
        perform public.record_activity(NEW.org_id, 'action', NEW.id, NEW.project_id, 'action-completed', 'actions', left(NEW.description, 140), '{}'::jsonb, true);
    end if;
    return NEW;
end;
$$;
drop trigger if exists trg_audit_actions on public.actions;
create trigger trg_audit_actions after insert or update on public.actions
    for each row execute function public.audit_actions();

-- Future Phase-4 modules (RFI, checklists, …) attach the same pattern:
--   create trigger trg_audit_<module> after insert or update on public.<module>
--     for each row execute function public.audit_<module>();
--   … calling record_activity(...) with an appropriate category so their
--   events flow into the same hub with no UI changes.
