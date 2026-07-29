-- ============================================================================
-- Step 1 — Programme baseline & delay record schema
-- ============================================================================
-- Applied 2026-07-29. Verification recorded at the bottom of this file, per the
-- discipline set after P0-1.
--
-- WHY THIS IS URGENT
-- project_key_dates has a single mutable target_date. When a date moves, the
-- previous value is gone. audit_log holds exactly ONE key_date row across the
-- whole database, so there is no history to reconstruct from either. Every week
-- this is not deployed is a week of programme history that cannot be rebuilt.
--
-- DESIGN NOTES (decided with Tom, 2026-07-29)
--
-- 1. The guarantee lives in a TRIGGER, not in the app. There are three live app
--    paths that move a target_date (KeyDatesSection.handleSaveEdit,
--    ProgrammeTimeline.updateDate, and the Step 13 programme import will be a
--    fourth), plus raw SQL. A trigger catches all of them and cannot be
--    bypassed or forged through PostgREST.
--
-- 2. A trigger cannot know WHY a date moved — it sees only OLD and NEW. The
--    meeting, the causing flag/action and the reason are context the app holds
--    and the row does not. PostgREST offers no per-request hook for a
--    transaction-local GUC without an RPC, and an RPC would bypass the RX bus's
--    auto-emit (which wraps sb.from, not sb.rpc) and silently break reactivity.
--    So context arrives in TRANSIENT COLUMNS the app sets in the SAME update
--    statement as the new date; the trigger folds them into the revision row and
--    blanks them again, so they are always NULL at rest. Context missing still
--    yields a correctly attributed revision — it just has no "why".
--
-- 3. ONE revision table covers both key dates and the three project-level date
--    columns, so the Step 5 per-project chronology export is a single ordered
--    query rather than a union.
--
-- 4. The subject name is SNAPSHOTTED (subject_label). If a key date is renamed
--    or deleted later, the record of what it was called at the time survives.
--    An evidential log must not be rewritable by editing the thing it describes.
--
-- 5. NO BASELINE IS BACKFILLED. Setting baseline_date = the current target_date
--    across the 159 existing rows would assert "this was always the plan" for
--    dates that may already have slipped — inventing the exact history this
--    migration exists to protect. Existing rows get a NULL baseline and simply
--    have no slip figure until somebody baselines them deliberately.
--
-- 6. programme_revisions is APPEND-ONLY AND TRIGGER-WRITTEN. There is a SELECT
--    policy and nothing else: no INSERT, UPDATE or DELETE policy exists, so no
--    API caller can forge, amend or erase a revision. The triggers are
--    SECURITY DEFINER and write past RLS.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Baseline columns
-- ---------------------------------------------------------------------------
-- Mirrors the existing secured_at / secured_by pattern.

alter table public.project_key_dates
  add column if not exists baseline_date    date,
  add column if not exists baseline_set_at  timestamptz,
  add column if not exists baseline_set_by  uuid references public.app_users(id) on delete set null;

comment on column public.project_key_dates.baseline_date is
  'The agreed programme date, frozen by an explicit "Baseline this programme" action. NULL means never baselined — there is deliberately no backfill, because a fabricated baseline is worse than none.';

alter table public.projects
  add column if not exists site_start_baseline_date             date,
  add column if not exists projected_completion_baseline_date   date,
  add column if not exists contracted_completion_baseline_date  date,
  add column if not exists programme_baselined_at               timestamptz,
  add column if not exists programme_baselined_by               uuid references public.app_users(id) on delete set null;

-- ---------------------------------------------------------------------------
-- 2. Transient change-context columns (see design note 2)
-- ---------------------------------------------------------------------------
-- Always NULL at rest. The BEFORE trigger reads them and blanks them.

alter table public.project_key_dates
  add column if not exists change_reason           text,
  add column if not exists change_meeting_id       uuid references public.meetings(id) on delete set null,
  add column if not exists change_cause_flag_id    uuid references public.meeting_handoffs(id) on delete set null,
  add column if not exists change_cause_action_id  uuid references public.actions(id) on delete set null;

