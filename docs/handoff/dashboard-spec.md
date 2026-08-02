# Dashboard consolidation — "Command view" spec (Step 4)

Agreed design: section `2a` in `dashboard-design/Dashboard Consolidation.dc.html`.
All styling comes from the lifecycle visual contract (B1–B4) — no dashboard-local chips/badges.

## Routing & shell

- New `#/dashboard` view is the DEFAULT landing for every role (replaces Projects as home).
- Ribbon: REGISTER tab is retired; DASHBOARD takes its slot, first in nav.
- `#/register` route survives as the drill-down page (= the dashboard's "Open register" tab with
  filters applied). Fixes the known two-click nav + non-restorable deep-link defect.
- Role gating reuses `isSenior`. Same page, gated sections — this IS the exec dashboard from the
  old Phase 7; do not build a second page later.

## Tabs

1. **Overview** (default)
   - KPI cards (4): role-scoped counts. Exec: Due this week / Overdue / Open flags / Key dates.
     Contributor: Your open actions / Due this week / Flags for your team / Your team's items.
     Every card navigates to Open register with that filter applied ("View in register →").
   - **Exec-only boards**, in order:
     - Project health — stage-weighted: open actions/flags/overdue key dates & programme milestones
       vs how far along the project is (further along ⇒ less outstanding tolerated), × module
       completeness (how much data the modules have been fed). RAG-graded bars (fill + tinted track
       + coloured %). Value movement joins the formula in Step 7 (slot already carries the caption).
     - Team performance — open/overdue aggregate per project team, stacked bar (prussian open,
       carmine overdue), "Needs assistance" chip at ≥2 overdue; row click → register filtered by team.
     - Right rail: Pipeline (by count, by value in Step 6) · Meetings (cadence & clearance) ·
       Slipping (programme moves this week from `programme_revisions`, attributed, with +Nd chips).
     - Programme strip (live tracker bars with risk markers).
     - Accountability — open items by person, aged (age-clock scale); row click → register by owner.
   - **Contributor**: "Your work this week" list (their items, register-row anatomy, one-click verbs).
2. **Open register** — unified actions / flags / key dates grouped Needs attention now / This week /
   Upcoming. Compact selector bar (single row of four dropdowns): Timescale (All open / Due this
   week / Overdue / Needs attention) · Kind · Team · Owner, plus "Clear all filters" + live count.
   Active selects highlighted carmine. Drill-ins from KPIs/teams/people pre-select the dropdown —
   every filter is switchable to an alternative, not just clearable.
   Filters are URL query params: `#/register?scope=overdue`, `?team=technical`, `?person=<user_id>`.
   Row expansion shows the item's event history (audit spine) as a timeline.
3. **Activity** (named just "Activity") — ONE tab, two lenses over the same audit spine:
   - **Feed** lens (everyone): readable activity stream, unread accents, bell dropdown unchanged.
   - **Log** lens (seniors only): the same events as an auditable table (when / actor / event /
     detail / project / source) with PDF + XLSX exports.
   Previous separate "Audit log" tab is merged away — two tabs would re-create the audit_log vs
   item_events divergence in the UI that Move 4 retires.

## Team as a derived dimension (no schema change)

- Action's team = its owner's discipline (from `app_users` role / `MEETING_TYPES` groupField mapping).
- Flag's team = its `to_department`.
- One `teamOf(item)` helper in the service layer; the register team filter and the team-performance
  aggregate both read it.

## Verbs, not writes

Dashboard one-click actions (Mark complete / Mark met / Acknowledge) call the Move-2 service verbs —
the same functions as the item modal, meeting pane and My Work. No dead stub buttons.

## Row anatomy (from the lifecycle contract)

- Kind identity (B1): flag = carmine + tinted card, action = prussian check-square, key date =
  prussian-80 calendar; 3px left accent border.
- State chips (B2): OPEN with dot; OVERDUE · Nd solid carmine (the one loud chip); DUE TODAY amber.
- Age clock (B3): 0–2d grey / 3–5d amber / 6d+ carmine, weight 700.
- Provenance strip (B4) under every title ("Raised in PM Meeting 14 Jul → chased 28 Jul"); each
  segment opens that item. Impact annotations in carmine ("→ PC Phase 1 +7d").
