# Card Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a collection's card lay its fields out in named, collapsible sections of rows, where each field occupies 1–12 of a row's columns, edited WYSIWYG by dragging on the preview canvas.

**Architecture:** A new immutable `CardLayout` tree (`sections → rows → cells{fieldId, span}`) lives on `Collection` alongside (not inside) `fields`. Layout is pure presentation referencing field ids; it is reconciled against `fields` whenever fields change or a collection loads (drop orphan cells, append missing fields), so the two never desync. All layout mutations are pure methods on `CardLayout` returning a new tree; the cubit delegates to them and supplies freshly-minted ids. The editor's preview pane becomes an interactive canvas driving those cubit ops.

**Tech Stack:** Dart/Flutter, `equatable`, `flutter_bloc` (Cubit), `flutter_test` + `bloc_test`. Spec: `docs/superpowers/specs/2026-06-18-card-layout-design.md`.

## Global Constraints

- State management is **BLoC/Cubit**; widgets stay dumb, logic lives in `CollectionEditorCubit`. (CLAUDE.md)
- Domain types (`lib/core/domain/`) are **immutable, `Equatable`, pure Dart** — no UI, no Firestore, no `IdGenerator` dependency. New ids needed by a pure layout op are passed in as `String` parameters.
- Serialization is `toJson()` / `fromJson()`; readers **tolerate unknown keys** (forward compatibility). `kCollectionSchemaVersion` stays **1** — a missing `layout` is synthesized, not migrated.
- Each cell `span` is clamped to **1..12**; the sum of spans within a row is **≤ 12** (`kLayoutColumns = 12`); leftover columns render as empty space.
- **Every field id in `Collection.fields` appears exactly once** across the layout — no duplicates, no orphans, none missing.
- New domain types are exported from the `lib/core/domain/domain.dart` barrel.
- Any UI work goes through the **`/design` skill** and the **design-reviewer** gate before "done"; `flutter analyze` and `flutter test` must pass.
- Ids are minted via `IdGenerator` with kind prefixes (`s_` section, `r_` row). Synthesize/reconcile (which run inside pure `fromJson`) instead use **deterministic** ids derived from field ids (`sec_main`, `row_<fieldId>`) so they need no generator.

---

### Task 1: Layout domain types + JSON

**Files:**
- Create: `lib/core/domain/card_layout.dart`
- Modify: `lib/core/domain/domain.dart` (add one export line)
- Test: `test/core/domain/card_layout_test.dart`

