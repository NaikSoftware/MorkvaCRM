# Epic 4 — Views & view modes: design

Mockups (Claude Design canvas, private): https://claude.ai/artifact/BNizNtkG66CENueFsw5A3n —
Table, Board, Setup card, Board on phone, New view.

## Intent

A collection is worked with through **saved views**: the same objects drawn by different
**modes**. One query core (filter → sort → group/bucket) feeds every mode; a mode is only a
renderer. Adding a mode later (Gallery, Timeline) is registering one class, never touching the
core. Nothing assumes a field name like "status".

## Owner decisions

- Views are saved per collection and shown as **tabs** at the top of the collection screen.
- Modes are pluggable. Ship **Table, Board, List, Calendar** now. Gallery appears in the mode
  picker disabled ("needs image files", Storage epic).
- What a board card shows is configured in **Setup card**: a pick-and-reorder list of fields with
  a live preview — not the layout builder.
- Phone board: **one column plus a peek of the next**, snapping horizontally (Trello style).
- Filters + one sort are shared by all modes.
- Dragging a board card to another column writes that field; dragging within a column is a manual
  order saved with the view. "+" in a column pre-fills that column's value.
- Setting up a collection and working with its data are **clearly separate** spaces; creating a
  new collection, editing one, and daily work must each be simple.
- The interface must be modern and polished; UI is designed in Claude Design first and checked
  by a UX designer and a design reviewer on rendered screens; everything is verified by unit tests
  **and** e2e.

## Information architecture: Work vs Build

Rule: **what changes the shape of the data is Build; what changes how you look at it is Work.**

| | Work (`/collections/:id`, default) | Build (`/collections/:id/edit`) |
|---|---|---|
| Purpose | daily work with objects | set up / change the collection |
| Holds | view tabs, data in the active mode, add/drag/delete objects, filters, sort, per-view settings (Setup card, Columns, Group by / Date field), view rename/duplicate/delete | fields (add, type, options, required), card layout builder, name, icon, description, delete collection |
| Entry | tap a collection on Home | "Customize" button in the Work header; collection card overflow → Customize |
| Exit | back to Home | "Done" → Work |
| Header cue | collection icon + name, view tabs | "Customize · <name>" title, tinted header, Done |

- **New collection**: create dialog → Build with a guided "Add your first fields" empty state →
  Done → Work with the default Table view and a "+ New <object>" call to action.
- **Work empty states**: no fields → "Set up fields" (goes to Build); fields but no objects →
  "Add your first …"; filters hide everything → "No matches" + Clear filters.
- Per-view settings open in a **side panel ≥ 840 dp / bottom sheet on phone**, never navigate
  away from the data.

## Calls made by the builder (my call)

- **Storage**: `views` is a list inside the collection document (`Collection.views`), next to
  `layout`. Saved with `saveCollection`; no rules or repository change; travels with JSON export.
  Missing/empty `views` on load → one default Table view "All".
- **Title**: an object's title is the first field of the view's `fieldIds` (Setup card / Columns
  order). Default `fieldIds` = first text field, then the next 3 fields in schema order.
- **Layout field**: each view has one optional `layoutFieldId` — the field a mode lays out by
  (Board: group-by; Calendar: date). One generic slot instead of per-mode properties.
- **Groupable fields**: single-select and single reference (`multiple == false`). Multi-select /
  multi-reference are not groupable (an object must live in exactly one column).
- **Board columns**: select → one per option in option order, then "No <field>". Reference → one
  per object of the target collection (label = its first text field), then "No <field>". Empty
  columns are kept.
- **Manual order**: `manualOrder: List<String>` (object ids) on the view, used when `sort` is
  null. Ids not in the list follow, oldest first (`createdAt`). Stale ids are ignored.
- **Calendar**: month grid ≥ 840 dp, agenda list (days with items) on phone. Objects with an empty
  date go to a "No date" tray. Dragging a card to a day sets the date, keeping the time part.
- **Unknown mode id** (data from a newer client) renders as Table with a small notice.
- **Object open**: Epic 5 owns the editor. Until then a tap opens a read-only detail sheet
  (all fields, formatted) with Delete. Quick-add: the title value + the pre-filled layout value;
  saved immediately.
- **Reconcile**: on load, view `fieldIds`, filters, sort and `layoutFieldId` that point at
  deleted fields are dropped (mirrors `CardLayout.reconcile`); `manualOrder` is kept as is.
- **Title field on create**: `createCollection` adds a "Name" text field, so every new
  collection's default view leads with it. There is no collection-level title concept.
