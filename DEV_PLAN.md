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
- **24 tables**, all RLS-enabled. Row counts **re-verified 2026-07-29**: projects 30,
  project_key_dates 159, meeting_entries 63, actions 36 (19 open), meeting_handoffs 13 (5 open),
  module_templates 8, module_template_items 244, project_checklist_items 6, queries 5, item_events 95.
  (2026-07-27 figures, not re-checked this batch: meetings 25, project_contacts 195,
  project_checklists 1, audit_log 5, notifications 43.)
- **Dev org** `dawlish` (`c6e9cc3c-…`), all fictional data. **No real Arke data yet** — deferred to the
  org/permissions + RLS go-live gate (Phase 6). Seed scripts are versioned under `seed/`.

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
appendix. **P0-1 (2026-07-27), P0-3, P0-2 and P0-4a (all 2026-07-29) are closed and verified. Only
P0-4b — per-project visibility — remains open**, and it is the gate for real Arke data.

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

### Carried over unshipped from PR12 feedback — confirm or close
- **Rename status `won` → `LTA`.** `org_statuses` still holds `value='won', label='Won'`. Either ship
  the label change (data-only, `org_statuses` is config) or strike the item.

---

## ▶ REMAINING PLAN — work top to bottom, confirm scope per phase

### Phase 4 — Project detail pane build-out  *(large, iterative — in progress)*
- ✅ **4a / 4c** merged/live (see DONE above).
- ↪ **4b — Audit trail → per-user activity** was expanded into the Register & activity hub (Phase 5).
- **Source of truth for the modules:** Tom's Excel process matrix `CLIENT_NAME_Arke_Process_Matrix.xlsm`
  (29 tabs), which collapse into a handful of reusable module **types**, not 29 bespoke builds:
  - **Overview** (Summary tab) · **Directory** (built, below)
  - **Checklist** type: BD / Designer / Technical Designer / Graphics / Building Regs / Legal Process /
    Legal Kick Off / Adjudication Checklist / 70% Close Out. **Not built as modules:** PM Checklist
    (it is a blank per-project *register*, not a fixed-question checklist — see below); WPB Kick Off,
    Onsite Handover, Accountant On Site (seeded 2026-07-26, **removed 2026-07-27** at Tom's request —
    niche operational tabs he did not want surfaced as modules).
  - **Register/log** type: RFI Schedule / Risk Register / Long Lead Items / Budget Movement Log /
    Quotes / Additional Sales Opportunities / Schedule of Derogation / **PM Checklist** (info-required
    log). **See 4d — several of these are commercial and must not be built as generic tables.**
  - **Agenda/meeting** type: Kick Off / Pre-Adjudication / Adjudication agendas.
  - **Documents/links** type: Hyperlink Page (K-drive links).
  - **Programme**: Programme Links → work-span (date-range) view. **See Phase 9.**
  - **Form/sign-off**: Bond Application, Leadership Sign Off.
  - ✅ **Standard module-page skeleton** (`MODULE_DEFS` + `ProjectModulePage`).
  - ✅ **Project Directory** — dashboard tab, `project_contacts` (195 rows live), role dropdown over
    the workbook taxonomy, company memory / auto-fill with tinted cells, history seeded across 19
    projects. **Next:** wire directory contacts into module people-fields as modules are built.
  - ✅ **Checklist module type — BUILT.** One `ChecklistModule` driven by a template row: `mode`
    (reference/record/signoff/tracked) · `status_set` (rag/yesno/complete) · `requireDetail` ·
    `flagOnAttention`. Sticky header, collapsible sections, status spine, notes, sign-off, toast.
    Row routing is real (writes `meeting_handoffs` / `actions` and shows the tie chip).
  - ✅ **8 checklist tabs seeded, 244 template items** (verified 2026-07-27): Building Regs
    (record/rag, 58), BD (reference/yesno, 22), Adjudication (record/rag, 30), 70% Close Out
    (signoff/complete, 15), **+ batch 2:** Designer (record/rag, 29), Graphics (reference/yesno, 22),
    Legal Kick Off (record/rag, 33), Legal Process (record/rag, 35). Seeds under
    `seed/2026-07-25-checklist-templates.sql` + `seed/2026-07-26-checklist-templates-batch2.sql`.
    Owners map to real `app_users` where a role matches. **✅ P0-3 closed 2026-07-29 — all 8 templates
    are now safe to edit in place; answers bind to `template_item_id`, not position. Deleting a
    question that has answers is blocked by `ON DELETE RESTRICT` rather than silently destroying them.**
  - ⬜ **Checklist follow-ups:** audit trigger so saves/sign-offs emit into the hub; "Attach evidence"
    row action; export (PDF/XLSX buttons render but defer to a dedicated pass). ✅ Save atomicity
    (RX-B) and template binding (P0-3) done 2026-07-29.

