# Epic 4 — Views: UX spec

Companion to `2026-11-02-epic-04-views-design.md`. Tokens: `lib/design/tokens/*`,
`lib/design/DESIGN.md`. One breakpoint: `AppShell.expandedBreakpoint` (840). Mockups:
https://claude.ai/artifact/BNizNtkG66CENueFsw5A3n (the fixes below override them).

## 0. Token fixes (ship first, check existing screens after)

- Light `onPrimary` → `#3A1E00` (white on carrot is ~2.8:1, fails AA).
- Add a `primaryText` role `#8A4708` for text-coloured actions/links on paper (carrot text ~4.2:1).
- Sorted table header uses `onSurface` + arrow icon, never carrot text.

## 1. Work vs Build

Tiebreak for the rule in the design doc: stored on the collection and seen by every view →
**Build**; saved per view → **Work**.

- **Build** (`/collections/:id/edit`, focused full-screen route outside the shell, as today):
  name, icon; fields, types, options + colours, required; the object editor's card layout —
  renamed **"Object form"** so it is never confused with a view's "Setup card"; delete collection.
  - Desktop header: "✕ Close" left, `edit` icon + "Customizing · <name>" `titleLarge`, sunk
    `surfaceContainer` header band, tabs **Fields · Object form · Settings**, solid carrot
    **Done** right. Phone: ✕, one-line title, Done; tabs become a `SegmentedButton` below.
  - This epic keeps the existing editor body and its explicit Save (name/icon/description are
    already in its header); only the header cue, deep link and "Object form" wording change.
    The tabbed Fields · Object form · Settings layout above is the target for a later pass.
  - Deep links: `/collections/:id/edit?field=<fieldId>` opens Fields with that field selected.
    Done returns to the exact view the user came from.
- **Work** (`/collections/:id`, inside the shell, rail visible on desktop): header = collection
  icon + `headlineMedium` name, quiet outlined **Customize** (`tune`), primary "+ New <item>";
  view tabs below. Phone: pushed route — back, name, `tune` = view settings sheet, overflow ⋯ →
  "Customize collection" (`edit` icon). Never two `tune` icons.
- Bridges from Work to Build only at moments of need: "+ Add field" in a field picker / empty
  state, "Edit options" in a board column menu → Build deep-linked to that field. No inline option
  editing in Work.
- **Home**: card tap → Work. Card overflow ⋯ → Customize, Rename, Delete.
- **First run**: New collection dialog (name + icon) → Build › Fields with a guided empty state:
  title "What do you track for each <item>?", a pre-made **Name** text field already present (it
  leads the default view, so it is the title there), 5 one-tap suggestion chips (Status · choice, Due date · date, Amount · number,
  Customer · reference, Notes · text) + "+ Custom field". Done always enabled → Work with an
  auto-created "All <name>" Table view showing all fields; one-time snackbar "Add your first
  <item>". No tours.
- **Work empty states**: no fields (legacy only) → "This collection has no fields yet" +
  Customize; fields but no objects → the real Table header + one ghost row "+ New <item>" and a
  "Change fields" link; Board shows real columns each with "+"; Calendar shows the month with
  "Click a day to add".

## 2. Collection screen toolbar (Work)