comment on column public.project_key_dates.change_reason is
  'Transient. Set by the client in the same UPDATE as a target_date change; consumed and blanked by the revision trigger. Never populated at rest.';

alter table public.projects
  add column if not exists date_change_reason           text,
  add column if not exists date_change_meeting_id       uuid references public.meetings(id) on delete set null,
  add column if not exists date_change_cause_flag_id    uuid references public.meeting_handoffs(id) on delete set null,
  add column if not exists date_change_cause_action_id  uuid references public.actions(id) on delete set null;

comment on column public.projects.date_change_reason is
  'Transient — see project_key_dates.change_reason.';

-- ---------------------------------------------------------------------------
-- 3. programme_revisions — the delay record
-- ---------------------------------------------------------------------------

create table if not exists public.programme_revisions (
  id              uuid primary key default gen_random_uuid(),
  org_id          uuid not null references public.organisations(id) on delete cascade,
  project_id      uuid not null references public.projects(id) on delete cascade,

  -- What moved. subject_kind decides which of the two identifying columns is
  -- used; subject_label is a snapshot so the record survives a rename/delete.
  subject_kind    text not null check (subject_kind in ('key_date','project_date')),
  key_date_id     uuid references public.project_key_dates(id) on delete set null,
  project_field   text,
  subject_label   text not null,

  -- The movement itself. new_date NULL means the date was cleared or the key
  -- date was deleted; change_kind says which.
  previous_date   date,
  new_date        date,
  change_kind     text not null default 'moved'
                    check (change_kind in ('moved','set','cleared','deleted')),

  -- Attribution.
  changed_by      uuid references public.app_users(id) on delete set null,
  -- clock_timestamp(), NOT now(): now() is transaction time, so two revisions
  -- written in one transaction (a re-import, a multi-date edit) would share a
  -- timestamp and the Step 5 chronology could not order them. Found in
  -- verification — see note 2 at the bottom of this file.
  changed_at      timestamptz not null default clock_timestamp(),

  -- Cause, where the client supplied it.
  meeting_id      uuid references public.meetings(id) on delete set null,
  cause_flag_id   uuid references public.meeting_handoffs(id) on delete set null,
  cause_action_id uuid references public.actions(id) on delete set null,
  reason          text,

  constraint programme_revisions_subject_ck check (
    (subject_kind = 'key_date'     and project_field is null)
    or
    (subject_kind = 'project_date' and project_field is not null and key_date_id is null)
  ),
  constraint programme_revisions_field_ck check (
    project_field is null or project_field in (
      'site_start_date','projected_completion_date','contracted_completion_date'
    )
  )
);

comment on table public.programme_revisions is
  'Append-only, trigger-written record of every programme date movement. Feeds the Step 5 delay record / EOT chronology. No INSERT/UPDATE/DELETE policy exists by design — nothing reachable through the API may write, amend or erase a row here.';

create index if not exists programme_revisions_project_idx
  on public.programme_revisions (project_id, changed_at desc);
create index if not exists programme_revisions_key_date_idx
  on public.programme_revisions (key_date_id) where key_date_id is not null;

alter table public.programme_revisions enable row level security;

-- Read only, and only within your org and the projects you can see.
drop policy if exists "programme revisions scoped to org" on public.programme_revisions;
create policy "programme revisions scoped to org" on public.programme_revisions
  for select using (org_id = current_org_id() and user_can_see_project(project_id));

-- Deliberately no INSERT/UPDATE/DELETE policies. See design note 6.
revoke insert, update, delete on public.programme_revisions from anon, authenticated;
grant select on public.programme_revisions to anon, authenticated;

-- Belt and braces (the triggers set org_id explicitly; this catches anything else).
drop trigger if exists trg_programme_revisions_set_org on public.programme_revisions;
create trigger trg_programme_revisions_set_org
  before insert on public.programme_revisions
  for each row execute function public.set_org_id_on_insert();

-- ---------------------------------------------------------------------------
-- 4. Revision triggers
-- ---------------------------------------------------------------------------