#### ▶ Phase 4d — **Commercial spine**  *(NEW — small schema, high leverage, do before more registers)*
`projects` currently has 27 columns and **not one of them is a value, cost, fee or margin.** There is
no money anywhere in the application.

This is not a missing feature, it's a missing axis. Look at what sits in the "register" bucket above:
Budget Movement Log, Quotes, Additional Sales Opportunities, Schedule of Derogation, Bond Application,
Adjudication. Those are not six unrelated tables that happen to share a shape — they are six views
onto **one number and its movement** from tender through adjudication to final account. Classifying
them by table shape is correct for the UI and wrong for the data: built as generic typed grids, the
Budget Movement Log becomes rows that roll up to nothing.

The consequence lands in Phase 7, which currently defines project health as *information
completeness* — how much of the form is filled in. No MD of a fit-out business asks that. They ask
what's the value on site, what's the margin erosion since adjudication, what's due to invoice, and
what's the pipeline worth weighted by stage. As specified, the exec view cannot answer any of them.

**Scope (confirm with Tom before building):**
- Columns on `projects`: `tender_value`, `contract_value`, `forecast_value`, `forecast_cost`,
  `value_confidence` (or reuse `secured`), all `numeric(14,2)`, GBP assumed.
- `budget_movements` table — *this is the Budget Movement Log register*, built as a ledger not a grid:
  `project_id, movement_date, direction (add/omit), category, description, value, status
  (potential/instructed/agreed/rejected), raised_by, agreed_at, source_ref`. The register view is a
  view over it; the project's current forecast is a rollup of it.
- Derived, not stored: stage-weighted pipeline value (weight per `org_statuses.value`, senior-editable).
- Pipeline pie in Phase 7 keyed by **value**, not count.

**Open question for Tom:** does Arke want cost/margin in this tool at all, or only value + movement?
Margin is the sharper number but it is also the one people will object to being visible org-wide.
The RLS answer differs (a senior-only column set vs a normal one) so decide before building.

### Phase 5 — Register & activity: notifications hub + site-wide audit  *(large — in progress)*
- ✅ **Hub UI** — bell + unread badge + dropdown activity panel. Reads per-user `notifications`.
- ✅ **Open register** — cross-project register of open actions / flags / key dates; summary tiles,
  scope filters, grouping, inline Mark complete / Mark met.
- ✅ **Audit + fan-out backend applied** — `audit_log` (senior-read) + generic triggers on projects,
  key dates/programme, meetings, flags, actions → `record_activity()` writes the audit row and fans
  out per-user `notifications` to `project_audience()`. SQL at
  `db/migrations/phase5_notifications_audit.sql`.
  **⚠ CORRECTION:** the accompanying claim that direct-RPC EXECUTE was revoked is **false as
  deployed** — see P0-1 (re-verified still-open 2026-07-27). And `project_audience()` is cross-org —
  see P0-2.
- ⚠️ **KNOWN ISSUE — activity log under-wired.** The Activity tab and bell read the **per-user
  `notifications`** table, so a user only sees events fanned out to them. It behaves like a personal
  inbox, not a cross-user activity log. The complete record lives in **`audit_log`** and is not
  surfaced. `audit_log` currently holds **5 rows, all 2026-07-24/25** — the triggers only populate
  going forward.
  **Fix direction:** point the Activity / "full audit log" view at `audit_log` (seniors = all;
  contributors = their visible projects once Phase 6 lands); keep the bell on `notifications`.
  Consider a one-off back-population. Verify actor attribution from the live app with a real JWT —
  the dev-org test ran without a user context, and `record_activity` writes `auth.uid()`, which is
  null for non-app writes.
- ⬜ **Deferred:** flag **severity** field (`meeting_handoffs` has no severity column — the register
  buckets by age as a stand-in); external transport (email/Teams via M365).

