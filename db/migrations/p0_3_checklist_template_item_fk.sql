-- =============================================================================
-- P0-3 — bind checklist answers to template rows by identity, not by position
-- Applied to tpxabhqsjngalilbznhz on 2026-07-29. Verification at the bottom.
-- =============================================================================
--
-- project_checklist_items keyed answers by (module_key, section_index, row_index)
-- with no FK to the template. Inserting one question into the middle of a
-- template silently shifted every saved status, note, stamp and sign-off below
-- it onto the wrong question. Nothing errored; the data just became quietly
-- wrong, including on signed-off tabs. Exposure spanned all 8 live templates
-- (244 template items).
--
-- ON DELETE RESTRICT is deliberate. Deleting a template question that has
-- recorded answers now fails loudly instead of silently destroying them, which
-- is the whole point of this fix. Note the consequence for template
-- maintenance: re-seeding a template in place (delete + re-insert) will now
-- error if any project has answered it, and must handle those answers
-- explicitly. Reversible to ON DELETE CASCADE if that proves too strict.

alter table public.project_checklist_items
  add column template_item_id uuid references public.module_template_items(id) on delete restrict;

-- Backfill using the positional key that was in force until now. Joined on
-- org_id as well, because module_template_items is unique on
-- (org_id, module_key, section_index, row_index) — without that predicate the
-- join becomes ambiguous the moment a second organisation exists.
update public.project_checklist_items p
   set template_item_id = t.id
  from public.module_template_items t
 where t.org_id       = p.org_id
   and t.module_key   = p.module_key
   and t.section_index = p.section_index
   and t.row_index    = p.row_index
   and p.template_item_id is null;

-- Refuse to proceed on a partial backfill rather than leave answers unbound.
do $$
declare unmatched int;
begin
  select count(*) into unmatched
    from public.project_checklist_items where template_item_id is null;
  if unmatched > 0 then
    raise exception 'P0-3 backfill incomplete: % answer row(s) match no template item', unmatched;
  end if;
end $$;

alter table public.project_checklist_items
  alter column template_item_id set not null;

alter table public.project_checklist_items
  add constraint project_checklist_items_project_template_key
  unique (project_id, template_item_id);

-- The positional key is retired as an identity. section_index / row_index
-- remain, as display order only, sourced from the template on every write.
alter table public.project_checklist_items
  drop constraint project_checklist_items_project_id_module_key_section_index_key;

-- =============================================================================
-- Verification recorded 2026-07-29 (per the plan's APPLIED discipline)
-- =============================================================================
--
-- 1. Appendix query E — template_item_id present:
--      id, org_id, project_id, module_key, section_index, row_index, status,
--      note, flag_id, action_id, updated_by, created_at, updated_at,
--      template_item_id
--
-- 2. Backfill total and correct: 6 rows, 0 unbound; every row's
--    template_item_id resolves to a template item whose (module_key,
--    section_index, row_index) equals the row's own -> "ok" x6.
--
-- 3. Constraints after:
--      project_checklist_items_project_template_key = UNIQUE (project_id, template_item_id)
--      project_checklist_items_template_item_id_fkey = FK -> module_template_items(id) ON DELETE RESTRICT
--      (positional UNIQUE (project_id, module_key, section_index, row_index) dropped)
--
-- 4. The defect itself is closed, demonstrated rather than asserted. Inserting
--    a new question mid-template inside a self-aborting DO block: the answer
--    previously at position 0/1 stayed bound to
--    "Does it meet the criteria: above 18m in height/consist of 7 storeys? ..."
--    before and after the shift. Pre-migration that answer would have moved
--    onto the inserted question. Nothing committed (0 test rows left behind,
--    244 template items unchanged).
--
-- 5. New write path exercised with the same ON CONFLICT target PostgREST uses
--    for upsert(..., { onConflict: 'project_id,template_item_id' }): the first
--    upsert added exactly one row, the second updated it in place with no
--    duplicate. Rolled back; 0 test rows remain.
--
-- 6. get_advisors(security) after the change: only the two accepted
--    current_org_id lints (RLS evaluates it as the invoking role) plus the
--    separate auth_leaked_password_protection toggle. No new lints; P0-1
--    remains closed.
