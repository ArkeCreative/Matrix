# arke [matrix] — living dev plan (single source of truth)

This file is the master dev plan, versioned in the repo. Update it with every batch so it always
matches what's shipped. First actions for a new session: **load the `arke-design` skill**; the split
source (`shell-head.html` + `app.jsx` + `shell-tail.html` + `rebuild.sh`) is already in the repo.

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
- **Dev org** `dawlish` (`c6e9cc3c-…`), all fictional data. **No real Arke data yet** — deferred to the
  org/permissions + RLS go-live gate (Phase 6). Seed scripts are versioned under `seed/` — latest
  (`seed/2026-07-24-test-data-expansion.sql`) grows the org to 30 projects across the full pipeline
  (created May 2024 → Jul 2026, mixed building- and client-named), with pre-con-weighted key dates,
  16 historic closed meetings, meeting entries, actions/queries and flags, all authored by a spread of users.

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

---

## ▶ REMAINING PLAN — work top to bottom, confirm scope per phase

### Phase 4 — Project detail pane build-out  *(large, iterative — in progress)*
- ✅ **4a / 4c** merged/live (see DONE above).
- ↪ **4b — Audit trail → per-user activity** was expanded into the Register & activity hub (Phase 5).
- **Source of truth for the modules:** Tom's Excel process matrix `CLIENT_NAME_Arke_Process_Matrix.xlsm`
  (29 tabs). Examined — the tabs collapse into a **handful of reusable module _types_**, not 29 bespoke
  builds:
  - **Overview** (Summary tab — have it) · **Directory** (Project Directory tab — built, below)
  - **Checklist** type: BD / Designer / Technical Designer / Graphics / Building Regs / Legal Process /
    PM Checklist / Adjudication Checklist / Legal Kick Off / WPB Kick Off / Onsite Handover / 70% Close
    Out / Accountant — task rows with action-by · date · response · traffic-light status.
  - **Register/log** type: RFI Schedule / Risk Register / Long Lead Items / Budget Movement Log /
    Quotes / Additional Sales Opportunities / Schedule of Derogation — typed rows, own columns each.
  - **Agenda/meeting** type: Kick Off / Pre-Adjudication / Adjudication agendas — overlaps our Meetings.
  - **Documents/links** type: Hyperlink Page (K-drive links).
  - **Programme**: Programme Links → extend our programme component into a **work-span (date-range)**
    view — "Partitions – first fix" etc., not just point key-dates.
  - **Form/sign-off**: Bond Application, Leadership Sign Off.
  - Decision: build **~6 reusable module types**, each Excel tab a **configured instance** (own
    columns/fields/statuses); Tom workshops each in Claude Design, passes it back. Every tab shares the
    auto-fed **Project Information** header (from the project record) + **Directory** people.
  - ✅ **Standard module-page skeleton** in place (`MODULE_DEFS` + `ProjectModulePage`). *(The 8-name
    `MODULE_DEFS` list will be reconciled to the full tab set as types are built.)*
  - ✅ **Project Directory** — new dashboard tab (Overview · **Directory** · Modules · Actions & Flags).
    `project_contacts` table (org-scoped RLS + set_org/touch triggers; SQL at
    `db/migrations/project_directory_contacts.sql`, **applied to live DB**). `ProjectDirectory`
    component: two groups (Client/Building, Subcontractors & Consultants), add/edit/remove rows
    (Role · Company · Address · Contact · Tel · Email). **Role is an inline dropdown** (chevron, flush
    with the row — same treatment as the project-detail status control) over the workbook taxonomy,
    with "Other…" for custom roles.
    **Company memory:** the same subs recur across projects, so the Company field suggests firms used
    before and pre-fills that firm's blank company-level details (address/tel/role); the *person* is
    never assumed — contacts differ between jobs — but once a known contact name is picked their
    tel/email fill in. Auto-filled cells tint briefly so the fill is visible, not magic.
    **Seed:** `seed/2026-07-25-project-directory-history.sql` (applied) — 143 subcontractor + 52
    client-side rows over 19 projects, 10 recurring firms with rotating contacts (e.g. Lineform
    Interiors on 14 projects across 3 people) so the auto-fill has real history to work against.
    **Next:** wire directory contacts into module people-fields (pickers) as modules are built.
  - ✅ **Checklist module type — BUILT** (first real module type, from Tom's Claude Design handoff
    `App modules checklist template`). One `ChecklistModule` component driven by a template row:
    `mode` (reference/record/signoff/tracked) · `status_set` (rag/yesno/complete) · `requireDetail`
    (nudges for evidence) · `flagOnAttention` (routes a stuck row out). Sticky header (donut +
    clickable status-count tiles + owner + expand/collapse + "not routed"/"answered without detail"
    filters), collapsible sections with tally + status pips, rows with status spine, note field,
    status buttons, stamp, hover actions, per-tab notes, sign-off, sticky save/discard bar, toast.
    **Row routing is real:** "Flag a team" writes a `meeting_handoffs` row, "Assign an action" writes
    an `actions` row, and the row then shows the tie chip. MODULES grid cards gained state + progress
    bar + donut. Schema: `module_templates`, `module_template_items`, `project_checklists`,
    `project_checklist_items` (applied; `db/migrations/` + `seed/2026-07-25-checklist-templates.sql`).
    **Seeded 4 tabs, 125 rows / 25 sections:** Building Regs (record/rag, 58), BD (reference/yesno,
    22), Adjudication (record/rag, 30), 70% Close Out (signoff/complete, 15 — rows carry a
    responsible discipline). PDF/XLSX buttons render but defer to a dedicated export pass.
  - ✅ **Batch 2 — 7 further tabs seeded, 133 rows / 26 sections** (`seed/2026-07-26-checklist-templates-batch2.sql`,
    applied to live DB): Designer (record/rag, 29 — Key Risks / Weekly / Design Checklist / Adjudication
    items), Graphics (reference/yesno, 22), Legal Kick Off (record/rag, 33), Legal Process (record/rag,
    35), WPB Kick Off (signoff/complete, 6 — steps carry a responsible role), Onsite Handover
    (signoff/complete, 4), Accountant On Site (signoff/complete, 4). All render through the same
    `ChecklistModule` (no code change beyond MODULE_DEFS cards). Owners map to real app_users where a
    role matches. **11 checklist templates now live.**
  - ⬜ **PM Checklist (workbook tab 22) is a register, not a checklist** — a blank per-project
    information-required log (Item / Work Package / Information Required / Action By / Comments / Date
    Required / Response / Status; 117 empty numbered rows, no fixed questions). Deliberately NOT forced
    into the checklist component; carried as a `pm-info` MODULE_DEFS card routing to the skeleton until
    the **register module type** is built. Same for Risk / Long Lead / RFI / Budget Movement.
  - ⬜ Per module: design → typed table + schema → specialise the register → audit trigger into the hub.
  - ⬜ **Checklist follow-ups:** audit trigger so checklist saves/sign-offs emit into the notifications
    hub (currently only the flags/actions they raise do); "Attach evidence" row action; export.

