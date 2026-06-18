# Task 7 Report: Layout canvas — read-only responsive render

## Status: DONE

## Implementation Summary

Rewrote `lib/features/collections/editor/card_preview.dart` to render from `collection.layout` instead of the flat `collection.fields` loop. Followed strict TDD (RED → GREEN → polish).

## Files Changed

- **Modified**: `lib/features/collections/editor/card_preview.dart`
- **Created**: `test/features/collections/editor/card_preview_test.dart`

## TDD Evidence

**RED**: Ran the test before implementing. Three failures:
- `renders the section title and both field labels` — expected "Main" text, found 0 widgets
- `wide: the two cells sit side by side` — fields were stacked, not side-by-side
- `narrow: cells stack` — passed accidentally but for wrong reasons

**GREEN**: After implementation, all 3 tests pass. No regression in `flutter test test/features/collections/` (69 tests total, all green).

## Design Tokens and Helpers Used

- `Spacing.xxs/xs/sm/md` — vertical/horizontal rhythm throughout
- `Radii.smAll`, `Radii.lgAll` — cell tile corners and outer container
- `scheme.surfaceContainerLow` — outer container background
- `scheme.surfaceContainerLowest` — cell tile background (one step lighter, distinct from container)
- `scheme.outlineVariant` — outer border, cell borders, section dividers
- `scheme.onSurfaceVariant` — label text, icons, chevron
- `scheme.onSurface` — section header title (intentionally stronger than labels)
- `scheme.error` — required field asterisk
- `theme.textTheme.titleSmall` — section header (Hanken Grotesk 14sp w600 — strong enough to anchor a group)
- `theme.textTheme.labelMedium` — field label (12sp w600 — subordinate to section)
- `theme.textTheme.titleMedium` — collection name (16sp w600 — card title)
- `PreviewStubInput` — fallback affordance for types without a registered editor
- `editor.buildPreviewAffordance(context, field)` — dispatches inert affordance through registry

## Name Resolutions

All names used exactly as found in the codebase. No name mismatches encountered:
- `CardLayout.fieldIds` is a getter (`Iterable<String>`) — `.isEmpty` works via `.toList().isEmpty` equivalence on the iterable
- `collection.fieldById(String)` returns `FieldDefinition?` — handled with null check in `_LayoutCellTile`
- `FieldEditorRegistry.forType(String)` returns `FieldEditor?` — null-safe dispatch pattern preserved from original

## Architecture Decisions

- **`_SectionView`** accepts `isFirst: bool` to conditionally render the inter-section divider (avoids leading divider above first section).
- **`_LayoutCellTile`** is a standalone `StatelessWidget` — no interaction logic, clean extension point for Tasks 8–10.
- **Responsive logic** lives in `LayoutBuilder` wrapping only the layout body, not the outer container, so the header/name/empty-state are unaffected.
- **Span → flex** mapping is direct: `Expanded(flex: cell.span, ...)` in the wide `Row`.
- **Collapse**: purely read from `section.collapsed` — no local `StatefulWidget` state. Interactive collapse lands in Task 8.

## Design Polish Applied

1. **Section header hierarchy**: Changed from `labelLarge + onSurfaceVariant` to `titleSmall + onSurface`. Section titles now anchor their groups visually — they read clearly above the `labelMedium + onSurfaceVariant` field labels beneath them.

2. **Inter-section divider**: Added a 1px `outlineVariant` `Divider` before every section except the first. This replaces the ambiguous bottom-padding approach and makes section boundaries explicit.

3. **Cell tile container**: Each `_LayoutCellTile` now has a `surfaceContainerLowest` background + `outlineVariant` border + `Radii.smAll` rounding. This creates a clear affordance boundary for each field — essential baseline for the drag handles Tasks 8–10 will add. The label area uses `Spacing.xs` padding so the content has breathing room without feeling spacious.

4. **Label color**: Field label text uses `onSurfaceVariant` (not `onSurface`) inside the cell tile, which keeps it quieter than the section title — correct information hierarchy.

5. **Chevron sizing**: Reduced from 18px to 16px and added `CrossAxisAlignment.center` on the header Row — aligns the chevron optically with the `titleSmall` baseline.

6. **Row spacing**: Changed from `Spacing.sm` (12px) to `Spacing.md` (16px) between rows. Prevents rows from running together when there are multiple rows per section.

## Test Results