#### ▶ My Actions rework  *(in progress — from Tom's Claude Design handoff `design_handoff_my_actions`)*
Rebuild `MyActionsView` into three categories (your actions / collaborating / your team), with **ball
in court**, a **state ribbon**, a capped **query ping-pong** that blocks completion, and a **reusable
site-wide item modal** (`openItem(kind,id)`) that **delivers the deferred Phase 5 item-detail modal**
and will replace every list's row-click app-wide. Decisions (2026-07-27): **5 incremental PRs**;
**P0-1 folded into PR1**; **manual escalation only** now (timed auto-escalation + Monday digest
deferred to when a serverless scheduler exists — same gap as programme-import; banner copy reworded,
no false promise); **flags stay acknowledge-*or*-convert** (plus a third "query it back" response per
the addendum). Escalation targets: lead = active `is_team_lead` in the ball-holder's `department`,
else the project's `project_manager_user_id`.
- **Addendum baked in (2026-07-27):** **queries are a first-class, POLYMORPHIC item type** — a query
  is raised against an action, a flag *or* a key date, with its own card/modal/audit. Collapsible page
  sections (localStorage-persisted, per-user) + the query surface as-built: a `Queries` section at the
  top of the actions column (replaces the "Needs your answer" band), the inline query block on the
  parent action becomes a compact meta chip, filter tabs become `All · Queries · Overdue · Due this
  week · Chasing others · Closed` (drop `Blocked`). Icons go through the app's own `lucide()` helper
  (add `pause`/`lock`/`chevron-right`/`help-circle` paths) — no CDN, no emoji.
- ✅ **PR1 — audit spine + polymorphic queries + P0-1** (`db/migrations/myactions_audit_spine.sql`,
  applied): `item_events` append-only audit table over all four item types (org-scoped select; insert
  forces `actor_id = auth.uid()`, no update/delete — genuinely tamper-evident); **`queries`** (first-
  class, polymorphic `parent_type ∈ action|flag|date` + `parent_id`, one-open-per-parent partial unique
  index, `resolution_note`) + **`query_messages`** thread; `actions.source_type`+`source_ref` for the
  provenance chip; `meeting_handoffs.acknowledged_note`. Backfilled 71 lifecycle events + migrated the
  4 legacy `action_queries` into the polymorphic model (`seed/2026-07-27-item-events-backfill.sql`).
  P0-1 closed + verified (box in the P0 section). **Legacy `action_queries` kept until the app cuts
  over** (deployed app still uses it); a later PR migrates any interim rows and drops it.
- ✅ **PR2 — reusable site-wide item modal + query state machine** (app.jsx): module-level
  `openItem(kind,id)` (registered by `App`, no prop-drilling) mounts `ItemModal` at the root. Handles
  `action` + `query` kinds: shell + kind chip + **state ribbon** (`StateRibbon`) + **ball chip**
  (`queryBall`/`queryExchange`/`querySpent` derived, never cached); left column = fact grid,
  collaborators, complete-with-mandatory-note (locked while a query is open), raise-query, senior
  reassign/move-date panel; right column tabs Thread / Audit trail / Related. Full query machine —
  raise / answer / counter / resolve (mandatory note) / escalate (`escalationTarget` → dept lead else
  PM) / chase — every step writing an `item_events` row via `logItemEvent`. Icons via `lucide()`
  (+4 paths). Entry point: the action title on the existing card opens the modal (the full page/card
  rebuild is PR3). `MA` local palette holds the handoff's exact hexes. Parse + 0/0/0 verified;
  live-interaction check is Tom's per the workflow. **Transitional:** the modal uses the new `queries`
  table; the legacy inline QueriesPanel (on `action_queries`) still shows alongside until PR3 removes it.
- ✅ **PR3 — the My Actions page rebuild** (app.jsx): `MyActionsView` rewritten. Full-bleed carmine
  header (H1 + context line + **WAITING ON YOU** figure, ball-derived), flat filter row
  (`All · Queries · Overdue · Due this week · Chasing others · Closed`), **collapsible sections**
  (per-user localStorage `arke.myactions.collapsed.v1.<uid>`, Collapse-all/Expand-all scoped to the
  sections actually rendered) — `Queries` (amber, first), `Your actions`, `Collaborating`, `Your team`
  (senior only), plus a Closed toggle. New **`MAActionCard`** (ribbon + ball chip + provenance chip +
  query-blocked chip; whole card opens the modal) and **`MAQueryCard`** (Asked→Answered→Resolved
  ribbon, parent anchor). Retired the legacy `QueriesPanel`/`ActionSection`/`MyActionCard`. Single
  column for now — the Flags/Dates **right rail is PR4**. Parse + 0/0/0 verified; visual/interaction
  check is Tom's on the live app.
