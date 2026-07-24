# seed

Version-controlled record of the fictional test data seeded into the **dawlish**
dev org (Supabase project `matrix`, `tpxabhqsjngalilbznhz`). This is dev/test
data only — no real Arke data lives here (that's gated behind Phase 6 RLS
go-live).

| File | Applied | What it adds |
|---|---|---|
| `2026-07-24-test-data-expansion.sql` | 2026-07-24 | +17 projects, ~125 key dates, 16 historic meetings + attendees, 54 meeting entries, 24 actions (+ collaborators & queries), 9 flags |

## Conventions

- **FKs resolved by natural key** — `app_users.initials`, `projects.project_number`,
  `meetings.started_at` — so no UUIDs are hard-coded and the scripts stay
  readable/reviewable.
- **`SET LOCAL session_replication_role = replica`** wraps each batch so the
  notify / touch / set-org triggers don't fire on a historic backfill (`org_id`
  is set explicitly). It is transaction-scoped and reverts on COMMIT/ROLLBACK.
- Scripts are **one-shot** against the baseline they were written for — they are
  **not idempotent** (`project_number` / `description` aren't unique-constrained),
  so re-running against a DB that already holds the data will duplicate it.

## Applying

Run against the target project via the Supabase SQL editor or MCP
(`execute_sql`). Review the header comment in each file first — it documents the
exact scope and the org it targets.