- **Build scope this epic**: the existing editor (explicit Save, name/icon/description header)
  moves to `/edit`; it gains the "Customizing · <name>" header cue, `?field=` deep link, and
  "Object form" wording for the card layout. No three-tab restructure.
- **Concurrency**: views and the schema share the collection doc; last write wins (the editor
  saves via `copyWith`, so it carries views through untouched).
- **Object saves merge values**: `saveObject` writes only the value keys the object carries and
  merges them over the stored `values`, so an object decoded with an older schema never erases a
  newer field's value (a present empty value still clears). Values of deleted fields stay in the
  document. Repository `watch*` streams hold their Firestore listener only while listened to.

## Model (pure Dart, `lib/core/domain/view/`)

```
ViewDefinition { id, name, mode: String, layoutFieldId?, fieldIds: List<String>,
                 filters: List<ViewFilter>, sort: ViewSort?, manualOrder: List<String> }
ViewFilter     { fieldId, op: FilterOp, operand: Object? (JSON) }
ViewSort       { fieldId, ascending }   // fieldId may be '@createdAt' / '@updatedAt'
FilterOp       { isEmpty, isNotEmpty, equals, notEquals, contains, notContains,
                 greaterThan, lessThan, before, after, onDay, anyOf, noneOf, isTrue, isFalse }
```

Operators per field type: text — contains/notContains/equals/isEmpty/isNotEmpty; number &
auto-number — equals/notEquals/greaterThan/lessThan/empties; date — before/after/onDay/empties;
single-select — anyOf/noneOf/empties; multi-select — anyOf (has any)/noneOf/empties; boolean —
isTrue/isFalse; reference — anyOf/empties; file — empties; calculated — empties.

## Query core (`lib/core/domain/view/`, pure, fully unit-tested)

- `applyView(Collection, ViewDefinition, List<MorkvaObject>) → List<MorkvaObject>` — filters
  (AND), then sort or manual order. Empty values sort last in both directions; ties keep
  `createdAt` order (stable).
- `groupObjects(Collection, field, ordered, {referenceLabels}) → List<ViewGroup>` —
  `ViewGroup { key (option id / object id / null = none), label, color?, objects }`.
- `bucketByDay(field, ordered) → DayBuckets { Map<DateTime, List>, undated }`.
- `formatFieldValue(FieldDefinition, FieldValue) → String` — one display formatter for cards,
  rows, detail sheet.
- `groupValueFor(field, key) → FieldValue` and `withDay(DateFieldValue, DateTime)` for drops.

## State (`lib/features/views/`)

`CollectionViewsCubit(DataRepository, collectionId)` watches the collection (from
`watchCollections`), its objects (`watchObjects`), and — when the active board groups by a
reference — the target collection's objects for labels. States: `ViewsLoading`, `ViewsReady
{ collection, activeViewId, objects (applied), groups?, days? }`, `ViewsNotFound`, `ViewsError`.
Commands: `selectView`, `createView(name, mode, layoutFieldId?)`, `renameView`, `duplicateView`,
`deleteView` (never the last), `setFilters`, `setSort`, `setFieldIds`, `setLayoutField`,
`moveToGroup(objectId, groupKey, {beforeId})`, `moveToDay(objectId, day)`, `reorder(objectId,
{beforeId})`, `quickAdd(title, {groupKey, day})`, `deleteObject`. View changes persist via
`saveCollection`; object changes via `saveObject`, applied optimistically then confirmed by the
stream.

## Modes (`lib/features/views/modes/`)

`abstract class ViewMode { id, label, icon, description; bool acceptsLayoutField(field);
bool get needsLayoutField; Widget build(context, ViewModeData) }` registered in
`ViewModeRegistry` (same shape as `FieldTypeRegistry`). Shared widgets: `ObjectCard`
(title + chosen fields as quiet chips), `ViewToolbar`, `ViewEmptyState`.

## Non-goals

Object editor (Epic 5), calculated values (Epic 6), Gallery/Timeline, multiple sorts,
OR-filters, grouping in Table/List, view permissions.

## Done means

Acceptance criteria of `docs/plan/epic-04-views.md`, plus: four modes work on web and phone;
`flutter analyze` clean; unit tests for model, reconcile, query core, cubit; widget tests per
mode; design review on rendered screens; an e2e pass on a device: create a collection with a
select field, add objects, switch Table ↔ Board, drag a card across columns, reload, see it
persisted; open Calendar and List.
