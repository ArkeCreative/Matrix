# arke [matrix] — living dev plan (single source of truth)

This file is the master dev plan, versioned in the repo. Update it with every batch so it always
matches what's shipped. First actions for a new session: **load the `arke-design` skill**; the split
source (`shell-head.html` + `app.jsx` + `shell-tail.html` + `rebuild.sh`) is already in the repo.

> **Revision note (2026-07-26).** This version corrects one claim that was verifiably false against
> the live DB, adds a **P0 defect list** found by direct schema inspection, and folds in two
> structural additions: a **commercial spine** (Phase 4d) and a **baselined programme + delay record**
> (Phase 9). Read the P0 section before starting any feature work.
>
> **Revision note (2026-07-27).** Batch-2 checklist seed applied (Designer, Graphics, Legal Kick Off,
> Legal Process → **8 templates / 244 items live**), and WPB Kick Off, Onsite Handover and Accountant
> On Site were seeded then **removed at Tom's request** (niche operational tabs, not wanted as modules).
> Counts below re-verified against the live DB. **⚠ These batch-2 tabs were seeded *before* P0-3 was
> addressed** — no data corruption occurred (whole new templates, no mid-template inserts), but the
> positional-binding risk now spans 8 templates instead of 4, so P0-3 is more urgent, not less.
> P0-1 re-verified still-open on 2026-07-27 (all four helpers retain the `=X/postgres` PUBLIC grant) —
> **since closed, 2026-07-27.** The positional-binding risk called out here (**P0-3**) was **closed
> 2026-07-29**: answers are now bound to `template_item_id`, so editing a template in place is safe.
>
> **Revision note (2026-07-29) — the plan is now ONE NUMBERED LIST.** Phases and letters (4d, 9a, P0-4b)
> were folding over each other and had stopped being useful to talk about. Everything still outstanding
> is now **Step 1 … Step 14** in build order under **▶ ROADMAP**, with a crosswalk from the old
> numbering. Work from Step 1 down. The sections above this line are the historical record and keep
> their original names — the crosswalk is how they map.
>
> **Revision note (2026-07-29) — Step 1 is done.** The programme baseline and delay record shipped:
> `programme_revisions` is accruing, so the clock that was running on this plan has stopped. Two
> things to know. **The record is append-only and trigger-written** — no API caller can forge, amend
> or erase a revision, which is the whole basis of its evidential value, so keep it that way.
> **No baseline was backfilled**, deliberately: a project shows no slip figure until a senior
> explicitly baselines it. **Step 2 is next.**
>
> **Revision note (2026-07-31) — lifecycle + dashboard handoff folded in.** Tom's design workshop
> produced a merged plan (**lifecycle unification + dashboard consolidation**), versioned at
> **`docs/handoff/`** and reviewed against the live code. It reshapes the middle of the roadmap:
> **Move 1** (canonical status vocabulary + CHECK constraints) rides **Step 3**; a new **Step 2.5** is
> the lifecycle *seam* (one service layer, one openness predicate, one visual contract) and a hard
> prerequisite; **Step 4** becomes the role-gated **Dashboard**, built as a consumer of that seam;
> **Move 5** (provenance/`threadOf`) pays off in **Step 5**. Build order: **3 → 2.5 → 4**. The prior
> ⚑ WORKSHOP placeholder is closed — this handoff is its output.

## What this is
Internal PM web app for **Arke Creative** (commercial office design & fit-out). Rebranded/
re-platformed from *BixFrame*. Real, deployed tool with a live DB. Live:
https://arkecreative.github.io/Matrix/ (auto-deploys on merge to `main`, ~1 min + CDN).

## Current state — verified & live
- **Repo** `ArkeCreative/Matrix` (public), trunk `main`, GitHub Pages. Base each new batch fresh from
  `origin/main` on a new feature branch.
- **Supabase** `matrix` = `tpxabhqsjngalilbznhz`, eu-west-2, PG17. Anon key public by design (RLS
  is the guard). Schema changes via Supabase MCP (`apply_migration` DDL / `execute_sql` data);
  `service_role` key must never reach the repo.
- **29 tables** (re-counted 2026-07-29; the "24" carried here for weeks was stale), all RLS-enabled.
  `programme_revisions` was added by Step 1. Row counts **re-verified 2026-07-29**: projects 30,
  project_key_dates 159, meeting_entries 63, actions 36 (19 open), meeting_handoffs 13 (5 open),
  module_templates 8, module_template_items 244, project_checklist_items 6, queries 5, item_events 95.
  (2026-07-27 figures, not re-checked this batch: meetings 25, project_contacts 195,
  project_checklists 1, audit_log 5, notifications 43.)
- **Dev org** `dawlish` (`c6e9cc3c-…`), all fictional data. **No real Arke data yet** — deferred to the
  go-live gate (**Step 10**). Seed scripts are versioned under `seed/`. Project addresses were replaced
  with real central-London ones on 2026-07-29 (`seed/2026-07-29-real-london-addresses.sql`) so the map
  geocodes truthfully rather than confidently placing a pin in the wrong place.

## How the code works
- Single self-contained `index.html`; React 18 CDN; **pre-compiled JSX — write
  `React.createElement`, not JSX.** No build step.
- Inline style objects + palette `C` (carmine/prussian families, prussian **status ramp**,
  greyscale, ink0, success, warn; traffic-light green/amber/redStatus kept independent).
  Icons via inline `lucide(name,size,color,stroke)` (fixed path map — add new glyphs there). `FONT` const.
- Edit `app.jsx` → `./rebuild.sh` → must pass `node --check` **and** `new Function()` and report
  **0/0/0** paren/brace/bracket balance before it splices `index.html`. Never hand-edit `index.html`.

## Visual verification (sandbox can't reach Supabase/CDNs)
Live writes are stubbed, so interaction correctness on write paths is checked by Tom on the live app.
Render-only changes are verified with standalone Chromium screenshots (Playwright at
`/opt/pw-browsers/chromium-1194/chrome-linux/chrome`) built from the real palette + component markup.

## Git / PR workflow — follow exactly (we hit stranding bugs 4×)
Commit as `noreply@anthropic.com`, Tom reviews/merges. **One PR per _batch_ (a whole phase or a
logical group of slices), opened at the END once every commit is pushed.** This replaced the earlier
"one PR per slice" rule after slice 1 of Phase 3 merged as PR #26 while slices 2–5 were still being
pushed, stranding them (a merged PR never picks up later pushes). If work is stranded:
`git rebase origin/main` the unmerged commits onto the merged base, force-with-lease, open a **new**
PR. Each new batch starts on a **fresh branch off `main`**. Before merge: **PR head SHA == latest
commit**; after merge: **merge's 2nd parent == that commit** + deploy green. GitHub's merge commits
show "unverified" — expected, don't rewrite.

## Font licensing — RESOLVED
Gilroy `.otf`s (Light/Regular/SemiBold/Bold) are committed + embedded. **Tom confirmed the licence is
held — keep Gilroy as-is.** (Medium 500 not supplied; maps to Regular. Century Gothic → system-ui fallback.)

---

# ⛔ P0 — verified defects, fix before further feature work

All four were found by querying the live database on 2026-07-26. Re-verification queries are in the
appendix. **✅ ALL FOUR ARE NOW CLOSED AND VERIFIED** — P0-1 (2026-07-27), then P0-3, P0-2, P0-4a and
P0-4b (all 2026-07-29). The go-live gate (**Step 10**) is no longer blocked by a known defect; what
remains there is the behavioural RLS test pass and the go-live UI, not a hole to plug. The one piece of
P0-4 still outstanding — operational *write* scoping — is now **Step 2**.

