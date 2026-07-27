-- ============================================================
-- My Actions rework — PR1: audit spine + query thread/escalation schema + P0-1 fix
-- APPLIED to the live dev DB on 2026-07-27 (migrations `myactions_audit_spine`
-- + `myactions_audit_spine_p0_tidy`). Backfill: seed/2026-07-27-item-events-backfill.sql.
-- ============================================================

-- (A) P0-1 — close the live security hole. The SECURITY DEFINER helpers kept the
-- PUBLIC execute grant (=X/postgres) that anon/authenticated inherit, so anyone with
-- the public anon key could invoke them by RPC (forge audit rows, spam notifications).
-- Revoke from PUBLIC + the roles. Triggers keep firing (EXECUTE is checked at
-- CREATE TRIGGER time; nested calls run as the SECURITY DEFINER owner).
-- current_org_id() is deliberately LEFT granted — it only returns the caller's own
-- org id and RLS policies evaluate it as the invoking role. Its advisor WARN is the
-- accepted exception. (Verified after applying: get_advisors(security) lists only
-- current_org_id + the separate auth_leaked_password_protection toggle.)
revoke execute on function public.record_activity(uuid,text,uuid,uuid,text,text,text,jsonb,boolean) from public, anon, authenticated;
revoke execute on function public.notify_user(uuid,uuid,text,jsonb)      from public, anon, authenticated;
revoke execute on function public.project_audience(uuid)                 from public, anon, authenticated;
revoke execute on function public.actor_name()                           from public, anon, authenticated;
revoke execute on function public.audit_app_user_change()                from public, anon, authenticated;
revoke execute on function public.handle_new_auth_user()                 from public, anon, authenticated;
revoke execute on function public.set_org_id_on_insert()                 from public, anon, authenticated;
revoke execute on function public.notify_action_owner()                  from public, anon, authenticated;
revoke execute on function public.notify_collaborator()                  from public, anon, authenticated;
revoke execute on function public.notify_query_events()                  from public, anon, authenticated;
-- The actual audit trigger functions (the plan's "tidy the remainder" list named the
-- wrong ones; these are the real trigger-only functions surfaced by get_advisors).
revoke execute on function public.audit_actions()   from public, anon, authenticated;
revoke execute on function public.audit_flags()      from public, anon, authenticated;
revoke execute on function public.audit_key_dates()  from public, anon, authenticated;
revoke execute on function public.audit_meetings()   from public, anon, authenticated;
revoke execute on function public.audit_projects()   from public, anon, authenticated;

-- (B) item_events — the append-only audit spine for every item lifecycle change.
-- app_users.id == auth.uid(), so actor_id is forced to the logged-in user by the
-- INSERT policy: a member can only write events attributed to themselves. There are
-- deliberately NO update/delete policies, so nothing here can be edited or removed.
create table if not exists public.item_events (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid references public.organisations(id) on delete cascade,
  item_type  text not null check (item_type in ('action','flag','date')),
  item_id    uuid not null,
  event_type text not null check (event_type in
    ('raised','query','answer','counter','resolve','escalate','chase','complete',
     'reassign','date_change','convert','acknowledge','nudge','collaborator_add')),
  actor_id   uuid references public.app_users(id) on delete set null,
  subject_id uuid references public.app_users(id) on delete set null,
  body       text,
  created_at timestamptz not null default now()
);
create index if not exists item_events_item_idx on public.item_events (item_type, item_id, created_at);
alter table public.item_events enable row level security;
create policy "item events scoped to org" on public.item_events
  for select using (org_id = current_org_id());
create policy "members append truthful item events" on public.item_events
  for insert with check ((org_id = current_org_id() or org_id is null) and actor_id = auth.uid());
create trigger trg_item_events_set_org
  before insert on public.item_events for each row execute function set_org_id_on_insert();

-- (C) action_queries — add the thread status + escalation columns (keep existing shape).
alter table public.action_queries add column if not exists status        text not null default 'open';
alter table public.action_queries add column if not exists escalated_to  uuid references public.app_users(id) on delete set null;
alter table public.action_queries add column if not exists escalated_by  uuid references public.app_users(id) on delete set null;
alter table public.action_queries add column if not exists escalated_at  timestamptz;
alter table public.action_queries add column if not exists resolved_at   timestamptz;
alter table public.action_queries add column if not exists resolved_by   uuid references public.app_users(id) on delete set null;

-- (D) action_query_messages — the capped ping-pong thread (question / answer / counter).
-- author_id forced to the caller by the INSERT policy; immutable (no update/delete policy).
create table if not exists public.action_query_messages (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid references public.organisations(id) on delete cascade,
  query_id   uuid not null references public.action_queries(id) on delete cascade,
  author_id  uuid references public.app_users(id) on delete set null,
  kind       text not null check (kind in ('question','answer','counter')),
  body       text not null,
  created_at timestamptz not null default now()
);
create index if not exists aqm_query_idx on public.action_query_messages (query_id, created_at);
alter table public.action_query_messages enable row level security;
create policy "query messages scoped to org" on public.action_query_messages
  for select using (org_id = current_org_id());
create policy "members append own query messages" on public.action_query_messages
  for insert with check ((org_id = current_org_id() or org_id is null) and author_id = auth.uid());
create trigger trg_aqm_set_org
  before insert on public.action_query_messages for each row execute function set_org_id_on_insert();

-- (E) actions — a source discriminator for the provenance chip (From meeting/module/…).
alter table public.actions add column if not exists source_type text
  check (source_type in ('meeting','module','project','flag','date','manual'));
alter table public.actions add column if not exists source_ref text;

-- (F) meeting_handoffs — record the acknowledgement note against the flag.
alter table public.meeting_handoffs add column if not exists acknowledged_note text;