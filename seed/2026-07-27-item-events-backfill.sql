-- ============================================================
-- One-time backfill of the item_events audit spine from existing timestamps,
-- so historical actions/flags aren't blank in the new site-wide item modal.
-- APPLIED to the live dev DB on 2026-07-27 (71 events: 35 action-raised,
-- 15 action-complete, 13 flag-raised, 6 flag-acknowledge, 2 flag-convert).
-- Runs as service role (RLS bypassed), so actor_id is set explicitly rather
-- than forced to auth.uid() the way live app inserts are.
-- ============================================================

-- Provenance discriminator for the action card's source chip.
update public.actions a set source_type = case
    when exists (select 1 from public.meeting_handoffs h where h.resulting_action_id = a.id) then 'flag'
    when a.meeting_id is not null then 'meeting'
    else 'manual' end
where a.source_type is null;

insert into public.item_events (org_id, item_type, item_id, event_type, actor_id, body, created_at)
select org_id, 'action', id, 'raised', coalesce(created_by, owner_user_id), 'Action raised', created_at
from public.actions;

insert into public.item_events (org_id, item_type, item_id, event_type, actor_id, body, created_at)
select org_id, 'action', id, 'complete', completed_by, coalesce(nullif(completed_note,''),'Completed'), completed_at
from public.actions where completed_at is not null;

insert into public.item_events (org_id, item_type, item_id, event_type, actor_id, body, created_at)
select org_id, 'flag', id, 'raised', created_by, note, created_at
from public.meeting_handoffs;

insert into public.item_events (org_id, item_type, item_id, event_type, actor_id, body, created_at)
select org_id, 'flag', id, 'acknowledge', acknowledged_by, coalesce(nullif(acknowledged_note,''),'Acknowledged'), acknowledged_at
from public.meeting_handoffs where acknowledged_at is not null and resulting_action_id is null;

insert into public.item_events (org_id, item_type, item_id, event_type, actor_id, subject_id, body, created_at)
select org_id, 'flag', id, 'convert', acknowledged_by, null, 'Converted to an action', coalesce(acknowledged_at, created_at)
from public.meeting_handoffs where resulting_action_id is not null;

-- ------------------------------------------------------------
-- Migrate the 4 existing action_queries into the polymorphic `queries` model
-- (design addendum Amendment 1), with their thread messages and audit events.
-- The legacy action_queries table is left in place until the app cuts over.
-- ------------------------------------------------------------
insert into public.queries (org_id, parent_type, parent_id, project_id, raised_by, target_user_id,
                            status, resolved_at, resolved_by, created_at)
select aq.org_id, 'action', aq.action_id, a.project_id, aq.raised_by, aq.target_user_id,
       case when aq.answered_at is not null then 'resolved' else 'open' end,
       aq.answered_at, aq.answered_by, aq.raised_at
from public.action_queries aq join public.actions a on a.id = aq.action_id;

insert into public.query_messages (org_id, query_id, author_id, body, created_at)
select q.org_id, q.id, aq.raised_by, aq.query_text, aq.raised_at
from public.action_queries aq
join public.queries q on q.parent_type='action' and q.parent_id=aq.action_id and q.created_at=aq.raised_at
where nullif(aq.query_text,'') is not null;

insert into public.query_messages (org_id, query_id, author_id, body, created_at)
select q.org_id, q.id, aq.answered_by, aq.answer_text, aq.answered_at
from public.action_queries aq
join public.queries q on q.parent_type='action' and q.parent_id=aq.action_id and q.created_at=aq.raised_at
where aq.answered_at is not null and nullif(aq.answer_text,'') is not null;

insert into public.item_events (org_id, item_type, item_id, event_type, actor_id, body, created_at)
select org_id, 'query', id, 'raised', raised_by, 'Query raised', created_at from public.queries;
insert into public.item_events (org_id, item_type, item_id, event_type, actor_id, body, created_at)
select org_id, 'query', id, 'resolve', resolved_by, 'Query resolved', resolved_at
from public.queries where status='resolved' and resolved_at is not null;