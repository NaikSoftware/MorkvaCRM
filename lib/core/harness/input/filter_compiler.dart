import '../../domain/collection.dart';
import '../../domain/field_definition.dart';
import '../../domain/types/auto_number_field.dart';
import '../../domain/types/boolean_field.dart';
import '../../domain/types/calculated_field.dart';
import '../../domain/types/date_field.dart';
import '../../domain/types/multi_select_field.dart';
import '../../domain/types/number_field.dart';
import '../../domain/types/reference_field.dart';
import '../../domain/types/single_select_field.dart';
import '../../domain/types/text_field.dart';
import '../../domain/view/view_definition.dart';
import '../../domain/view/view_query.dart';
import '../api/envelope.dart';
import '../api/screen_context.dart';
import '../schema/arg_shapes.dart';
import 'input_errors.dart';
import 'ref_resolver.dart';
import 'value_codec.dart';

/// The pseudo date-time field a [kCreatedAtRef] / [kUpdatedAtRef] filter is
/// checked and evaluated with: pass it to `matchesFilter` together with a
/// `DateFieldValue` of the card's timestamp.
DateFieldDefinition metaDateField(String id) => DateFieldDefinition(
  id: id,
  name: id == kCreatedAtRef ? 'Created at' : 'Updated at',
  includeTime: true,
);

/// The field a compiled filter on [fieldId] reads in [collection]: a schema
/// field, a timestamp pseudo field ([metaDateField]), or null when gone.
FieldDefinition? filterFieldOf(Collection collection, String fieldId) =>
    fieldId == kCreatedAtRef || fieldId == kUpdatedAtRef
    ? metaDateField(fieldId)
    : collection.fieldById(fieldId);

/// The operators a filter on [field] may use: `operatorsFor` its presented
/// type, and only `before` / `after` / `onDay` on the timestamps (they are
/// never empty).
List<FilterOp> filterOpsFor(FieldDefinition field) =>
    field.id == kCreatedAtRef || field.id == kUpdatedAtRef
    ? const [FilterOp.before, FilterOp.after, FilterOp.onDay]
    : operatorsFor(field);

/// Why `matchesFilter` would ignore [filter] on [field] (and so let every
/// card pass), or null when the filter really filters: an operator the field
/// does not take, or a missing, blank or wrong-typed operand.
String? filterProblem(FieldDefinition field, ViewFilter filter) {
  final typed = _presented(field);
  final op = filter.op;
  if (!filterOpsFor(field).contains(op)) {
    return '${op.name} does not apply to ${field.name}';
  }
  if (_noOperand.contains(op)) return null;
  final operand = filter.operand;
  final ok = switch (typed) {
    TextFieldDefinition() => operand is String && operand.trim().isNotEmpty,
    NumberFieldDefinition() ||
    AutoNumberFieldDefinition() => operand is num && operand.isFinite,
    DateFieldDefinition() =>
      operand is String && DateTime.tryParse(operand) != null,
    SingleSelectFieldDefinition() ||
    MultiSelectFieldDefinition() ||
    ReferenceFieldDefinition() =>
      operand is List && operand.whereType<String>().isNotEmpty,
    _ => false,
  };
  return ok ? null : '${field.name} ${op.name} needs a value';
}

const _noOperand = {
  FilterOp.isEmpty,
  FilterOp.isNotEmpty,
  FilterOp.isTrue,
  FilterOp.isFalse,
};

const _singleDays = {'today': 0, 'yesterday': -1, 'tomorrow': 1};

/// The screen's query: what `"from": "@screen"` and `{"screen": true}`
/// mean. The query engine runs it like a view: [filters] (AND), then
/// [search], ordered by [sort] or, when null, by [view]'s manual order.
final class ScreenQuery {
  const ScreenQuery({
    required this.screen,
    required this.collection,
    required this.view,
    required this.filters,
    required this.search,
    required this.sort,
  });

  /// The snapshot the query came from (shown ids and count, for previews).
  final ScreenContext screen;
  final Collection collection;

  /// The view on screen, when it still exists.
  final ViewDefinition? view;

  /// The screen's effective filters plus any extra `where`, every one valid.
  /// Ids may be [kCreatedAtRef] / [kUpdatedAtRef]: evaluate with
  /// [filterFieldOf].
  final List<ViewFilter> filters;

  /// The search text, or null.
  final String? search;
  final ViewSort? sort;
}

