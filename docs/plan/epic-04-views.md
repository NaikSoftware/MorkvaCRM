# Epic 4 — Views & View Modes

## Goal
**One** view system that renders a collection's objects in different modes. A *table* shows
objects as rows; a *board* ("kanban") shows them as columns **grouped by an attribute**. Same
objects, same data — different render. This is the single most important architectural epic.

## Why
The user was explicit: tables and kanban are **not** separate features — they are view modes.
A board is a table grouped by a field. Building them as one system (with a pluggable set of
modes) is what keeps the product universal and lets calendar/gallery modes drop in later
without rework. The morkvawear examples confirm the need: their order boards group by *status*
and their inventory boards group by *size* — identical machinery, different group-by field.

## In scope
- **View definition** (saved per collection): a **mode** + **group-by field** (when the mode
  needs one) + **filters** + **sort** + **visible fields/columns**. A collection can have
  several saved views.
- **Mode: Table** — objects as rows, fields as columns; choose visible columns; sort; filter.
- **Mode: Board** — choose any **single-select or reference field** as the group-by; render one
  column per option value (plus an "unset" column); objects appear as cards in their column;
  **drag a card to another column to change that field's value**; reorder within a column.
- **Group-by is generic.** Nothing assumes the field is called "status." Any select/reference
  field is a valid grouping; that is what produces a pipeline board, an inventory-by-size
  board, or anything else.
- **Filters & sort** shared across modes (e.g. show only objects where a field matches).
- **Switching modes** on the same collection without losing the data or the view config.
- **Add an object** from within a view (lands the user in the Epic 5 editor or an inline
  quick-add).
- A clean **card/row rendering** that shows a few chosen fields (title + a small set of badges/
  values), reused by every mode.

## Out of scope
- The full object editor (Epic 5) — views open it but don't implement it.
- Calculated/aggregate values (Epic 6) — views display whatever the object holds; once Epic 6
  lands, calculated values render here automatically.
- Extra modes beyond table and board (calendar, gallery) — future epic; but the mode system
  must be built so adding one is additive, not a rewrite.

## Key concepts
- **Mode = renderer over a query.** Filters + sort + group-by define a query/grouping; each
  mode is a way to draw the result. Keep the query/grouping logic separate from the rendering
  so modes share it.
- **Board column = a value of the group-by field.** Moving a card = writing that value. This is
  the entire "kanban" mechanic, expressed generically.
- **Reuse the object-card renderer** across modes for consistency.

## Deliverables
- A view-definition model (persisted via storage) and a bloc managing the active view, its
  filters/sort/group-by, and the resulting grouped/ordered object set.
- Table mode rendering with column selection, sort, and filter.
- Board mode rendering with configurable group-by, drag-and-drop between columns (writing the
  field value) and within columns.
- Mode switching and saved-view management UI.
- A shared object-card/row widget.
- Tests for the query/grouping logic (filter, sort, group-by) and for the drag-to-change-value
  behavior.

## Acceptance criteria
- For one collection, a user can switch between a table view and a board view of the **same**
  objects.
- In board mode the user can pick **which** field groups the columns, and picking a different
  field re-groups the board with no code change.
- Dragging a card to another column updates that object's grouped field value and persists it.
- Filters and sort apply consistently regardless of mode.
- There is exactly one view subsystem — table and board share the query/grouping core and the
  object-card renderer (verifiable in the code structure).

## Dependencies & design notes
- Depends on Epic 3 (collections + schema to view).
- **Use `/design`** heavily here — this is the product's main working surface. The table and
  especially the board must look and feel polished (smooth drag-and-drop, clear columns,
  attractive cards), distinct from generic grid/Trello clones. Design the table and board as
  two expressions of one visual language.
