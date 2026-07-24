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
  org/permissions + RLS go-live gate (Phase 6).

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
- **Phase 3 — Meetings workflow & flag integrity.** Shipped across PR #26 (merged, live) + PR #27:
  - *Slice 1 (PR #26, merged/live):* closed-meeting flag integrity — block posthumous
    acknowledge/convert; unresolved flags read as "⚑ Carried forward — needs action". Resolved the
    Westlake flag mystery (flags were acknowledged into oblivion after their meeting closed).
  - *Slices 2–5 (PR #27, open):* in-meeting rail indicators (covered tick + flag/action badges);
    edit project status from within a meeting (senior); "no team member assigned" flag warning with
    an "Assign a team member →" link to the project detail page; meetings-list "Closed meetings"
    section header + standardised closed-badge emboss.

---

## ▶ REMAINING PLAN — work top to bottom, confirm scope per phase

### Phase 4 — Project detail pane build-out  *(large, iterative — in progress)*
- ✅ **4a — Clickable metric tiles → catalogues** (PR #28): Open actions / Open flags / Overdue dates
  tiles jump to the Actions & Flags catalogue; catalogue gains a collapsible Completed section.
- ✅ **4c — Team-change data integrity** (PR #28): warn on reassigning/removing a member who owns open
  actions; offer to reassign them or keep; actions retained either way.
- ↪ **4b — Audit trail → per-user activity** was expanded by Tom into a full permission-scoped
  notifications + audit hub and **folded into Phase 5** (below).
- ⬜ **Modules build-out** — the 8 "PLANNED" placeholder tiles (Building Regs, Adjudication, Risk
  Register, Long Lead Items, RFI Schedule, Budget Movement, Close Out, Lessons Learned). Each is a
  real feature needing its own schema + design — **dedicated per-module scoping pass, own session.**

### Phase 5 — Notifications & site-wide audit hub  *(large — brought forward & expanded from original "Notifications")*
Tom's spec: a **full audit trail of site-wide field changes / any update submitted to the app, wired
to every customisable field**, surfaced as a **notifications hub — a bell by the profile tab
(top-right)** with unread badge + dropdown panel. **Permission-scoped:** a user only sees
notifications for things they're entitled to (e.g. a team that can't see a project gets none).
Three layers:
1. **Audit layer** — generic DB triggers on every table logging field-level before/after diffs to an
   audit log. Today only `notify_action_owner` / `notify_collaborator` / `notify_query_events` exist
   (actions/queries only); `org_audit_log` logs member changes only. Everything else (project fields,
   status, team, new projects, key dates, meetings, flags) is unwired.
2. **Notification fan-out** — those triggers also enqueue per-user `notifications` rows (already
   RLS-scoped to the recipient via `user_id = auth.uid()`).
3. **Bell hub UI** — greenfield (no notification UI exists today).
- **Scoping decision:** fan-out by **project-team membership + role + pre-con visibility now**,
  structured so **Phase 6's per-project visibility rules tighten it automatically**. True per-team
  project-level scoping depends on Phase 6 — do not claim it's complete before then.
- Then external transport (email/Teams via M365).

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
