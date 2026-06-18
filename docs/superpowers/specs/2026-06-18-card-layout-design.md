# Card Layout — Design Spec

**Date:** 2026-06-18
**Status:** Approved (design); implementation plan pending
**Area:** `core/domain`, `features/collections/editor`, `api/data`

## Problem

Today a collection's card configuration renders every field as a single
vertical **Column**. There is no way to control layout: an autonumber field
takes the same full width as a long title, and fields cannot sit side by side.
Users need **basic layouting** — group fields into rows, place fields next to
each other, and control each field's width.

## Goals

- Arrange a card's fields into **named, collapsible sections**.
- Within a section, arrange fields into **rows**; multiple fields per row.
- Control each field's width via a **12-column span** (1–12).
- Edit the layout **WYSIWYG** by dragging directly on the preview canvas.
- Be **responsive**: on narrow widths every field renders full-width.
- Persist losslessly to Firestore and stay backward-compatible with existing
  collections (which have no layout).

## Non-goals (this version)

- Free-form pixel/percentage drag-resize (we use a 12-column grid).
- Per-view layouts (a single default layout lives on the collection; the model
  is structured so Epic 4 "views" can later carry their own layout).
- Conditional visibility, label positioning, tabs, or nested sub-sections.

## Decisions (from brainstorming)

| Fork | Decision |
|------|----------|
| Width model | **12-column span picker** (1–12 per field); stacks full-width on mobile |
| Edit UX | **WYSIWYG drag on the canvas** (the preview pane becomes interactive) |
| Sections | **Yes** — named, collapsible sections, each containing rows |
| Data-model placement | **Approach A** — separate `CardLayout` on the collection, referencing field ids |

## Approach A — why

`Collection.fields` stays a **flat ordered list** and remains the source of
truth for *what fields exist* and their per-type config. Layout is a **separate
presentation structure** that points at field ids.

- Clean separation of data vs. presentation; field definitions are untouched.
- Aligns with upcoming **Epic 4 (views)** — a view can later own its own layout.
- Cost: the layout must be **reconciled** against `fields` on load (handle
  fields added or removed outside the layout editor). This is handled by pure
  self-healing logic (see below).

Rejected: **B** (embedding `sectionId`/`rowId`/`span` in each `FieldDefinition`)
pollutes field definitions with presentation, gives section titles no home, and
makes future multi-layout support painful. **C** (per-field break flags) is
simpler than a tree but makes section metadata awkward and dragging harder.

## Domain model

New immutable types (Equatable, `toJson`/`fromJson`) in
`lib/core/domain/card_layout.dart`:

```
CardLayout    { List<LayoutSection> sections }
LayoutSection { String id; String? title; bool collapsed; List<LayoutRow> rows }
LayoutRow     { String id; List<LayoutCell> cells }   // cells ordered left -> right
LayoutCell    { String fieldId; int span }            // span in 1..12
```

`Collection` gains `final CardLayout layout;` serialized under a new `"layout"`
key. `kCollectionSchemaVersion` stays **1** — a missing layout is synthesized,
not migrated.

### Invariants

- Each `span` is clamped to `1..12`.
- Sum of spans within a row is `<= 12`. Leftover columns render as empty space.
- **Every field id in `Collection.fields` appears exactly once** across all
  sections/rows/cells. No duplicates, no orphans, nothing missing.

## Backward-compat & self-healing

All reconciliation lives in pure functions over the immutable types, invoked by
`Collection.fromJson` (and reused by the cubit after add/remove field):

- **No `"layout"` key** (every existing collection): synthesize a default —
  one untitled section, each field as its own full-width (span 12) row, in the
  current `fields` order.
- **Layout present**: reconcile against `fields` —
  - drop cells whose field id no longer exists; prune rows left empty; prune
    sections left empty only if more than one section remains (always keep at
    least one section).
  - append any field present in `fields` but absent from the layout as a new
    full-width row in the **last** section.

This keeps add/remove-field robust without coupling `fields` and `layout`.

## Editor UI — WYSIWYG canvas

The preview pane (`card_preview.dart`) becomes an interactive **layout canvas**.
The field list (`field_list.dart`) keeps add / remove / select; the config panel
keeps per-field config. The cubit (`collection_editor_cubit.dart`) gains layout
operations.

- **Cells:** each field tile shows its label + preview affordance, a drag handle,
  and a resize handle on the right edge. Dragging the resize handle changes the
  span 1–12, snapping to grid columns; the row neighbor gives/takes to keep the
  row sum `<= 12`.
- **Rows:** drop a field beside another -> join that row; drop into the gap
  between rows -> new row; drag within a row to reorder cells.
- **Sections:** an "Add section" control; inline-editable title; collapse/expand
  chevron; reorder sections; drag rows between sections. **Deleting a section**
  moves its rows into the adjacent section (never orphans fields).
- **Adding a field** (field list / AddFieldSheet) drops it as a new full-width
  row in the last section; selecting a tile still opens its config panel.
- **Responsive:** below the editor's narrow breakpoint, every cell renders
  full-width (spans ignored); section headers remain. This is the same rule the
  future runtime card form will follow.

### Cubit operations

All return a new immutable `CardLayout`, routed through the existing draft/save
flow (`save()` -> `DataRepository.saveCollection`):

`setSpan`, `moveCellToRow`, `moveCellToNewRow`, `reorderCellInRow`,
`addSection`, `renameSection`, `toggleSectionCollapsed`, `reorderSections`,
`moveRowToSection`, `deleteSection`.

Removing/adding fields via the field list calls the same reconcile helper used
by `fromJson`, so the layout stays consistent.

## Persistence

`Collection.toJson` emits `"layout"`; `fromJson` reads + reconciles (or
synthesizes). Saving reuses the existing `DataRepository.saveCollection` path —
no new Firestore plumbing. The structure is plain nested
maps/lists, so it stays queryable and losslessly exportable to JSON.

## Error handling & testing

- **Layout logic is pure** over immutable types -> unit-tested independent of UI:
  - JSON round-trip for all four types.
  - Reconciliation: orphan cell dropped, missing field appended, empty-row /
    empty-section pruning, always-keep-one-section.
  - `setSpan` clamping and the row-sum `<= 12` invariant after resize.
  - `deleteSection` re-homing rows into the adjacent section.
  - Default-layout synthesis from a legacy collection (no `layout` key).
- **Widget tests** for the canvas: drag-to-join-row, resize span, collapse
  section, narrow-width full-width collapse.
- Visual polish (handles, drop indicators, spacing rhythm, color roles) goes
  through the **`/design` skill** and the **design-reviewer** gate during
  implementation, per project rules. `flutter analyze` + tests must pass before
  done.

## Touch points

- `lib/core/domain/card_layout.dart` — **new** types + reconcile/synthesize helpers.
- `lib/core/domain/collection.dart` — add `layout` field, `toJson`/`fromJson`.
- `lib/features/collections/editor/card_preview.dart` — interactive canvas.
- `lib/features/collections/editor/collection_editor_cubit.dart` — layout ops + reconcile on add/remove field.
- `lib/features/collections/editor/field_list.dart` — wire add/remove to reconcile.
- Tests under `test/core/domain/` and `test/features/collections/editor/`.
