import 'package:equatable/equatable.dart';

/// The number of columns a layout row is divided into (a 12-column grid).
const int kLayoutColumns = 12;

/// One field placed in a row, occupying [span] of the row's 12 columns.
class LayoutCell extends Equatable {
  const LayoutCell({required this.fieldId, int span = kLayoutColumns})
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
            return row.copyWith(cells: _normalizeRow(cells));
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
}

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
