# Handoff: Lifecycle Unification & Cross-App Visual Fidelity

Target codebase: **ArkeCreative/Matrix** (`app.jsx`, single-file React app, Supabase backend, main branch).
All line numbers below were verified against `app.jsx` on main, 31 Jul 2026 — re-locate by searching the quoted strings if the file has moved on.

## Overview
This package specifies a refactor, not a new feature: unify the lifecycle of the four item kinds — **flags, actions, queries, key dates** — behind one service layer, one openness predicate, one audit spine, one provenance resolver, and **one visual contract rendered identically on every surface**. It retires the class of bug where the same operation is implemented on multiple surfaces and the copies drift (the register stubs, meeting-acknowledge not recording, acknowledged flags vanishing from views).

## About the Design Files
`Lifecycle Contract.dc.html` in this bundle is a **design reference created in HTML** — a spec document showing the plan and the exact intended visual treatments. It is not production code. The task is to implement the refactor inside `app.jsx` using the app's existing patterns (the `sb` Supabase client, the RX bus, `item_events`, the inline `lucide()` icon helper, and the `MA`/`C` token objects). Do not ship the HTML.

## Fidelity
**High-fidelity** for the visual contract (Part B): chips, card anatomy, age clock, settled treatment, and kind identity are specified with exact hexes, sizes, and weights, and must render pixel-identically across surfaces. The code plan (Part A) is architectural guidance — follow the codebase's conventions for implementation detail.

---

# PART A — Code plan (five moves, in order)

## Move 1 — Canonical vocabulary + CHECK constraints
One settled word per table. Actions settle as **`closed`** — nothing else.
- Fix the one divergent writer: `sb.from('actions').update({ status: 'completed', ... })` (~line 1446) → `'closed'`.
- Fix the third spelling in a filter: `.neq('complete')` (~line 7236) → `'closed'`.
- Add a Postgres `CHECK` constraint per status column so a wrong spelling fails loudly:
  - `actions.status IN ('open','closed')`
  - `meeting_handoffs.status IN ('open','acknowledged','converted')`
  - `queries.status IN ('open','resolved')`
- Data migration cost today: **zero rows** (all existing data is already `'closed'`). Ship the writer/filter fixes and constraints in the same PR.

## Move 2 — One service layer (highest leverage)
One module, one exported verb per transition. Every surface — item modal, meeting pane, My Work, Register, project Flags & Actions tab, checklist routing — calls the same function. No surface writes a status directly.

Verbs: `completeAction`, `reopenAction`, `acknowledgeFlag`, `convertFlag`, `resolveQuery`, `answerQuery`, `escalateQuery`, `markDateMet`, `moveDate`.

Each verb owns, in one place:
1. its canonical write shape (status word, timestamps, side fields like `resulting_action_id`),
2. its `item_events` entries (append-only spine — never optional, never best-effort skipped),
3. its `audit_log` emission (interim rule until Move 4 lands: every verb emits both trails),
4. riding `sb` so the RX bus auto-emits as today.

Known duplicate implementations to collapse into these verbs (search anchors):
- Acknowledge a flag: modal (~3457), meeting pane (~6822), meeting bulk path (~6989).
- Complete an action: ~1446, ~2861, ~3360, ~7034, ~7880.
This is the existing RX-B `rowPayload()` doctrine ("so the two write paths can't drift") applied app-wide. **It must land before the Register rework (Step 4) and before Steps 8–9 add new modules**, which would otherwise multiply the copy count.