-- Resolve the actor without ever blocking the edit. auth.uid() is preferred
-- because it cannot be forged by the client, unlike updated_by; the lookup
-- against app_users means an unmatched id degrades to an unattributed record
-- rather than failing the FK and refusing a legitimate programme change.
create or replace function public.programme_actor(p_fallback uuid)
returns uuid language sql stable security definer set search_path to 'public' as $$
  select u.id from public.app_users u
   where u.id = coalesce(auth.uid(), p_fallback)
   limit 1;
$$;

create or replace function public.record_key_date_revision()
returns trigger language plpgsql security definer set search_path to 'public' as $$
begin
  if old.target_date is distinct from new.target_date then
    insert into public.programme_revisions (
      org_id, project_id, subject_kind, key_date_id, subject_label,
      previous_date, new_date, change_kind, changed_by,
      meeting_id, cause_flag_id, cause_action_id, reason
    ) values (
      new.org_id, new.project_id, 'key_date', new.id, coalesce(new.event_name, old.event_name, 'Key date'),
      old.target_date, new.target_date,
      case
        when old.target_date is null then 'set'
        when new.target_date is null then 'cleared'
        else 'moved'
      end,
      public.programme_actor(new.updated_by),
      new.change_meeting_id, new.change_cause_flag_id, new.change_cause_action_id,
      nullif(btrim(coalesce(new.change_reason,'')), '')
    );
  end if;

  -- Transient context never persists, whether or not the date actually moved.
  new.change_reason          := null;
  new.change_meeting_id      := null;
  new.change_cause_flag_id   := null;
  new.change_cause_action_id := null;
  return new;
end;
$$;

drop trigger if exists trg_key_date_revision on public.project_key_dates;
create trigger trg_key_date_revision
  before update on public.project_key_dates
  for each row execute function public.record_key_date_revision();

-- Deleting a key date is programme history too: without this, delete-and-recreate
-- (exactly what a re-import does) would erase a milestone with no trace.
create or replace function public.record_key_date_deletion()
returns trigger language plpgsql security definer set search_path to 'public' as $$
begin
  if old.target_date is not null then
    insert into public.programme_revisions (
      org_id, project_id, subject_kind, key_date_id, subject_label,
      previous_date, new_date, change_kind, changed_by, reason
    ) values (
      old.org_id, old.project_id, 'key_date', null, coalesce(old.event_name, 'Key date'),
      old.target_date, null, 'deleted',
      public.programme_actor(old.updated_by), null
    );
  end if;
  return old;
end;
$$;

drop trigger if exists trg_key_date_deletion on public.project_key_dates;
create trigger trg_key_date_deletion
  before delete on public.project_key_dates
  for each row execute function public.record_key_date_deletion();

-- The three project-level programme dates get the same treatment.
create or replace function public.record_project_date_revision()
returns trigger language plpgsql security definer set search_path to 'public' as $$
declare
  v_actor uuid;
  v_field text;
  v_label text;
  v_old   date;
  v_new   date;
begin
  v_actor := public.programme_actor(new.last_updated_by);

  foreach v_field in array array['site_start_date','projected_completion_date','contracted_completion_date']
  loop
    v_old := case v_field
               when 'site_start_date'            then old.site_start_date
               when 'projected_completion_date'  then old.projected_completion_date
               else old.contracted_completion_date end;
    v_new := case v_field
               when 'site_start_date'            then new.site_start_date
               when 'projected_completion_date'  then new.projected_completion_date
               else new.contracted_completion_date end;

    if v_old is distinct from v_new then
      v_label := case v_field
                   when 'site_start_date'           then 'Site start'
                   when 'projected_completion_date' then 'Projected completion'
                   else 'Contracted completion (PC)' end;

      insert into public.programme_revisions (
        org_id, project_id, subject_kind, project_field, subject_label,
        previous_date, new_date, change_kind, changed_by,
        meeting_id, cause_flag_id, cause_action_id, reason
      ) values (
        new.org_id, new.id, 'project_date', v_field, v_label,
        v_old, v_new,
        case when v_old is null then 'set' when v_new is null then 'cleared' else 'moved' end,
        v_actor,
        new.date_change_meeting_id, new.date_change_cause_flag_id, new.date_change_cause_action_id,
        nullif(btrim(coalesce(new.date_change_reason,'')), '')
      );
    end if;
  end loop;

  new.date_change_reason          := null;
  new.date_change_meeting_id      := null;
  new.date_change_cause_flag_id   := null;
  new.date_change_cause_action_id := null;
  return new;