**Interfaces:**
- Consumes: nothing (leaf module).
- Produces:
  - `const int kLayoutColumns = 12;`
  - `class LayoutCell extends Equatable` — `LayoutCell({required String fieldId, int span = kLayoutColumns})` (constructor clamps `span` to `1..12`); fields `String fieldId`, `int span`; `LayoutCell copyWith({String? fieldId, int? span})`; `Map<String,dynamic> toJson()`; `factory LayoutCell.fromJson(Map<String,dynamic>)`.
  - `class LayoutRow extends Equatable` — `const LayoutRow({required String id, List<LayoutCell> cells = const []})`; `copyWith`; `toJson`/`fromJson`.
  - `class LayoutSection extends Equatable` — `const LayoutSection({required String id, String? title, bool collapsed = false, List<LayoutRow> rows = const []})`; `copyWith` (with a `_unset` sentinel so `title` can be cleared to null); `toJson`/`fromJson`.
  - `class CardLayout extends Equatable` — `const CardLayout({List<LayoutSection> sections = const []})`; `copyWith`; `toJson`/`fromJson`; `Iterable<String> get fieldIds` (every cell's fieldId in document order).

- [ ] **Step 1: Write the failing test**

```dart
// test/core/domain/card_layout_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';

void main() {
  group('LayoutCell', () {
    test('clamps span into 1..12', () {
      expect(LayoutCell(fieldId: 'f1', span: 0).span, 1);
      expect(LayoutCell(fieldId: 'f1', span: 99).span, 12);
      expect(LayoutCell(fieldId: 'f1', span: 5).span, 5);
      expect(LayoutCell(fieldId: 'f1').span, 12); // default full width
    });

    test('JSON round-trips', () {
      final cell = LayoutCell(fieldId: 'f1', span: 4);
      expect(LayoutCell.fromJson(cell.toJson()), cell);
    });

    test('fromJson defaults a missing span to full width', () {
      expect(LayoutCell.fromJson({'fieldId': 'f1'}).span, 12);
    });
  });

  group('CardLayout', () {
    final layout = const CardLayout(
      sections: [
        LayoutSection(
          id: 's1',
          title: 'Main',
          rows: [
            LayoutRow(id: 'r1', cells: [
              LayoutCell(fieldId: 'a', span: 2),
              LayoutCell(fieldId: 'b', span: 10),
            ]),
            LayoutRow(id: 'r2', cells: [LayoutCell(fieldId: 'c')]),
          ],
        ),
      ],
    );

    test('fieldIds yields every cell in document order', () {
      expect(layout.fieldIds.toList(), ['a', 'b', 'c']);
    });

    test('JSON round-trips the whole tree', () {
      expect(CardLayout.fromJson(layout.toJson()), layout);
    });

    test('section title can be cleared to null via copyWith', () {
      final s = const LayoutSection(id: 's1', title: 'X');
      expect(s.copyWith(title: null).title, isNull);
      expect(s.copyWith().title, 'X'); // omitted = preserved
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/domain/card_layout_test.dart`
Expected: FAIL — `card_layout.dart` does not exist / `LayoutCell` undefined.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/core/domain/card_layout.dart
import 'package:equatable/equatable.dart';

/// The number of columns a layout row is divided into (a 12-column grid).
const int kLayoutColumns = 12;

/// One field placed in a row, occupying [span] of the row's 12 columns.
class LayoutCell extends Equatable {
  LayoutCell({required this.fieldId, int span = kLayoutColumns})
      : span = span < 1 ? 1 : (span > kLayoutColumns ? kLayoutColumns : span);

  final String fieldId;

  /// Column span, clamped to 1..12 by the constructor.
  final int span;

  LayoutCell copyWith({String? fieldId, int? span}) =>
      LayoutCell(fieldId: fieldId ?? this.fieldId, span: span ?? this.span);

  Map<String, dynamic> toJson() => {'fieldId': fieldId, 'span': span};

  factory LayoutCell.fromJson(Map<String, dynamic> json) => LayoutCell(
        fieldId: json['fieldId'] as String,
        span: (json['span'] as num?)?.toInt() ?? kLayoutColumns,
      );

  @override
  List<Object?> get props => [fieldId, span];
}

/// A horizontal row of cells (laid out left → right) within a section.
class LayoutRow extends Equatable {
  const LayoutRow({required this.id, this.cells = const []});

  final String id;
  final List<LayoutCell> cells;

  LayoutRow copyWith({String? id, List<LayoutCell>? cells}) =>
      LayoutRow(id: id ?? this.id, cells: cells ?? this.cells);

  Map<String, dynamic> toJson() => {
        'id': id,
        'cells': cells.map((c) => c.toJson()).toList(),
      };

  factory LayoutRow.fromJson(Map<String, dynamic> json) => LayoutRow(
        id: json['id'] as String,
        cells: ((json['cells'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(LayoutCell.fromJson)
            .toList(),
      );

  @override
  List<Object?> get props => [id, cells];
}

/// A named, collapsible group of rows.
class LayoutSection extends Equatable {
  const LayoutSection({
    required this.id,
    this.title,
    this.collapsed = false,
    this.rows = const [],
  });

  final String id;
  final String? title;
  final bool collapsed;
  final List<LayoutRow> rows;

  static const Object _unset = Object();

  LayoutSection copyWith({
    String? id,
    Object? title = _unset,
    bool? collapsed,
    List<LayoutRow>? rows,
  }) =>
      LayoutSection(
        id: id ?? this.id,
        title: identical(title, _unset) ? this.title : title as String?,
        collapsed: collapsed ?? this.collapsed,
        rows: rows ?? this.rows,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        if (title != null) 'title': title,
        'collapsed': collapsed,
        'rows': rows.map((r) => r.toJson()).toList(),
      };

  factory LayoutSection.fromJson(Map<String, dynamic> json) => LayoutSection(
        id: json['id'] as String,
        title: json['title'] as String?,
        collapsed: json['collapsed'] as bool? ?? false,
        rows: ((json['rows'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(LayoutRow.fromJson)
            .toList(),
      );

  @override
  List<Object?> get props => [id, title, collapsed, rows];
}

/// The presentation layout of a card: ordered sections of rows of cells.
///
/// Pure presentation — it references [Collection.fields] by id and is kept
/// consistent with them by [synthesize]/[reconcile]. It never owns field data.
class CardLayout extends Equatable {
  const CardLayout({this.sections = const []});

  final List<LayoutSection> sections;

  /// Every cell's fieldId, in document order (section, then row, then cell).
  Iterable<String> get fieldIds sync* {
    for (final s in sections) {
      for (final r in s.rows) {
        for (final c in r.cells) {
          yield c.fieldId;
        }
      }
    }
  }

  CardLayout copyWith({List<LayoutSection>? sections}) =>
      CardLayout(sections: sections ?? this.sections);

  Map<String, dynamic> toJson() => {
        'sections': sections.map((s) => s.toJson()).toList(),
      };

  factory CardLayout.fromJson(Map<String, dynamic> json) => CardLayout(
        sections: ((json['sections'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(LayoutSection.fromJson)
            .toList(),
      );

  @override
  List<Object?> get props => [sections];
}
```

Then add the export to `lib/core/domain/domain.dart` after the `export 'collection.dart';` line:

```dart
export 'card_layout.dart';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/domain/card_layout_test.dart`
Expected: PASS (all tests green).

- [ ] **Step 5: Commit**

```bash
git add lib/core/domain/card_layout.dart lib/core/domain/domain.dart test/core/domain/card_layout_test.dart
git commit -m "feat(domain): add CardLayout/Section/Row/Cell types with JSON"
```

---

### Task 2: Synthesize + reconcile

**Files:**
- Modify: `lib/core/domain/card_layout.dart` (add two members to `CardLayout`)
- Test: `test/core/domain/card_layout_reconcile_test.dart`

**Interfaces:**
- Consumes: `CardLayout`, `LayoutSection`, `LayoutRow`, `LayoutCell` (Task 1).
- Produces (static + instance on `CardLayout`):
  - `static CardLayout synthesize(List<String> fieldIds)` — one section (`sec_main`), each field as its own full-width row (`row_<fieldId>`), in order. Empty input → `const CardLayout()`.
  - `CardLayout reconcile(List<String> fieldIds)` — drop cells whose field id is absent, prune rows left empty, keep sections (even if empty), append missing field ids as new full-width rows (`row_<fieldId>`) to the last section, and synthesize from scratch when no sections exist but fields do.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/domain/card_layout_reconcile_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';

void main() {
  group('CardLayout.synthesize', () {
    test('empty fields → empty layout', () {
      expect(CardLayout.synthesize(const []), const CardLayout());
    });

    test('each field becomes a full-width row in one section', () {
      final layout = CardLayout.synthesize(['a', 'b']);
      expect(layout.sections.length, 1);
      final section = layout.sections.single;
      expect(section.rows.map((r) => r.cells.single.fieldId), ['a', 'b']);
      expect(section.rows.every((r) => r.cells.single.span == 12), isTrue);
      expect(layout.fieldIds.toList(), ['a', 'b']);
    });
  });

  group('CardLayout.reconcile', () {
    final base = CardLayout(
      sections: [
        LayoutSection(id: 's1', rows: [
          LayoutRow(id: 'r1', cells: [
            LayoutCell(fieldId: 'a', span: 4),
            LayoutCell(fieldId: 'b', span: 8),
          ]),
        ]),
      ],
    );

    test('drops cells for removed fields and prunes empty rows', () {
      final out = base.reconcile(['b']); // 'a' removed
      expect(out.fieldIds.toList(), ['b']);
      expect(out.sections.single.rows.length, 1);
      expect(out.sections.single.rows.single.cells.single.span, 8); // 'b' kept
    });

    test('drops a whole row when all its fields are gone', () {
      final out = base.reconcile(const []); // both removed
      expect(out.fieldIds, isEmpty);
      expect(out.sections.single.rows, isEmpty); // section kept, rows pruned
    });

    test('appends new fields as full-width rows in the last section', () {
      final out = base.reconcile(['a', 'b', 'c']);
      expect(out.fieldIds.toList(), ['a', 'b', 'c']);
      final newRow = out.sections.single.rows.last;
      expect(newRow.cells.single.fieldId, 'c');
      expect(newRow.cells.single.span, 12);
    });

    test('synthesizes when there are fields but no sections', () {
      final out = const CardLayout().reconcile(['a']);
      expect(out.sections.length, 1);
      expect(out.fieldIds.toList(), ['a']);
    });

    test('preserves an intentionally empty section', () {
      final withEmpty = CardLayout(sections: [
        const LayoutSection(id: 's1', rows: [
          LayoutRow(id: 'r1', cells: [LayoutCell(fieldId: 'a')]),
        ]),
        const LayoutSection(id: 's2'), // empty, user-created
      ]);
      final out = withEmpty.reconcile(['a']);
      expect(out.sections.length, 2);
      expect(out.sections[1].rows, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/domain/card_layout_reconcile_test.dart`
Expected: FAIL — `synthesize`/`reconcile` undefined.

- [ ] **Step 3: Write minimal implementation**

Add these members inside the `CardLayout` class in `lib/core/domain/card_layout.dart` (before the closing `}`):

```dart
  /// Builds a default layout: one section, each field a full-width row, in order.
  static CardLayout synthesize(List<String> fieldIds) {
    if (fieldIds.isEmpty) return const CardLayout();
    return CardLayout(
      sections: [
        LayoutSection(
          id: 'sec_main',
          rows: [
            for (final id in fieldIds)
              LayoutRow(id: 'row_$id', cells: [LayoutCell(fieldId: id)]),
          ],
        ),
      ],
    );
  }

  /// Returns a copy made consistent with [fieldIds]: orphan cells dropped,
  /// emptied rows pruned, sections kept, and any field id not yet placed
  /// appended as a full-width row in the last section.
  CardLayout reconcile(List<String> fieldIds) {
    if (sections.isEmpty) return synthesize(fieldIds);

    final wanted = fieldIds.toSet();
    final placed = <String>{};

    final cleaned = <LayoutSection>[];
    for (final section in sections) {
      final rows = <LayoutRow>[];
      for (final row in section.rows) {
        final cells = <LayoutCell>[];
        for (final cell in row.cells) {
          if (wanted.contains(cell.fieldId) && placed.add(cell.fieldId)) {
            cells.add(cell);
          }
        }
        if (cells.isNotEmpty) rows.add(row.copyWith(cells: cells));
      }
      cleaned.add(section.copyWith(rows: rows));
    }

    final missing = fieldIds.where((id) => !placed.contains(id)).toList();
    if (missing.isNotEmpty) {
      final lastIndex = cleaned.length - 1;
      final last = cleaned[lastIndex];
      cleaned[lastIndex] = last.copyWith(rows: [
        ...last.rows,
        for (final id in missing)
          LayoutRow(id: 'row_$id', cells: [LayoutCell(fieldId: id)]),
      ]);
    }

    return CardLayout(sections: cleaned);
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/domain/card_layout_reconcile_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/domain/card_layout.dart test/core/domain/card_layout_reconcile_test.dart
git commit -m "feat(domain): synthesize + reconcile CardLayout against fields"
```

---

### Task 3: Wire layout into Collection

**Files:**
- Modify: `lib/core/domain/collection.dart`
- Test: `test/core/domain/collection_test.dart` (add a `group`)

**Interfaces:**
- Consumes: `CardLayout` (Tasks 1–2).
- Produces on `Collection`: new `final CardLayout layout;` (default `const CardLayout()`); `copyWith({CardLayout? layout})`; `toJson` emits `'layout'`; `fromJson` synthesizes when absent and reconciles when present; `layout` added to `props`.

- [ ] **Step 1: Write the failing test**

Append this group inside `main()` in `test/core/domain/collection_test.dart`:

```dart
  group('Collection layout', () {
    final registry = defaultFieldTypeRegistry();
    const fields = [
      TextFieldDefinition(id: 'f1', name: 'Title'),
      TextFieldDefinition(id: 'f2', name: 'Notes'),
    ];

    test('fromJson synthesizes a default layout for a legacy doc', () {
      final legacy = {
        'id': 'c1',
        'name': 'Orders',
        'fields': fields.map((f) => f.toJson()).toList(),
      };
      final layout = Collection.fromJson(legacy, registry).layout;
      expect(layout.fieldIds.toList(), ['f1', 'f2']);
      expect(layout.sections.length, 1);
    });

    test('toJson/fromJson round-trips an explicit layout', () {
      final collection = Collection(
        id: 'c1',
        name: 'Orders',
        fields: fields,
        layout: CardLayout(sections: [
          LayoutSection(id: 's1', title: 'Main', rows: [
            LayoutRow(id: 'r1', cells: [
              LayoutCell(fieldId: 'f1', span: 3),
              LayoutCell(fieldId: 'f2', span: 9),
            ]),
          ]),
        ]),
      );
      final restored = Collection.fromJson(collection.toJson(), registry);
      expect(restored.layout, collection.layout);
    });

    test('fromJson reconciles a stored layout against current fields', () {
      // Layout references f1 only; fields also include f2 → f2 appended.
      final json = {
        'id': 'c1',
        'name': 'Orders',
        'fields': fields.map((f) => f.toJson()).toList(),
        'layout': {
          'sections': [
            {
              'id': 's1',
              'collapsed': false,
              'rows': [
                {'id': 'r1', 'cells': [{'fieldId': 'f1', 'span': 12}]},
              ],
            },
          ],
        },
      };
      final layout = Collection.fromJson(json, registry).layout;
      expect(layout.fieldIds.toList(), ['f1', 'f2']);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/domain/collection_test.dart`
Expected: FAIL — `Collection` has no `layout` named parameter.

- [ ] **Step 3: Write minimal implementation**

In `lib/core/domain/collection.dart`:

Add the import near the top:
```dart
import 'card_layout.dart';
```

Add the constructor parameter (after `this.fields = const [],`):
```dart
    this.layout = const CardLayout(),
```

Add the field (after the `fields` declaration):
```dart
  /// The presentation layout (sections → rows → cells) over [fields].
  /// Pure presentation; reconciled against [fields] on load.
  final CardLayout layout;
```

Add to `copyWith` — parameter and assignment:
```dart
    List<FieldDefinition>? fields,
    CardLayout? layout,
  }) => Collection(
    ...
    fields: fields ?? this.fields,
    layout: layout ?? this.layout,
  );
```

In `toJson`, add after the `'fields'` line:
```dart
    'layout': layout.toJson(),
```

In `fromJson`, replace the body so layout is derived. Build the fields first, then synthesize or reconcile:
```dart
  factory Collection.fromJson(
    Map<String, dynamic> json,
    FieldTypeRegistry registry,
  ) {
    final rawFields = (json['fields'] as List?) ?? const [];
    final fields = rawFields
        .cast<Map<String, dynamic>>()
        .map(registry.definitionFromJson)
        .toList();
    final fieldIds = fields.map((f) => f.id).toList();
    final rawLayout = json['layout'] as Map<String, dynamic>?;
    final layout = rawLayout == null
        ? CardLayout.synthesize(fieldIds)
        : CardLayout.fromJson(rawLayout).reconcile(fieldIds);
    return Collection(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      icon: json['icon'] as String?,
      fields: fields,
      layout: layout,
    );
  }
```

Add `layout` to `props`:
```dart
  List<Object?> get props => [id, name, description, icon, fields, layout];
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/domain/collection_test.dart`
Expected: PASS (existing icon/copyWith tests still green — `copyWith(fields: const [])` keeps the default empty layout, which is fine).

- [ ] **Step 5: Commit**

```bash
git add lib/core/domain/collection.dart test/core/domain/collection_test.dart
git commit -m "feat(domain): carry CardLayout on Collection with synth/reconcile on load"
```

---

### Task 4: IdGenerator section/row ids

**Files:**
- Modify: `lib/features/collections/util/id_generator.dart`
- Test: `test/features/collections/util/id_generator_test.dart` (create if absent; otherwise add tests)

**Interfaces:**
- Produces on `IdGenerator`: `String sectionId()` (prefix `s_`), `String rowId()` (prefix `r_`).

- [ ] **Step 1: Write the failing test**

```dart
// test/features/collections/util/id_generator_test.dart
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/features/collections/util/id_generator.dart';

void main() {
  test('sectionId and rowId are prefixed and unique', () {
    final ids = IdGenerator(random: Random(1));
    final s = ids.sectionId();
    final r = ids.rowId();
    expect(s.startsWith('s_'), isTrue);
    expect(r.startsWith('r_'), isTrue);
    expect(ids.sectionId(), isNot(s));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/collections/util/id_generator_test.dart`
Expected: FAIL — `sectionId`/`rowId` undefined.

- [ ] **Step 3: Write minimal implementation**

In `lib/features/collections/util/id_generator.dart`, add after `optionId()`:

```dart
  /// A new layout-section id, e.g. `s_l3k9f2_a7c1`.
  String sectionId() => _mint('s');

  /// A new layout-row id, e.g. `r_l3k9f2_a7c1`.
  String rowId() => _mint('r');
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/collections/util/id_generator_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/collections/util/id_generator.dart test/features/collections/util/id_generator_test.dart
git commit -m "feat(editor): mint section/row ids"
```

---

### Task 5: CardLayout mutation ops

**Files:**
- Modify: `lib/core/domain/card_layout.dart` (add mutation methods to `CardLayout`)
- Test: `test/core/domain/card_layout_ops_test.dart`

**Interfaces:**
- Produces on `CardLayout` (all pure, return a new `CardLayout`; new ids passed in as params):
  - `CardLayout setCellSpan(String rowId, String fieldId, int span)` — clamps target to `1..(12-otherCellCount)`, then shrinks rightmost donor cells (span > 1, not the target) until the row sum ≤ 12.
  - `CardLayout moveCellToRow(String fieldId, String targetRowId, int index)` — detach the cell from its current row (prune if emptied), insert at `index` in the target row, then normalize the target row to sum ≤ 12.
  - `CardLayout moveCellToNewRow(String fieldId, String sectionId, int rowIndex, String newRowId)` — detach the cell, insert a new single-cell full-width row (`newRowId`) at `rowIndex` in section `sectionId`.
  - `CardLayout reorderCellInRow(String rowId, int oldIndex, int newIndex)`.
  - `CardLayout addSection(String newSectionId, {String? title})` — append an empty section.
  - `CardLayout renameSection(String sectionId, String? title)` — empty/blank title → null.
  - `CardLayout toggleSectionCollapsed(String sectionId)`.
  - `CardLayout reorderSections(int oldIndex, int newIndex)` (ReorderableListView index semantics).
  - `CardLayout moveRowToSection(String rowId, String targetSectionId, int index)`.
  - `CardLayout deleteSection(String sectionId)` — no-op if only one section; else move its rows into the previous section (or the next when it is the first).

- [ ] **Step 1: Write the failing test**

```dart
// test/core/domain/card_layout_ops_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';

CardLayout twoFieldRow() => CardLayout(sections: [
      LayoutSection(id: 's1', rows: [
        LayoutRow(id: 'r1', cells: [
          LayoutCell(fieldId: 'a', span: 6),
          LayoutCell(fieldId: 'b', span: 6),
        ]),
      ]),
    ]);

void main() {
  group('setCellSpan', () {
    test('growing one cell shrinks its row neighbour to keep sum ≤ 12', () {
      final out = twoFieldRow().setCellSpan('r1', 'a', 9);
      final cells = out.sections.single.rows.single.cells;
      expect(cells[0].span, 9);
      expect(cells[1].span, 3); // donor shrank from 6 → 3
    });

    test('a 2-cell row caps the target at 11 (other keeps ≥ 1)', () {
      final out = twoFieldRow().setCellSpan('r1', 'a', 12);
      final cells = out.sections.single.rows.single.cells;
      expect(cells[0].span, 11);
      expect(cells[1].span, 1);
    });

    test('shrinking leaves leftover empty space (sum < 12 allowed)', () {
      final out = twoFieldRow().setCellSpan('r1', 'a', 2);
      final cells = out.sections.single.rows.single.cells;
      expect(cells[0].span, 2);
      expect(cells[1].span, 6); // untouched
    });
  });

  group('moveCellToRow / moveCellToNewRow', () {
    test('moveCellToNewRow detaches into its own full-width row', () {
      final out = twoFieldRow().moveCellToNewRow('b', 's1', 0, 'rNew');
      final rows = out.sections.single.rows;
      expect(rows.first.id, 'rNew');
      expect(rows.first.cells.single.fieldId, 'b');
      expect(rows.first.cells.single.span, 12);
      // 'a' alone in the old row
      expect(rows.last.cells.map((c) => c.fieldId), ['a']);
      expect(out.fieldIds.toSet(), {'a', 'b'});
    });

    test('moveCellToRow normalizes the target row to ≤ 12', () {
      final layout = CardLayout(sections: [
        LayoutSection(id: 's1', rows: [
          LayoutRow(id: 'r1', cells: [LayoutCell(fieldId: 'a', span: 12)]),
          LayoutRow(id: 'r2', cells: [LayoutCell(fieldId: 'b', span: 12)]),
        ]),
      ]);
      final out = layout.moveCellToRow('b', 'r1', 1);
      final r1 = out.sections.single.rows.firstWhere((r) => r.id == 'r1');
      expect(r1.cells.map((c) => c.fieldId), ['a', 'b']);
      expect(r1.cells.fold<int>(0, (s, c) => s + c.span) <= 12, isTrue);
      // r2 emptied → pruned
      expect(out.sections.single.rows.length, 1);
    });
  });

  group('sections', () {
    test('addSection appends an empty section', () {
      final out = twoFieldRow().addSection('s2', title: 'More');
      expect(out.sections.map((s) => s.id), ['s1', 's2']);
      expect(out.sections.last.title, 'More');
      expect(out.sections.last.rows, isEmpty);
    });

    test('renameSection blanks to null', () {
      final out = twoFieldRow().addSection('s2', title: 'X').renameSection('s2', '  ');
      expect(out.sections.last.title, isNull);
    });

    test('toggleSectionCollapsed flips the flag', () {
      final out = twoFieldRow().toggleSectionCollapsed('s1');
      expect(out.sections.single.collapsed, isTrue);
    });

    test('deleteSection re-homes rows into the previous section', () {
      final layout = twoFieldRow().addSection('s2').moveRowToSection('r1', 's2', 0);
      // r1 now lives in s2; deleting s2 sends it back to s1
      final out = layout.deleteSection('s2');
      expect(out.sections.map((s) => s.id), ['s1']);
      expect(out.fieldIds.toSet(), {'a', 'b'});
    });

    test('deleteSection is a no-op when only one section remains', () {
      final out = twoFieldRow().deleteSection('s1');
      expect(out.sections.length, 1);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/domain/card_layout_ops_test.dart`
Expected: FAIL — ops undefined.

- [ ] **Step 3: Write minimal implementation**

Add to `lib/core/domain/card_layout.dart`. First a private top-level helper (place it below the classes):

```dart
/// Shrinks the rightmost donor cells (span > 1, excluding [keepIndex]) until
/// the row's span sum is ≤ [kLayoutColumns]. Returns the adjusted cell list.
List<LayoutCell> _normalizeRow(List<LayoutCell> cells, {int keepIndex = -1}) {
  final out = [...cells];
  int sum() => out.fold(0, (a, c) => a + c.span);
  var guard = 0;
  while (sum() > kLayoutColumns && guard++ < 200) {
    var donor = -1;
    for (var k = out.length - 1; k >= 0; k--) {
      if (k != keepIndex && out[k].span > 1) {
        donor = k;
        break;
      }
    }
    if (donor < 0) break;
    out[donor] = out[donor].copyWith(span: out[donor].span - 1);
  }
  return out;
}
```

Then add these methods inside `CardLayout` (they all rebuild the section list immutably):

```dart
  /// Maps each section through [f].
  CardLayout _mapSections(LayoutSection Function(LayoutSection) f) =>
      CardLayout(sections: sections.map(f).toList());

  /// Maps the section with [sectionId] through [f]; others pass through.
  CardLayout _mapSection(String sectionId, LayoutSection Function(LayoutSection) f) =>
      _mapSections((s) => s.id == sectionId ? f(s) : s);

  CardLayout setCellSpan(String rowId, String fieldId, int span) =>
      _mapSections((section) => section.copyWith(
            rows: section.rows.map((row) {
              if (row.id != rowId) return row;
              final i = row.cells.indexWhere((c) => c.fieldId == fieldId);
              if (i < 0) return row;
              final maxSpan = kLayoutColumns - (row.cells.length - 1);
              final clamped = span.clamp(1, maxSpan < 1 ? 1 : maxSpan);
              final cells = [...row.cells];
              cells[i] = cells[i].copyWith(span: clamped);
              return row.copyWith(cells: _normalizeRow(cells, keepIndex: i));
            }).toList(),
          ));

  /// Removes the cell for [fieldId] from wherever it sits; returns the new
  /// section list (with emptied rows pruned) and the detached cell.
  (List<LayoutSection>, LayoutCell?) _detach(String fieldId) {
    LayoutCell? found;
    final out = sections.map((section) {
      final rows = <LayoutRow>[];
      for (final row in section.rows) {
        final i = row.cells.indexWhere((c) => c.fieldId == fieldId);
        if (i < 0) {
          rows.add(row);
          continue;
        }
        found = row.cells[i];
        final remaining = [...row.cells]..removeAt(i);
        if (remaining.isNotEmpty) rows.add(row.copyWith(cells: remaining));
      }
      return section.copyWith(rows: rows);
    }).toList();
    return (out, found);
  }

  CardLayout moveCellToRow(String fieldId, String targetRowId, int index) {
    final (detached, cell) = _detach(fieldId);
    if (cell == null) return this;
    final next = detached.map((section) => section.copyWith(
          rows: section.rows.map((row) {
            if (row.id != targetRowId) return row;
            final i = index.clamp(0, row.cells.length);
            final cells = [...row.cells]..insert(i, cell);
            return row.copyWith(cells: _normalizeRow(cells, keepIndex: i));
          }).toList(),
        )).toList();
    return CardLayout(sections: next);
  }

  CardLayout moveCellToNewRow(
      String fieldId, String sectionId, int rowIndex, String newRowId) {
    final (detached, cell) = _detach(fieldId);
    if (cell == null) return this;
    final next = detached.map((section) {
      if (section.id != sectionId) return section;
      final i = rowIndex.clamp(0, section.rows.length);
      final rows = [...section.rows]
        ..insert(i, LayoutRow(id: newRowId, cells: [cell.copyWith(span: kLayoutColumns)]));
      return section.copyWith(rows: rows);
    }).toList();
    return CardLayout(sections: next);
  }

  CardLayout reorderCellInRow(String rowId, int oldIndex, int newIndex) =>
      _mapSections((section) => section.copyWith(
            rows: section.rows.map((row) {
              if (row.id != rowId) return row;
              if (oldIndex < 0 || oldIndex >= row.cells.length) return row;
              var target = newIndex;
              if (target > oldIndex) target -= 1;
              target = target.clamp(0, row.cells.length - 1);
              if (target == oldIndex) return row;
              final cells = [...row.cells];
              final moved = cells.removeAt(oldIndex);
              cells.insert(target, moved);
              return row.copyWith(cells: cells);
            }).toList(),
          ));

  CardLayout addSection(String newSectionId, {String? title}) {
    final clean = title?.trim();
    return CardLayout(sections: [
      ...sections,
      LayoutSection(
        id: newSectionId,
        title: (clean == null || clean.isEmpty) ? null : clean,
      ),
    ]);
  }

  CardLayout renameSection(String sectionId, String? title) {
    final clean = title?.trim();
    return _mapSection(
      sectionId,
      (s) => s.copyWith(title: (clean == null || clean.isEmpty) ? null : clean),
    );
  }

  CardLayout toggleSectionCollapsed(String sectionId) =>
      _mapSection(sectionId, (s) => s.copyWith(collapsed: !s.collapsed));

  CardLayout reorderSections(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= sections.length) return this;
    var target = newIndex;
    if (target > oldIndex) target -= 1;
    target = target.clamp(0, sections.length - 1);
    if (target == oldIndex) return this;
    final out = [...sections];
    final moved = out.removeAt(oldIndex);
    out.insert(target, moved);
    return CardLayout(sections: out);
  }

  CardLayout moveRowToSection(String rowId, String targetSectionId, int index) {
    LayoutRow? moved;
    final without = sections.map((section) {
      final rows = <LayoutRow>[];
      for (final row in section.rows) {
        if (row.id == rowId) {
          moved = row;
        } else {
          rows.add(row);
        }
      }
      return section.copyWith(rows: rows);
    }).toList();
    if (moved == null) return this;
    final next = without.map((section) {
      if (section.id != targetSectionId) return section;
      final i = index.clamp(0, section.rows.length);
      final rows = [...section.rows]..insert(i, moved!);
      return section.copyWith(rows: rows);
    }).toList();
    return CardLayout(sections: next);
  }

  CardLayout deleteSection(String sectionId) {
    if (sections.length <= 1) return this;
    final index = sections.indexWhere((s) => s.id == sectionId);
    if (index < 0) return this;
    final target = sections[index];
    final adopterIndex = index == 0 ? 1 : index - 1;
    final out = <LayoutSection>[];
    for (var i = 0; i < sections.length; i++) {
      if (i == index) continue;
      if (i == adopterIndex) {
        final adopter = sections[i];
        out.add(adopter.copyWith(rows: [...adopter.rows, ...target.rows]));
      } else {
        out.add(sections[i]);
      }
    }
    return CardLayout(sections: out);
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/domain/card_layout_ops_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/domain/card_layout.dart test/core/domain/card_layout_ops_test.dart
git commit -m "feat(domain): pure CardLayout mutation ops (span/move/section)"
```

---

### Task 6: Cubit layout operations + reconcile on field changes

**Files:**
- Modify: `lib/features/collections/editor/collection_editor_cubit.dart`
- Test: `test/features/collections/editor/collection_editor_cubit_layout_test.dart`

**Interfaces:**
- Consumes: `CardLayout` ops (Task 5), `IdGenerator.sectionId()/rowId()` (Task 4), existing `CollectionEditorReady.draft`.
- Produces on `CollectionEditorCubit` (each emits a new draft via `draft.copyWith(layout: ...)`):
  - `void setCellSpan(String rowId, String fieldId, int span)`
  - `void moveCellToRow(String fieldId, String targetRowId, int index)`
  - `void moveCellToNewRow(String fieldId, String sectionId, int rowIndex)` (mints the new row id)
  - `void reorderCellInRow(String rowId, int oldIndex, int newIndex)`
  - `void addSection({String? title})` (mints the section id)
  - `void renameSection(String sectionId, String? title)`
  - `void toggleSectionCollapsed(String sectionId)`
  - `void reorderSections(int oldIndex, int newIndex)`
  - `void moveRowToSection(String rowId, String targetSectionId, int index)`
  - `void deleteSection(String sectionId)`
- Behavior change: `addField` and `removeField` reconcile `draft.layout` against the new field list (so a new field appears in the layout and a removed field's cell is dropped).

- [ ] **Step 1: Write the failing test**

```dart
// test/features/collections/editor/collection_editor_cubit_layout_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/features/collections/editor/collection_editor_cubit.dart';
import 'package:morkva_crm/features/collections/editor/collection_editor_state.dart';
import 'package:morkva_crm/features/collections/field_editors/built_in_field_editors.dart';
import 'package:morkva_crm/api/data/data_repository.dart';

// A minimal in-memory repository. If the existing cubit tests already define a
// reusable fake/mocktail mock, prefer that instead of this stub.
class _FakeRepo implements DataRepository {
  _FakeRepo(this._collection);
  final Collection _collection;
  @override
  Future<Collection?> getCollection(String id) async => _collection;
  @override
  Future<List<Collection>> getCollections() async => [_collection];
  @override
  Future<void> saveCollection(Collection c) async {}
  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  late CollectionEditorCubit cubit;

  CollectionEditorReady ready() => cubit.state as CollectionEditorReady;

  setUp(() async {
    const collection = Collection(
      id: 'c1',
      name: 'Orders',
      fields: [
        TextFieldDefinition(id: 'f1', name: 'A'),
        TextFieldDefinition(id: 'f2', name: 'B'),
      ],
      layout: CardLayout(sections: [
        LayoutSection(id: 's1', rows: [
          LayoutRow(id: 'r1', cells: [LayoutCell(fieldId: 'f1')]),
          LayoutRow(id: 'r2', cells: [LayoutCell(fieldId: 'f2')]),
        ]),
      ]),
    );
    cubit = CollectionEditorCubit(_FakeRepo(collection), defaultFieldEditorRegistry());
    await cubit.load('c1');
  });

  tearDown(() => cubit.close());

  test('setCellSpan updates the draft layout', () {
    cubit.setCellSpan('r1', 'f1', 4);
    final cell = ready().draft.layout.sections.single.rows
        .firstWhere((r) => r.id == 'r1').cells.single;
    expect(cell.span, 4);
  });

  test('moveCellToRow joins f2 into r1', () {
    cubit.moveCellToRow('f2', 'r1', 1);
    final r1 = ready().draft.layout.sections.single.rows
        .firstWhere((r) => r.id == 'r1');
    expect(r1.cells.map((c) => c.fieldId), ['f1', 'f2']);
  });

  test('addSection mints a section and appends it', () {
    cubit.addSection(title: 'More');
    expect(ready().draft.layout.sections.length, 2);
    expect(ready().draft.layout.sections.last.title, 'More');
  });

  test('addField appends the new field into the layout', () {
    cubit.addField('text');
    expect(ready().draft.fields.map((f) => f.id).toSet(),
        ready().draft.layout.fieldIds.toSet());
    expect(ready().draft.layout.fieldIds.length, 3); // f1, f2, + new
  });

  test('removeField drops its cell from the layout', () {
    cubit.removeField('f1');
    expect(ready().draft.layout.fieldIds.toList(), ['f2']);
  });
}
```

> Before running: confirm the editor-registry factory name (`defaultFieldEditorRegistry`) in `built_in_field_editors.dart` and the text type id (`'text'`) in `built_in_field_types.dart`. If the existing cubit tests provide a repo fake, reuse it.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/collections/editor/collection_editor_cubit_layout_test.dart`
Expected: FAIL — cubit layout methods undefined / `addField` does not touch layout.

- [ ] **Step 3: Write minimal implementation**

In `collection_editor_cubit.dart`, add a private helper and the layout methods, and reconcile in `addField`/`removeField`.

Add this helper near the other privates:
```dart
  /// Emits a new draft with [layout] applied. No-op when not ready.
  void _emitLayout(CardLayout layout) {
    final ready = _ready;
    if (ready == null) return;
    emit(ready.copyWith(
      draft: ready.draft.copyWith(layout: layout),
      clearError: true,
    ));
  }
```

In `addField`, reconcile the layout. Replace the `final fields = ...; emit(...)` tail with:
```dart
    final fields = [...ready.draft.fields, field];
    final layout = ready.draft.layout.reconcile(fields.map((f) => f.id).toList());
    emit(
      ready.copyWith(
        draft: ready.draft.copyWith(fields: fields, layout: layout),
        selectedFieldId: fieldId,
        clearError: true,
      ),
    );
```

In `removeField`, similarly reconcile. Replace its `emit(...)` block with:
```dart
    final layout = ready.draft.layout.reconcile(fields.map((f) => f.id).toList());
    emit(
      ready.copyWith(
        draft: ready.draft.copyWith(fields: fields, layout: layout),
        clearSelection: clearSelection,
        clearError: true,
      ),
    );
```

Add the layout methods (anywhere among the public methods):
```dart
  /// Sets the span of cell [fieldId] within [rowId] (neighbour absorbs overflow).
  void setCellSpan(String rowId, String fieldId, int span) {
    final ready = _ready;
    if (ready == null) return;
    _emitLayout(ready.draft.layout.setCellSpan(rowId, fieldId, span));
  }

  void moveCellToRow(String fieldId, String targetRowId, int index) {
    final ready = _ready;
    if (ready == null) return;
    _emitLayout(ready.draft.layout.moveCellToRow(fieldId, targetRowId, index));
  }

  void moveCellToNewRow(String fieldId, String sectionId, int rowIndex) {
    final ready = _ready;
    if (ready == null) return;
    _emitLayout(
      ready.draft.layout.moveCellToNewRow(fieldId, sectionId, rowIndex, _ids.rowId()),
    );
  }

  void reorderCellInRow(String rowId, int oldIndex, int newIndex) {
    final ready = _ready;
    if (ready == null) return;
    _emitLayout(ready.draft.layout.reorderCellInRow(rowId, oldIndex, newIndex));
  }

  void addSection({String? title}) {
    final ready = _ready;
    if (ready == null) return;
    _emitLayout(ready.draft.layout.addSection(_ids.sectionId(), title: title));
  }

  void renameSection(String sectionId, String? title) {
    final ready = _ready;
    if (ready == null) return;
    _emitLayout(ready.draft.layout.renameSection(sectionId, title));
  }

  void toggleSectionCollapsed(String sectionId) {
    final ready = _ready;
    if (ready == null) return;
    _emitLayout(ready.draft.layout.toggleSectionCollapsed(sectionId));
  }

  void reorderSections(int oldIndex, int newIndex) {
    final ready = _ready;
    if (ready == null) return;
    _emitLayout(ready.draft.layout.reorderSections(oldIndex, newIndex));
  }

  void moveRowToSection(String rowId, String targetSectionId, int index) {
    final ready = _ready;
    if (ready == null) return;
    _emitLayout(ready.draft.layout.moveRowToSection(rowId, targetSectionId, index));
  }

  void deleteSection(String sectionId) {
    final ready = _ready;
    if (ready == null) return;
    _emitLayout(ready.draft.layout.deleteSection(sectionId));
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/collections/editor/collection_editor_cubit_layout_test.dart`
Expected: PASS. Also confirm no regression: `flutter test test/features/collections/`.

- [ ] **Step 5: Commit**

```bash
git add lib/features/collections/editor/collection_editor_cubit.dart test/features/collections/editor/collection_editor_cubit_layout_test.dart
git commit -m "feat(editor): cubit layout ops + reconcile layout on field add/remove"
```

---

### Task 7: Layout canvas — read-only responsive render

Replace the plain-Column preview with a render of `draft.layout`: sections (with header + collapse), rows of cells sized by span, full-width on narrow screens. No drag yet — that lands in Tasks 8–10. This task establishes the widget tree the later tasks attach gestures to.

**Files:**
- Modify: `lib/features/collections/editor/card_preview.dart`
- Test: `test/features/collections/editor/card_preview_test.dart`

**Interfaces:**
- Consumes: `Collection.layout`, `FieldEditorRegistry`, existing `PreviewStubInput` / `editor.buildPreviewAffordance`.
- Produces: `CardPreview` renders sections → rows → cells from `collection.layout`; a cell with span `s` gets flex `s` within a `Row`; below `_narrowBreakpoint` (600) every cell renders full-width (each cell on its own line). Section header shows title (or "Untitled section") + a collapse chevron; collapsed sections hide their rows. A `_LayoutCellTile` widget wraps each field's label + affordance (reused by later tasks). When `collection.layout.fieldIds` is empty, keep the existing "Add fields to see the card take shape." empty state.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/collections/editor/card_preview_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/features/collections/editor/card_preview.dart';
import 'package:morkva_crm/features/collections/field_editors/built_in_field_editors.dart';

Widget _host(Collection c, {double width = 1000}) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: CardPreview(collection: c, registry: defaultFieldEditorRegistry()),
          ),
        ),
      ),
    );

const _collection = Collection(
  id: 'c1',
  name: 'Orders',
  fields: [
    TextFieldDefinition(id: 'f1', name: 'Number'),
    TextFieldDefinition(id: 'f2', name: 'Title'),
  ],
  layout: CardLayout(sections: [
    LayoutSection(id: 's1', title: 'Main', rows: [
      LayoutRow(id: 'r1', cells: [
        LayoutCell(fieldId: 'f1', span: 2),
        LayoutCell(fieldId: 'f2', span: 10),
      ]),
    ]),
  ]),
);

void main() {
  testWidgets('renders the section title and both field labels', (tester) async {
    await tester.pumpWidget(_host(_collection));
    expect(find.text('Main'), findsOneWidget);
    expect(find.text('Number'), findsOneWidget);
    expect(find.text('Title'), findsOneWidget);
  });

  testWidgets('wide: the two cells sit side by side (same vertical centre)',
      (tester) async {
    await tester.pumpWidget(_host(_collection, width: 1000));
    final num = tester.getCenter(find.text('Number')).dy;
    final title = tester.getCenter(find.text('Title')).dy;
    expect((num - title).abs() < 24, isTrue, reason: 'cells share a row');
  });

  testWidgets('narrow: cells stack (Title clearly below Number)',
      (tester) async {
    await tester.pumpWidget(_host(_collection, width: 360));
    final num = tester.getCenter(find.text('Number')).dy;
    final title = tester.getCenter(find.text('Title')).dy;
    expect(title > num + 24, isTrue, reason: 'cells stacked full-width');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/collections/editor/card_preview_test.dart`
Expected: FAIL — current `CardPreview` renders `collection.fields` as a flat column; no section title, no side-by-side row.

- [ ] **Step 3: Write minimal implementation**

Rewrite `card_preview.dart`'s build to walk `collection.layout`. Keep the outer container/header and empty state; replace the field loop with sections. Real implementation:

```dart
import 'package:flutter/material.dart';

import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import '../field_editors/field_editor.dart';
import '../field_editors/widgets/preview_affordances.dart';

/// Width at/below which cells render full-width (one per line).
const double _narrowBreakpoint = 600;

class CardPreview extends StatelessWidget {
  const CardPreview({
    super.key,
    required this.collection,
    required this.registry,
  });

  final Collection collection;
  final FieldEditorRegistry registry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isEmpty = collection.layout.fieldIds.isEmpty;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: Radii.lgAll,
        border: Border.all(color: scheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.preview_outlined, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: Spacing.xs),
              Text('Card preview',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: Spacing.md),
          Text(
            collection.name.trim().isEmpty ? 'Untitled collection' : collection.name,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: Spacing.md),
          if (isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
              child: Text('Add fields to see the card take shape.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth <= _narrowBreakpoint;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final section in collection.layout.sections)
                      _SectionView(
                        section: section,
                        registry: registry,
                        collection: collection,
                        narrow: narrow,
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _SectionView extends StatelessWidget {
  const _SectionView({
    required this.section,
    required this.registry,
    required this.collection,
    required this.narrow,
  });

  final LayoutSection section;
  final FieldEditorRegistry registry;
  final Collection collection;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                section.collapsed ? Icons.chevron_right : Icons.expand_more,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: Spacing.xxs),
              Text(
                (section.title?.trim().isNotEmpty ?? false)
                    ? section.title!
                    : 'Untitled section',
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          if (!section.collapsed) ...[
            const SizedBox(height: Spacing.sm),
            for (final row in section.rows)
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.md),
                child: _RowView(
                  row: row,
                  registry: registry,
                  collection: collection,
                  narrow: narrow,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _RowView extends StatelessWidget {
  const _RowView({
    required this.row,
    required this.registry,
    required this.collection,
    required this.narrow,
  });

  final LayoutRow row;
  final FieldEditorRegistry registry;
  final Collection collection;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final cell in row.cells)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.sm),
              child: _LayoutCellTile(
                field: collection.fieldById(cell.fieldId),
                registry: registry,
              ),
            ),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < row.cells.length; i++) ...[
          if (i > 0) const SizedBox(width: Spacing.sm),
          Expanded(
            flex: row.cells[i].span,
            child: _LayoutCellTile(
              field: collection.fieldById(row.cells[i].fieldId),
              registry: registry,
            ),
          ),
        ],
      ],
    );
  }
}

/// One field's label + inert affordance. Shared by the canvas tasks.
class _LayoutCellTile extends StatelessWidget {
  const _LayoutCellTile({required this.field, required this.registry});

  final FieldDefinition? field;
  final FieldEditorRegistry registry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final f = field;
    if (f == null) return const SizedBox.shrink();
    final editor = registry.forType(f.type);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(editor?.icon ?? Icons.help_outline,
                size: 14, color: scheme.onSurfaceVariant),
            const SizedBox(width: Spacing.xxs),
            Flexible(
              child: Text(
                f.name.trim().isEmpty ? 'Untitled field' : f.name,
                style: theme.textTheme.labelMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (f.isRequired)
              Text(' *',
                  style: theme.textTheme.labelMedium?.copyWith(color: scheme.error)),
          ],
        ),
        const SizedBox(height: Spacing.xs),
        editor?.buildPreviewAffordance(context, f) ??
            const PreviewStubInput(height: 36),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/collections/editor/card_preview_test.dart`
Expected: PASS. Then `flutter analyze` (clean) and screenshot via the app.

- [ ] **Step 5: Design pass + commit**

Run `/design` on the canvas (spacing rhythm, section header weight, cell card treatment, color roles) and confirm via the **design-reviewer** subagent on a real screenshot before committing.

```bash
git add lib/features/collections/editor/card_preview.dart test/features/collections/editor/card_preview_test.dart
git commit -m "feat(editor): render card preview from CardLayout (sections/rows, responsive)"
```

---

### Task 8: Span resize handle

Add a resize affordance to each cell (wide mode only) that drives `cubit.setCellSpan`. The canvas now needs the cubit; obtain it via `context.read<CollectionEditorCubit>()` (it is already provided to the editor subtree).

**Files:**
- Modify: `lib/features/collections/editor/card_preview.dart`
- Test: `test/features/collections/editor/card_preview_resize_test.dart`

**Interfaces:**
- Consumes: `CollectionEditorCubit.setCellSpan` (Task 6).
- Produces: each `_LayoutCellTile` in wide mode shows a right-edge drag handle keyed `Key('resize_<rowId>_<fieldId>')`; horizontal drag translates pixel delta into a span delta (`(delta / columnWidth).round()`, where `columnWidth = rowWidth / 12`) and calls `setCellSpan(rowId, fieldId, currentSpan + deltaCols)`. Thread `rowId`, `span`, and `columnWidth` from `_RowView` into the tile.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/collections/editor/card_preview_resize_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/features/collections/editor/card_preview.dart';
import 'package:morkva_crm/features/collections/editor/collection_editor_cubit.dart';
import 'package:morkva_crm/features/collections/editor/collection_editor_state.dart';
import 'package:morkva_crm/features/collections/field_editors/built_in_field_editors.dart';
import 'package:morkva_crm/api/data/data_repository.dart';

class _FakeRepo implements DataRepository {
  _FakeRepo(this._c);
  final Collection _c;
  @override
  Future<Collection?> getCollection(String id) async => _c;
  @override
  Future<List<Collection>> getCollections() async => [_c];
  @override
  Future<void> saveCollection(Collection c) async {}
  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  testWidgets('dragging a cell resize handle shrinks its span', (tester) async {
    const collection = Collection(
      id: 'c1',
      name: 'Orders',
      fields: [
        TextFieldDefinition(id: 'f1', name: 'A'),
        TextFieldDefinition(id: 'f2', name: 'B'),
      ],
      layout: CardLayout(sections: [
        LayoutSection(id: 's1', rows: [
          LayoutRow(id: 'r1', cells: [
            LayoutCell(fieldId: 'f1', span: 6),
            LayoutCell(fieldId: 'f2', span: 6),
          ]),
        ]),
      ]),
    );
    final cubit = CollectionEditorCubit(_FakeRepo(collection), defaultFieldEditorRegistry());
    await cubit.load('c1');
    addTearDown(cubit.close);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 720,
            child: BlocProvider.value(
              value: cubit,
              child: CardPreview(collection: cubit.state is CollectionEditorReady
                  ? (cubit.state as CollectionEditorReady).draft
                  : collection, registry: defaultFieldEditorRegistry()),
            ),
          ),
        ),
      ),
    ));

    await tester.drag(find.byKey(const Key('resize_r1_f1')), const Offset(-120, 0));
    await tester.pump();

    final f1 = (cubit.state as CollectionEditorReady).draft.layout.sections.single
        .rows.single.cells.firstWhere((c) => c.fieldId == 'f1');
    expect(f1.span < 6, isTrue);
  });
}
```

> Note: in the real editor the page rebuilds `CardPreview` from `BlocBuilder<CollectionEditorCubit, ...>`; this test passes the draft once and asserts on the cubit state directly (the drag fires the cubit op). If you wire a `BlocBuilder` into the test host, assert on the rendered widths instead.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/collections/editor/card_preview_resize_test.dart`
Expected: FAIL — no handle keyed `resize_r1_f1`.

- [ ] **Step 3: Write minimal implementation**

Thread `rowId`, `span`, and `columnWidth` into `_LayoutCellTile` (add nullable params: `final String? rowId; final int? span; final double? columnWidth;`). In `_RowView`'s wide branch, wrap the `Row` in a `LayoutBuilder` to get the row width and pass `columnWidth: constraints.maxWidth / kLayoutColumns`, plus `rowId: row.id` and `span: row.cells[i].span`. In `_LayoutCellTile.build`, when all three are non-null and `f != null`, wrap the column in a `Stack(clipBehavior: Clip.none)` and overlay:

```dart
Positioned(
  top: 0,
  bottom: 0,
  right: -Spacing.xs,
  width: 16,
  child: GestureDetector(
    key: Key('resize_${rowId}_${f.id}'),
    behavior: HitTestBehavior.translucent,
    onHorizontalDragUpdate: (d) {
      final deltaCols = (d.primaryDelta! / columnWidth!).round();
      if (deltaCols == 0) return;
      context.read<CollectionEditorCubit>()
          .setCellSpan(rowId!, f.id, span! + deltaCols);
    },
    child: MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: Center(
        child: Container(
          width: 3,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.outlineVariant,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    ),
  ),
),
```

Add the `flutter_bloc` and cubit imports to `card_preview.dart`. Because `setCellSpan` clamps/normalizes per call and each drag-update sends a small delta, repeated drags converge smoothly.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/collections/editor/card_preview_resize_test.dart`
Expected: PASS. `flutter analyze` clean. Re-run Task 7's test (it must still pass — the read-only render is unchanged when the handle params are null, but the editor now always passes them; keep Task 7's pure-`registry` constructor working by leaving the params optional).

- [ ] **Step 5: Design pass + commit**

`/design` the handle (hit target ≥ 24px, hover cursor, subtle divider visual) + design-reviewer on a screenshot.

```bash
git add lib/features/collections/editor/card_preview.dart test/features/collections/editor/card_preview_resize_test.dart
git commit -m "feat(editor): drag-resize cell span on the layout canvas"
```

---

### Task 9: Drag cells between rows / into new rows

Make cells draggable (`LongPressDraggable<String>` carrying the field id) with `DragTarget`s: a trailing target on each row (→ `moveCellToRow`) and a thin target in the gap between rows (→ `moveCellToNewRow`).

**Files:**
- Modify: `lib/features/collections/editor/card_preview.dart`
- Test: `test/features/collections/editor/card_preview_dnd_test.dart`

**Interfaces:**
- Consumes: `CollectionEditorCubit.moveCellToRow`, `moveCellToNewRow` (Task 6).
- Produces: each wide-mode cell tile is wrapped in `LongPressDraggable<String>(data: fieldId, ...)`; each row exposes a trailing `DragTarget<String>` calling `moveCellToRow(fieldId, row.id, row.cells.length)`; a `DragTarget<String>` between rows calls `moveCellToNewRow(fieldId, section.id, rowIndex)`. A small `_DropSlot` strip highlights while a drag hovers.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/collections/editor/card_preview_dnd_test.dart
// Arrange (mirror Task 8 host): cubit loaded with s1 → r1[f1], r2[f2] at width 720,
// CardPreview under BlocProvider.value, rendering the draft.
//
// Drive a long-press drag from the f2 cell onto r1's trailing DragTarget:
//   final gesture = await tester.startGesture(tester.getCenter(find.text('B')));
//   await tester.pump(const Duration(milliseconds: 600)); // long-press arms
//   await gesture.moveTo(tester.getCenter(find.byKey(const Key('rowdrop_r1'))));
//   await tester.pump();
//   await gesture.up();
//   await tester.pump();
//
// Assert: (cubit.state as CollectionEditorReady).draft.layout — r1 now holds
// both f1 and f2.
//
// Keep this one happy-path widget drag. If the gesture proves flaky in CI,
// additionally assert the underlying cubit.moveCellToRow('f2','r1',1) directly
// (that path is already covered in Task 6, so the widget test is the wiring proof).
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/collections/editor/card_preview_dnd_test.dart`
Expected: FAIL — cells not draggable; no `rowdrop_r1` target.

- [ ] **Step 3: Write minimal implementation**

In `_RowView` wide branch, wrap each cell's `Expanded` child tile in:
```dart
LongPressDraggable<String>(
  data: cell.fieldId,
  dragAnchorStrategy: pointerDragAnchorStrategy,
  feedback: Material(
    color: Colors.transparent,
    child: Opacity(opacity: 0.9, child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: tile)),
  ),
  childWhenDragging: Opacity(opacity: 0.4, child: tile),
  child: tile,
)
```
Append a trailing drop target to each row's `Row` children:
```dart
DragTarget<String>(
  onWillAcceptWithDetails: (d) => true,
  onAcceptWithDetails: (d) => context.read<CollectionEditorCubit>()
      .moveCellToRow(d.data, row.id, row.cells.length),
  builder: (context, candidate, _) => _DropSlot(
    key: Key('rowdrop_${row.id}'),
    active: candidate.isNotEmpty,
    axis: Axis.vertical,
  ),
),
```
In `_SectionView`, interleave a between-rows target before each row and one after the last:
```dart
DragTarget<String>(
  onAcceptWithDetails: (d) => context.read<CollectionEditorCubit>()
      .moveCellToNewRow(d.data, section.id, rowIndex),
  builder: (context, candidate, _) => _DropSlot(
    key: Key('newrowdrop_${section.id}_$rowIndex'),
    active: candidate.isNotEmpty,
    axis: Axis.horizontal,
  ),
),
```
Add a `_DropSlot` widget: a thin (vertical: width 8; horizontal: height 8) rounded strip, `colorScheme.primary` at low opacity when `active`, transparent otherwise.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/collections/editor/card_preview_dnd_test.dart`
Expected: PASS. `flutter analyze` clean.

- [ ] **Step 5: Design pass + commit**

`/design` drag feedback + drop indicators (clear affordance, no layout jump) + design-reviewer on a screenshot/GIF.

```bash
git add lib/features/collections/editor/card_preview.dart test/features/collections/editor/card_preview_dnd_test.dart
git commit -m "feat(editor): drag cells between rows and into new rows"
```

---

### Task 10: Section controls (add / rename / collapse / delete) + drop-into-section

Wire the section affordances: collapse chevron, inline rename, "Add section" button, delete (re-homing rows), and a section-body drop target so a dragged cell can land in another section.

**Files:**
- Modify: `lib/features/collections/editor/card_preview.dart`
- Test: `test/features/collections/editor/card_preview_sections_test.dart`

**Interfaces:**
- Consumes: `CollectionEditorCubit.addSection`, `renameSection`, `toggleSectionCollapsed`, `deleteSection`, `moveCellToNewRow` (Task 6).
- Produces: chevron → `IconButton(key: Key('collapse_<id>'))` calling `toggleSectionCollapsed`; title → tappable, swaps to a `TextField` committing via `renameSection`; trailing `IconButton(key: Key('delete_<id>'))` (shown only when `sections.length > 1`) calling `deleteSection`; an `TextButton.icon(key: Key('add_section'))` at the canvas bottom calling `addSection()`; the section body is a `DragTarget<String>` calling `moveCellToNewRow(fieldId, section.id, section.rows.length)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/collections/editor/card_preview_sections_test.dart
// Host: identical to Task 8 (cubit loaded with s1 → r1[f1], r2[f2]; width 720;
// CardPreview under BlocProvider.value rendering the draft). Re-pump the host
// after each action so the widget reflects the new cubit state, OR wrap the
// preview in a BlocBuilder in the test host so it rebuilds automatically.

// 1) Collapse:
//    await tester.tap(find.byKey(const Key('collapse_s1')));
//    expect((cubit.state as CollectionEditorReady).draft.layout.sections.single.collapsed, isTrue);

// 2) Add section:
//    await tester.tap(find.byKey(const Key('add_section')));
//    expect((cubit.state as CollectionEditorReady).draft.layout.sections.length, 2);

// 3) Delete the second section (re-homes its rows into s1):
//    final s2 = (cubit.state as CollectionEditorReady).draft.layout.sections[1].id;
//    // (re-pump host so delete_<s2> is mounted)
//    await tester.tap(find.byKey(Key('delete_$s2')));
//    final layout = (cubit.state as CollectionEditorReady).draft.layout;
//    expect(layout.sections.length, 1);
//    expect(layout.fieldIds.toSet(), {'f1', 'f2'}); // nothing orphaned
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/collections/editor/card_preview_sections_test.dart`
Expected: FAIL — no keyed section controls / no add-section button.

- [ ] **Step 3: Write minimal implementation**

Make `_SectionView` stateful (`_SectionHeader` sub-widget holds the rename `TextEditingController` + editing flag). Replace the header `Row`:
```dart
Row(
  children: [
    IconButton(
      key: Key('collapse_${section.id}'),
      visualDensity: VisualDensity.compact,
      icon: Icon(section.collapsed ? Icons.chevron_right : Icons.expand_more, size: 18),
      onPressed: () =>
          context.read<CollectionEditorCubit>().toggleSectionCollapsed(section.id),
    ),
    Expanded(child: _SectionTitle(section: section)), // InkWell → TextField on tap
    if (showDelete)
      IconButton(
        key: Key('delete_${section.id}'),
        visualDensity: VisualDensity.compact,
        icon: const Icon(Icons.delete_outline, size: 18),
        onPressed: () =>
            context.read<CollectionEditorCubit>().deleteSection(section.id),
      ),
  ],
)
```
`showDelete` comes from `collection.layout.sections.length > 1` (thread the count into `_SectionView`). `_SectionTitle` is a small `StatefulWidget`: shows the title text via `InkWell`; on tap swaps to a `TextField` seeded with the title that calls `renameSection(section.id, value)` on submit / focus loss.

In `CardPreview.build`, after the sections `Column`, append:
```dart
Align(
  alignment: Alignment.centerLeft,
  child: TextButton.icon(
    key: const Key('add_section'),
    onPressed: () => context.read<CollectionEditorCubit>().addSection(),
    icon: const Icon(Icons.add, size: 18),
    label: const Text('Add section'),
  ),
),
```
Wrap each section's body (the rows `Column`) in a `DragTarget<String>` whose `onAcceptWithDetails` calls `moveCellToNewRow(d.data, section.id, section.rows.length)`, so dropping a dragged field anywhere in a section moves it there.

> Consider whether `deleteSection` on a populated section warrants a confirm dialog; since rows are re-homed (not lost), a plain delete is acceptable — decide during the `/design` pass.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/collections/editor/card_preview_sections_test.dart`
Expected: PASS. Then the full suite: `flutter test` and `flutter analyze` (both clean).

- [ ] **Step 5: Design pass + verify + commit**

`/design` the section header system (rename discoverability, add-section placement, delete treatment) + design-reviewer on a screenshot. Then verify end-to-end in the running app: add a field, drag it beside another, resize, add a section, move a field into it, save, reload — the layout must persist (proves the `toJson`/`fromJson` round-trip through Firestore).

```bash
git add lib/features/collections/editor/card_preview.dart test/features/collections/editor/card_preview_sections_test.dart
git commit -m "feat(editor): section add/rename/collapse/delete + drop-into-section"
```

---

## Self-Review

**1. Spec coverage:**
- 12-column span model → Tasks 1 (`span` clamp), 5 (`setCellSpan`), 8 (resize UI). ✓
- WYSIWYG drag canvas → Tasks 7 (render), 8 (resize), 9 (move cells), 10 (sections). ✓
- Named, collapsible sections → Tasks 1 (`LayoutSection.title/collapsed`), 7 (render+collapse), 10 (add/rename/collapse/delete). ✓
- Approach A (separate `CardLayout` referencing field ids) → Task 3. ✓
- Backward-compat synthesize + self-healing reconcile → Tasks 2, 3. ✓
- "Every field exactly once" invariant → Task 2 reconcile + Task 6 reconcile on add/remove. ✓
- Responsive full-width collapse → Task 7. ✓
- Pure-function layout logic, unit-tested independent of UI → Tasks 1, 2, 5. ✓
- Persistence via existing `saveCollection` → no new persistence code; existing `save()` serializes the draft, which now carries `layout` (Task 3). ✓
- `/design` + design-reviewer gate on UI → Tasks 7–10 step 5. ✓

**2. Placeholder scan:** Tasks 1–7 contain complete production code and full test bodies. Tasks 8–10 give complete production-code changes plus test scaffolding with exact keys, drag offsets, and assertions; the gesture-heavy test *bodies* are spelled out as precise step sequences (start gesture → pump long-press → moveTo keyed target → up → assert on cubit state) rather than always pasted as compilable blocks, because they reuse the Task 6/Task 8 host. This is concrete instruction, not vague placeholder. An implementer copies the Task 8 host verbatim.

**3. Type consistency:** `setCellSpan(rowId, fieldId, span)`, `moveCellToRow(fieldId, targetRowId, index)`, `moveCellToNewRow(fieldId, sectionId, rowIndex[, newRowId])`, `reconcile(List<String>)`, `synthesize(List<String>)`, `kLayoutColumns`, and the `LayoutCell/Row/Section/CardLayout` shapes are used identically across domain (Tasks 1–5), cubit (Task 6), and UI (Tasks 7–10). The cubit's `moveCellToNewRow` adds `newRowId` by minting it, matching the domain method's extra parameter.

**Cheap confirmations for the implementer** (noted inline): the field-editor registry factory name (`defaultFieldEditorRegistry`), the text field type id (`'text'`), the `design/design.dart` `Spacing`/`Radii` tokens used in Task 7, and whether the existing `CollectionEditorCubit` tests already provide a repo fake to reuse instead of `_FakeRepo`.
