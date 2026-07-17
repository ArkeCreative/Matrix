# arke [matrix]

Internal project-management web app for **Arke Creative** — bespoke commercial
office design & fit-out (Central London + South East).

Formerly built under the working name *BixFrame*; rebranded and re-platformed as
**arke [matrix]**. This is a rebrand and re-platform, not a rewrite — every
feature carries over.

## Architecture

A single self-contained `index.html`:

- **React 18** via CDN, **pre-compiled JSX** — the embedded source is already
  `React.createElement` form. There is no `tsc`/build step. Write new code in
  that form, not JSX.
- **Inline style objects** + a JS palette object `C`. Only a handful of CSS
  classes exist (the pre-React splash).
- **Supabase** backend (project `matrix`). URL + anon key are baked into the
  compiled output; Row-Level Security is the guard, not the key.
- **Hash routing:** `#/projects`, `#/meetings`, `#/actions`, `#/tracker`.

## Working from source

`index.html` is the deliverable. It is assembled from three parts so the large
compiled script is editable:

| File | What it is |
|---|---|
| `shell-head.html` | Everything up to and including the app `<script>` tag |
| `app.jsx` | The compiled application source |
| `shell-tail.html` | The closing tags |
| `rebuild.sh` | Verifies + splices the parts back into `index.html` |

Rebuild and verify:

```bash
./rebuild.sh
```

This runs `node --check` (static parse) and a `new Function()` runtime parse,
reports paren/brace/bracket balance (target 0/0/0), and splices `index.html`.
Both parse checks must pass before the splice is trusted.

## Design system

Branding follows the **arke-design** system: Carmine `#8C002A` (primary),
Prussian `#183B4F` (secondary, sparing), Century Gothic type. Traffic-light
status colours (green / amber / red) are kept as independent semantic colours.

## Status

- **Stage A** — consolidated baseline schema deployed to Supabase. ✓
- **Stage B** — identity & branding rebrand. ✓
- **Stage C** — organisations & users (roster reseed). Pending.
- **Stage D** — repository & deployment. In progress.
