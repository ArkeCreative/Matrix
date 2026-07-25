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
- ↪ **4b — Audit trail → per-user activity** was expanded by Tom into the permission-scoped
  Register & activity hub and **folded into Phase 5** (below).
- ⬜ **Modules build-out** — the 8 modules (Building Regs, Adjudication, Risk Register, Long Lead
  Items, RFI Schedule, Budget Movement, Close Out, Lessons Learned). **Workflow:** Tom workshops each
  module's design in Claude Design and passes it back; each is **custom** (its own fields/info types)
  and needs **its own schema** to be functional. Build one at a time.
  - ✅ **Standard module-page skeleton** in place: the MODULES tab is now 8 clickable cards
    (`MODULE_DEFS`) opening a reusable `ProjectModulePage` shell (back nav, title + "In design" pill,
    blurb, stat tiles, register table shell + empty state). Each module specialises this shell.
  - ⬜ Per module: design (Claude Design) → typed table + schema → specialise the register (columns,
    add/edit form, statuses) → audit trigger so its events flow into the hub (e.g. `rfi-raised` /
    `rfi-answered`; a "Modules" hub category may be added). No per-module data yet.

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
