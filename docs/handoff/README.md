# Handoff: Lifecycle Unification + Dashboard Consolidation

Target codebase: **ArkeCreative/Matrix**, branch `main` (single-file React app, `app.jsx`, Supabase backend).
This bundle merges two workstreams into ONE plan. Read this file first, then:

1. `lifecycle-plan/README.md` — the original lifecycle unification & cross-app visual fidelity handoff
   (Moves 1–5, Part B visual contract B1–B4, acceptance criteria). Still authoritative for its scope.
2. `dashboard-spec.md` — the NEW work: consolidating the Register tab + Activity into a role-gated
   Dashboard landing page ("Command view"), agreed with Tom via design review.
3. `dashboard-design/` — the agreed design mocks (open the .dc.html files in a browser):
   - `Dashboard Consolidation.dc.html` — interactive mock; section id `2a` is the AGREED design
     (earlier options 1a/1b/1c are retained below it for reference only).
   - `Consolidated Dev Plan.dc.html` — the merged dev-plan document, presentation form of this README.

## Merged sequencing (supersedes both source plans' ordering)

- **Step 3 (housekeeping)** — lifecycle Move 1 rides with the queued one-liners: canonical status
  vocabulary (actions settle as `'closed'`; fix the `'completed'` writer ~line 1446 and the
  `.neq('complete')` filter ~line 7236) + Postgres CHECK constraints per status column.
- **Step 2.5 (NEW — the seam; hard prerequisite for Step 4)** — lifecycle Moves 2 + 3 + Part B:
  service layer (one exported verb per transition: `completeAction`, `acknowledgeFlag`, `convertFlag`,
  `resolveQuery`, `markDateMet`, `moveDate`, …), one shared `isOpen(kind, item)` predicate, dumb
  scope-only loaders, and the shared visual components `STATE_META` / `StateChip` / `AgeClock` /
  `ProvenanceStrip`. Acceptance: each surface's local chip/badge/filter code is DELETED.
- **Step 4 (expanded)** — the Dashboard (see `dashboard-spec.md`). Absorbs "exec view part 1" and the
  Register/activity-log rework. Move 4 (audit spine: `item_events` vs `audit_log`) is decided inside
  this step's scoping; until then all verbs emit both.
- **Step 5** — `threadOf(item)` provenance resolver; chronology export prints the same object the
  dashboard's provenance strips render. Dashboard "Slipping" card reads accrued `programme_revisions`.
- **Steps 6–7** — commercial spine, then value-weighted pipeline + full stage-weighted health swap
  into dashboard slots already built.

Rationale for the order: the dashboard must be a CONSUMER of the lifecycle contract, never a seventh
copy of the verbs/chips. Land the seam at six surfaces, not sixteen.

## Acceptance (Tom, on the live app)

1. Contributor login lands on `#/dashboard` showing their week; senior login same route with exec
   boards. No two-click nav; refresh restores view + register filters (URL query params).
2. Click "Overdue" KPI → register filtered to overdue; click a person in Accountability → their
   plate; click a team in Team performance → that team's items. All filters switchable from the
   register's selector bar, not just clearable.
3. Complete an action from the dashboard → project KPI, register count and My Work move live, and
   the audit spine carries the event with actor attribution.
4. The same item shows identical chip / age colour / provenance strip on dashboard register, My Work,
   project tab and item modal.
5. Acknowledge a flag anywhere → moves to RESOLVED block on every surface, never vanishes.
