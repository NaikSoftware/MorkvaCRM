import '../../domain/domain.dart';
import '../api/capability.dart';
import '../cache/workspace_cache.dart';
import '../input/filter_compiler.dart';
import '../input/screen_line.dart';
import 'query_engine.dart';
import 'result_shaper.dart';

/// The workspace as the model reads it, in two forms:
/// - [text]: the compact `<workspace-data>` block of the context message
///   (about 30 tokens per collection);
/// - [describe] / [schema]: the JSON of `workspace.describe` and
///   `collections.get`.
///
/// Collections outside the caller's grants are left out. Every user-authored
/// name in [text] is JSON-quoted, stripped of control, bidi and zero-width
/// characters, cut to 60 characters and has `<` / `>` escaped, so a
/// collection named "Ignore previous rules…" or `</workspace-data>` stays a
/// quoted string inside the data block, never instruction text.
final class WorkspaceDigest {
  const WorkspaceDigest({
    this.shaper = const ResultShaper(),
    this.maxCollections = 30,
    this.maxChars = 12000,
    this.maxOptions = 6,
    this.largeCount = 20000,
  });

  final ResultShaper shaper;

  /// Above this many collections [text] drops to names and counts.
  final int maxCollections;

  /// About 3k tokens: a longer [text] drops to names and counts.
  final int maxChars;

  /// Option labels a select shows in [text] before `(+N)`.
  final int maxOptions;

  /// Card counts from here on are flagged `large` in [text].
  final int largeCount;

  static const String open = '<workspace-data>';
  static const String close = '</workspace-data>';
  static const String legend =
      'Types: t text · n number · b yes/no · d date · s select · m multi · '
      'r link · f file · # auto · c calc · * many';

  /// The digest block of [collections] for [grants]. [countOf] gives a
  /// collection's card count, or null while unknown (shown as `?`: a cheap
  /// count needs the collection's listener).
  String text(
    List<Collection> collections, {
    int? Function(String collectionId)? countOf,
    Grants? grants,
  }) {
    final visible = [
      for (final c in collections)
        if (grants?.allowsCollection(c.id) ?? true) c,
    ];
    if (visible.isEmpty) return '$open\nNo collections yet.\n$close';
    final byId = {for (final c in visible) c.id: c};
    String head(Collection c) =>
        '- ${quote(c.name)} (${_count(countOf?.call(c.id))})';

    if (visible.length <= maxCollections) {
      final full = [
        open,
        legend,
        for (final c in visible)
          c.fields.isEmpty
              ? head(c)
              : '${head(c)}: '
                    '${[for (final f in c.fields) _field(f, byId)].join(', ')}',
        close,
      ].join('\n');
      if (full.length <= maxChars) return full;
    }

    // Too big: names and counts only, cut to the budget.
    const note = 'Fields omitted; call workspace.describe or collections.get.';
    final lines = <String>[open, note];
    var length = open.length + note.length + close.length + 2;
    for (final (i, c) in visible.indexed) {
      final line = head(c);
      final rest = visible.length - i;
      if (length + line.length + 1 > maxChars - 40) {
        lines.add('- (+$rest more; workspace.describe lists them)');
        break;
      }
      lines.add(line);
      length += line.length + 1;
    }
    return [...lines, close].join('\n');
  }

  /// [text] over what [cache] holds now: counts of the collections it has
  /// leased, `?` for the rest (the digest never leases).
  String ofCache(WorkspaceCache cache, {Grants? grants}) => text(
    cache.collections,
    countOf: (id) => cache.current(id)?.count,
    grants: grants,
  );

  /// [name] sanitized, JSON-quoted, with `<` and `>` escaped so it can never
  /// close the data block.
  static String quote(String name) =>
      quoteName(name).replaceAll('<', r'\u003c').replaceAll('>', r'\u003e');

  /// One `workspace.describe` collection: `{id, name, icon?, count?,
  /// fields: [{id, name, type, required?, readOnly?, options?, target?,
  /// calc?, …}], views: [{id, name, mode}]}`. [full] adds descriptions,
  /// every option with its id and per-type flags; the digest form lists up
  /// to [maxOptions] option labels.
  Map<String, Object?> describe(
    Collection c, {
    required List<Collection> all,
    required Grants grants,
    int? count,
    bool full = false,
  }) => {
    'id': c.id,
    'name': shaper.name(c.name),
    if (c.icon != null) 'icon': c.icon,
    if (full && (c.description?.trim().isNotEmpty ?? false))
      'description': shaper.text(c.description!),
    'count': ?count,
    'fields': [
      for (final f in c.fields) _describeField(c, f, all, grants, full: full),
    ],
    'views': [
      for (final v in c.views)
        {'id': v.id, 'name': shaper.name(v.name), 'mode': v.mode},
    ],
  };