- ✅ **PR4 — Flags + Dates right rail + flag/date modal kinds** (app.jsx): My Actions is now
  two-column (`minmax(0,1fr) 340px`). Right rail = **Flags** (addressed to the user's `department`,
  open/acknowledged/converted states + age clock) and **Dates** (key dates on the user's projects,
  overdue + next 14 days, urgency-coloured), both collapsible via the same persistence. Header context
  line gained open-flag + dates counts. `ItemModal` extended to **`flag`** and **`date`** kinds:
  flag modal has facts + FLAG_RIBBON + the team-lead-only **acknowledge-with-note / convert-to-action
  (owner + due) / query-it-back**, non-leads get read-only + **nudge**; date modal has facts, an
  overdue banner and **raise-a-recovery-action** (self-owned, `source_type='date'`). `doRaiseQuery`
  generalised so query-it-back works on any parent kind. New `MARailFlag` / `MARailDate` cards open the
  modal. Parse + 0/0/0 verified; visual/interaction check is Tom's.
- ✅ **PR5 — app-wide `openItem` rollout + legacy retirement** (app.jsx + DB): the item modal is now
  reachable from the **Open register** (this delivers Phase 5's deferred "item detail modal" — its
  placeholder `onDeferredAction('Open detail')` row-click is now `openItem(it.kind, it.id)`), the
  **project dashboard** action + flag rows, and the **meeting-detail** action rows. The meeting-detail
  query flow (`raiseQueryOnAction`/`answerQueryOnAction` + the fetch) was **repointed off
  `action_queries` onto the polymorphic `queries`/`query_messages`** (answer = a thread message +
  resolve, with an `item_events` row), so the inline meeting query UX is preserved on the new model.
  **Legacy `action_queries` dropped** (`db/migrations/drop_legacy_action_queries.sql`) — no code
  references remain; all rows were migrated in PR1. Advisor still clean.
  - Role gating is client-side only (senior/lead controls omitted for others in the modal + page) —
    real RLS enforcement is **P0-4 / Phase 6**, unchanged by this rework.
  - ⬜ **Deferred (need a serverless scheduler — same gap as programme-import):** timed
    auto-escalation of stale queries + the weekly Monday "ball-in-your-court" digest. Also still open:
    wiring `openItem` into the Live Tracker + checklist rows (lower value); the checklist→hub audit
    trigger; "attach evidence"; export.

**▶ My Actions rework — COMPLETE** (PRs #39–#43). Actions, queries (first-class + polymorphic), flags
and dates all share one append-only-audited lifecycle, one reusable site-wide modal, and one page with
ball-in-court, state ribbons, the capped query ping-pong + escalation ladder, and the Flags/Dates rail.
P0-1 was closed as part of it.
  Notes: `parent_type` uses the modal's `kind` vocabulary (`action/flag/date`, not `key_date`) so it
  feeds `openItem` directly; the handoff's `from_meeting_type` on `actions` doesn't exist — replaced by
  `source_type`/`source_ref`, set at every creation point in PR2+.

### Phase 6 — Organisation & permissions layer  *(large — GO-LIVE GATE)*
- Org dashboard (add/edit users incl. title + team-lead; per-member project visibility; per-team
  meeting-status config); **new-org wizard** + persistent "which org am I in" indicator;
  permission-based project visibility + "assigned to me" filter; **new-project approval flow**
  (contributor creates → "pending" → senior approves) + duplicate address/name detection; "lead"
  projects below-the-line in meetings; **"My Team" view**.
- **⚠ Re-scoped by P0-4.** The current policy set is org-scoped only; role restrictions are enforced
  in client JS. This phase must therefore **rewrite the operational RLS policies** (senior vs
  contributor predicates + a per-project visibility join), not sit on top of them. Budget accordingly.
  - ✅ **P0-4a done (2026-07-29)** — the *role* half, on the records the app already treats as
    senior-owned: `projects` and `meetings` UPDATE.
  - ⬜ **P0-4b — per-project visibility, the last P0.** Which projects a contributor may see and touch
    at all, across `project_key_dates`, `project_contacts`, `meeting_handoffs`, `project_checklists`,
    `project_checklist_items`, `actions` and `meeting_entries`. These were deliberately left alone in
    4a: contributors legitimately write flags, dates, directory rows and checklist answers, so the
    defect there is **missing project scoping, not missing role scoping**. Also here: narrow `actions`
    UPDATE/DELETE from org-wide to owner / creator / collaborator / senior.
  - **Blocked on a decision:** 4b's visibility join is written against the team model, so the
    `project_team` vs six-hardcoded-FKs question below must be settled **first** — that is the whole
    reason the plan says to decide it before the joins are written.
#### ▶ Organisation tab — interactive org chart  *(NEW — from Tom's Claude Design handoff
`design_handoff_organisation_tab`, folded in 2026-07-29)*
A new top-level ribbon tab, **ORGANISATION**, routed at `#/organisation`, giving the company one
canonical view of who reports to whom. Every active `app_users` record renders as a card on a pannable
snap-grid canvas with elbow connectors; seniors edit people in place (name, job title, initials,
department, seniority, team lead, reports-to), add/remove people, trace an escalation path, gauge
workload, and raise an action, query or flag against anyone but themselves. Read-only for everyone
else (pan, zoom, search, filters, workload and escalation stay available to all).

