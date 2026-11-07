import 'package:equatable/equatable.dart';

import '../field_definition.dart';
import '../types/text_field.dart';

/// Ids of the built-in view modes. [ViewDefinition.mode] is a plain string so
/// a view written by a newer client (unknown mode) survives a round-trip.
abstract final class ViewModeIds {
  static const String table = 'table';
  static const String board = 'board';
  static const String list = 'list';
  static const String calendar = 'calendar';
  static const String summary = 'summary';
}

/// Filter operators. Serialized by [Enum.name]; which operators apply to a
/// field is decided by `operatorsFor`.
enum FilterOp {
  isEmpty,
  isNotEmpty,
  equals,
  notEquals,
  contains,
  notContains,
  greaterThan,
  lessThan,
  before,
  after,
  onDay,
  anyOf,
  noneOf,
  isTrue,
  isFalse,
}

/// One filter condition of a view. Filters of a view are AND-ed.
///
/// [operand] is JSON-native (String / num / bool / List of String) so the view
/// stores as-is in Firestore: text → String, number → num, date → a
/// `YYYY-MM-DD` calendar day, select / reference → a list of ids.
class ViewFilter extends Equatable {
  const ViewFilter({required this.fieldId, required this.op, this.operand});

  final String fieldId;
  final FilterOp op;
  final Object? operand;

  static const Object _unset = Object();

  ViewFilter copyWith({
    String? fieldId,
    FilterOp? op,
    Object? operand = _unset,
  }) => ViewFilter(
    fieldId: fieldId ?? this.fieldId,
    op: op ?? this.op,
    operand: identical(operand, _unset) ? this.operand : operand,
  );

  Map<String, dynamic> toJson() => {
    'fieldId': fieldId,
    'op': op.name,
    if (operand != null) 'operand': operand,
  };

  /// Throws [ArgumentError] for an unknown `op` name; [ViewDefinition.fromJson]
  /// skips such filters instead of calling this.
  factory ViewFilter.fromJson(Map<String, dynamic> json) {
    final op = FilterOp.values.asNameMap()[json['op']];
    if (op == null) throw ArgumentError.value(json['op'], 'op');
    return ViewFilter(
      fieldId: json['fieldId'] as String,
      op: op,
      operand: json['operand'],
    );
  }

  @override
  List<Object?> get props => [fieldId, op, operand];
}

/// The single sort of a view.
class ViewSort extends Equatable {
  const ViewSort({required this.fieldId, this.ascending = true});

  /// Pseudo field id: sort by the object's creation time.
  static const String createdAt = '@createdAt';

  /// Pseudo field id: sort by the object's last update time.
  static const String updatedAt = '@updatedAt';

  /// A schema field id, or [createdAt] / [updatedAt].
  final String fieldId;
  final bool ascending;

  bool get isPseudo => fieldId == createdAt || fieldId == updatedAt;

  ViewSort copyWith({String? fieldId, bool? ascending}) => ViewSort(
    fieldId: fieldId ?? this.fieldId,
    ascending: ascending ?? this.ascending,
  );

  Map<String, dynamic> toJson() => {'fieldId': fieldId, 'ascending': ascending};

  factory ViewSort.fromJson(Map<String, dynamic> json) => ViewSort(
    fieldId: json['fieldId'] as String,
    ascending: (json['ascending'] as bool?) ?? true,
  );

  @override
  List<Object?> get props => [fieldId, ascending];
}

/// A saved way of looking at a collection's objects: a [mode] renderer over
/// one shared query (filters → sort or manual order → group / bucket).
class ViewDefinition extends Equatable {
  const ViewDefinition({
    required this.id,
    required this.name,
    this.mode = ViewModeIds.table,
    this.layoutFieldId,
    this.fieldIds = const [],
    this.filters = const [],
    this.sort,
    this.manualOrder = const [],
    this.collapsedGroups = const [],
  });

  /// Id of the view every collection starts with.
  static const String defaultId = 'all';

  /// The default "All" table view for [fields]: the first text field (the
  /// title), then the first 3 other fields in schema order. Without a text
  /// field it shows the first 4 fields.
  factory ViewDefinition.defaultFor(List<FieldDefinition> fields) {
    final title = fields.whereType<TextFieldDefinition>().firstOrNull;
    final ids = [
      if (title != null) title.id,
      ...fields.where((f) => f != title).map((f) => f.id),
    ];
    return ViewDefinition(
      id: defaultId,
      name: 'All',
      fieldIds: ids.take(4).toList(),
    );
  }

  final String id;
  final String name;