> **P0-1 — ✅ FIXED 2026-07-27** (folded into the My Actions rework PR1, `db/migrations/myactions_audit_spine.sql`).
> Revoked EXECUTE from `public, anon, authenticated` on all the helper + audit-trigger functions
> (`record_activity`, `notify_user`, `project_audience`, `actor_name`, the `notify_*`/`audit_*`
> trigger functions, `set_org_id_on_insert`, `handle_new_auth_user`). **Verified:** `proacl` now shows
> only `postgres`/`service_role`; `get_advisors(security)` returns just `current_org_id` (the accepted
> exception — returns the caller's own org id, RLS needs it) and the separate
> `auth_leaked_password_protection` toggle. P0-2/P0-3/P0-4 remain open.

### P0-1 — SECURITY DEFINER revoke never took effect (live security hole)  *(✅ fixed — see box above)*
The Phase 5 notes claimed *"SECURITY DEFINER helpers had direct-RPC EXECUTE revoked."* That is
**false as deployed.** `pg_proc.proacl` shows `record_activity`, `project_audience` and `notify_user`
lost their explicit `anon` / `authenticated` grants but **retain `=X/postgres`, the grant to
`PUBLIC`**, which `anon` and `authenticated` inherit. `get_advisors(security)` still flags all of
them. The revoke targeted the roles, not the source of the privilege. **Re-verified still-open
2026-07-27** — `proacl` on all four helpers still shows `=X/postgres` (and `actor_name` still carries
explicit `anon=X/postgres | authenticated=X/postgres` on top).

**Impact, today:** the anon key is baked into a world-readable Pages site. Anyone can
`POST /rest/v1/rpc/record_activity` and insert arbitrary rows into `audit_log` — including forged
actors and summaries — and fan them out as notifications to every senior. An audit log that
unauthenticated callers can write to has no evidential value, which undermines Phase 7 outright.

**Fix.** Revoke from `PUBLIC`, not from the roles:

```sql
revoke execute on function public.record_activity(uuid,text,uuid,uuid,text,text,text,jsonb,boolean)
  from public, anon, authenticated;
revoke execute on function public.notify_user(uuid,uuid,text,jsonb)  from public, anon, authenticated;
revoke execute on function public.project_audience(uuid)              from public, anon, authenticated;
revoke execute on function public.actor_name()                        from public, anon, authenticated;
-- tidy the remainder so the advisor goes quiet (all trigger-only functions):
revoke execute on function public.audit_app_user_change()   from public, anon, authenticated;
revoke execute on function public.handle_new_auth_user()    from public, anon, authenticated;
revoke execute on function public.set_org_id_on_insert()    from public, anon, authenticated;
revoke execute on function public.notify_action_owner()     from public, anon, authenticated;
revoke execute on function public.notify_collaborator()     from public, anon, authenticated;
revoke execute on function public.notify_query_events()     from public, anon, authenticated;
```

**This does not break the triggers.** Postgres checks `EXECUTE` on a trigger function at
`CREATE TRIGGER` time, not on each fire; and functions invoked *inside* a `SECURITY DEFINER` function
are checked against the definer (`postgres`), which retains the grant. Leave `current_org_id()`
granted — RLS policies evaluate it as the invoking role.

**Verify after applying:** re-run the `proacl` query in the appendix and confirm no `=X/postgres`
on those functions, then `get_advisors(security)` returns zero
`anon_security_definer_function_executable` lints for them.

> **P0-2 — ✅ FIXED 2026-07-29** (`db/migrations/p0_2_cross_org_containment.sql`, applied + verified).
> `project_audience()` and `record_activity()`'s null-project branch are now org-filtered, and the
> `notifications` policies carry `org_id = current_org_id()`.
> **⚠ Scope was widened after inspecting the live policy set — two further routes would have made a
> second org unsafe on their own:**
> - **`projects` / `meetings` INSERT checks had no org predicate.** `set_org_id_on_insert` only fills
>   `org_id` when NULL, so an explicit `org_id` in the request body passed straight through. Every
>   other org-scoped table already had `org_id = current_org_id()` in its INSERT check; these two were
>   the outliers. Now fixed.
> - **`app_users` "users edit self" was `USING/WITH CHECK (id = auth.uid())` with no column
>   restriction — and this one is exploitable *today*, with one org.** Any authenticated user could
>   update their own `org_id`, and `current_org_id()` is literally
>   `select org_id from app_users where id = auth.uid()` — a one-request move into another tenant,
>   after which every org-scoped policy in the database resolves to the new org. The same policy
>   allowed self-promotion to `role = 'senior'`. The app only ever sends name/initials/job title on a
>   self-edit, but that was a **client-side convention enforced nowhere** — the P0-4 pattern, on the
>   one table that controls tenancy. RLS cannot compare against `OLD`, so the invariant is now a
>   `BEFORE UPDATE` trigger (`enforce_app_user_field_guard`): `org_id`/`id` immutable through the API
>   for anyone; `role`/`department`/`is_team_lead`/`active` changeable only by an active senior in the
>   same org. No-JWT (service_role/migration) contexts pass through untouched.
>
> **Verified behaviourally, not asserted.** A self-aborting block stood up a second organisation,
> moved an active senior (deliberately one *not* on the project's team, so the all-seniors branch was
> their only route in) into it, then set `request.jwt.claims` to a real contributor's id to exercise
> the guard under an actual JWT: **audience 3 → 2**; foreign senior in audience **before=t, after=f**;
> self `org_id` change **blocked**; self role escalation **blocked**; legitimate rename **saved ok**
> (so the guard isn't over-broad). Rolled back clean — one org, 2 seniors, 0 stray rows.
> P0-1 re-verified still closed (`proacl` shows only `postgres`/`service_role` on all three
> functions); `get_advisors(security)` clean. **P0-4 remains open** — it is the Phase 6 rewrite.

### P0-2 — `project_audience()` has no org filter (cross-tenant leak, go-live blocker)  *(✅ fixed — see box above)*
Deployed body ends with:

```sql
union
select a.id from public.app_users a where a.role = 'senior' and a.active
```

No `org_id` predicate. It returns seniors of **every organisation**. `record_activity`'s
null-project branch has the same defect. `notifications` RLS is `user_id = auth.uid()` with **no org
check**, so the resulting rows are readable by the recipient.

This is invisible today because `dawlish` is the only org. **The moment the real `arke` org is
created, dawlish test activity notifies real Arke seniors and vice versa** — precisely the failure
mode the Phase 6 gate exists to prevent, sitting inside a function that currently looks correct.

**Fix.**

```sql
create or replace function public.project_audience(p_project uuid)
returns setof uuid language sql security definer set search_path to 'public' as $$
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
$$;
```

In `record_activity`, the else-branch becomes
`... from app_users a where a.role='senior' and a.active and a.org_id = p_org`.

Belt and braces on the notifications policies:

```sql
drop policy "own notifications read"   on public.notifications;
drop policy "own notifications update" on public.notifications;
create policy "own notifications read"   on public.notifications for select
  using (user_id = auth.uid() and org_id = current_org_id());
create policy "own notifications update" on public.notifications for update
  using (user_id = auth.uid() and org_id = current_org_id())
  with check (user_id = auth.uid() and org_id = current_org_id());
```

> **P0-3 — ✅ FIXED 2026-07-29** (`db/migrations/p0_3_checklist_template_item_fk.sql`, applied +
> verified; app write path switched in the same batch as RX-B). `template_item_id` added, backfilled
> (**6 rows, 0 unbound**, every row resolving to the question it was actually answering), set
> `NOT NULL`, `UNIQUE (project_id, template_item_id)` added and the positional
> `UNIQUE (project_id, module_key, section_index, row_index)` **dropped**. FK is **`ON DELETE
> RESTRICT`** — deleting a template question that has recorded answers now fails loudly instead of
> silently destroying them. **Consequence to know:** re-seeding a template in place (delete +
> re-insert) will now error if any project has answered it; handle those answers explicitly, or tell
> me to relax it to `CASCADE`.
> **Demonstrated, not asserted:** inserting a new question mid-template inside a self-aborting block
> left the answer at position 0/1 still bound to *"Does it meet the criteria: above 18m in height…"*
> before and after the shift — pre-migration it would have moved onto the inserted question. Nothing
> committed (0 test rows, 244 template items unchanged). `get_advisors(security)` shows no new lints.
> **P0-2 and P0-4 remain open.**

### P0-3 — checklist answers are bound to templates *positionally*  *(✅ fixed — see box above)*
`project_checklist_items` keys answers by `module_key` + `section_index` + `row_index`. There is no
FK to `module_template_items.id`. Templates are changing constantly (workshopped in Claude Design and
passed back). **The first time a row is inserted mid-template, every project's saved statuses, notes,
stamps and sign-offs below it silently shift onto the wrong questions.** Nothing errors; the data
just becomes quietly wrong, including on signed-off tabs.

**⚠ 2026-07-27 update:** batch 2 seeded four more templates (8 live, 244 template items) *before* this
fix. No corruption occurred — the batch added whole new templates, not rows inside existing ones, so
no answer shifted. But the exposure now spans **8 templates**, and every future "insert one question
into an existing tab" is a live corruption risk. There are still only **4 rows in
`project_checklist_items` across 1 checklist**, so the migration itself is still trivially cheap. Do
it before any template is edited in place.

**Fix.** Add `template_item_id uuid references module_template_items(id)`, backfill by matching
`(module_key, section_index, row_index)` against the template, make it `not null`, add a unique
constraint on `(project_id, template_item_id)`, and switch the component's read/write path to join on
it. Keep `section_index` / `row_index` as display-order only, sourced from the template.

> **P0-4a — ✅ FIXED 2026-07-29** (`db/migrations/p0_4a_project_write_authority.sql` + app.jsx).
> `projects` and `meetings` UPDATE are now senior-only at the database, not by convention.
> **⚠ Correction to the claim below:** P0-4 says these controls are "enforced in JavaScript". For the
> project **name, number and address** inline fields on the Projects list they were **not enforced in
> JavaScript either** — `ProjectRow` uses `isSenior` exactly once, to gate the status control. Any
> contributor could rename any project from the Projects list, and it saved. A live defect, not merely
> a weak control.
> **Verified** under real JWTs for both roles in a self-aborting block: contributor rename → **0 rows**;
> senior rename → **1 row**; rolled back.
> **The failure mode drove an app change in the same batch:** a policy-filtered UPDATE returns from
> PostgREST as *success with zero rows*, not an error. `updateProjectField`/`updateProjectFields` only
> threw on `error`, so a refused edit would have applied optimistically, shown "saved", and silently
> reverted on reload. Both now `.select('id')` and treat an empty result as a refusal — undoing the
> optimistic edit via `refreshProjects()` (the RX loader) and telling the user. `ProjectRow`'s three
> inline inputs are `readOnly` for non-seniors.
> **P0-4b remains open** — see the box in Phase 6.

### P0-4 — role enforcement is client-side only (scope correction, not a same-day fix)  *(part a fixed — see box above)*
Every RLS policy on the operational tables is **org-scoped, not role- or project-scoped**. Notably
`members edit projects` is `USING (org_id = current_org_id())` for `UPDATE` — so **any authenticated
org member can update any project**, including `status`, `name`, `secured` and the team FK columns.
The same pattern applies to `meeting_handoffs` (an `ALL` policy), `project_key_dates`,
`project_contacts` and the checklist tables.

Everything the plan describes as "senior-only" — team assignment, inline status/name/number editing,
the closed-meeting acknowledgement block — is enforced **in JavaScript in a public single-page app**.
It is a UI convention, not a control.

For a 13-person internal tool with fictional data that is arguably tolerable. It is **not** tolerable
as the foundation Phase 6 sits on. **Correct the Phase 6 estimate accordingly:** it is not a UI layer
over working policies, it is a rewrite of the operational policy set (senior-vs-contributor predicates
plus a per-project visibility join), and the behavioural RLS test must be written against the *new*
policies, not the current ones. Record this now so it isn't discovered at the gate.

### Discipline change that follows from P0-1
The plan's ✅/APPLIED marks are self-reported by the session that did the work. One of them was
wrong. **From now on: no item is marked APPLIED without a verification query recorded next to it,
and every batch re-runs the appendix queries.** Assume any unverified claim in this file may be stale.

---

# 🔍 Review findings — site-wide pass (Claude-in-Chrome, 2026-07-27)

An external click-through of the deployed app. The good news it confirmed: the **single-source-of-truth
chain works** — data written in a deep module checklist propagates to project KPIs, the Actions & Flags
tab, and the global Register (on reload). The findings below harden and extend that. Renamed off the
review's P-numbers into where they land in this plan; test artefacts it left (a "TEST FLAG (Claude)…"
on #2305 and a "Claude Test Consultancy / Jane Tester" directory row) were **cleaned from the dev DB**.

### RX — Live aggregate reactivity  *(✅ BUILT 2026-07-29 — see box below)*
Aggregated views didn't update in place — they only refreshed on a full page reload. Raise a flag from
a checklist and the toast fired, but the project's Open Flags KPI, the Actions & Flags tab, and the
Register counts stayed stale until reload. **This directly undercut the "single source of truth, live"
pitch** — the propagation was correct, but it wasn't *reactive*.

> **✅ RX APPLIED 2026-07-29** (app.jsx only, no schema change). Approach chosen with Tom: a shared
> **live data bus** with **auto-emit at the Supabase client boundary**, plus focus revalidation.
> Verification recorded below.

**Root cause — corrected against the source.** The review's guess (prop-drilled callbacks + siblings
holding their own copies) was half right, and the real shape made RX *smaller* than assumed:
- **The shared store already existed.** `Dashboard` holds `projects / users / meetings / latestNotes /
  keyDates / projectActions / projectFlags / notifications`, and Tracker, Register, Live Tracker,
  Meetings and Project Dashboard all read them **as props** — already reactive to it. The job was
  making writes reach the store, not building one.
- **There was no flags refresher at all.** `projectFlags` was fetched exactly once, in the mount effect,
  and nothing re-ran it — ever. Every other resource had a refresher; flags didn't. That single
  omission *was* the headline repro, since the front-page indicator, the project Open Flags KPI, the
  Register count and the inline detail pane all read that one frozen array.
- **`ItemModal` had no change callback.** Mounted at the app root (so `openItem` needs no prop-drilling)
  with no way to signal a write — and since PR5 it is the primary write surface app-wide (~12 write
  sites: complete, resolve/escalate/answer query, acknowledge, convert, reassign, move date). Not
  fixable by prop-drilling; that's the whole point of `openItem`.
- **"Last updated" staleness, same root:** projects were loaded once and thereafter only mutated
  optimistically in memory, so DB-written `updated_at` / `last_updated_by` and other users' edits never
  appeared.

**What shipped.**
- **`dataBus`** (module-level, ~60 lines, same pattern as the `_openItemHandler` registry PR2 proved):
  `subscribe(topics, fn)` / `emit(topics)` over resource topics (`projects · actions · flags · dates ·
  notes · meetings · queries · events · notifications · checklists · contacts · users`). Emits coalesce
  on a 120 ms trailing flush, and a subscriber registered on several invalidated topics runs **once**
  per flush.
- **Auto-emit publisher:** `sb.from(table)` is wrapped so `insert / upsert / update / delete` emit that
  table's topics when the write returns clean. **Reads are untouched**, so a subscriber's refetch can
  never re-trigger the bus. Zero call-site edits — and future write paths are reactive by construction.
  `sbQuiet` is the raw non-emitting client, used **only** for the debounced per-field project save,
  where the row is already applied optimistically and a refetch would race the debounce.
- **`useLiveData(topics, loader)`** — subscribes any component's own loader, at any depth, wherever it's
  mounted. Wired to: the 8 Dashboard loaders (including the two new ones, **`refreshProjectFlags`** and
  **`refreshProjects`**); `ItemModal` (silently — `load(silent)` now skips the spinner, which also
  removes the flash that followed every modal action before); `MyActionsView`; `ProjectDashboardView`'s
  module rings + Completed catalogue.
- **Focus/visibility revalidation** (30 s throttle) replaces the hand-maintained per-view refresh table,
  which covered notes/actions/meetings/dates and silently never covered flags or projects at all. View
  switches revalidate on the same throttle. `refreshProjects` keeps the local row for any project with a
  save still in flight, so a refetch can't overwrite mid-edit state.

**Deliberately not subscribed — editors holding unsaved user input.** `ChecklistModule` (unsaved
RES/AWT/INFO/N-A answers) and `MeetingDetailView` (notes being typed) would have their in-progress edits
clobbered by a refetch. Their *writes* publish normally, so every aggregate goes live; only their own
re-read is deferred.
> **Update 2026-07-29 (RX-B, then RX-C).** `ChecklistModule` now **does** subscribe, behind a
> pending-work guard (re-reads only when nothing is queued, in flight or seconds old). RX-C then went
> further and made the checklist **auto-save** outright, so the original prediction in this box — that
> RX-B would remove the unsaved state — ended up true only after RX-C, not after RX-B.
> `MeetingDetailView` is still unsubscribed and needs its monolithic loader split before it can be.

**Not done, deliberately:** Supabase **Realtime**. It's the natural second publisher into the same bus
(one `postgres_changes` channel → `emit`), and the bus is what makes it a small change — but it needs
the realtime publication + RLS verified, and it doesn't address the actual complaint (your own write, in
your own tab). Revisit when two users are genuinely concurrent.