end;
$$;

drop trigger if exists trg_project_date_revision on public.projects;
create trigger trg_project_date_revision
  before update on public.projects
  for each row execute function public.record_project_date_revision();

-- ---------------------------------------------------------------------------
-- 5. baseline_programme() — the explicit action
-- ---------------------------------------------------------------------------
-- Tom's decision (2026-07-29): the baseline is frozen by a deliberate senior
-- action, not silently on secure. A baseline set by a side effect is not
-- evidence of anything; a baseline a named person chose to set, on a recorded
-- date, is.
--
-- Atomicity is why this is a function rather than client-side writes:
-- baseline_date = target_date is a column-to-column assignment PostgREST cannot
-- express, so the client would have to issue one write per key date and could
-- half-baseline a project.
--
-- It REFUSES to overwrite an existing baseline. A baseline that can be quietly
-- re-set is not a baseline. Agreed re-baselining (post-EOT) is a Step 5
-- decision and will need its own audited path.

create or replace function public.baseline_programme(p_project uuid)
returns integer language plpgsql security definer set search_path to 'public' as $$
declare
  v_proj  public.projects%rowtype;
  v_count integer;
  v_uid   uuid := auth.uid();
begin
  select * into v_proj from public.projects where id = p_project;
  if not found then
    raise exception 'Project not found';
  end if;

  -- No-JWT contexts (service_role, migrations) pass through, matching the
  -- enforce_app_user_field_guard pattern from P0-2.
  if v_uid is not null then
    if not exists (
      select 1 from public.app_users a
       where a.id = v_uid and a.role = 'senior' and a.active and a.org_id = v_proj.org_id
    ) then
      raise exception 'Only an active senior may baseline a programme';
    end if;
    if not public.user_can_see_project(p_project) then
      raise exception 'Project not visible to this user';
    end if;
  end if;

  if v_proj.programme_baselined_at is not null then
    raise exception 'This programme is already baselined (%). Re-baselining is not available.',
      to_char(v_proj.programme_baselined_at, 'DD Mon YYYY');
  end if;

  update public.project_key_dates
     set baseline_date   = target_date,
         baseline_set_at = now(),
         baseline_set_by = coalesce(v_uid, v_proj.last_updated_by)
   where project_id = p_project
     and target_date is not null
     and baseline_date is null;
  get diagnostics v_count = row_count;

  update public.projects
     set site_start_baseline_date            = site_start_date,
         projected_completion_baseline_date  = projected_completion_date,
         contracted_completion_baseline_date = contracted_completion_date,
         programme_baselined_at              = now(),
         programme_baselined_by              = coalesce(v_uid, last_updated_by)
   where id = p_project;

  return v_count;
end;
$$;

-- P0-1 lesson: revoke from PUBLIC, not just from the roles. PUBLIC is the
-- source of the privilege and anon inherits it.
revoke execute on function public.baseline_programme(uuid)        from public, anon, authenticated;
revoke execute on function public.programme_actor(uuid)           from public, anon, authenticated;
revoke execute on function public.record_key_date_revision()      from public, anon, authenticated;
revoke execute on function public.record_key_date_deletion()      from public, anon, authenticated;
revoke execute on function public.record_project_date_revision()  from public, anon, authenticated;

-- baseline_programme is the one that is meant to be callable, by signed-in
-- users only. The senior check inside it is the real gate.
grant execute on function public.baseline_programme(uuid) to authenticated;