### Phase 5 — Register & activity: notifications hub + site-wide audit  *(large — in progress, branch `claude/phase-5-notifications-hub`)*
Reworked with Tom from a pure notifications hub into a **"Register & activity"** page (nav tab) with
two tabs, plus a header bell:
- ✅ **Hub UI** — bell + unread badge + dropdown activity panel (filter chips, day grouping, typed
  event rows, mark-all-read). Reads per-user `notifications` (RLS-scoped).
- ✅ **Open register** — cross-project register of every open action / flag / key date: summary tiles,
  scope filters (All open / Needs attention / This week), grouping (By urgency / person / project),
  per-kind rows with owner + urgency pill + inline buttons. Wired the two safe writes (Mark complete,
  Mark met).
- ✅ **Audit + fan-out backend (APPLIED to live DB)** — `audit_log` table (senior-read) + generic
  triggers on projects (every field), key dates/programme, meetings, flags, actions →
  `record_activity()` writes the audit row and fans out per-user `notifications` to
  `project_audience()` (team ∪ seniors). Verified end-to-end (edit → diff row → 6 fan-out notifs).
  SECURITY DEFINER helpers had direct-RPC EXECUTE revoked (advisor hardening). SQL versioned at
  `db/migrations/phase5_notifications_audit.sql`.
