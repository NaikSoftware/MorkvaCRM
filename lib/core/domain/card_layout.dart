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
}