  /// The `collections.get` result: the collection's JSON (names in display
  /// form, formulas in name form, views without their manual order) plus
  /// [count] and the filter `operators` of every field. [fieldIds] narrows
  /// the fields. Not budgeted: callers run it through
  /// `ResultShaper.fitSchema`.
  Map<String, Object?> schema(
    Collection c, {
    required List<Collection> all,
    required Grants grants,
    int? count,
    Set<String>? fieldIds,
  }) => {
    'id': c.id,
    'name': shaper.name(c.name),
    if (c.description?.trim().isNotEmpty ?? false)
      'description': shaper.text(c.description!),
    if (c.icon != null) 'icon': c.icon,
    'count': ?count,
    'fields': [
      for (final f in c.fields)
        if (fieldIds == null || fieldIds.contains(f.id))
          _schemaField(c, f, all, grants),
    ],
    'views': [
      for (final v in c.views)
        {
          'id': v.id,
          'name': shaper.name(v.name),
          'mode': v.mode,
          if (v.layoutFieldId != null) 'layoutFieldId': v.layoutFieldId,
          'fieldIds': v.fieldIds,
          if (v.filters.isNotEmpty)
            'filters': [
              for (final f in v.filters)
                {
                  'fieldId': f.fieldId,
                  'op': f.op.name,
                  if (f.operand != null) 'operand': _operand(f.operand),
                },
            ],
          if (v.sort case final s?)
            'sort': {'fieldId': s.fieldId, 'ascending': s.ascending},
        },
    ],
  };

  /// What a calculated [field] of [owner] computes, in words: its formula
  /// in name form (`{Price} * {Qty}`), `sum of Qty of Orders linking here
  /// via Client`, or `Client › City` for a lookup. Null for other fields.
  String? calcText(
    Collection owner,
    FieldDefinition field,
    List<Collection> all,
  ) {
    if (field is! CalculatedFieldDefinition) return null;
    String nameOf(Collection? c, String? fieldId) =>
        c?.fields.where((f) => f.id == fieldId).firstOrNull?.name ??
        (fieldId ?? '?');
    Collection? byId(String? id) => all.where((c) => c.id == id).firstOrNull;
    final own = owner.fields;
    if (field.lookup case final l?) {
      final via = own.where((f) => f.id == l.referenceFieldId).firstOrNull;
      final target = via is ReferenceFieldDefinition
          ? byId(via.targetCollectionId)
          : null;
      return sanitizeName(
        '${via?.name ?? '?'} › ${nameOf(target, l.fieldId)}',
        max: 160,
      );
    }
    if (field.aggregate case final a? when !field.isLookup) {
      final ref = a.referenceFieldId;
      final source = a.source == AggregateSource.linked
          ? switch (own.where((f) => f.id == ref).firstOrNull) {
              ReferenceFieldDefinition(:final targetCollectionId) => byId(
                targetCollectionId,
              ),
              _ => null,
            }
          : byId(a.collectionId);
      final sourceName = source?.name ?? '?';
      final what = a.op == AggregateOp.count
          ? 'count of'
          : '${a.op.name} of ${nameOf(source, a.fieldId)} of';
      final scope = switch (a.source) {
        AggregateSource.linkedFrom =>
          '$sourceName linking here via ${nameOf(source, ref)}',
        AggregateSource.linked => 'linked $sourceName',
        AggregateSource.all => 'all $sourceName',
      };
      final where = switch (a.filters.length) {
        0 => '',
        1 => ' (1 filter)',
        final n => ' ($n filters)',
      };
      return sanitizeName('$what $scope$where', max: 160);
    }
    if (field.expression case final e?) {
      return sanitizeName(formulaToDisplay(e, own), max: 500);
    }
    return null;
  }

  // ---------------------------------------------------------------------------

  String _count(int? count) => switch (count) {
    null => '?',
    final n when n >= largeCount => '$n, large',
    final n => '$n',
  };

