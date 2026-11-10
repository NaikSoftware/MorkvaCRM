import 'dart:convert';

import '../../domain/collection.dart';
import '../../domain/field_definition.dart';
import '../../domain/types/calculated_field.dart';
import '../../domain/types/multi_select_field.dart';
import '../../domain/types/select_option.dart';
import '../../domain/types/single_select_field.dart';
import '../../domain/view/view_definition.dart';
import '../api/screen_context.dart';
import 'filter_compiler.dart';

/// The most characters a `[Screen: …]` line has, brackets included.
const int kScreenLineMax = 600;

/// The most characters of one name, label or search text in the line.
const int kScreenNameMax = 60;

/// The compact line that prefixes a user message with what they see, e.g.
/// `[Screen: collection "Orders" › view "Unpaid" (table) · filters: "Paid"
/// is false, "Status" any of ["Packing"] · search "melnyk" · sort "Total"
/// desc · 23 shown · columns: "No", "Client" · open card "b_or_1042"]`.
///
/// Built from [screen] and the schema only, so it carries **no row values**:
/// names, option labels and the search text appear JSON-quoted, stripped of
/// control, bidi and zero-width characters and cut to [kScreenNameMax]
/// characters; reference operands are counted, never titled. The whole line
/// stays within [kScreenLineMax] characters, ending in `…]` when cut.
String screenLine(ScreenContext screen, List<Collection> collections) {
  final line = _Line(kScreenLineMax);
  final collection = collections
      .where((c) => c.id == screen.collectionId)
      .firstOrNull;
  if (collection == null) {
    line.put(_pageName(screen.page));
    return line.close();
  }
  line.put('collection ${quoteName(collection.name)}');
  final view = collection.views.where((v) => v.id == screen.viewId).firstOrNull;
  final viewName = view?.name ?? screen.viewName;
  if (viewName != null) {
    final mode = screen.mode ?? view?.mode;
    line.put(
      ' › view ${quoteName(viewName)}'
      '${mode == null ? '' : ' (${sanitizeName(mode)})'}',
    );
  }

  String? name(String fieldId) {
    final field = filterFieldOf(collection, fieldId);
    return field == null ? null : quoteName(field.name);
  }

  final clauses = [
    for (final f in screen.filters)
      if (filterFieldOf(collection, f.fieldId) case final field?)
        '${quoteName(field.name)} ${_describe(field, f)}',
  ];
  line.list(' · filters: ', clauses);
  final search = screen.search?.trim();
  if (search != null && search.isNotEmpty) {
    line.put(' · search ${quoteName(search)}');
  }
  if (screen.sort case final sort? when name(sort.fieldId) != null) {
    line.put(
      ' · sort ${name(sort.fieldId)} ${sort.ascending ? 'asc' : 'desc'}',
    );
  }
  if (screen.groupByFieldId case final id? when name(id) != null) {
    line.put(' · grouped by ${name(id)}');
  }
  if (screen.shownCount case final count?) line.put(' · $count shown');
  line.list(' · columns: ', [
    for (final id in screen.visibleFieldIds) ?name(id),
  ]);
  if (screen.selectedIds.isNotEmpty) {
    line.put(' · ${screen.selectedIds.length} selected');
  }
  if (screen.openCardId case final id?) {
    line.put(' · open card ${quoteName(id)}');
  }
  return line.close();
}

/// [text] made safe to show the model inside quotes: control, bidi and
/// zero-width characters removed, runs of whitespace (newlines too) folded
/// into one space, cut to [max] characters with a trailing `…`.
String sanitizeName(String text, {int max = kScreenNameMax}) {
  final clean = text.replaceAll(_invisible, '').replaceAll(_spaces, ' ').trim();
  final runes = clean.runes;
  if (runes.length <= max) return clean;
  return '${String.fromCharCodes(runes.take(max - 1))}…';
}

/// [text] sanitized ([sanitizeName]) and JSON-quoted.
String quoteName(String text, {int max = kScreenNameMax}) =>
    jsonEncode(sanitizeName(text, max: max));

final RegExp _invisible = RegExp(
  r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F\u00AD\u061C'
  r'\u180E\u200B-\u200F\u202A-\u202E\u2060-\u206F\uFEFF]',
);
final RegExp _spaces = RegExp(r'\s+');

String _pageName(ScreenPage page) => switch (page) {
  ScreenPage.home => 'home',
  ScreenPage.allCollections => 'all collections',
  ScreenPage.collection => 'a collection',
  ScreenPage.card => 'a card',
  ScreenPage.settings => 'settings',
  ScreenPage.other => 'another page',
};

/// How one filter reads, from the schema only.
String _describe(FieldDefinition field, ViewFilter filter) {
  final typed = field is CalculatedFieldDefinition ? field.outputField : field;
  final operand = filter.operand;
  String value() => switch (operand) {
    num() => '$operand',
    String() => quoteName(operand),
    _ => '?',
  };
  String set() {
    final ids = operand is List ? operand.whereType<String>().toList() : [];
    final options = switch (typed) {
      SingleSelectFieldDefinition(:final options) ||
      MultiSelectFieldDefinition(:final options) => options,
      _ => null,
    };
    if (options == null) {
      return '${ids.length} ${ids.length == 1 ? 'card' : 'cards'}';
    }
    final labels = [
      for (final id in ids) quoteName(_label(options, id) ?? 'unknown option'),
    ];
    return '[${labels.join(', ')}]';
  }

  return switch (filter.op) {
    FilterOp.isEmpty => 'is empty',
    FilterOp.isNotEmpty => 'is not empty',
    FilterOp.isTrue => 'is true',
    FilterOp.isFalse => 'is false',
    FilterOp.equals => '= ${value()}',
    FilterOp.notEquals => '≠ ${value()}',
    FilterOp.greaterThan => '> ${value()}',
    FilterOp.lessThan => '< ${value()}',
    FilterOp.contains => 'contains ${value()}',
    FilterOp.notContains => 'does not contain ${value()}',
    FilterOp.before => 'before ${value()}',
    FilterOp.after => 'after ${value()}',
    FilterOp.onDay => 'on ${value()}',
    FilterOp.anyOf => 'any of ${set()}',
    FilterOp.noneOf => 'none of ${set()}',
  };
}

String? _label(List<SelectOption> options, String id) =>
    options.where((o) => o.id == id).firstOrNull?.label;

/// A line with a character budget: pieces are added whole or not at all;
/// the first that does not fit ends the line with `…`.
final class _Line {
  _Line(this._max);

  static const String _open = '[Screen: ';

  final int _max;
  final StringBuffer _buf = StringBuffer(_open);
  bool _cut = false;

  /// Adds [piece] if it fits (leaving room for `…]`).
  void put(String piece) {
    if (_cut) return;
    if (_buf.length + piece.length > _max - 2) {
      _cut = true;
      return;
    }
    _buf.write(piece);
  }

  /// `<lead>a, b, c`, item by item; nothing when [items] is empty.
  void list(String lead, List<String> items) {
    if (items.isEmpty) return;
    put('$lead${items.first}');
    for (final item in items.skip(1)) {
      put(', $item');
    }
  }

  String close() => '$_buf${_cut ? '…' : ''}]';
}