- View tabs: `TabBar(isScrollable)` with edge fades, Material Symbols `table_rows`,
  `view_kanban`, `view_agenda`, `calendar_month` (18 px). Trailing "+" always visible. Tab menu
  (right-click / long-press / ⋯ on the active tab): Rename (inline), Duplicate, Delete (confirm;
  the last view can't be deleted).
- One toolbar row: left = filter chips (`InputChip`, filled `primaryContainer`, ✕) + dashed
  "+ Filter"; right = one neutral-outline cluster with leading icons: mode setting ("Group:
  Status" / "Date: Due"), Sort, "Columns" (Table) or "Setup card" (Board/List/Calendar).
  Chips look 36 px but have a 44 px hit area.
- Phone: the `tune` button opens one **view settings** bottom sheet (Mode as segmented icons,
  Group/Date field, Sort, Card fields); filter chips are a horizontal row under the tabs.
- Per-view settings never navigate away: side panel ≥840, bottom sheet below.

## 3. Shared object card (`ObjectCard`, one widget, densities: board / list / pill)

- Board density: `surfaceContainerLowest`, radius 12, padding 12×14, level1. Title `titleSmall`
  600 one line; the first numeric/date field may sit top-right in `labelLarge` tabular; the rest
  as quiet chips (`surfaceContainer`, radius 8, `labelMedium onSurfaceVariant`); empty fields are
  skipped. Select values use the option's colour mapped to tokens, never hard-coded.
- Hover: level2; press: `PressableScale`.

## 4. Table

- Custom scroll (no `DataTable`): sticky header row, sticky first (title) column on horizontal
  scroll. Rows 52 px, hover `surfaceContainerLow`, focus 2 px carrot left bar.
- Header tap cycles sort asc → desc → none. Footer "6 of 41".
- Select cells render as pills in the option colour.
- "Columns" opens the same pick-and-reorder sheet as Setup card.
- Horizontal overflow (Table columns, Board columns, view tabs) is cued by a 24 px edge fade on
  the side with more content, plus a visible horizontal scrollbar on pointer devices.

## 5. Board

- Columns 272 px, `surfaceContainerLow`, radius 16, padding 12, gap 16; header: 10 px colour dot,
  name `titleSmall`, count, 44 px "+" (pre-fills the column value), ⋯ menu with "Edit options"
  (deep-link to Build).
- Empty column: dashed `outlineVariant` area — "Drop here to clear <field>" for the No-value
  column, "No <items>" otherwise. Never a tall blank.
- Drag: desktop after 4 px, touch long-press 300 ms + haptic. Lifted card scale 1.03, level3,
  2° tilt, follows the pointer; source slot collapses (`base`); ghost = dashed 2 px `primary` at
  6 % fill at the real card height; target column `surfaceContainerHigh` + 2 px inset primary.
  Auto-scroll within 48 px of an edge. Counts change on drop only.
- Every drop → snackbar with Undo (5 s). Drop into a value hidden by a filter: "Moved to Ready —
  hidden by filter" + Undo.
- Phone: `PageView(padEnds: false, viewportFraction: (w-72)/w)` snapping one column; the next
  column peeks at full opacity; the column header is a 44 px "In work ▾" button opening a column
  jump list; dots only when ≤7 columns, else "2 / 9"; 88 px bottom padding so the FAB never covers
  a card. Holding a dragged card at the screen edge 500 ms moves one page.

## 6. Setup card / Columns sheet

- Pinned title row on top (no handle, note "Card title"). Below: `ReorderableListView` rows
  (52 px; the whole row toggles Show; handle on the left; `proxyDecorator` lift = level2 + 1.02).
  One "Show" column header, bare checkboxes. The group-by field is not listed; a note under the
  preview says "Status is shown as the columns".
- Live preview of a real object (first object of the view, else field-name placeholders).
- Handle menu: Move up / Move down (keyboard path).
- Phone: full-screen dialog, sticky preview on top.

## 7. List

- One `surfaceContainerLowest` card, radius 16; rows 56 px (64 with subtitle), 1 px
  `outlineVariant` divider inset 16. Leading 10 px colour dot when the view has a select layout
  field; title `titleSmall` 600 ellipsis; subtitle = the next 2 card fields joined " · "
  `bodySmall`; trailing one number/date in `labelLarge` tabular.
- Optional grouping by the layout field: sticky 36 px section headers (`labelMedium` uppercase,
  count). Manual sort → long-press / hover handle reorders; dragging between sections writes the
  value like the board. "+" at section end pre-fills.

## 8. Calendar

- ≥840: month grid 7 × 5–6 in a radius-16 card. Header: "November 2026" `headlineSmall`,
  prev/next 44 px icon buttons, "Today" outlined chip, "Date: Due ▾" chip. Week rows share the grid height (≥88 px; the grid scrolls only below that), so a 6-week month
  shows every week; pills are capped by the cell height. Date
  `labelMedium` top-left; today = 28 px carrot circle; outside-month days dimmed on
  `surfaceContainerLow`. Items: 24 px pills, radius 8, `surfaceContainer`, 3 px left bar in the
  option colour, title `labelMedium`; max 3, then "+N more" (opens that day's list). Hover "+" in
  a cell creates with that date. "No date" tray: collapsible 280 px right panel with a count;
  drag tray→day sets the date, pill→tray clears it (with Undo). Drag pill→day writes the date,
  keeping the time.
- <840: agenda — a 56 px snapping week strip on top, sticky day headers ("Mon 4 Nov", today in
  carrot), list-density rows; "No date (5)" last, collapsed. No drag on phone: long-press →
  "Move to date…" date picker.

## 9. New view dialog

- Name field + mode tiles: 5 across ≥840, 2 columns on phone. Unavailable tiles keep
  full-contrast text, mute only the illustration, show the reason ("Needs a date field" + "Add
  date field" → Build; Gallery: "Needs image files"), stay focusable with a tooltip.
- The mode's required setting ("Group by" / "Date field") reveals under the tiles (`slow`
  size+fade); hidden for Table/List. "Create view" disabled until valid.

## 10. Filters & sort

- Filter builder: popover 360 px ≥840, bottom sheet below. Steps: field (searchable, type icons)
  → operator (by type, see design doc) → value (select: multi-check list with colours). Applying
  adds a chip; tapping a chip reopens at the value step. AND only.
- Sort menu: field list + asc/desc `SegmentedButton`; "Manual" offered on Board/List (enables
  reorder). Choosing a field sort keeps the saved manual order.

## 11. States

- Empty: reuse `empty_state.dart`. No matches → "Nothing matches these filters" + "Clear
  filters" (chips stay). Board without a groupable field → "Board needs a choice or reference
  field" + "Add field". Calendar without a date field → "Calendar needs a date field" + "Add date
  field". (Others: §1.)
- Loading: skeletons in the mode's shape, `surfaceContainer` pulse 0.5↔1 over 1.2 s (static with
  reduce-motion), shown only after 150 ms.
- Error: inline card "Couldn't load this view" + Retry. A failed write → error snackbar and the
  item returns. Offline is not an error (the sync pill covers it).

## Deferred (not this epic)

Full keyboard drag (Space/arrows), multi-sort, OR filters, "between" / "within N days"
operators, swipe actions, dark-mode mockups (dark theme tokens still apply), Duplicate
collection.
