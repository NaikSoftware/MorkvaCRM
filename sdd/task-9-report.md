# Task 9 Report — Drag cells between rows / into new rows

## Status
DONE

## Implemented

### `lib/features/collections/editor/card_preview.dart`

Four private classes added; existing `_SectionView` and `_RowView` updated:

**`_DraggableCell`** — wraps each wide-mode cell tile in `LongPressDraggable<String>` carrying `cell.fieldId`. Uses `pointerDragAnchorStrategy` so the ghost follows the pointer precisely. Feedback is a `Material`-elevated 160 px ghost clone of the tile; `childWhenDragging` is `Opacity(0.4)` of the same tile.

**`_RowDropTarget`** (keyed `rowdrop_<rowId>`) — trailing `DragTarget<String>` appended to each wide-mode `_RowView`. On accept calls `cubit.moveCellToRow(fieldId, rowId, cellCount)`. Renders `_DropSlot(axis: Axis.vertical)`.

**`_BetweenRowDropTarget`** (keyed `newrowdrop_<sectionId>_<rowIndex>`) — horizontal `DragTarget<String>` injected before each row and once after the last row in `_SectionView` (wide mode only). On accept calls `cubit.moveCellToNewRow(fieldId, sectionId, rowIndex)`. Renders `_DropSlot(axis: Axis.horizontal)`.

**`_DropSlot`** — animated `Container` with `AnimatedContainer` 150 ms transition. Active state: `colorScheme.primary` at 25 % alpha fill + 60 % alpha border. Inactive: fully transparent. Fixed minimum dimension (8 px width / height) prevents layout jump. Vertical orientation for row-trailing slot; horizontal for between-rows.

**`_SectionView` update** — row loop converted from `for (final row in section.rows)` to an indexed loop, inserting `_BetweenRowDropTarget` before each row and one trailing target after the last row. Both guarded by `!narrow` (DnD is wide-mode only).

**`_RowView` update** — wide-mode cells now wrapped in `_DraggableCell`; `_RowDropTarget` appended as a trailing sibling in the `Row`.

### Gesture-arena analysis

`LongPressDraggable` recognises on a **long press** (500 ms hold + threshold); the Task 8 resize handle is a `GestureDetector.onHorizontalDragUpdate` overlay covering a narrow right-edge strip. These two recognisers do not compete: the draggable wins the arena via the long-press timeout, and horizontal drag on the resize handle is a distinct recogniser class. Empirically verified: the resize test (`dragging a cell resize handle shrinks its span`) continues to pass with no changes to the handle.

### DnD in narrow mode

`_DraggableCell`, `_RowDropTarget`, and `_BetweenRowDropTarget` are only rendered in wide mode (`!narrow`). Narrow mode remains a plain stacked `Column` (unchanged from Task 7).

## TDD evidence

**RED phase** — test file written first; ran `flutter test card_preview_dnd_test.dart`:
```
+0 -3: row drop target key rowdrop_r1 exists in wide mode  [FAIL — key not found]
+0 -3: between-row drop target key newrowdrop_s1_0 exists  [FAIL — key not found]
+0 -3: dragging cell B onto rowdrop_r1 joins it into row r1  [FAIL — key not found]
+1 -3: cubit.moveCellToRow moves f2 into r1 at index 1  [PASS — cubit already existed]
```

**GREEN phase** — after implementation:
```
+4: All tests passed!
```

Widget-gesture drag test passed first attempt — `LongPressDraggable` + `DragTarget` cooperate cleanly in the Flutter test environment with `startGesture` + 600 ms pump.

## Test results

| Suite | Before | After |
|---|---|---|
| `card_preview_test.dart` (Task 7) | 4/4 | 4/4 |
| `card_preview_resize_test.dart` (Task 8) | 1/1 | 1/1 |
| `card_preview_dnd_test.dart` (Task 9) | — | 4/4 |
| Full `test/features/collections/` | 70/70 | 74/74 |

## Self-review

- Cells draggable (wide mode only): confirmed by widget-gesture test.
- Row drop target `rowdrop_<rowId>` wired to `moveCellToRow`: confirmed.
- Between-row drop targets `newrowdrop_<sectionId>_<rowIndex>` wired to `moveCellToNewRow`: structural key test confirms presence.
- Resize handle (Task 8) still passes: `card_preview_resize_test.dart` green.
- Tasks 7–8 regressions: none.
- `flutter analyze`: 0 issues in `card_preview.dart`; 2 pre-existing `firebase_options.dart` errors in `main.dart` (worktree artifact, not introduced here).

## Concerns

None. The `_DropSlot` uses `AnimatedContainer` which re-renders on `candidateData` change; if this causes jank on very large layouts (many rows), it could be replaced with a `ColoredBox` + explicit `setState` wrapper. For the current scope this is negligible.

## Files changed

- `lib/features/collections/editor/card_preview.dart` — DnD implementation
- `test/features/collections/editor/card_preview_dnd_test.dart` — new TDD test file (created)

## Commit

`991f66f feat(editor): drag cells between rows / into new rows on layout canvas`
