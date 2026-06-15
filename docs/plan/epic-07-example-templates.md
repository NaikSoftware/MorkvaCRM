# Epic 7 — Example Templates (optional, non-hardcoded)

## Goal
Ship a few **importable example templates** — built entirely as data on top of the generic
engine — that a user can load to get started, and that double as the product's end-to-end
acceptance test. **No domain logic enters the product code.**

## Why
The fastest proof that the engine is universal is to rebuild the user's real setups (the hoodie
spreadsheet and the morkvawear Trello) **using only collections, fields, views, and calculated
fields** — no special-casing. If they can be expressed as a template, the engine is done right.
Templates also give new users a running start instead of a blank app.

## In scope
- A lightweight **template format**: a bundle of collection schemas + views + (optionally) seed
  objects, expressed in the same JSON the engine already uses. A template is just data the app
  can import into the user's Drive.
- An **import flow**: pick a template, and it creates the collections/views (and any seed
  objects) in the user's workspace, fully editable afterward like anything else.
- **Two example templates**, authored as data only (see [`appendix-examples.md`](appendix-examples.md)
  for the source setups they model):
  1. **Apparel production & inventory** — collections for a color/option reference list,
     material purchases, inventory items (with derived available/reserved/used), and a cost
     roll-up; reproducing the spreadsheet's aggregations.
  2. **Orders pipeline & boards** — an orders collection with a status select field (board view
     grouped by status), an inventory collection (board view grouped by size), reference fields
     linking orders to inventory, tag/label fields, an auto-number order field, and derived
     stock counts.

## Out of scope
- Any code that knows about hoodies, orders, colors, or sizes. If implementing a template needs
  a capability the engine lacks, that capability is a **generic** gap to fix in Epics 1–6, not a
  hardcode here.
- A template marketplace/sharing system (future epic). This epic is local example templates +
  import only.

## Key concepts
- **A template is data, not a feature.** It exercises the engine exactly as a user would.
- **This epic is the acceptance gate for the whole plan**: if both examples can be built and
  used purely through templates, Epics 1–6 are validated.

## Deliverables
- The template (bundle) format and an import flow.
- The two example templates above, authored entirely as engine data.
- A short written walkthrough showing each example running on the generic engine (table + board
  views, references linking, calculations matching the originals).
- Tests verifying a template imports into a clean workspace and produces working collections,
  views, and correct calculated values.

## Acceptance criteria
- Importing the apparel template yields collections whose roll-up/aggregation values match the
  spreadsheet's cost and balance math.
- Importing the orders template yields an orders board grouped by status and an inventory board
  grouped by size, with orders linked to inventory via reference fields and stock counts
  derived automatically.
- Everything imported is ordinary user data — fully editable, with **zero** domain-specific
  branches anywhere in the product code.
- A grep of the codebase for domain terms (hoodie, order, color, size, etc.) finds them only in
  template data and docs, never in engine/UI logic.

## Dependencies & design notes
- Depends on Epic 4 (views) and Epic 6 (calculations/references/auto-number).
- **Use `/design`** for the template picker/import screen.