-- ============================================================================
-- VERIFICATION — 2026-07-29, against the live database
-- ============================================================================
-- All of it behavioural, in self-aborting DO blocks under real JWTs
-- (`set local role authenticated` + set_config('request.jwt.claims', …)),
-- ending in `raise exception` so nothing committed. Results are quoted verbatim
-- from the raised messages.
--
-- 1. REVISION CAPTURE, under a real contributor JWT (Jen Okafor), moving
--    Kingfisher House's "Enquiry Received" with context in the same statement:
--      revision rows=1 | subject=Enquiry Received | kind=key_date/moved
--      | 2024-05-06 -> 2024-06-17 | changed_by=Jen Okafor | meeting_linked=true
--      | reason=[Client delayed the brief sign-off]   <- note: whitespace trimmed
--      | transient_cols_null=4/4
--    A second move appended rather than overwriting (rows=2), and an edit that
--    changed only event_name wrote NO revision (rows still 2).
--
-- 2. DEFECT FOUND AND FIXED DURING VERIFICATION. changed_at defaulted to now(),
--    which is TRANSACTION time — two revisions written in one transaction (a
--    re-import, or a multi-date edit) carried identical timestamps and the
--    Step 5 chronology could not order them. Changed to clock_timestamp();
--    re-verified: distinct_timestamps=true, and with deterministic ordering the
--    second move correctly showed reason=[NULL], meeting=NULL — i.e. the
--    transient context really is consumed, not carried forward.
--
-- 3. TAMPER RESISTANCE, under an authenticated JWT:
--      forge_insert=blocked(42501) | tamper_update=blocked(42501) | delete=blocked(42501)
--    Hard privilege errors, not silent RLS filtering, because the table
--    privileges themselves are revoked. The record cannot be forged, amended or
--    erased through the API.
--
-- 4. BASELINE GATE:
--      contributor_baseline=refused["Only an active senior may baseline a programme"]
--      senior_baselined_key_dates=12 | kd_with_baseline=12 | baseline_equals_target=12
--      proj_site_start_baseline=2024-09-16 | baselined_by=Tom Staples
--      rebaseline=refused["This programme is already baselined (29 Jul 2026)…"]
--    Then moving a baselined date +30 days left the baseline intact:
--      1 row(s) now differ from baseline  <- slip is measurable, which is the point.
--
-- 5. PROJECT-LEVEL DATES:
--      project_date_revisions=1 | field=site_start_date | label=Site start
--      | reason=Landlord licence to alter delayed | transient_cleared=true
--
-- 6. DELETION LEAVES A RECORD, with the name snapshotted:
--      delete_revision=Handover [deleted] was 2025-02-14
--
-- 7. RLS READ SCOPING (same user, same project, visibility flipped):
--      offteam_before_exclusion sees=1
--      offteam_after_exclusion can_see_project=false sees_revisions=0
--      anon_sees=0
--
-- 8. FUNCTION PRIVILEGES — no `=X/postgres` (the PUBLIC grant) on any new
--    function, which was the P0-1 failure mode:
--      baseline_programme            postgres=X | service_role=X | authenticated=X
--      programme_actor               postgres=X | service_role=X
--      record_key_date_revision      postgres=X | service_role=X
--      record_key_date_deletion      postgres=X | service_role=X
--      record_project_date_revision  postgres=X | service_role=X
--    get_advisors(security): NO anon_security_definer_function_executable lint
--    for any of them. baseline_programme raises the *authenticated* lint, which
--    is intentional — it is the RPC seniors call, and the senior check inside it
--    is the gate. The remaining lints (current_org_id, user_can_see_project,
--    reset_password_to_temporary, auth_leaked_password_protection) are the
--    pre-existing accepted exceptions.
--
-- 9. NOTHING COMMITTED. After every block: programme_revisions 0 rows,
--    baselined key dates 0, baselined projects 0, key dates still 159, projects
--    still 30, Kingfisher's first key date back at 2024-05-06, and zero rows
--    with a non-null transient context column on either table.
--
-- NOT VERIFIED FROM THE SANDBOX: the browser write paths themselves. The sandbox
-- cannot reach Supabase or the deployed Pages site, so the reason modal actually
-- reaching the database is Tom's live check — see the test list on the PR.