## Move 3 — One openness predicate, dumb loaders (same batch as Move 2)
- Loaders fetch a **scope** (this project, my department) — never a lifecycle slice. Delete the `.neq('acknowledged')` (~1642, ~7166, ~7235), `.neq('converted')` (~3283), `status !== 'converted'` (~3957), and `acked || converted || resulting_action_id` (~3345) family.
- One shared `isOpen(kind, item)` derives open vs settled everywhere; `doneFlags`/`doneActions` become selectors over the one dataset.
- Fetch cost is a non-issue (~460 rows across every aggregate per the dev plan's own count).
- This generalises the Fitzrovia fix so it cannot recur per-view.

## Move 4 — One audit spine (scope with Tom inside the Step 4 Register conversation)
`item_events` is the record. `audit_log` / the `record_activity` trigger narrows to notification fan-out, or the feed becomes a view over `item_events`. Until decided, Move 2's verbs emit both, so nothing diverges by path.

## Move 5 — Provenance as a followable object
The links already exist in schema (`resulting_action_id`, `parent_type`/`parent_id`, `cause_flag_id`/`cause_action_id`, `meeting_id`). Add one `threadOf(item)` resolver in the service layer that walks flag → action → query → date change, and render it as the **provenance strip** (Part B, card anatomy) on every card and modal. The Step 5 chronology export is then a print of the same object.

## Lifecycle contract (the shared state model)
Every kind is either **OPEN** or **SETTLED** — one shared axis with kind-specific settled words. Overdue, in-query, escalated, and slipped are **overlays derived at render time — never stored statuses**.

| Kind | Table | Open | Settled | Notes |
|---|---|---|---|---|
| Flag | `meeting_handoffs` | `open` | `acknowledged` or `converted` | converted always writes `resulting_action_id`; nothing reads that field as a shadow status |
| Action | `actions` | `open` | `closed` (only word) | overlays: overdue (due < today), in-query (open query attached) |
| Query | `queries` | `open` | `resolved` | escalation stays an overlay (`escalated_to`); ball-in-court derived from thread, never cached |
| Key date | `project_key_dates` | boolean `completed` = false | true ("Met") | only `markDateMet()` touches it; a *move* is a `programme_revisions` event, never a state; overlay: slipped +Nd vs baseline |

One **`STATE_META`** map drives chip, ribbon, filter, and count alike, so they cannot disagree.

---

# PART B — Cross-app visual fidelity (a key tenet, not a polish pass)

**The rule: no surface invents its own signal.** Kind identity, state chips, the age clock, the provenance strip, and the settled treatment render **identically** on all of: My Work cards, the department rail, the project Flags & Actions tab, Register rows, the meeting pane, the item modal header, and ProgrammeHistory. Density may vary by surface; order, vocabulary, colour, and iconography never do. Everything below already exists somewhere in the app — this promotes the best existing treatment to the **only** treatment, driven off the same `STATE_META` the service layer uses.

All hexes are the app's existing `MA`/`C` tokens (which are the Arke design-system core: Carmine `#8C002A`, Prussian `#183B4F`). Icons are the existing inline `lucide()` helper at 1.75px stroke. Type is Gilroy per the app.

## B1 — Kind identity (icon + accent, fixed forever)
| Kind | Icon (lucide) | Accent | Usage |
|---|---|---|---|
| Flag | `flag` | carmine `#8C002A` | only kind allowed a carmine-tinted open card — attention-seeking while open |
| Action | `check-square` | prussian `#183B4F` | calm workhorse; carmine appears only as the overdue overlay, never identity |
| Query | `message-square` | amber `#C47D11` (text `#A5741C`) | amber = waiting-on-someone, matches existing ribbon/ball-in-court colours |
| Key date | `calendar-check` | prussian-80 `#466272` | programme family; shares the prussian ramp with pipeline/timeline |

Rendered as: 3px left border accent on cards + kind icon at 15–18px beside the title.

## B2 — The state chip (one component, six states)
Spec: 9px Gilroy SemiBold (600), letter-spacing 0.12em, uppercase, **square corners**, 1px border on a tint fill, padding 4px 9px. Open states carry a 6px dot; settled carry a ✓ glyph.

| State | Fill | Border | Text | Note |
|---|---|---|---|---|
| Open | `#E8ECEE` | `#D1D8DC` | `#183B4F` | prussian dot |
| In query (overlay) | `#FEF3C7` | `#EAD08A` | `#A5741C` | amber dot `#C47D11` |
| Overdue · Nd (overlay) | solid `#8C002A` | `#8C002A` | `#FFFFFF` | **the one loud chip** |
| ✓ Settled | `#E7F0EA` | `#CFE3D6` | `#1E6B45` | wording per kind: Closed / Acknowledged / Resolved / Met |
| → Converted | `#F4E6EA` | `#E8CCD4` | `#8C002A` | links to the resulting action |
| Archived | transparent | 1px dashed `#B5B5B5` | `#767676` | ghost; matches lost/handed-over convention |

The item modal's state ribbon stays — it is the detail form of the same `STATE_META`; chip and ribbon read the same map so they cannot diverge.

## B3 — Age clock (every open item, one scale)
The existing MARailFlag thresholds, applied everywhere: **0–2d grey `#767676` · 3–5d amber `#A5741C` · 6d+ carmine `#8C002A`**. Format: "7 days open", weight 700 at the threshold colours. Paired with attribution ("raised by Priya N · for Design team"). Closes the exec "attribution + ageing" ask with no new data.

## B4 — Card anatomy (one order, every surface)
Top to bottom, never reordered:
1. **Kind mark** — left-border accent + kind icon.
2. **Title** — 13px Gilroy SemiBold `#0A0A0A`.
3. **Provenance strip** — 10.5px grey `#767676` inline chain: project · "Raised in DT 12 Jun" → "action A-114" → "query resolved" → impact ("Practical Completion +10d" in carmine, 600). Each segment clickable, opens that item's modal. This is `threadOf()` rendered inline.
4. **State chip** — top right.
5. **Footer** — attribution left, age clock right, above a `#F0EFEC` hairline.

## B5 — Settled treatment (never hidden, always sectioned)
The project-tab RESOLVED pattern becomes the standard on My Work closed list, Register, and meeting pane:
- green check (stroke `#1E6B45`, 2.5px) + line-through title (`text-decoration-color: #B5B5B5`),
- "by {person} · {date}, in {surface}" in 10.5px grey,
- resolution note in 11.5px italic `#1E6B45` on a 2px `#2D7A5F` left rule,
- ✓ Settled chip, card at ~0.92 opacity.
Settled items move to a collapsible RESOLVED block **on the same surface — they never vanish** (the Fitzrovia rule).

## B6 — Implementation shape
One `STATE_META` object (per kind × state: label, chip colours, icon, settled?) + three shared render helpers — `StateChip(item)`, `AgeClock(item)`, `ProvenanceStrip(thread)` — consumed by every surface. Deleting each surface's local chip/badge/filter code is part of the acceptance criteria, not optional cleanup.

---

## Sequencing against DEV_PLAN.md
- **Step 3 (next housekeeping batch):** Move 1 rides alongside the queued one-liners (won→LTA, dead columns, flag severity).
- **New Step 2.5 (insert before Step 4):** Moves 2 + 3 + the Part B shared components. Mostly mechanical call-site routing.
- **Step 4 (with Tom):** Move 4, inside the already-deferred Register/activity-log scoping conversation.
- **Step 5:** Move 5 pays off — the chronology export prints the provenance object.
- **Why before Steps 8–9:** every new register/agenda module multiplies the surfaces writing these verbs — land the seam at six surfaces, not sixteen. Step 14's regression guard then tests one seam instead of a matrix of copies.

## State management
- No new client state model: verbs write via `sb`, RX bus emits, views select. `isOpen`/`doneX` become pure selectors over one fetched dataset per scope.
- `STATE_META` is a static module-level constant, imported by verbs and render helpers alike.

## Design tokens
Use the app's existing `MA` (~line 3154) and `C` (~line 175) objects — do not introduce new hexes. Values referenced above: carmine `#8C002A` / dark `#6E0021` / tint `#F4E6EA` / border `#E8CCD4`; prussian `#183B4F` / 80 `#466272` / tint `#E8ECEE` / border `#D1D8DC`; amber `#C47D11` / text `#A5741C` / fill `#FEF3C7` / border `#EAD08A`; green `#1E6B45` / fill `#E7F0EA` / border `#CFE3D6` / rule `#2D7A5F`; greys `#0A0A0A #2A2E2C #6B7270 #767676 #B5B5B5 #D6D6D6 #E2E2DF #F0EFEC #F6F6F4`. If any differ from the live `MA`/`C` values, **the live tokens win**.

## Assets
None required — icons come from the app's inline `lucide()` map; type and colour from existing tokens.

## Files in this bundle
- `README.md` — this document (self-sufficient).
- `Lifecycle Contract.dc.html` — the visual spec: diagnosis table, five moves, lifecycle contract, chip/card/settled specimens, roadmap placement. Open in a browser for the rendered reference.
- `screenshots/01–06-spec.png` — the rendered spec, top to bottom: header + diagnosis, five moves, lifecycle contract, kind identity + state chips, card anatomy + settled treatment, roadmap placement.