It is **the Phase 6 "Org dashboard" item, specified** — build it as that deliverable rather than as a
separate feature. The handoff is high-fidelity and final on colour, type, spacing, geometry, copy and
interaction; it is an HTML prototype on a bespoke runtime and **must not be ported structurally** —
rebuild in `app.jsx` with `C` / `FONT` / `lucide()` / `React.createElement` / the `#/` hash router.

**Schema it needs**
- `app_users.manager_id uuid null references app_users(id)` — an explicit reporting line overriding
  the derived default. `null` = fall back to: active team lead of the person's department → exec.
  Cycle-break by walking ancestors (cap ~50) and resetting a repeat to the exec; refuse a drop that
  would loop, and exclude the person's own descendants from the "Reports to" picker.
- `org_chart_layout (user_id pk, x, y, updated_at)` — shared, saved card positions.

**⚠ Both need P0-work applied at the same time, or they reopen what we just closed:**
- `manager_id` **must be added to the `enforce_app_user_field_guard` trigger** (P0-2) alongside
  role/department/is_team_lead/active — otherwise any contributor can re-parent themselves in the
  org chart by forging one request.
- `org_chart_layout` **must carry `org_id` + RLS + the `set_org_id_on_insert` trigger.** The handoff
  spec has no `org_id`; a new table without one is exactly the P0-2 defect, freshly minted.

**✅ SETTLED 2026-07-29 — team lead is separate from seniority.** Tom: *"team lead should be a
separate indicator to 'is senior'. Someone may be a team lead but might not carry the permissions that
come with senior."* This matches the app's existing model (`ProfileModal`'s hint reads *"Leads their
department — separate from seniority"*) and the live data — of the five team leads only Priya Anand is
senior; Grace Boateng, Carlos Garcia, Jen Okafor and Marcus Bell are `is_team_lead = true` with
`role = 'contributor'`.
- **The handoff's force-to-senior rule is dropped.** Building it as written would have promoted those
  four to senior on first use of the tab — and P0-4a has made `senior` the database-enforced authority
  to edit any project, so that would have been a privilege escalation performed by a UI convention.
- The chart's three levels stay **derived**: exec = `senior` with no department · team lead =
  `is_team_lead` (whatever the role) · contributor = everyone else. The **TEAM LEAD** and **SENIOR**
  toggles on a card are independent; neither forces the other. Setting a lead still clears the
  previous lead of that department (one lead per department).
- **Consequence for P0-4b — do not miss this.** Authority a *team lead* needs (acknowledging a flag
  addressed to their department, converting it to an action, answering an escalated query) must key on
  **`is_team_lead`, not on `role = 'senior'`**. Four of the five current leads are contributors, so a
  senior-only predicate on `meeting_handoffs` would break the flag ladder the My Actions rework built.
- P0-2's field guard already prevents self-promotion: only an active senior in the same org can change
  `role` / `is_team_lead` / `department` / `active`, so a contributor team lead cannot make themselves
  senior — and the org chart is senior-only to edit in any case.