  String _field(FieldDefinition f, Map<String, Collection> byId) {
    final name = quote(f.name);
    return switch (f) {
      AutoNumberFieldDefinition() => '$name#',
      SingleSelectFieldDefinition(:final options) =>
        '$name s(${_options(options)})',
      MultiSelectFieldDefinition(:final options) =>
        '$name m(${_options(options)})',
      ReferenceFieldDefinition(:final targetCollectionId, :final multiple) =>
        '$name r${multiple ? '*' : ''}→'
            '${switch (byId[targetCollectionId]) {
              final c? => quote(c.name),
              null => '?',
            }}',
      FileFieldDefinition(:final multiple) => '$name f${multiple ? '*' : ''}',
      CalculatedFieldDefinition(:final outputField) =>
        '$name c:${_letter(outputField)}${_unit(outputField)}',
      _ => '$name ${_letter(f)}${_unit(f)}',
    };
  }

  String _options(List<SelectOption> options) {
    final shown = [for (final o in options.take(maxOptions)) quote(o.label)];
    final more = options.length - shown.length;
    return '${shown.join('|')}${more > 0 ? ' (+$more)' : ''}';
  }

  static String _letter(FieldDefinition f) => switch (f.type) {
    kTextFieldType => 't',
    kNumberFieldType => 'n',
    kBooleanFieldType => 'b',
    kDateFieldType => 'd',
    kSingleSelectFieldType => 's',
    kMultiSelectFieldType => 'm',
    kReferenceFieldType => 'r',
    kFileFieldType => 'f',
    kAutoNumberFieldType => '#',
    kCalculatedFieldType => 'c',
    _ => '?',
  };

  static String _unit(FieldDefinition f) => switch (f) {
    NumberFieldDefinition(:final unitLabel?) when unitLabel.trim().isNotEmpty =>
      ' ${quote(unitLabel)}',
    _ => '',
  };

  Map<String, Object?> _describeField(
    Collection c,
    FieldDefinition f,
    List<Collection> all,
    Grants grants, {
    required bool full,
  }) {
    final redacted = readsUngranted(c, f, grants, all);
    final options = _selectOptions(f);
    final target = f is ReferenceFieldDefinition
        ? all.where((t) => t.id == f.targetCollectionId).firstOrNull
        : null;
    final shownTarget = target != null && grants.allowsCollection(target.id);
    return {
      'id': f.id,
      'name': shaper.name(f.name),
      'type': f.type,
      if (full && (f.description?.trim().isNotEmpty ?? false))
        'description': shaper.text(f.description!),
      if (f.isRequired) 'required': true,
      if (_readOnly(f)) 'readOnly': true,
      if (options != null)
        'options': full
            ? [
                for (final o in options)
                  {'id': o.id, 'label': shaper.label(o.label)},
              ]
            : [for (final o in options.take(maxOptions)) shaper.label(o.label)],
      if (options != null && !full && options.length > maxOptions)
        'moreOptions': options.length - maxOptions,
      if (shownTarget) 'target': target.id,
      if (f is ReferenceFieldDefinition && f.multiple) 'multiple': true,
      if (f is FileFieldDefinition && f.multiple) 'multiple': true,
      if (full && f is DateFieldDefinition && f.includeTime)
        'includeTime': true,
      if (f is CalculatedFieldDefinition) 'output': f.outputField.type,
      'unit': ?shaper.unitOf(f),
      if (redacted) 'redacted': true else 'calc': ?calcText(c, f, all),
    };
  }

  Map<String, Object?> _schemaField(
    Collection c,
    FieldDefinition f,
    List<Collection> all,
    Grants grants,
  ) {
    final json = <String, Object?>{...f.toJson()};
    json['name'] = shaper.name(f.name);
    if (f.description?.trim().isNotEmpty ?? false) {
      json['description'] = shaper.text(f.description!);
    } else {
      json.remove('description');
    }
    if (_selectOptions(f) case final options?) {
      json['options'] = [
        for (final o in options)
          {...o.toJson(), 'label': shaper.label(o.label)},
      ];
    }
    if (f is NumberFieldDefinition && f.unitLabel != null) {
      json['unitLabel'] = shaper.name(f.unitLabel!);
    }
    if (f case CalculatedFieldDefinition(:final unitLabel?)) {
      json['unitLabel'] = shaper.name(unitLabel);
    }
    if (f case AutoNumberFieldDefinition(:final prefix?)) {
      json['prefix'] = shaper.name(prefix);
    }
    if (f is CalculatedFieldDefinition) {
      if (readsUngranted(c, f, grants, all)) {
        json
          ..remove('expression')
          ..remove('aggregate')
          ..remove('lookup')
          ..['redacted'] = true;
      } else {
        if (f.expression case final e?) {
          json['expression'] = sanitizeName(
            formulaToDisplay(e, c.fields),
            max: 500,
          );
        }
        if (calcText(c, f, all) case final calc?) json['calc'] = calc;
      }
    }
    if (_readOnly(f)) json['readOnly'] = true;
    json['operators'] = [for (final op in filterOpsFor(f)) op.name];
    return json;
  }

  Object? _operand(Object? operand) => switch (operand) {
    final String s => shaper.text(s),
    final List l => [for (final v in l) v is String ? shaper.text(v) : v],
    _ => operand,
  };

  static List<SelectOption>? _selectOptions(FieldDefinition f) => switch (f) {
    SingleSelectFieldDefinition(:final options) ||
    MultiSelectFieldDefinition(:final options) => options,
    _ => null,
  };

  /// Fields the harness never writes: derived ones, and files (Storage is
  /// deferred, so v1 refuses file values).
  static bool _readOnly(FieldDefinition f) =>
      f is CalculatedFieldDefinition ||
      f is AutoNumberFieldDefinition ||
      f is FileFieldDefinition;
}