/// Friendly filters (`{field, op, value?, relative?, n?}`) → validated
/// [ViewFilter]s. A filter never reaches `matchesFilter` unchecked: it lets
/// bad filters pass, and a bad filter would make a bulk delete match every
/// card.
///
/// - The field is a ref (or `@createdAt` / `@updatedAt`); the op must be one
///   [filterOpsFor] allows (`invalid_filter` lists them). For select and
///   reference fields `equals` / `notEquals` read as `anyOf` / `noneOf`, and
///   for booleans `equals true` reads as `isTrue`.
/// - Operands are typed by the field's presented type (a calculated field's
///   output): text, a number (an auto-number may carry its prefix, `#1042`),
///   a day (`YYYY-MM-DD`, `today`, `-1w`, …), option labels or ids, card
///   titles or ids (`@card`, `@selected` too).
/// - `relative` is expanded from `HarnessContext.today`, never by the
///   caller. `today` / `yesterday` / `tomorrow` keep the op (`onDay`,
///   `before`, `after`). A range (`this_week` from Monday, `last_week`,
///   `this_month`, `last_month`, `this_year`, `last_n_days`: the last n days
///   up to today, `next_n_days`: today and the n − 1 after) with `onDay`
///   becomes an exclusive `after` / `before` pair around it; with `before`
///   it means before its first day, with `after` after its last day.
///
/// Schemas must have their lookups resolved, so a lookup filters as the
/// field it shows.
final class FilterCompiler {
  FilterCompiler(this.refs);

  final RefResolver refs;

  /// Every filter of [where] compiled against [collection]. Problems go to
  /// [errors] when given (the filters that failed are left out); otherwise
  /// all of them are thrown together.
  List<ViewFilter> compile(
    Collection collection,
    List<Object?> where, {
    String path = 'where',
    InputErrors? errors,
  }) {
    final sink = errors ?? InputErrors();
    final out = <ViewFilter>[];
    for (final (i, raw) in where.indexed) {
      final compiled = sink.guard(
        () => compileOne(collection, raw, path: '$path[$i]'),
      );
      if (compiled != null) out.addAll(compiled);
    }
    if (errors == null) {
      sink.throwIfAny(hint: 'collections.get lists each field\'s operators.');
    }
    return out;
  }

  /// One friendly filter as one [ViewFilter], or two for a relative range.
  List<ViewFilter> compileOne(
    Collection collection,
    Object? raw, {
    required String path,
  }) {
    if (raw is! Map) throw _args('A filter is an object.', path);
    final ref = raw['field'];
    final opName = raw['op'];
    if (ref is! String) throw _args('"field" must be a string.', '$path.field');
    var op = FilterOp.values.asNameMap()[opName];
    if (op == null) {
      throw HarnessException.of(
        ErrorCode.invalidArgs,
        'There is no filter op "$opName".',
        path: '$path.op',
        candidates: [for (final o in FilterOp.values) o.name],
      );
    }
    final fieldId = refs.fieldIdOrMeta(collection, ref, path: '$path.field');
    final field = filterFieldOf(collection, fieldId)!;
    final typed = _presented(field);
    final value = raw['value'];
    final relative = raw['relative'];
    op = _alias(typed, op, value);

    final allowed = filterOpsFor(field);
    if (!allowed.contains(op)) {
      throw HarnessException.of(
        ErrorCode.invalidFilter,
        '${op.name} does not apply to "${field.name}" '
        '(${_kind(typed)}). Use one of: '
        '${allowed.map((o) => o.name).join(', ')}.',
        path: '$path.op',
        candidates: [for (final o in allowed) o.name],
      );
    }
    if (relative != null) {
      return _relative(field, typed, op, raw, path);
    }
    if (raw['n'] != null) {
      throw _args('"n" goes with relative last_n_days / next_n_days.', path);
    }
    if (_noOperand.contains(op)) return [ViewFilter(fieldId: fieldId, op: op)];
    if (value == null || (value is String && value.trim().isEmpty)) {
      throw HarnessException.of(
        ErrorCode.invalidFilter,
        '"${field.name}" ${op.name} needs a value.',
        path: '$path.value',
      );
    }
    final operand = _operand(typed, field.name, value, '$path.value');
    return [ViewFilter(fieldId: fieldId, op: op, operand: operand)];
  }

  /// `{field, dir}` as a [ViewSort].
  ViewSort compileSort(
    Collection collection,
    Map<String, Object?> sort, {
    String path = 'sort',
  }) {
    final ref = sort['field'];
    final dir = sort['dir'] ?? 'asc';
    if (ref is! String) throw _args('"field" must be a string.', '$path.field');
    if (dir != 'asc' && dir != 'desc') {
      throw _args('"dir" is asc or desc.', '$path.dir');
    }
    return ViewSort(
      fieldId: refs.fieldIdOrMeta(collection, ref, path: '$path.field'),
      ascending: dir == 'asc',
    );
  }

