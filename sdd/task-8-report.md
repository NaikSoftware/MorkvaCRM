# Task 8 Report: Span Resize Handle

## What was implemented

A right-edge drag handle on each `_LayoutCellTile` in wide mode that calls
`CollectionEditorCubit.setCellSpan` on every `onHorizontalDragUpdate` event.

### Integration with the Task-7 structure

Task 7's `_LayoutCellTile` used a plain two-required-param constructor
(`field`, `registry`). Three optional nullable params were added:
`rowId`, `span`, and `columnWidth`. The build method branches at the end:
when any of the three is null the widget returns the bare tile (narrow path and
Task 7's plain test callers unchanged). When all three are present it wraps
the tile in a `Stack(clipBehavior: Clip.none)` and overlays a `Positioned`
handle at the right edge.

`_RowView`'s narrow branch passes no new params (unchanged). The wide branch
was wrapped in a `LayoutBuilder` so `constraints.maxWidth / kLayoutColumns`
gives a pixel-accurate `columnWidth`, which is threaded into each tile together
with `row.id` and `row.cells[i].span`.

`kLayoutColumns` is imported from `lib/core/domain/card_layout.dart` via the
existing `domain.dart` barrel — no new import needed.

`flutter_bloc` and `collection_editor_cubit.dart` were added as imports.
The cubit is obtained via `context.read<CollectionEditorCubit>()`, valid because
`CollectionEditorPage` wraps all children (including `CardPreview`) in a
`BlocConsumer<CollectionEditorCubit, ...>`, so the cubit is always in the widget
tree above `CardPreview`.

### Design

- Handle width: `Spacing.lg` (24 px) — meets the 24 px minimum touch target.
- Position: `right: -Spacing.xs` (-8 px) so the handle straddles the cell's
  right border without pushing layout.
- Visual: 3 px wide `Container` with `colorScheme.outlineVariant` fill and
  rounded ends — subtle at rest, not jarring.
- Cursor: `SystemMouseCursors.resizeLeftRight` via `MouseRegion` — explicit
  affordance on desktop/web.
- `HitTestBehavior.translucent` — pointer events fall through to the tile when
  outside the drag zone.
- Key: `Key('resize_<rowId>_<fieldId>')` per spec.

## Test helper used

`_FakeRepo` inline stub (implements `DataRepository`, stubs `getCollection`,
`getCollections`, `saveCollection`; delegates everything else to `noSuchMethod`).
Pattern follows the brief exactly; `FakeDataRepository` from
`test/features/collections/fake_data_repository.dart` was considered but it
requires `watchCollections` + `rxdart` while `CollectionEditorCubit.load` only
calls `getCollection`/`getCollections` — the inline stub is simpler and correct.

## TDD evidence

RED: `flutter test test/.../card_preview_resize_test.dart` → FAIL
  "Found 0 widgets with key [<'resize_r1_f1'>]"

GREEN (after implementation): same command → PASS (1 test)

Task 7 regression: `flutter test test/.../card_preview_test.dart` → PASS (3 tests)

Full suite: `flutter test test/features/collections/` → PASS (70 tests, 0 failures)

`flutter analyze lib/.../card_preview.dart` → No issues found.
`dart format` → 2 files formatted.

## Files changed

- `lib/features/collections/editor/card_preview.dart` — added imports, optional
  params to `_LayoutCellTile`, `LayoutBuilder` in `_RowView` wide branch,
  resize `Stack` + `Positioned` overlay in tile build.
- `test/features/collections/editor/card_preview_resize_test.dart` — new test file.

## Self-review

- Handle only in wide mode: yes — narrow branch passes no params.
- New params optional: yes — `String? rowId`, `int? span`, `double? columnWidth`.
- Task 7 tests still green: yes — 3/3 pass.
- Cubit wired: yes — `context.read<CollectionEditorCubit>()` inside the handle's
  `onHorizontalDragUpdate`.
- Analyze clean: yes.

## Concerns

None. The `setCellSpan` implementation in the cubit clamps and normalizes spans
on every call, so rapid drag updates converge safely without any guard needed in
the handle itself (other than the `deltaCols == 0` short-circuit to avoid no-op
emits).
