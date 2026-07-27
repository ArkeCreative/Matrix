-- ============================================================
-- My Actions rework — PR1: audit spine + first-class polymorphic queries + P0-1 fix
-- APPLIED to the live dev DB on 2026-07-27 (migrations `myactions_audit_spine`,
-- `myactions_audit_spine_p0_tidy`, `myactions_queries_polymorphic`).
-- Data migration / backfill: seed/2026-07-27-item-events-backfill.sql.
--
-- This file is the clean, final DDL. On the live DB the query tables were first
-- built as an action_queries extension, then reworked to the polymorphic form below
-- (design addendum Amendment 1); a fresh apply just creates the final shape directly.
-- ============================================================

-- (A) P0-1 — close the live security hole. The SECURITY DEFINER helpers kept the
-- PUBLIC execute grant (=X/postgres) that anon/authenticated inherit, so anyone with
-- the public anon key could invoke them by RPC (forge audit rows, spam notifications).
-- Revoke from PUBLIC + the roles. Triggers keep firing (EXECUTE is checked at
-- CREATE TRIGGER time; nested calls run as the SECURITY DEFINER owner).
-- current_org_id() is deliberately LEFT granted — it only returns the caller's own
-- org id and RLS evaluates it as the invoking role. Its advisor WARN is accepted.
-- (Verified: get_advisors(security) lists only current_org_id + auth_leaked_password_protection.)
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
revoke execute on function public.audit_actions()                        from public, anon, authenticated;
revoke execute on function public.audit_flags()                          from public, anon, authenticated;
revoke execute on function public.audit_key_dates()                      from public, anon, authenticated;
revoke execute on function public.audit_meetings()                       from public, anon, authenticated;
revoke execute on function public.audit_projects()                       from public, anon, authenticated;

-- (B) item_events — the append-only audit spine for every item lifecycle change,
-- across all four item types (action, flag, date, query). app_users.id == auth.uid(),
-- so actor_id is forced to the logged-in user by the INSERT policy: a member can only
-- write events attributed to themselves. No update/delete policies → tamper-evident.
create table if not exists public.item_events (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid references public.organisations(id) on delete cascade,
  item_type  text not null check (item_type in ('action','flag','date','query')),
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

-- (C) queries — first-class, POLYMORPHIC item type (design addendum Amendment 1).
-- A query is raised against an action, a flag or a key date. parent_type uses the
-- modal's kind vocabulary (action/flag/date) so parent_id feeds openItem(parent_type,
-- parent_id) with no mapping layer. One open query per parent, enforced by a partial
-- unique index. resolution_note is mandatory on resolve (enforced in the app).
create table if not exists public.queries (
  id             uuid primary key default gen_random_uuid(),
  org_id         uuid references public.organisations(id) on delete cascade,
  parent_type    text not null check (parent_type in ('action','flag','date')),
  parent_id      uuid not null,
  project_id     uuid references public.projects(id) on delete cascade,
  raised_by      uuid references public.app_users(id) on delete set null,
  target_user_id uuid references public.app_users(id) on delete set null,
  status         text not null default 'open' check (status in ('open','resolved')),
  escalated_to   uuid references public.app_users(id) on delete set null,
  escalated_by   uuid references public.app_users(id) on delete set null,
  escalated_at   timestamptz,
  resolved_at    timestamptz,
  resolved_by    uuid references public.app_users(id) on delete set null,
  resolution_note text,
  created_at     timestamptz not null default now()
);
create unique index if not exists queries_one_open_per_parent
  on public.queries (parent_type, parent_id) where status = 'open';
create index if not exists queries_parent_idx  on public.queries (parent_type, parent_id);
create index if not exists queries_project_idx on public.queries (project_id);
alter table public.queries enable row level security;
create policy "queries scoped to org" on public.queries
  for select using (org_id = current_org_id());
create policy "members raise queries" on public.queries
  for insert with check ((org_id = current_org_id() or org_id is null) and raised_by = auth.uid());
create policy "members update queries" on public.queries
  for update using (org_id = current_org_id()) with check (org_id = current_org_id());
create trigger trg_queries_set_org
  before insert on public.queries for each row execute function set_org_id_on_insert();

-- (D) query_messages — the capped ping-pong thread (question / answer / counter derived
-- from author + position; not cached as a column). Immutable; author forced to the caller.
create table if not exists public.query_messages (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid references public.organisations(id) on delete cascade,
  query_id   uuid not null references public.queries(id) on delete cascade,
  author_id  uuid references public.app_users(id) on delete set null,
  body       text not null,
  created_at timestamptz not null default now()
);
create index if not exists query_messages_query_idx on public.query_messages (query_id, created_at);
alter table public.query_messages enable row level security;
create policy "query messages scoped to org" on public.query_messages
  for select using (org_id = current_org_id());
create policy "members append query messages" on public.query_messages
  for insert with check ((org_id = current_org_id() or org_id is null) and author_id = auth.uid());
create trigger trg_qm_set_org
  before insert on public.query_messages for each row execute function set_org_id_on_insert();

-- NOTE: the legacy public.action_queries table is intentionally left in place — the
-- deployed app still reads/writes it until the app cuts over to `queries`, at which
-- point a later PR migrates any interim rows and drops it.

-- (E) actions — a source discriminator for the provenance chip (From meeting/module/…).
alter table public.actions add column if not exists source_type text
  check (source_type in ('meeting','module','project','flag','date','manual'));
alter table public.actions add column if not exists source_ref text;

-- (F) meeting_handoffs — record the acknowledgement note against the flag.
alter table public.meeting_handoffs add column if not exists acknowledged_note text;