  /// The query of what is on screen (`"from": "@screen"`, `{"screen":
  /// true}`), AND-ed with the friendly [where] when given.
  ///
  /// The screen's filters are already in effect there, so the ones the
  /// screen itself ignores (blank operands) are dropped; one on a field that
  /// no longer exists is an `invalid_filter`, never silently widened.
  /// `invalid_args` when nothing with a collection is on screen.
  ScreenQuery screenQuery({
    List<Object?>? where,
    String path = 'from',
    String wherePath = 'where',
  }) {
    final screen = refs.screen(path: path);
    final collection = refs.screenCollection(path: path);
    final errors = InputErrors();
    final filters = <ViewFilter>[];
    for (final f in screen.filters) {
      final field = filterFieldOf(collection, f.fieldId);
      if (field == null) {
        errors.add(
          ErrorDetail(
            path: path,
            code: ErrorCode.invalidFilter,
            message:
                'A filter on screen uses a field of ${collection.name} that '
                'no longer exists; ask the user to refresh the view.',
          ),
        );
      } else if (filterProblem(field, f) == null) {
        filters.add(f);
      }
    }
    if (where != null) {
      filters.addAll(
        compile(collection, where, path: wherePath, errors: errors),
      );
    }
    errors.throwIfAny(hint: 'collections.get lists each field\'s operators.');
    return ScreenQuery(
      screen: screen,
      collection: collection,
      view: collection.views.where((v) => v.id == screen.viewId).firstOrNull,
      filters: filters,
      search: (screen.search?.trim().isEmpty ?? true) ? null : screen.search,
      sort: screen.sort,
    );
  }

  List<ViewFilter> _relative(
    FieldDefinition field,
    FieldDefinition typed,
    FilterOp op,
    Map<Object?, Object?> raw,
    String path,
  ) {
    final relative = raw['relative'];
    final n = raw['n'];
    if (typed is! DateFieldDefinition) {
      throw HarnessException.of(
        ErrorCode.invalidFilter,
        'relative only applies to date fields; "${field.name}" is '
        '${_kind(typed)}.',
        path: '$path.relative',
      );
    }
    if (raw['value'] != null) {
      throw _args('Give value or relative, not both.', '$path.relative');
    }
    if (op != FilterOp.onDay && op != FilterOp.before && op != FilterOp.after) {
      throw HarnessException.of(
        ErrorCode.invalidFilter,
        'relative goes with onDay, before or after, not ${op.name}.',
        path: '$path.op',
        candidates: const ['onDay', 'before', 'after'],
      );
    }
    final needsN = relative == 'last_n_days' || relative == 'next_n_days';
    if (needsN && (n is! int || n < 1)) {
      throw _args('$relative needs "n" (days, at least 1).', '$path.n');
    }
    if (!needsN && n != null) {
      throw _args('"n" only goes with last_n_days / next_n_days.', '$path.n');
    }
    final t = refs.ctx.today;
    DateTime day(int y, int m, int d) => DateTime(y, m, d);
    final single = _singleDays[relative];
    if (single != null) {
      final operand = isoDay(day(t.year, t.month, t.day + single));
      return [ViewFilter(fieldId: field.id, op: op, operand: operand)];
    }
    final monday = t.day - (t.weekday - DateTime.monday);
    final (DateTime first, DateTime last) = switch (relative) {
      'this_week' => (
        day(t.year, t.month, monday),
        day(t.year, t.month, monday + 6),
      ),
      'last_week' => (
        day(t.year, t.month, monday - 7),
        day(t.year, t.month, monday - 1),
      ),
      'this_month' => (day(t.year, t.month, 1), day(t.year, t.month + 1, 0)),
      'last_month' => (day(t.year, t.month - 1, 1), day(t.year, t.month, 0)),
      'this_year' => (day(t.year, 1, 1), day(t.year, 12, 31)),
      'last_n_days' => (
        day(t.year, t.month, t.day - (n as int) + 1),
        day(t.year, t.month, t.day),
      ),
      'next_n_days' => (
        day(t.year, t.month, t.day),
        day(t.year, t.month, t.day + (n as int) - 1),
      ),
      _ => throw HarnessException.of(
        ErrorCode.invalidArgs,
        'There is no relative date "$relative".',
        path: '$path.relative',
        candidates: kRelativeDates,
      ),
    };
    String dayAfter(DateTime d) => isoDay(day(d.year, d.month, d.day + 1));
    String dayBefore(DateTime d) => isoDay(day(d.year, d.month, d.day - 1));
    ViewFilter f(FilterOp op, String operand) =>
        ViewFilter(fieldId: field.id, op: op, operand: operand);
    return switch (op) {
      FilterOp.before => [f(FilterOp.before, isoDay(first))],
      FilterOp.after => [f(FilterOp.after, isoDay(last))],
      _ => [
        f(FilterOp.after, dayBefore(first)),
        f(FilterOp.before, dayAfter(last)),
      ],
    };
  }