**Verification (2026-07-29).** `./rebuild.sh` PASS/PASS, balance **0/0/0**. The publisher is the
load-bearing piece, so it was unit-tested against a mock PostgREST builder rather than assumed —
`10/10 passing`: a write emits its table's topic; `insert().select().single()` (the PR2 write style)
keeps the patched thenable and returns the real result; **reads emit nothing**; a **failed** write emits
nothing; three writes → each affected topic refreshes exactly once; two writes to one table → one
refresh; a multi-topic subscriber runs once per flush; `sbQuiet` emits nothing; a throwing subscriber
can't block the others. Live row counts confirming refetch cost is trivial: projects 30 · actions 36
(19 open) · handoffs 13 (5 open) · key_dates 159 · meeting_entries 63 · queries 5 · item_events 95 ·
project_checklist_items 5 — **~460 rows across every aggregate**.
- **Acceptance (Tom, on the live app):** raising/resolving a flag moves the project KPI + Register count
  immediately, no reload.

### RX-B — Checklist save atomicity  *(✅ APPLIED 2026-07-29, paired with P0-3)*
Flags persisted the instant they were raised, but checklist RES/AWT/INFO/N-A answers persisted only on
explicit **Save checklist**. Navigate away and the answer was discarded — orphaning a flag that pointed
at a row now showing no answer. **Invariant now enforced: no persisted flag/action may have an unsaved
source row.**

Shipped as recommended option (a): `ChecklistModule.confirmRoute` writes the flag/action *and* upserts
that single `project_checklist_items` row in the same step, via a new `persistRow(row, patch)` helper
that also carries the note captured in the routing modal. The row's **baseline moves with it**, so a
row saved this way stops counting as a pending edit while genuinely-unsaved rows still do. Toasts now
read "… · row saved" so the user can see it happened.

Also in this batch, since both touch the same write path: the module's in-memory answer map is **keyed
by `template_item_id`** rather than `section_index + ':' + row_index` (P0-3), the save upsert targets
`onConflict: 'project_id,template_item_id'`, and `rowPayload()` centralises the row shape so the two
write paths can't drift. `section_index` / `row_index` are still written, as display order sourced from
the template.

**Reactivity gap now closed too.** `ChecklistModule` subscribes to the bus (`checklists · actions ·
flags`) **behind a pending-work guard** — it re-reads when a flag or action changes underneath it, and
never while a save is queued, in flight, or seconds old. `MeetingDetailView` remains unsubscribed — its
monolithic loader would clobber notes being typed; it needs the same treatment separately.

#### ▶ RX-C — checklist auto-save  *(✅ APPLIED 2026-07-29, Tom's call after using RX-B)*
Tom, on the deployed app: *"clicking info required on one line didn't retain the information when
clicking away without saving."* Correct, and it exposed something worse — **RX-B had made the checklist
half auto-saving**: a row you raised a flag from saved itself, an identical row you merely answered did
not. Same click, two outcomes depending on what you did next. The checklist was also the *only* surface
in the app still asking the user to remember to save; project fields, meeting notes, actions, flags and
queries all persist themselves.

**Decision (Tom, offered three options): full auto-save per row.** The Save/Discard pair is gone.
- **Status clicks write immediately** — a discrete, deliberate fact, and re-clicking the active status
  clears it, so a mis-click costs nothing.
- **Notes debounce at 1200ms** (the same constant the project-field save uses) **and flush on blur**.
- **Sign-off stays an explicit button** — that one *is* a commitment.
- Save/Discard replaced by a **save-state bar**: amber dot "Saving…", green tick "All changes saved"
  (self-clearing after 2.5s), or a red dot with the error and a **Retry** — a failed write is put back
  on the queue, never dropped, so the answer survives on screen and retries on the next edit or click.