**Corrections to the handoff, checked against the live DB 2026-07-29**
- Its open question 1 is moot: `job_title` is **13/13 populated**, not empty. Use the live values.
- `actions` has **no `assignee_id`** — the column is `owner_user_id` (same class of slip as the
  `from_meeting_type` correction in the My Actions rework). Raise → action writes `owner_user_id`,
  and should set `source_type`/`source_ref` so the provenance chip reads "raised from the org chart".
- Raise → query writes the polymorphic `queries` table (`parent_type`/`parent_id`), not a new one.
  Raise → flag writes `meeting_handoffs.to_department`. Both flows already exist end-to-end.
- Its vacancy-card path (department with no `is_team_lead`) **will not appear with live data** — all
  five departments have a lead. The screenshots show four vacancy cards because the prototype's data
  is invented. Build it anyway (a lead can be removed), but don't expect to see it.
- Open question 5 (realtime): the **RX bus** now exists — the chart subscribes via
  `useLiveData(['users'], …)`. That covers refresh; it does **not** solve two seniors saving
  conflicting edits, which the save-bar diff model resolves last-write-wins. Acceptable for 13 people;
  note it rather than build locking.
- Open question 4 (multiple roots): live data has exactly one exec (Tom Staples), so the single-root
  assumption holds today.

**Answered here:** layout is shared, not per-user (as specified). Export = print-to-PDF plus a PNG for
induction packs.

- **Also fix here:** `projects.site_manager` is free `text` — the last team-shaped free-text escape
  hatch in a strict-FK schema. Either FK it to `app_users` or accept it explicitly and note why.
- **Structural note:** the six hardcoded team FK columns on `projects` and the five `org_meeting_types`
  rows that map onto them are rigid. Adding a discipline (M&E lead, QS, site manager) means a schema
  change + a meeting type + a `project_audience()` change + UI. If Arke's team shape is likely to
  change, normalise to a `project_team (project_id, user_id, role)` table **during this phase** —
  it is far cheaper before per-project visibility joins are written against the current shape.
- **Gate:** run the outstanding **RLS behavioural verification** (two accounts, table-by-table
  pass/fail, against the *new* policies) and `get_advisors` **before** the real `arke` org and the
  first user migration. ✅ P0-2 closed 2026-07-29, so a second org is no longer unsafe by construction
  — but P0-4 still is, and it is this phase.
- **Technique proven in the P0-2 batch, reuse it here:** the behavioural test ran inside a
  self-aborting `DO` block with `set_config('request.jwt.claims', ...)` to impersonate a real user,
  so policies and triggers were exercised under an actual JWT and the whole thing rolled back. That is
  the harness the table-by-table pass/fail gate should be written in — no throwaway accounts needed.

### Phase 7 — Executive health view  *(large — depends on 4d and 9)*
- Accountability register (open actions/flags by staff × severity/urgency); pipeline pie **by value**
  (needs 4d); clickable project register; audit log (needs P0-1 to be worth anything); meetings
  register; portfolio clash calendar (needs Phase 9).
- **Redefine project health.** "Health = information completeness" measures form-filling, not the
  project. Replace with a composite: **slip against baseline** (Phase 9) + **margin/value movement**
  (4d) + **overdue actions and unacknowledged flags** (exists today), with completeness as a fourth,
  smallest term. This is the difference between a dashboard seniors open once and one they use.

### Phase 8 — Schema & decisions cleanup  *(small)*
- Drop dead `meeting_entries.flag`; settle `owner_name_fallback`; `org_meeting_types.group_field` **is**
  populated with real FK column names (`pre_con_lead_user_id` etc.) — confirm the app actually reads it,
  else drop.
- `action_queries` carries three overlapping policies (two `ALL`, one redundant `SELECT`) — collapse.
- `project_checklists` has no `DELETE` policy — add or confirm intentional.

### ▶ Phase 9 — **Baselined programme & self-writing delay record**  *(NEW — the differentiator)*
`project_key_dates` has a single mutable `target_date`. When a date moves, the previous value is
**gone** — the only trace is `audit_log.changes`, which has existed since 24 July and holds 5 rows.
There is no baseline, no revision history, and no recorded cause.

