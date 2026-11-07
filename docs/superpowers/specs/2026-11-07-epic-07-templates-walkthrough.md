# Epic 7 — Example templates: design & walkthrough

**Date:** 2026-11-07 · decided autonomously ("my call" marks my decisions)
**Mockup:** `Templates` artboard on https://claude.ai/artifact/2vnJ4H4n17vK9C6pVXU3mW (copy in
`docs/superpowers/mockups/epic-07/Templates.dc.html`)

## Format (my call: the engine's own JSON)

`assets/templates/*.json` = `{id, name, description, icon, collections: [Collection JSON], objects:
[{id, collectionId, values}]}`. Collections are exactly what Firestore stores (fields, layout,
views); values are stored values.

- **Every collection and object id starts with `@`** (`@orders`, `@o1`).
  `WorkspaceTemplate.instantiate` swaps each one for a fresh id wherever it appears. A template can
  therefore be added any number of times without the importer knowing which keys hold ids.
  Covered: reference targets, aggregate sources, reference values, manual orders.
- Import (`CollectionsListCubit.importTemplate`) writes the collections first, then the sample
  objects as new objects. Auto-numbers are allocated by the same transaction as any new card.
- No template code knows a domain word. A test greps `lib/` for them.

## UI

Home → **From template** (an icon button on phones; "Start from a template" in the empty state)
opens a dialog. Each template card shows its name, what it does, its collections as chips, a
"4 collections · 13 sample cards" line and **Add to workspace**. A failed add says so and keeps the
dialog open. After adding: a snackbar, then its first collection opens.

## Walkthrough

### Production & materials (the hoodie spreadsheet)

| Collection | What it holds |
|---|---|
| Colours | Per piece: fabric and ribbing in kg. **Pieces sewn** = sum of the Sewing journal. **Spent** = sum of purchases. **Material cost per piece** = spent ÷ pieces. **Fabric left** = bought − pieces × per piece − written off. **Pieces the fabric still makes** = ⌊left ÷ per piece⌋. Same for ribbing. "Per colour" Summary view. |
| Material purchases | Date, colour (link), material (Main fabric / Ribbing), kg, cost, written off |
| Sewing journal | Date, colour, pieces, sizes, notes |
| Cost summary | Totals over everything: materials per piece, plus the sewing and delivery constants, give the **true cost** and **margin** against the target price |

The spreadsheet's latent bug was the kg-per-piece cell left empty, so the balance showed raw
purchases. Here an empty "Fabric per piece" makes *Fabric left* and *Pieces still makes* blank
instead of misleading: the formula adds `0 / {per piece}`, which is blank when that field is empty.
Sample numbers checked in the test against hand math:
- Black: 28 pieces, 300 ₴/piece, 5.4 kg left (7 more pieces).
- Season: 359.21 ₴ materials per piece, true cost 769.21 ₴, margin 1,030.79 ₴.

### Orders pipeline (the Trello boards)

| Collection | What it holds |
|---|---|
| Orders | Auto-numbered `ORD-0001`. Status (ordered → to clarify → in queue → in progress → made → shipped → received, plus not picked up). Deadline, labels, recipient/phone/city/shipping point, prepayment / cash on delivery, design images. Items / items done totals. **Pipeline** board grouped by status. Delivery fields sit in a collapsed group, so the order's items show near the top. |
| Order items | Pick an **item from stock** (one link). **Garment, size, colour** come from it by lookup and title the row in the order's item list. Also: embroidery & notes, quantity, **done**, the order, and *Order status* (lookup). |
| Inventory | Item, garment, size, colour, received. **Reserved** = sum of item quantities whose order is still open. **Sold** = shipped / received / not picked up. **Available** = received − reserved − sold. Boards per garment, grouped by size. |
| Gift certificates | Code, status (created → issued → used), amount, given to, issued on. Lifecycle board. |

Reserved and sold are derived from the orders, so the "negative reserve" drift the manual Trello
setup had can't happen.

## Verification

- `templates_acceptance_test.dart`: both templates instantiate, derive and match the hand math.
  Also covered: boards group by the right field, ids are fresh, no `@` leaks, and no domain words
  in `lib/`.
- `template_import_test.dart`: the import writes every collection and card linked, auto-numbers
  1–3, and a second import doesn't collide; the picker adds and closes, and shows the error when an
  add fails.
- Web e2e on the real workspace:
  - picker vs mockup;
  - Orders pipeline added → Pipeline board with `ORD-0001`/`ORD-0002`; an order shows its items
    titled from the stock item's garment, size and colour;
  - Production & materials added → "Per colour" tiles 28 / 8,400 ₴ / 300 ₴ / 5.40 kg / 7.

## Known limits

- Importing writes one collection after another and the samples in parallel. A failure midway
  leaves what was written; adding again creates a fresh copy.
- Templates ship inside the app; a marketplace is a future epic.