  /// A [ViewModeIds] value, or an id unknown to this client (kept verbatim).
  final String mode;

  /// The field the mode lays out by (Board: group-by; Calendar: date).
  final String? layoutFieldId;

  /// Fields shown by the view, in order. The first one is the object title.
  final List<String> fieldIds;

  final List<ViewFilter> filters;

  /// When null, objects follow [manualOrder].
  final ViewSort? sort;

  /// Object ids in manual order; ids not listed follow, oldest first. Stale
  /// ids are ignored at query time and kept as is.
  final List<String> manualOrder;

  /// Board groups shown collapsed, by group key ([noGroupToken] for the
  /// `No <field>` group). Keys of deleted options are ignored and kept.
  final List<String> collapsedGroups;

  /// Stored in [collapsedGroups] for the `No <field>` group (null key);
  /// `@`-prefixed like the pseudo sort ids, so no option / object id clashes.
  static const String noGroupToken = '@none';

  /// Whether the board group [key] (null = `No <field>`) is collapsed.
  bool isGroupCollapsed(String? key) =>
      collapsedGroups.contains(key ?? noGroupToken);

  static const Object _unset = Object();

  /// [layoutFieldId] and [sort] use a sentinel so an explicit `null` clears.
  ViewDefinition copyWith({
    String? id,
    String? name,
    String? mode,
    Object? layoutFieldId = _unset,
    List<String>? fieldIds,
    List<ViewFilter>? filters,
    Object? sort = _unset,
    List<String>? manualOrder,
    List<String>? collapsedGroups,
  }) => ViewDefinition(
    id: id ?? this.id,
    name: name ?? this.name,
    mode: mode ?? this.mode,
    layoutFieldId: identical(layoutFieldId, _unset)
        ? this.layoutFieldId
        : layoutFieldId as String?,
    fieldIds: fieldIds ?? this.fieldIds,
    filters: filters ?? this.filters,
    sort: identical(sort, _unset) ? this.sort : sort as ViewSort?,
    manualOrder: manualOrder ?? this.manualOrder,
    collapsedGroups: collapsedGroups ?? this.collapsedGroups,
  );

  /// Drops every reference to a field not in [fieldIds] (shown fields,
  /// filters, sort, layout field). Pseudo sorts and [manualOrder] are kept.
  ViewDefinition reconcile(List<String> fieldIds) {
    final known = fieldIds.toSet();
    final currentSort = sort;
    return ViewDefinition(
      id: id,
      name: name,
      mode: mode,
      layoutFieldId: known.contains(layoutFieldId) ? layoutFieldId : null,
      fieldIds: this.fieldIds.where(known.contains).toSet().toList(),
      filters: filters.where((f) => known.contains(f.fieldId)).toList(),
      sort:
          currentSort == null ||
              currentSort.isPseudo ||
              known.contains(currentSort.fieldId)
          ? currentSort
          : null,
      manualOrder: manualOrder,
      collapsedGroups: collapsedGroups,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'mode': mode,
    if (layoutFieldId != null) 'layoutFieldId': layoutFieldId,
    'fieldIds': fieldIds,
    'filters': filters.map((f) => f.toJson()).toList(),
    if (sort != null) 'sort': sort!.toJson(),
    'manualOrder': manualOrder,
    if (collapsedGroups.isNotEmpty) 'collapsedGroups': collapsedGroups,
  };

  /// Filters with an operator unknown to this client are skipped.
  factory ViewDefinition.fromJson(Map<String, dynamic> json) {
    final ops = FilterOp.values.asNameMap();
    final rawSort = json['sort'] as Map<String, dynamic>?;
    return ViewDefinition(
      id: json['id'] as String,
      name: json['name'] as String,
      mode: (json['mode'] as String?) ?? ViewModeIds.table,
      layoutFieldId: json['layoutFieldId'] as String?,
      fieldIds: _strings(json['fieldIds']),
      filters: ((json['filters'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .where((f) => ops.containsKey(f['op']))
          .map(ViewFilter.fromJson)
          .toList(),
      sort: rawSort == null ? null : ViewSort.fromJson(rawSort),
      manualOrder: _strings(json['manualOrder']),
      collapsedGroups: _strings(json['collapsedGroups']),
    );
  }

  static List<String> _strings(Object? raw) =>
      raw is List ? raw.whereType<String>().toList() : const [];

  @override
  List<Object?> get props => [
    id,
    name,
    mode,
    layoutFieldId,
    fieldIds,
    filters,
    sort,
    manualOrder,
    collapsedGroups,
  ];
}