  Object _operand(
    FieldDefinition typed,
    String name,
    Object value,
    String path,
  ) {
    HarnessException bad(String expected) => HarnessException.of(
      ErrorCode.invalidFilter,
      '"$name" filters by $expected; got "$value".',
      path: path,
    );
    switch (typed) {
      case TextFieldDefinition():
        return switch (value) {
          String() => value,
          num() when value.isFinite => '$value',
          _ => throw bad('text'),
        };
      case NumberFieldDefinition():
        return switch (value) {
          num() when value.isFinite => value,
          String() => parseNumber(value) ?? (throw bad('a number')),
          _ => throw bad('a number'),
        };
      case AutoNumberFieldDefinition(:final prefix):
        if (value is num && value.isFinite) return value;
        if (value is String) {
          final t = value.trim();
          final bare =
              prefix != null && prefix.isNotEmpty && t.startsWith(prefix)
              ? t.substring(prefix.length)
              : t;
          final n = parseNumber(bare);
          if (n != null) return n;
        }
        throw bad('a number');
      case DateFieldDefinition():
        final day = value is String ? parseDay(value, refs.ctx.today) : null;
        if (day == null) {
          throw bad('a day: YYYY-MM-DD, today, yesterday, tomorrow, +3d, -1w');
        }
        return isoDay(day);
      case SingleSelectFieldDefinition(:final options) ||
          MultiSelectFieldDefinition(:final options):
        return <String>{
          for (final r in _refs(value, name, path))
            refs.option(name, options, r.$1, path: r.$2).id,
        }.toList();
      case ReferenceFieldDefinition(:final targetCollectionId):
        final target = refs.collectionById(targetCollectionId, path: path);
        final list = _refs(value, name, path);
        return <String>{
          for (final r in list) ...refs.cards(target, [r.$1], path: r.$2),
        }.toList();
    }
    throw bad('nothing (only isEmpty / isNotEmpty apply)');
  }

  /// [value] as (ref, path) pairs: a list, or one scalar.
  List<(String, String)> _refs(Object value, String name, String path) {
    final list = value is List ? value : [value];
    if (list.isEmpty) {
      throw HarnessException.of(
        ErrorCode.invalidFilter,
        '"$name" needs at least one value.',
        path: path,
      );
    }
    return [
      for (final (i, item) in list.indexed)
        switch (item) {
          String() => (item, value is List ? '$path[$i]' : path),
          num() => ('$item', value is List ? '$path[$i]' : path),
          _ => throw HarnessException.of(
            ErrorCode.invalidFilter,
            '"$name" values are names or ids; got $item.',
            path: value is List ? '$path[$i]' : path,
          ),
        },
    ];
  }

  /// The op a common near-miss means: `equals` on a select or reference is
  /// `anyOf`, `notEquals` is `noneOf`; `equals true` on a boolean is
  /// `isTrue`.
  FilterOp _alias(FieldDefinition typed, FilterOp op, Object? value) {
    switch (typed) {
      case SingleSelectFieldDefinition() ||
          MultiSelectFieldDefinition() ||
          ReferenceFieldDefinition():
        if (op == FilterOp.equals) return FilterOp.anyOf;
        if (op == FilterOp.notEquals) return FilterOp.noneOf;
      case BooleanFieldDefinition():
        final b = switch (value) {
          bool() => value,
          String() => switch (value.trim().toLowerCase()) {
            'true' || 'yes' => true,
            'false' || 'no' => false,
            _ => null,
          },
          _ => null,
        };
        if (b != null && op == FilterOp.equals) {
          return b ? FilterOp.isTrue : FilterOp.isFalse;
        }
        if (b != null && op == FilterOp.notEquals) {
          return b ? FilterOp.isFalse : FilterOp.isTrue;
        }
    }
    return op;
  }

  static String _kind(FieldDefinition typed) => switch (typed) {
    AutoNumberFieldDefinition() => 'an auto-number field',
    _ => 'a ${typed.type.replaceAll('_', '-')} field',
  };

  static HarnessException _args(String message, String path) =>
      HarnessException.of(ErrorCode.invalidArgs, message, path: path);
}

FieldDefinition _presented(FieldDefinition field) =>
    field is CalculatedFieldDefinition ? field.outputField : field;