- **Clearing an answer deletes the row** rather than storing a row of nulls (the old batch save filtered
  empties out; the table shouldn't start collecting them now every click writes).
- Flushes on **blur, module-back, unmount, tab-hide and beforeunload**. `visibilitychange` is the
  reliable one — a write started in `beforeunload` is often cancelled by the browser.
- Answers are held in a **ref mirror** as well as state, so two fast keystrokes can't read a stale map.

**Verification (2026-07-29).** `./rebuild.sh` PASS/PASS, **0/0/0**. Both new write shapes exercised
against the live DB in self-aborting blocks: a **status-only click on a previously unanswered row**
added exactly one row with the right status, and **clearing it removed the row**, returning the count
to its starting value. Nothing committed.

**Verification (2026-07-29).** `./rebuild.sh` PASS/PASS, balance **0/0/0**. The new write path was
exercised against the live DB with the same `ON CONFLICT (project_id, template_item_id)` target
PostgREST generates: first upsert added exactly one row, second updated in place with no duplicate,
rolled back with 0 test rows remaining. Live-interaction check is Tom's per the workflow.

### Surface-bug sweep  *(one small batch PR — quick wins)*
- **Key Dates expander is dead** — on project Overview the `KEY DATES ›` chevron and "Expand key dates"
  link do nothing; the dates never reveal. **⚠ Probably already fixed — awaiting Tom's repro.**
  Re-traced 2026-07-29: the wiring is correct (`onClick: () => setKdOpen(v => !v)` on the whole header
  row, `kdOpen && …` body, in `constructionCard` on the Overview tab), and the Pages deploy of `6a420af`
  is green with #45's defensive empty-state shipped. **Hypothesis:** before #45, an expander opening
  onto an empty `myKeyDates` rendered *nothing at all* — indistinguishable from a dead chevron. #45's
  "No key dates recorded for this project yet." placeholder would make the same click now look like it
  works. To settle it we need the project it was seen on + the account role; if it's still inert there
  with real dates on screen, it's a different bug. (The sandbox can't confirm on the live app: the
  network policy blocks `arkecreative.github.io`, and the page needs auth to render.)
- **Register nav + deep-link** — the top-nav "Register & activity" link often needs two clicks (first
  lands on Projects), and `#/register` isn't deep-linkable (loads Projects on refresh). Register the
  route + fix the first-click resolve.
- **Modal survives resize** — resizing the window with the Flag modal open collapses the viewport to a
  strip until a route change; recompute layout / release the overlay on resize.
- **Directory role required** — a contact saved with no Role won't feed the role-based module
  people-pickers (the Directory's whole purpose). Require a role before commit (or mark roleless rows
  and exclude them). **Also verify the forward promise** the review couldn't confirm: a newly-added,
  properly-roled contact actually appears in a module people-field.

### Exec-facing enhancements  *(schedule into Phase 7 — the executive health view)*
- **Attribution + ageing on every flag/action** — many read "System"-raised and some are undated; show
  who raised it and when, with a consistent SLA/ageing colour. **The My Actions rework already built
  the substrate** (`item_events` = who/when, append-only; the flag age-clock pattern). This is now
  mostly surfacing that data everywhere flags/actions render, + backfilling actor attribution.
- **Interactive Live Tracker** — click a bar to open that project; render flag / overdue / key-date
  markers on the bars. It's the natural exec landing page but is read-only today. → **Phase 7** (also
  wire `openItem` here, a deferred PR5 item).
- **Register portfolio strip** — a summary band atop the Register (flags by team, actions by owner,
  overdue trend) to complement the By-person / By-project grouping. → **Phase 7**.
- **Excel programme import** — bump priority; "the feature most likely to get people off the
  spreadsheet." Already the **cross-cutting** item below — needs the serverless proxy (same gap as the
  deferred My-Actions scheduler). WORKSHOP the proxy once, unblocks both.

### Regression guard  *(WORKSHOP — no test harness exists yet)*
After RX lands, add a test that runs the full cross-reference chain in one pass, no reloads: edit a
project field → confirm in the Projects list; raise a flag from a checklist → confirm on the project
KPI, the Actions & Flags tab, and the Register count; resolve → confirm all three decrement. This chain
*is* the product promise. The app is a single self-contained `index.html` with no build/test step, so
the harness is a decision: **Playwright E2E against the deployed app** (fits the existing standalone
Chromium tooling) is the most likely fit — decide before writing it.