- **Scoping:** audience = team + seniors + pre-con now; **Phase 6's per-project visibility tightens
  `project_audience()` automatically**. Not true per-team scoping until then.
- ⬜ **Deferred to a cross-app "tie-back" pass:** the item **detail modal** (chevron), and the
  register's cross-app buttons (Reassign / Chase / Acknowledge / Convert / Raise a query).
- ⬜ **Deferred:** flag **severity** field (register buckets flags by age for now); external transport
  (email/Teams via M365).
- ⚠️ **KNOWN ISSUE — activity log under-wired (revisit).** Tom's observation: the Activity feed
  "isn't picking up the level of detail across users it needs." Root cause: the Activity tab + bell
  read the **per-user `notifications`** table, so a user only sees events **fanned out to them**
  (their team's projects + senior audience) — it behaves like a personal inbox, **not** a full
  cross-user activity log. The complete record lives in **`audit_log`** (all users/events, senior-
  read) but is **not surfaced in the UI**. Also, fan-out only populates **going forward** from when
  the triggers were added, and `record_activity` writes `actor_user_id` from `auth.uid()` (null for
  non-app writes). **Fix direction:** point the Activity/"full audit log" view at **`audit_log`**
  (scoped: seniors = all; contributors = their visible projects once Phase 6 lands) so it shows
  every user's activity with full detail; keep the bell on per-user `notifications`. Consider a
  one-off back-population of `audit_log`/notifications for recent history. Verify actor attribution
  end-to-end from the live app (real JWT) — the dev-org fan-out test ran without a user context.

### Phase 6 — Organisation & permissions layer  *(large — GO-LIVE GATE)*
- Org dashboard (add/edit users incl. title + team-lead; per-member project visibility; per-team
  meeting-status config); **new-org wizard** + persistent "which org am I in" indicator;
  permission-based project visibility + "assigned to me" filter; **new-project approval flow**
  (contributor creates → "pending" → senior approves) + duplicate address/name detection; "lead"
  projects below-the-line in meetings; **"My Team" view**.
- **Gate:** run the outstanding **RLS behavioural verification** (two accounts, table-by-table
  pass/fail) and `get_advisors` **before** the real `arke` org + first user migration.

### Phase 7 — Executive health view  *(large)*
- Accountability register (open actions/flags by staff × severity/urgency); pipeline pie + clickable
  project register; project-health scoring from module completeness; audit log; meetings register;
  portfolio clash calendar.

### Phase 8 — Schema & decisions cleanup  *(small)*
- Drop dead `meeting_entries.flag`; settle `owner_name_fallback`; confirm
  `org_meeting_types.group_field` is actually read (else drop).

### Cross-cutting / parallel
- **Claude programme-import** — wire the real API behind the Project Detail Page Excel stub
  (`importProgramme` / `convertArkeProgrammeToKeyDates` TODO): xlsx → Claude → `{event_name,
  target_date}[]` → `project_key_dates`. **Needs a serverless proxy** (public static app can't hold the key).

## Open decisions
- **Workflow:** one PR per batch, fresh branch off `main`, opened at the end (settled after the #26/#27
  stranding incident).
- New-project approval = a new project state (e.g. `pending`).
- Default project-visibility rules per role (Phase 6).
- "Team lead" flag (built as `is_team_lead`) treated as settled unless Tom reopens.

## Working agreement
Scope honestly before building; confirm design choices before code; say when an idea's wrong. One PR
per batch, verified in the harness, deploy confirmed green. **Keep this file updated with every batch.**
Long sessions split into fresh chats.