**9a — schema only. Do this early, ideally in the P0 batch.** It is a handful of columns and one
trigger, and it is **time-sensitive in a way nothing else in this plan is**: every week it isn't
deployed is a week of programme history that cannot be recovered later. The UI can wait; the accrual
cannot.
- `project_key_dates.baseline_date date`, `baseline_set_at timestamptz`, `baseline_set_by uuid` —
  frozen when the project is secured (mirror the existing `secured_at` / `secured_by` pattern).
- `key_date_revisions (id, org_id, key_date_id, project_id, previous_date, new_date, changed_by,
  changed_at, meeting_id, cause_flag_id, cause_action_id, reason text)`.
- Trigger on `UPDATE OF target_date` writes the revision row. `meeting_id` / cause FKs populate when
  the change originates in a meeting or from a flag/action — all four objects already exist and are
  already linked, which is the whole reason this is cheap here and expensive elsewhere.
- Same treatment for `projects.site_start_date` / `projected_completion_date` /
  `contracted_completion_date`.

**9b — the views (later, once history has accrued).**
1. **Internal:** project health stops being form-completeness and becomes *slip against baseline,
   attributed* — which projects are moving, by how much, and whose decisions moved them. Feeds the
   Phase 7 exec view and the portfolio clash calendar directly.
2. **External, and this is the point:** what accrues is a **contemporaneous record**. When a fit-out
   job goes wrong, the entire delay / EOT argument turns on who knew what, when, and what it pushed.
   Contractors lose that argument routinely because the record gets reconstructed from email threads
   nine months later by someone who wasn't in the room. A tool that emits a timestamped, attributed,
   evidence-linked delay narrative **as a byproduct of people just running their weekly meetings** is
   worth more than every checklist in the workbook combined, and pays for itself on one disputed job.
   Deliverable: a per-project chronology export (PDF) — date changed, from → to, by whom, in which
   meeting, against which flag/action, with the note.
- Nobody in this market does this well. Procore and Fieldwire log events; they don't build the causal
  chain. arke [matrix] is unusually close to it because meetings, flags and actions are already
  first-class linked objects rather than comment threads.
- **Merges with:** the Programme Links tab's work-span (date-range) view — build the span model and
  the revision model together, once.

### Cross-cutting / parallel
- **Claude programme-import** — wire the real API behind the Project Detail Page Excel stub
  (`importProgramme` / `convertArkeProgrammeToKeyDates` TODO): xlsx → Claude → `{event_name,
  target_date}[]` → `project_key_dates`. **Needs a serverless proxy** (public static app can't hold the
  key). Note this is also the natural place to set the **baseline** on first import (Phase 9a).

## Open decisions
- **Workflow:** one PR per batch, fresh branch off `main`, opened at the end.
- New-project approval = a new project state (e.g. `pending`).
- Default project-visibility rules per role (Phase 6).
- "Team lead" flag (built as `is_team_lead`) settled unless Tom reopens.
- **NEW — commercial scope (4d):** value + movement only, or cost/margin too? Determines whether a
  senior-only column set is needed.
- **NEW — team model (Phase 6):** keep six hardcoded role FKs on `projects`, or normalise to
  `project_team`? **No longer blocking P0-4b** — see below. The question in plain terms: *can a
  project ever have two people in the same discipline, or someone on the team who isn't one of the six
  roles (M&E lead, QS, site manager)?* If yes, the list model wins eventually; if no, the six slots
  are fine. **Recommendation: keep the six slots for now.**
  **De-risked:** P0-4b will be written behind a single SECURITY DEFINER helper
  `user_can_see_project(p_project)` that today checks the six FK columns. Normalising later changes
  that one function; every policy calling it is untouched. That makes the decision cheaply reversible
  on the database side. (App screens reading `project.designer_user_id` etc. still need reworking if
  it is ever normalised — that cost is unchanged either way.)
- ~~**team lead vs seniority (Organisation tab)**~~ — **SETTLED 2026-07-29 (Tom): team lead is a
  separate indicator from seniority.** *"Someone may be a team lead but might not carry the
  permissions that come with senior."* The handoff's force-to-senior rule is **dropped**; no one is
  promoted. See the Organisation tab section for what this means for the build.
- **NEW — baseline trigger (9a):** does baseline freeze on `secured = true`, on first programme
  import, or on an explicit "baseline this programme" action? Tom's call; the last is most honest.

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