### Suggested sequence
1. ✅ **Surface-bug sweep** (PR #45) and ✅ **RX live reactivity** (2026-07-29) — both shipped.
2. ✅ **RX-B checklist atomicity + P0-3** (2026-07-29), then ✅ **RX-C checklist auto-save**
   (2026-07-29, Tom's call after using it) — the Save button is gone; every answer persists itself.
   `MeetingDetailView` is the one view still unsubscribed; splitting its monolithic loader is a small
   follow-up.
3. ✅ **P0-2** cross-org containment and ✅ **P0-4a** project write authority (both 2026-07-29).
   **P0-4b** (per-project visibility) is the last P0 open, and is blocked on the team-model decision.
4. **Phase 7 exec view** absorbs attribution/ageing, interactive Live Tracker, the Register strip.
5. **Programme import** once the serverless proxy is workshopped (also unblocks timed auto-escalation).
6. **Regression guard** after RX, to lock the chain.

---

## ✅ DONE
- **Phase 1 — Colour & visual reset.**
- **Phase 2 — Project data spine & quick-win UX** (secured toggle, promoted programme dates, inline
  senior editing, people model `job_title`+`is_team_lead`, re-openable actions).
- **Design revamp** — Projects List View, inline ProjectDetail, Programme timeline, Project Detail
  Page, Live Tracker.
- **Phase 3 — Meetings workflow & flag integrity** (PR #26 + #27, both merged/live): closed-meeting
  flag integrity (resolved the Westlake mystery); in-meeting rail indicators; edit project status
  from within a meeting; "no team member assigned" flag warning + link; meetings-list "Closed
  meetings" section + standardised closed-badge emboss.
- **Phase 4a/4c** (PR #28, merged/live): clickable metric tiles → catalogues (+ collapsible
  Completed); team-change data integrity (warn + offer reassign).

### ⚠ Fixed 2026-07-29 — people edits never reached the rest of the app
Reported by Tom: *"I changed Marcus' title on the org chart but that hasn't reflected in his profile
module top right."* Three separate causes, all now closed:
1. **`users` was fetched with an explicit column list that omitted `job_title`** (and `is_team_lead`,
   `manager_id`). Now `select('*')`.
2. **Nothing subscribed to the bus's `users` topic.** `app_users` writes emitted it and no one
   listened, so an org-chart save updated the database and nothing else. Added `refreshUsers`.
3. **`profile` was read once at sign-in and never again**, so the signed-in user's own header chip and
   profile could only change by logging out and back in. `refreshUsers` now propagates a changed
   self-row up through `onProfileUpdated`.
**Worse than reported, and found while fixing it:** `ProfileModal` resolved its target as
`users.find(...) || profile` — and *self is in `users`* — so it read the row that had no `job_title`.
Opening your own profile showed a blank job title, and clicking Save wrote that blank back over it.
Self now prefers the full `profile` record.

### Nav + chrome (2026-07-29, Tom)
- Ribbon tabs renamed: **My Actions → MY WORK**, **Register & activity → REGISTER**. Page headings
  and the "→ My Actions" cross-links moved with them; the routes (`#/actions`, `#/register`) and the
  `my-actions` / `register` view keys are unchanged, so nothing deep-linked breaks.
- The **arke [matrix] wordmark is now a link home** — clicking (or Enter/Space, it is focusable)
  clears the current project/meeting and returns to the Projects list, with a subtle hover fade.

### Carried over unshipped from PR12 feedback — confirm or close
- **Rename status `won` → `LTA`.** `org_statuses` still holds `value='won', label='Won'`. Either ship
  the label change (data-only, `org_statuses` is config) or strike the item.

---

## ▶ ROADMAP — one numbered list, in build order

**Work from Step 1 down.** Each step carries its own size, dependencies and status, so nothing needs
cross-referencing a phase letter any more. Restructured 2026-07-29 at Tom's request, because
"9a" and "4d" in the same breath had stopped being useful.

### Crosswalk — old numbering → new
Anything committed before 2026-07-29 uses the old scheme; this is how it maps.

| Old | Now |
|---|---|
| P0-1 · P0-2 · P0-3 · P0-4a · P0-4b | ✅ all closed 2026-07-27 → 29 |
| P0-4 leftover — operational write scoping | ✅ **Step 2**, done 2026-07-30 |
| RX · RX-B · RX-C (reactivity, checklist atomicity, auto-save) | ✅ done |
| Phase 4a / 4c — project detail, directory | ✅ done |
| Phase 4b — audit trail per user | ✅ absorbed into the Register hub |
| Phase 4d — commercial spine | **Step 6** |
| Phase 4 — register/log modules | **Step 8** |
| Phase 4 — agenda modules | **Step 9** |
| Phase 4 — checklist follow-ups | **Step 3** |
| Phase 5 — register & activity hub | ✅ done, bar the scheduler items → **Step 13** |
| Phase 6 — org & permissions | ✅ done, bar follow-ups → **Step 11** and go-live → **Step 10** |
| Phase 7 — executive health view | **split**: **Step 4** (buildable now) + **Step 7** (needs 1 and 6) |
| Phase 8 — schema cleanup | **Step 3** |
| Phase 9a — baseline schema | ✅ **Step 1**, done 2026-07-29 |
| Phase 9b — delay record views | **Step 5** |
| Map view · Organisation tab · project permissions | ✅ done |

---

### ▶ Step 1 — Programme baseline & delay record: schema  *(✅ **DONE 2026-07-29** — see box below)*
**This was the only item in the plan with a clock on it.** `project_key_dates` had a single mutable
`target_date`: when a date moved the previous value was **gone**. The trace was meant to be
`audit_log`, which held **exactly one `key_date` row in the entire database** — so there was nothing
to reconstruct from either. The accrual is now running; the views are Step 5.

> **✅ APPLIED 2026-07-29** — `db/migrations/step1_programme_baseline_and_revisions.sql`, applied to
> `tpxabhqsjngalilbznhz` and verified behaviourally. Full verification is recorded at the bottom of
> the migration file, per the P0-1 discipline.
>
> **Three scope decisions Tom took before the build:**
> 1. **The baseline freezes on an explicit senior action**, not silently on `secured = true`. A
>    baseline nobody chose to set is not evidence of anything.
> 2. **Schema + minimal capture UI**, not schema alone — cause only exists in someone's head at the
>    moment they move a date, so it has to be captured then or not at all.
> 3. **One `programme_revisions` table** covers key dates *and* the three project-level date columns,
>    so the Step 5 chronology export is a single ordered query rather than a union.
>
> **What shipped.**
> - Baseline columns on `project_key_dates` (`baseline_date`, `baseline_set_at`, `baseline_set_by`)
>   and on `projects` (three `*_baseline_date` columns + `programme_baselined_at` / `_by`).
> - **`programme_revisions`** — `subject_kind` (`key_date` / `project_date`), `key_date_id`,
>   `project_field`, **`subject_label`** (a *snapshot* of the name, so the record survives a rename or
>   a delete), `previous_date`, `new_date`, `change_kind` (`moved`/`set`/`cleared`/`deleted`),
>   `changed_by`, `changed_at`, `meeting_id`, `cause_flag_id`, `cause_action_id`, `reason`.
>   `org_id` + RLS from birth (the P0-2 lesson).
> - **Append-only and trigger-written.** There is a SELECT policy and *nothing else* — no INSERT,
>   UPDATE or DELETE policy, and the table privileges are revoked, so forging, amending or erasing a
>   revision through the API fails with a hard privilege error (42501), not a silent zero-row filter.
> - Triggers on `project_key_dates` UPDATE **and DELETE** (delete-and-recreate — what a re-import does
>   — would otherwise erase a milestone with no trace), and on the three `projects` date columns.
> - **`baseline_programme(uuid)`** — senior-gated at the database, atomic, and it **refuses to
>   overwrite an existing baseline**. A baseline that can be quietly re-set is not a baseline; agreed
>   re-baselining after an EOT is a Step 5 decision needing its own audited path.
>
> **How the cause is captured, since a trigger cannot know it.** A trigger sees only OLD and NEW.
> PostgREST has no per-request hook for a transaction-local GUC without an RPC, and an RPC would
> **bypass the RX bus's auto-emit** (which wraps `sb.from`, not `sb.rpc`) and silently break
> reactivity. So context rides in **transient `change_*` columns** the client sets in the *same UPDATE
> statement* as the new date; the trigger folds them into the revision and blanks them, so they are
> always NULL at rest. Verified: 4/4 transient columns null after a write, and a second move carried
> no stale context. `baseline_programme` is the one `sb.rpc` call, so it emits on the bus by hand.
>
> **No baseline was backfilled, deliberately.** Setting `baseline_date = target_date` across the 159
> existing rows would assert "this was always the plan" for dates that may already have slipped —
> inventing the exact history the migration exists to protect. Existing rows have a NULL baseline and
> no slip figure until somebody baselines them.
>
> **Defect found *during* verification, not after:** `changed_at` defaulted to `now()`, which is
> *transaction* time — two revisions written in one transaction shared a timestamp and the chronology
> could not order them. Changed to `clock_timestamp()`.
>
> **UI (minimal, by design).** A *Baseline this programme* control in the project CONSTRUCTION card
> (senior-only, confirms, shows who froze it and when); a **reason prompt** on every date move —
> key-dates list, programme timeline, and the two project-level date fields — with an optional link to
> an open flag or action as the cause. The reason is **optional on purpose**: forcing it produces "."
> and "update", not evidence, and would block typo corrections. A date moved inside a meeting is
> attributed to that meeting (`meetingId` threaded through `ProjectCapturePane`).
>
> **Follow-up, same session — the record is now visible.** The first cut shipped the capture with
> *no display at all*, on the reasoning that all views were Step 5. That was wrong, and Tom caught it
> immediately: he baselined a project, moved two key dates, gave reasons — and had nowhere to see any
> of it. A record nobody can read is one nobody can trust, or even confirm is working. So a
> **`ProgrammeHistory`** panel now sits at the foot of the project CONSTRUCTION card (shown to
> everyone; RLS scopes which revisions each person can read), in two deliberately separate blocks:
> - **AGAINST BASELINE** — for each baselined date, where it started vs where it is now, with a
>   +later / −earlier day chip and a net-movement line. Only appears once a project is baselined.
> - **EVERY CHANGE, MOST RECENT FIRST** — the full chronology from `programme_revisions`: from→to,
>   who, when, the reason (or an explicit "No reason recorded"), and the meeting / flag / action it
>   was linked to, resolved to readable labels. Subscribed to the RX bus (`dates`, `projects`), so it
>   updates live when a date moves. Open key-date rows also carry an inline `+Nd` / `−Nd` baseline
>   drift chip.
>
> **Still Step 5, genuinely deferred:** the per-project **PDF chronology export** (the EOT deliverable)
> and the portfolio-level slip roll-up. This panel is the in-app record; Step 5 is the document you
> hand a contractor and the cross-project view.

### ▶ Step 2 — Operational write scoping  *(✅ **DONE 2026-07-30** — see box below)*
The last piece of P0-4. Visibility was solved; *who may change what* was not — every operational write
policy was org-wide, so any member who could **see** a project could edit or delete any of its actions
and flags. The "senior/team-lead only" rules the app showed were JavaScript, not controls.

> **✅ APPLIED 2026-07-30** — `db/migrations/step2_operational_write_scoping.sql`, applied to
> `tpxabhqsjngalilbznhz` and verified behaviourally under real JWTs (recorded at the bottom of the
> migration). Landed on the same branch as the Step 1 follow-up (PR #62 was still open).
>
> **What narrowed:**
> - **`actions`** — UPDATE → owner / creator / collaborator / senior. DELETE → **creator or senior
>   only** (Tom's call: deleting is more destructive than editing; an assignee completes or declines an
>   action, they don't delete it). SELECT/INSERT unchanged.
> - **`meeting_handoffs`** — the blanket `ALL` split into four. Acknowledge/convert (UPDATE) is keyed to
>   the **target department's lead, a senior, or the raiser**. Delete is raiser-or-senior.
> - **`action_assignees`** — the blanket `ALL` split; managing collaborators now needs the same
>   authority as editing the parent action, so nobody who can already edit is newly refused.
>
> **Two facts corrected against the live DB.** The plan said "4 of 5 team leads are contributors" — it
> is **2 of 5** (Grace/furniture, Jen/pre-con); the principle held, a senior-only rule would still lock
> those two out. And the app gated acknowledge/convert on the **meeting chair**, not `is_team_lead` —
> but a policy cannot express "chair of the meeting I'm acting from" (a flag isn't bound to the acting
> meeting). So the meeting-pane gate was **realigned** to the same `{senior · target-dept lead ·
> raiser}` predicate as the DB, so UI and database agree and there's no silent zero-row revert. The
> `ItemModal` flag surface already used dept-lead authority, so it was left as-is.
>
> **Helpers added:** `is_active_senior()`, `is_dept_lead(text)`, `is_action_collaborator(uuid)` — all
> SECURITY DEFINER, PUBLIC grant revoked, granted to anon+authenticated (they're policy helpers, same
> accepted class as `current_org_id`/`user_can_see_project`; each returns only a boolean about the
> caller's own authority).
>
> **Defect found *during* verification:** the first `action_assignees` policies sub-queried
> `action_assignees` for the collaborator check — a policy reading its own table re-enters RLS and
> Postgres aborts with "infinite recursion detected". Fixed via `is_action_collaborator()` (definer),
> which reads the table past RLS.
>
> **Verified behaviourally.** actions UPDATE: random 0 / owner 1 / creator 1 / senior 1; DELETE: owner
> 0 / collaborator 0 / creator 1. handoffs ACT: random 0 / **contributor furniture-lead 1** (the
> load-bearing case) / raiser 1 / senior 1; DELETE: non-raiser lead 0 / senior 1. assignee-insert:
> unrelated blocked(42501) / creator 1. Nothing committed; `get_advisors` shows only the accepted
> policy-helper class. **NOT sandbox-verifiable:** the browser acknowledge/convert path — Tom's check.
>
> **Follow-up (2026-07-30), from Tom testing on the live app — two gaps the permission work exposed
> but did not itself cause:**
> - **The Register's per-row buttons were dead stubs.** *Acknowledge / Convert / Chase / Reassign /
>   Raise-a-query* all fired one "coming later" alert; only *Mark complete* / *Mark met* were wired.
>   The row-click already opened the working item modal (where those actions live and are audited), so
>   the buttons actively misled. **Removed** them — flags and not-yours actions now show a single
>   honest **Open** (opens the modal); the wired one-click actions stay. The dead `deferredRegisterAction`
>   stub is gone.
> - **Acknowledging in a meeting recorded unevenly.** The DB trigger writes the activity-log line on
>   any status→acknowledged (so it was never invisible), but the meeting-pane path skipped the flag's
>   own `item_events` timeline and captured no note, while the modal wrote both. **Fixed:** meeting-pane
>   acknowledge now takes an optional note and writes the `item_events` entry, and convert writes the
>   `flag→convert` + `action→raised` events — matching the modal. Verified a contributor lead can insert
>   its own `item_event` (=1) and a forged actor is blocked (42501).
> - **Chair note (Tom):** the "non-lead contributor chairs a meeting" case my test list named **can't
>   arise** — contributors can't create meetings. The real, testable change is that a contributor
>   *lead* who isn't the chair can now act; that works.

> **Follow-up 2 (2026-07-30), from Tom — acknowledged flags vanished from the project detail.** Priya
> acknowledged a flag on Fitzrovia Yard with a note; it recorded perfectly in the DB, but on the
> project **Flags & Actions** tab neither the closed state nor the note appeared — while closed
> *actions* with notes did. **Root cause:** `refreshProjectFlags` is `.neq('acknowledged')` (it feeds
> the app-wide Open-Flags KPI and indicators), so an acknowledged flag was filtered out of the data the
> tab reads. Actions dodge this because the tab loads a *separate* `doneActions` query for the
> Completed section; flags had no equivalent. **Fixed** by mirroring that: a `doneFlags` loader
> (project-scoped, non-open, live on the `flags` topic) plus a **RESOLVED** section that shows each
> acknowledged/converted flag with who/when and the `acknowledged_note` in full. Also corrected the
> Open-Flags KPI and the tab badge to count genuinely-open flags only (they were counting converted
> ones, a resolved state, as open). `./rebuild.sh` PASS/PASS, 0/0/0; checked in Chromium.
>
> **⚠ DEFERRED to a later session (Tom, 2026-07-30): the Register + activity log rework.** Beyond the
> stub-button fix above, Tom's view is the Register and activity log "aren't quite operating how I
> envisaged". This is not a bug list, it's a design pass on what the Register *is* — how flags/actions
> are triaged from it, what the activity feed shows and reads from (`audit_log` via `record_activity`
> vs the per-item `item_events` timeline — the two currently diverge by path), and whether per-row
> inline actions come back. **Resolved by the 2026-07-31 handoff: absorbed into Step 4 (the Dashboard),
> built on the Step 2.5 seam. The `audit_log` vs `item_events` reconciliation is Move 4, decided inside
> Step 4's scoping.** See `docs/handoff/`.

### ▶ Step 3 — Housekeeping batch + lifecycle **Move 1**  *(small · no dependencies · **IN PROGRESS**)*
Several one-liners carried for weeks, **plus lifecycle Move 1** (canonical vocabulary), which rides
here per the handoff (`docs/handoff/`).

- **Move 1 — canonical status vocabulary + CHECK constraints.** One settled word per table.
  - Fix the one divergent writer: `sb.from('actions').update({ status: 'completed', … })` (~line 1446)
    → `'closed'`. Fix the third spelling in a filter: `.neq('status','complete')` (~line 7236) →
    `'closed'`. **Order within the PR matters:** fix the writer first, then add the constraint, or the
    next "Mark complete" click throws.
  - Add a Postgres `CHECK` per status column so a wrong spelling fails loudly:
    `actions.status IN ('open','closed')` · `meeting_handoffs.status IN ('open','acknowledged','converted')`
    · `queries.status IN ('open','resolved')`. **Verified safe:** live data is already all-clean
    (actions open/closed only, flags open/acknowledged, queries open/resolved — zero rejected rows).
  - This hardens the vocabulary the Step 2.5 verbs will assume. It does **not** build the verbs — that
    is Step 2.5.
**Housekeeping outcomes (investigated against code + live DB 2026-07-31):**
- ✅ **won → LTA.** `org_statuses.label` set to `LTA` (`db/migrations/step3_housekeeping.sql`). Note:
  `org_statuses` is **dead config** — the app renders from a hardcoded `STATUSES` const and reads the
  table nowhere (0 refs) — so this is honesty for a future org-configurable-statuses feature, not a
  live change.
- ✅ **`meeting_entries.flag`** confirmed dead (selected, never consumed). Removed from the app select
  now; the **column DROP is deferred to a post-deploy follow-up** — dropping it before this PR deploys
  would break the currently-live app, which still selects it.
- ✅ **`action_queries`** confirmed **already gone** (`to_regclass` null) — nothing to do.
- ✅ **`owner_name_fallback`** confirmed **actively used** (11 sites, free-text action owner) — keep.
- ✅ **`project_checklists` DELETE policy** confirmed **intentionally absent** — the app has no delete
  path for a checklist container; SELECT/INSERT/UPDATE only, by design.
- ⏸ **`org_meeting_types.group_field`** — same dead-shadow-config as `org_statuses` (app uses hardcoded
  `MEETING_TYPES.groupField`, reads the DB column nowhere). **Not dropped.** Retiring the shadow-config
  tables (`org_statuses`, `org_meeting_types`) is a go-live decision for Tom, not a Step 3 one-liner.
- ⏭ **Flag severity** (`meeting_handoffs` has no severity column, so the register can't rank flags) —
  **NOT a one-liner; deferred to Step 4** (the dashboard/register is where ranking lives; adding the
  column + the UI belongs with that build, not here).
- ⏭ **Checklist follow-ups** (audit trigger for saves/sign-offs; "attach evidence"; working PDF/XLSX
  export) — **features, deferred.** The export path also needs the serverless proxy (Step 13).

> **✅ The accountability-spine workshop is CLOSED (2026-07-31).** Tom ran a design workshop and handed
> back a merged plan — **lifecycle unification + dashboard consolidation** — versioned in the repo at
> **`docs/handoff/`** (`README.md` master plan, `lifecycle-plan.md` = Moves 1–5 + visual contract B1–B6
> authoritative, `dashboard-spec.md`, and the agreed mocks — the dashboard's agreed design is section
> **`2a`** of `Dashboard Consolidation.dc.html`; match its row anatomy exactly). Claude reviewed it
> against the live code (all anchors verified) and endorsed the sequencing. What follows replaces the
> workshop placeholder: **Move 1 → Step 3** (above), **the seam → Step 2.5** (below), **the Dashboard →
> Step 4**, **provenance → Step 5**.

### ▶ Step 2.5 — the lifecycle seam (Moves 2 + 3 + visual contract)  *(large · **DONE** · **hard prerequisite for Step 4**)*
Build order is **Step 3 → Step 2.5 → Step 4** (Move 1 rides Step 3 because it's queued housekeeping;
this seam is the real prerequisite the dashboard consumes). Authoritative spec: `docs/handoff/lifecycle-plan.md`.

> **BUILT (2026-08-02).** Landed in verifiable slices under one batch:
> - **Slice A — lifecycle contract + chips.** `isOpen`, `settledWord`, `KIND_META`, `STATE_META`,
>   `resolveChip`, `ageMeta`, and the shared `StateChip` / `AgeClock` render helpers (app.jsx ~256–344).
> - **Slice C — the 9 service verbs** (`--VERBS-BEGIN--`/`--VERBS-END--`): `completeAction`,
>   `reopenAction`, `acknowledgeFlag`, `convertFlag`, `resolveQuery`, `answerQuery`, `escalateQuery`,
>   `markDateMet`, `moveDate`. Each owns its write shape, its `item_events` entry and a zero-row refusal
>   throw. Unit-tested by `tests/verbs.test.js` (extracts real source, mock-PostgREST, **34/34**).
> - **Slice D — every write surface routed through the verbs** (ItemModal, MeetingDetailView, App
>   markActionComplete/markKeyDateMet, tracker, KeyDatesSection, ProgrammeTimeline, ActionRow/
>   updateAction); and the **visual chip swap** — `StateChip`/`AgeClock` now render on My Work (flag
>   rail + action overdue), the project Flags & Actions tab, the Register rows and the My Work key-date
>   rail, deleting each surface's bespoke pill/badge/age code (incl. the pill-shaped `borderRadius:9999`
>   chips → square corners). **Decision (Tom, 2026-08-02):** the Register + key-date rail were forced
>   onto `StateChip` even though it drops the due-soon/due-today gradient (overdue stays the one loud
>   chip; age shown via the age clock; the urgency *sort* is retained). Step 4 reworks the Register
>   anyway. The item-modal State cell stays a fact-grid presentation by design (not a list-row chip).
> - **Slice E — Move 3, full-scope loaders + one openness predicate.** `refreshProjectActions` /
>   `refreshProjectFlags` no longer filter by status — they carry open **and** settled; the App derives
>   `openProjectActions`/`openProjectFlags` **once** via `isOpen` and routes them to the open-only
>   consumers, while the project dashboard reads the full arrays and derives its Completed/Resolved
>   sections via `isOpen` (the per-view `loadDoneActions`/`loadDoneFlags` slices are **deleted**). This
>   fixes the Fitzrovia vanishing-flag class of bug at the root. Side effect (a fix): the Register no
>   longer counts `converted` flags as open. `keyDates` already followed this model (`!completed`).
>
> **Known tradeoff to revisit (not a blocker):** the full-scope action loader now fetches every
> settled action org-wide on each `actions` RX emit, where the old dashboard done-loader was
> project-scoped. Fine at current data volume; at scale, scope the global loader to open + recently
> settled (or make settled lazy per-project). Flagged here so it isn't forgotten.
>
> **Deferred to Step 4 / later (unchanged by this step):** two `.neq(status)` filters that are
> purposeful open-scoped *feature* queries, not shared-array slicing — the item-modal related-items
> browse panel (app.jsx ~3476) and the date-move "caused by" cause picker (~7372–73). ProvenanceStrip
> (B4) still lands with `threadOf()` in **Step 5**. Move 4 (audit spine) decision stays inside **Step 4**.

**The rule: one operation, one implementation; one visual signal, one component. Deleting each
surface's local copy is part of acceptance, not optional cleanup.** This is the single highest-value
batch in the plan and the highest regression risk — a refactor across ~6 surfaces that ships no visible
feature, on a repo with no automated guard yet (Step 14). Build it in **verifiable slices** under one
batch, and unit-test the pure pieces (`STATE_META` / `isOpen` / the verbs) with the mock-PostgREST
technique the RX bus used.

- **Move 2 — one service layer.** One exported verb per transition — `completeAction`, `reopenAction`,
  `acknowledgeFlag`, `convertFlag`, `resolveQuery`, `answerQuery`, `escalateQuery`, `markDateMet`,
  `moveDate`. Each verb owns, in one place: its canonical write shape, its `item_events` entry (never
  best-effort skipped), its `audit_log` emission (interim: emit both until Move 4), and it rides `sb`
  so the RX bus auto-emits. **Duplicates to collapse:** acknowledge-flag (modal ~3453, meeting
  ~6822, bulk ~6989); complete-action (~1446, ~2861, ~3360, ~7034/7095, ~7880). Authority checks live
  in the verb (fold in Step 2's `canActOnHandoff`).
- **Move 3 — one openness predicate + dumb loaders.** Loaders fetch a *scope* (this project, my dept),
  never a lifecycle slice. Delete the `.neq('acknowledged')` (~1642, ~7235), `.neq('converted')`
  (~3283), `.neq('open')` done-loaders (~5061, ~5080) and the `acked||converted||resulting_action_id`
  family. One shared `isOpen(kind, item)`; `doneFlags`/`doneActions` become selectors over one dataset.
  **This generalises the Fitzrovia fix so it can't recur per-view — and it replaces the interim
  `doneFlags`/`openFlags` loaders Claude added in the Fitzrovia PR.**
- **Part B — the visual contract (B1–B6), rendered identically everywhere.** One `STATE_META` map
  drives chip + ribbon + filter + count so they cannot disagree. Shared helpers `StateChip(item)`,
  `AgeClock(item)`, `ProvenanceStrip(thread)`, consumed by My Work, department rail, project Flags &
  Actions tab, Register rows, meeting pane, item-modal header, ProgrammeHistory. Kind identity: flag =
  carmine `flag`; action = prussian `check-square`; query = amber `message-square`; key date =
  prussian-80 `calendar-check`. State chip: OPEN (prussian dot) · IN QUERY (amber) · **OVERDUE·Nd
  (solid carmine, the one loud chip)** · ✓ SETTLED (green, word per kind) · → CONVERTED (carmine tint)
  · ARCHIVED (dashed ghost). Age clock: 0–2d grey / 3–5d amber / 6d+ carmine, weight 700. Card anatomy
  fixed order (kind mark · title · provenance strip · state chip · attribution+age footer). Settled
  items **section, never vanish** (the Fitzrovia rule, now the standard). Use the live `MA`/`C` tokens
  (~3154 / ~175) — the live tokens win over any hex in the handoff. **Reconcile Claude's interim
  `ProgrammeHistory` (Step 1) into the B4 strip / B5 settled treatment rather than leaving it bespoke.**
- **Lifecycle contract:** every kind is **OPEN** or **SETTLED** (kind-specific settled word); overdue /
  in-query / escalated / slipped are **render-time overlays, never stored statuses**. Key dates stay a
  boolean `completed`; a *move* is a `programme_revisions` event (Step 1), never a state.
- **Interim conflicts to absorb (Claude's Steps 1–2 code):** `canActOnHandoff` → into the verbs; the
  meeting-pane acknowledge note/`item_events` enrichment → into `acknowledgeFlag`; `DateChangeReasonModal`
  + the `change_*` transient columns → into `moveDate`; `doneFlags`/`openFlags` → `isOpen` selectors.
  These aren't rework of good code — they're the interim copies this step exists to unify.

### ▶ Step 4 — Dashboard ("Command view")  *(large · **needs Step 2.5** · consumer of the seam)*
Absorbs the old "exec view part 1" **and** the Register/activity-log rework into one role-gated landing
page. Authoritative spec: `docs/handoff/dashboard-spec.md`; agreed design is section **`2a`** of
`docs/handoff/Dashboard Consolidation.dc.html` — match its row anatomy exactly. **Built entirely as a
consumer of the Step 2.5 verbs/chips — never a seventh copy.**

> **Wiring note carried from Step 2.5 (Move 3).** `MasterResourceTracker` → `ProjectRow` (the per-role
> `⚑ N` flag badges + `ActionIndicatorBadge` per discipline column, app.jsx ~2965/2966/3066) is
> **defined but never mounted** today — it renders nowhere. It counts raw `.length` with **no** status
> filter (the badge assumes its array is open-only). When this view is brought alive here, hand it the
> App's derived **`openProjectActions` / `openProjectFlags`** (the `isOpen`-filtered arrays), NOT the
> full-scope `projectActions` / `projectFlags` — otherwise settled actions/flags double-count into the
> per-role badges. `ActionIndicatorBadge` (~3102) likewise has date-defensiveness but no status check,
> so it must be fed the open slice too. Same rule as the other open-only consumers the App already
> routes to.

- **Routing:** new `#/dashboard` is the **default landing for every role** (replaces Projects as home);
  the **REGISTER ribbon tab retires**, DASHBOARD takes its slot first; `#/register` survives as the
  filtered drill-down. **Plumbing needed:** `parseHash`/`writeHash` (~1767) don't parse query strings
  today — the dashboard's URL-backed filters (`#/register?scope=overdue&team=technical&person=<id>`,
  refresh-safe, switchable) require that. Role gating reuses `isSenior`; the wordmark "home" now → dashboard.
- **Three tabs:** **Overview** (role-scoped KPI cards for everyone; exec-only boards — project health,
  team performance, pipeline, meetings, slipping programme moves from `programme_revisions`, programme
  strip, accountability by person; contributors get "your work this week"), **Open register** (unified
  actions/flags/key-dates grouped by urgency, compact four-dropdown filter bar — timescale/kind/team/owner,
  URL-backed), **Activity** (one tab, two lenses over the audit spine — a readable feed for everyone, an
  exportable log table for seniors; the separate Audit-log tab merges away).
- **Interaction contract:** every number is a filter. KPI / accountability / team rows navigate to the
  Open register with the filter pre-selected as URL params — switchable from the register's dropdowns,
  not just clearable.
- **Team is derived (no schema change):** action's team = owner's discipline; flag's team =
  `to_department`; one `teamOf(item)` helper in the service layer.
- **Project health** = stage-weighted (open actions/flags/overdue dates & milestones vs how far along
  the project is) × module completeness. Value movement joins in Step 7 (slot carries the caption now).
- **Move 4 decision (audit spine) is made INSIDE this step's scoping** — `item_events` as the record
  with `audit_log` narrowed to notification fan-out, or the feed becomes a view over `item_events`.
  Until then the Step 2.5 verbs emit both, so nothing diverges. Note `audit_log` is trigger-written and
  `item_events` app-written, so "emit both" is already a clean split.

Deliberately **excludes** money/baseline-weighted health — that is Step 7, into slots this page carries.

### ▶ Step 5 — Delay record: the views  *(medium · **Step 1 done** — now needs accrued history)*
Once revisions have been accruing for a few weeks:
1. **Internal** — project health stops being form-completeness and becomes *slip against baseline,
   attributed*: which projects are moving, by how much, and whose decisions moved them.
2. **External, and this is the point** — what accrues is a **contemporaneous record**. When a fit-out
   job goes wrong the entire delay/EOT argument turns on who knew what, when, and what it pushed.
   Contractors lose that argument routinely because the record gets reconstructed from email threads
   nine months later by someone who wasn't in the room. A tool that emits a timestamped, attributed,
   evidence-linked delay narrative **as a byproduct of people just running their weekly meetings** is
   worth more than every checklist in the workbook combined, and pays for itself on one disputed job.
   Deliverable: a per-project chronology export (PDF) — date changed, from → to, by whom, in which
   meeting, against which flag/action, with the note.
- Nobody in this market does this well. Procore and Fieldwire log events; they don't build the causal
  chain. arke [matrix] is unusually close to it because meetings, flags and actions are already
  first-class linked objects rather than comment threads.
- **Merges with** the Programme Links work-span (date-range) view — build the span model and the
  revision model together, once.
- **Lifecycle Move 5 pays off here.** Add one `threadOf(item)` resolver (service layer) that walks
  flag → action → query → date-change from the FKs that already exist (`resulting_action_id`,
  `parent_type`/`parent_id`, `cause_flag_id`/`cause_action_id`, `meeting_id`). The provenance strip
  (Step 2.5 Part B) renders it inline; the chronology export is a print of the same object. **Wrinkle:**
  the flag→action edge is stored twice (`resulting_action_id` on the flag *and* `source_type='flag'`/
  `source_ref` on the action) — `threadOf` must treat them as one edge.

### ▶ Step 6 — Commercial spine  *(medium schema, high leverage · needs a decision from Tom)*
`projects` has 27 columns and **not one is a value, cost, fee or margin.** There is no money anywhere
in the application. That is not a missing feature, it is a missing axis — and it is what stops the
exec view answering the questions an MD actually asks.

Budget Movement Log, Quotes, Additional Sales Opportunities, Schedule of Derogation, Bond Application
and Adjudication are not six unrelated tables that share a shape. They are six views onto **one number
and its movement** from tender through adjudication to final account. Built as generic typed grids the
Budget Movement Log becomes rows that roll up to nothing.

**Scope:**
- Columns on `projects`: `tender_value`, `contract_value`, `forecast_value`, `forecast_cost`,
  `value_confidence`, all `numeric(14,2)`, GBP assumed.
- `budget_movements` — the Budget Movement Log, built as a **ledger not a grid**: `project_id,
  movement_date, direction (add/omit), category, description, value, status
  (potential/instructed/agreed/rejected), raised_by, agreed_at, source_ref`. The register view is a
  view over it; the project's forecast is a rollup of it.
- Derived, not stored: stage-weighted pipeline value (weight per `org_statuses.value`, senior-editable).

**⚠ Open question for Tom, needed before building:** does Arke want **cost/margin** in this tool, or
only **value + movement**? Margin is the sharper number and the one people will object to being
visible org-wide. The RLS answer differs — a senior-only column set versus a normal one — so it has
to be settled first.

### ▶ Step 7 — Executive view, part 2: health & value  *(medium · needs Steps 1, 5, 6)*
The half that has real dependencies:
- pipeline pie keyed by **value**, not count (needs Step 6);
- portfolio clash calendar (needs Step 1);
- **redefined project health** — a composite of *slip against baseline* (Step 1/5) + *margin/value
  movement* (Step 6) + *overdue actions and unacknowledged flags* (exists today), with completeness as
  a fourth and smallest term. This is the difference between a dashboard seniors open once and one
  they use.

### ▶ Step 8 — Project registers & logs  *(large · the commercial ones need Step 6)*
The register/log module type, from Tom's process matrix: RFI Schedule · Risk Register · Long Lead
Items · Quotes · Schedule of Derogation · **PM Checklist** (which is a blank per-project *register*,
not a fixed-question checklist). Budget Movement Log is delivered by Step 6 as a ledger, not here.

### ▶ Step 9 — Meeting agenda modules  *(medium)*
The agenda/meeting module type: Kick Off · Pre-Adjudication · Adjudication agendas.

### ▶ Step 10 — Go-live: real Arke data  *(gate)*
- Run the **RLS behavioural verification** — two roles, table by table, pass/fail — and
  `get_advisors` before the real `arke` org and the first user migration.
  **Use the harness this session proved:** a self-aborting `DO` block with
  `set_config('request.jwt.claims', …)` to impersonate a real user, so policies and triggers are
  exercised under an actual JWT and the whole thing rolls back. No throwaway accounts needed.
- Decide the two dev-mode carve-outs before real people arrive:
  **(a)** swap `DEV_TEMP_PASSWORD` back to the random generator;
  **(b)** keep or drop invite-based email-confirmation skipping, and keep or drop the senior-only
  `reset_password_to_temporary` (impersonation-capable, audited).
- New-org wizard; persistent "which org am I in" indicator; new-project approval flow (contributor
  creates → pending → senior approves) + duplicate address/name detection; "My Team" view.

### ▶ Step 11 — Organisation chart follow-ups  *(small)*
Marquee multi-select + group drag · Export chart (print/PNG) · the project-team filter select.
The RAISE composers were built and then **removed** at Tom's request — not deferred, rejected.

### ▶ Step 12 — Projects home page UI  *(small · **PART DONE 2026-07-29**, remainder PARKED)*

**Done 2026-07-29** — eight minor changes Tom specified, shipped in the projects-home PR:
- search filter kept; **status dropdown and owner dropdown removed** (the carmine pipeline strip above
  the list already filters by status, so the select was a competing control over the same state — this
  also closes the "two overlapping ways to hide things" point below, and the owner filter is gone
  rather than fixed);
- `+ New project` no longer wraps when the filter bar narrows;
- **open items / site area / floor columns dropped** from the row (all three appear on expand, so the
  row duplicated the detail pane), with Project and Address widened into the freed space;
- column minimums set to `0` so **"Open page" stays the right-most visible column** at any width —
  with `minmax(160px,…)` the flexible columns refused to shrink and pushed it off the clipped edge;
- **sortable headers** on Project #, Project, Address, Updated, Secured, Status — click to sort, click
  again to reverse, chevron rotates and turns carmine; Status sorts by pipeline order, every sort ties
  on project number. This closes the "fixed sort" point below.
- **The sort persists across the List / Full / Map switch.** It is held in `Dashboard` beside
  `projectViewMode`, not inside `ProjectListTable`, and both views order through the one shared
  `sortProjects()` helper. Full has no column headers to click, so it prints a banner —
  "Sorted by *last updated*, descending. Return to the list view to reorder." — with the link
  switching back.
- **The project-number tie-break never reverses.** It is a stable secondary order, not part of what the
  direction toggle flips. Reversing it too meant that filtering to one stage — or hiding unsecured
  projects — left every visible row with the same sort value, so clicking that column silently flipped
  the whole list by project number and looked like an arbitrary reshuffle. A column the active filters
  have made inert (one distinct value across the visible set) now greys out and refuses the click, with
  a tooltip saying why.
Verified in Chromium at 1400 / 1040 / 860px, plus 24 unit tests over `sortProjects()`.

**Still parked.** The open questions were: what is the page primarily for; should the List/Full/Map
choice persist per person; and two specifics that survive the above —
- **no "just mine" filter** (the old owner filter matched only `owner_user_id`, so a designer could not
  filter to their own work — the other five team columns were invisible to it; if this comes back it
  should match against all six team FKs, not one);
- tall rows — 30 projects is a lot of scrolling.

### ▶ Step 13 — Serverless scheduler, and what it unblocks  *(needs an infra decision)*
One missing capability blocks three features, which is why they are grouped. A public static app
cannot hold an API key or run a cron.
- **Claude programme-import** — wire the real API behind the Excel stub (`importProgramme` /
  `convertArkeProgrammeToKeyDates`): xlsx → Claude → `{event_name, target_date}[]` →
  `project_key_dates`. Also the natural place to set the **baseline** on first import (Step 1).
- **Timed auto-escalation** of stale queries.
- **The weekly Monday "ball-in-your-court" digest.**

### ▶ Step 14 — Regression guard  *(WORKSHOP — no test harness exists)*
Nothing automated protects the cross-reference chain. Two candidates proved useful this session and
should inform it: the **self-aborting SQL block** for anything touching the database, and the
**mock-PostgREST unit test** used on the RX bus for pure client logic. A Playwright pass over the
deployed app is the third leg.

## Open decisions
- ~~**accountability spine (workshop)**~~ — **RESOLVED 2026-07-31.** Tom's design workshop produced the
  merged lifecycle+dashboard handoff (`docs/handoff/`), now folded into Steps 3 / 2.5 / 4 / 5. One
  decision remains, deliberately deferred to Step 4 scoping: **Move 4 — the audit spine** (`item_events`
  as the record with `audit_log` narrowed to notifications, or the feed as a view over `item_events`).
- **Workflow:** one PR per batch, fresh branch off `main`, opened at the end.
- New-project approval = a new project state (e.g. `pending`).
- Default project-visibility rules per role (Phase 6).
- "Team lead" flag (built as `is_team_lead`) settled unless Tom reopens.
- **NEW — commercial scope (4d):** value + movement only, or cost/margin too? Determines whether a
  senior-only column set is needed.
- **NEW — team model (Phase 6):** keep six hardcoded role FKs on `projects`, or normalise to
  `project_team`? **Fully decoupled from permissions as of 2026-07-29** — visibility no longer derives
  from team assignment at all (see *Project permissions*), so the six FKs now mean only *who is
  appointed*, never *who can see*. That removes the urgency entirely. The remaining question is a
  product one: *can a project ever have two people in the same discipline, or someone on the team who
  isn't one of the six roles (M&E lead, QS, site manager)?* If yes the list model wins eventually; if
  no, the six slots are fine. **Recommendation: keep the six slots; revisit when a real case appears.**
- ~~**team lead vs seniority (Organisation tab)**~~ — **SETTLED 2026-07-29 (Tom): team lead is a
  separate indicator from seniority.** *"Someone may be a team lead but might not carry the
  permissions that come with senior."* The handoff's force-to-senior rule is **dropped**; no one is
  promoted. See the Organisation tab section for what this means for the build.
- ~~**baseline trigger (9a)**~~ — **SETTLED 2026-07-29 (Tom): an explicit "Baseline this programme"
  action**, not `secured = true` and not first import. Shipped in Step 1. The remaining question it
  raises is **re-baselining**: `baseline_programme()` currently refuses to overwrite an existing
  baseline, which is right for a first cut but will need an audited re-baseline path once a real EOT
  is agreed. Decide as part of Step 5.

## Working agreement
Scope honestly before building; confirm design choices before code; say when an idea's wrong. One PR
per batch, verified in the harness, deploy confirmed green. **Keep this file updated with every batch
— and record the verification query beside anything marked APPLIED.** Long sessions split into fresh
chats.

---

## Appendix — verification queries

Run these at the start of any batch that touches security or schema, and after applying P0.

```sql
-- A. function privileges: PUBLIC grant shows as "=X/postgres"
select p.proname, p.prosecdef,
       coalesce(array_to_string(p.proacl,' | '),'(default: PUBLIC EXECUTE)') as acl,
       p.proconfig
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' order by p.proname;

-- B. full RLS policy set
select tablename, policyname, cmd, roles::text,
       coalesce(qual,'-') as using_expr, coalesce(with_check,'-') as check_expr
from pg_policies where schemaname = 'public' order by tablename, cmd, policyname;

-- C. bodies of the fan-out helpers (check for org filters)
select pg_get_functiondef(p.oid)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('record_activity','project_audience','notify_user','actor_name');

-- D. audit coverage and actor attribution
select count(*) total, count(*) filter (where actor_user_id is null) actor_missing,
       min(created_at) earliest, max(created_at) latest
from audit_log;

-- E. checklist template coupling (should show a template_item_id column after P0-3)
select column_name from information_schema.columns
where table_schema='public' and table_name='project_checklist_items' order by ordinal_position;
```

Then `get_advisors(project_id => 'tpxabhqsjngalilbznhz', type => 'security')` — expect zero
`anon_security_definer_function_executable` lints for the four helpers. The
`auth_leaked_password_protection` warning is separate: enable it in Auth settings before real users.