```
flutter test test/features/collections/editor/card_preview_test.dart
→ All 3 tests passed

flutter test test/features/collections/
→ 69 tests, all passed (no regression)

flutter analyze lib/features/collections/editor/card_preview.dart
→ No issues found
```

## Self-Review Checklist

- [x] Renders sections/rows/cells from `collection.layout`
- [x] Span → flex mapping via `Expanded(flex: cell.span)`
- [x] Responsive: stacked full-width at/below 600px breakpoint
- [x] Section title + collapse chevron rendered
- [x] Empty state preserved ("Add fields to see the card take shape.")
- [x] Collection name line preserved
- [x] "Card preview" header preserved
- [x] Tests green (3/3 task tests, 69/69 full suite)
- [x] `flutter analyze` clean
- [x] Visually polished: section hierarchy, cell tile treatment, dividers, spacing rhythm

## Concerns

None. The widget is interaction-free as specified; interactive collapse and drag/resize are cleanly deferred to Tasks 8–10 by keeping `_SectionView` stateless and `_LayoutCellTile` unwrapped.

---

## Design polish fixes

Applied via commit `8c7d573` — `style(editor): polish card preview spacing + muted untitled section + required-marker truncation`

### Changes made

1. **Post-divider gap** (`_SectionView.build`): `SizedBox` after inter-section `Divider` changed from `Spacing.sm` (12 px) → `Spacing.md` (16 px). Section header now breathes consistently with the card's outer padding.

2. **Section title → first row gap** (`_SectionView.build`): `SizedBox` after the header Row (before rows, when not collapsed) changed from `Spacing.sm` (12 px) → `Spacing.md` (16 px). Title-to-first-cell gap now matches the 16 px inter-row rhythm.

3. **Cell tile padding** (`_LayoutCellTile`): `EdgeInsets.all(Spacing.xs)` (8 px) → `EdgeInsets.all(Spacing.sm)` (12 px). Cells no longer feel cramped; content has proper breathing room.

4. **Label → affordance gap** (`_LayoutCellTile.build`): `SizedBox(height: Spacing.xxs)` (4 px) → `SizedBox(height: Spacing.xs)` (8 px). The space between the label row and the preview affordance is now visually balanced.

5. **"Untitled section" muted color** (`_SectionView.build`): Section title `Text` now uses `scheme.onSurfaceVariant` when `section.title` is null/blank, and `scheme.onSurface` for real titles. Untitled sections no longer falsely project the same visual weight as titled ones.

6. **Required asterisk truncation** (`_LayoutCellTile.build`): Replaced the `Flexible(Text(...))` + trailing `Text(' *')` pattern with a single `Flexible(Text.rich(TextSpan(..., children: [TextSpan(' *')])))`. The asterisk is now a child span inside the same `Flexible`, so on narrow cells both the name and the `*` truncate as one unit rather than the `*` floating off to the right. The error-color style on the asterisk span is preserved; no asterisk is rendered when `f.isRequired` is false.

### Analyzer result

```
flutter analyze lib/features/collections/editor/card_preview.dart
→ No issues found
```

### Test results

```
flutter test test/features/collections/editor/card_preview_test.dart
→ 3/3 passed (renders section title + labels, wide side-by-side, narrow stacked)

flutter test test/features/collections/
→ 69/69 passed (no regression across the collections suite)
```

---

## Re-audit polish (M1+M2)

### Changes made

1. **M1 — Collapsed-section bottom gap** (`_SectionView.build`, `else` branch of `if (!section.collapsed)`): `SizedBox(height: Spacing.sm)` (12 px) → `SizedBox(height: Spacing.md)` (16 px). A collapsed section's bottom rhythm now matches every other 16 px vertical step in the widget.

2. **M2 — Italic "Untitled section" placeholder** (`_SectionView.build`, section header `Row`): Introduced `final isPlaceholder = !(section.title?.trim().isNotEmpty ?? false)` and replaced the bare `Text(...)` + double conditional with a `Builder`-wrapped `Text` using `isPlaceholder` for both the `color` (`onSurfaceVariant` vs `onSurface`) and the new `fontStyle` (`FontStyle.italic` vs `FontStyle.normal`). Real section titles remain upright.

### Analyzer result

```
flutter analyze lib/features/collections/editor/card_preview.dart
→ No issues found
```

### Test results

```
flutter test test/features/collections/editor/card_preview_test.dart
→ 3/3 passed

flutter test test/features/collections/
→ 69/69 passed (no regression)
```
