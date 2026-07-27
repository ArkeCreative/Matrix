-- My Actions rework PR5 — retire the legacy single-answer query table.
-- APPLIED to the live dev DB on 2026-07-27 (migration `drop_legacy_action_queries`).
--
-- action_queries was the pre-rework query store (one question + one answer per row).
-- PR1 introduced the polymorphic `queries` + `query_messages` tables and migrated its
-- rows in; PR5 repointed the last writer (the meeting-detail action rows) onto the new
-- tables, so nothing reads or writes action_queries any more. Safe to drop.
drop table if exists public.action_queries cascade;