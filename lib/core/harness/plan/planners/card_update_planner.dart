import '../../../domain/domain.dart';
import '../../api/envelope.dart';
import '../../input/input_errors.dart';
import '../../input/value_codec.dart';
import '../plan.dart';
import 'plan_call.dart';
import 'targets.dart';

/// The most `patches` one `cards.update` takes.
const int kMaxPatches = 200;

/// The most `setFrom` entries one `cards.update` takes.
const int kMaxSetFrom = 5;

/// `cards.update`: one `updateCard` per card that actually changes, holding
/// only the touched keys before → after. Cards that would not change are
/// noted and left out.
///
/// - `target` (`{ids}`, `{where}`, `{screen: true}`) with `set`, `clear`,
///   `setFrom`, `add` or `remove`; `patches` set values per card id. A card
///   both matched by `target` and patched is refused.
/// - `setFrom` computes per card: `from` copies another field, `formula`
///   (name form, `{Price} * 1.1`) is evaluated with the card's values. A
///   card whose result does not convert to the field is skipped with a
///   note; when none converts the call fails.
/// - `add` / `remove` edit one multi-select or multi-link list per card.
Future<void> planCardsUpdate(Map<String, Object?> args, PlanCall call) async {
  final collection = call.collection(args['collection']! as String);
  await call.leased([collection.id], () async {
    final schema = call.schemaOf(collection.id);
    final ops = _TargetOps.parse(args, schema, call);
    final patches = _patches(args, schema, call);
    final rawTarget = args['target'];
    if (rawTarget == null && !ops.isEmpty) {
      throw invalidArgs(
        'set, clear, setFrom, add and remove need a "target".',
        path: 'target',
      );
    }
    if (rawTarget != null && ops.isEmpty) {
      throw invalidArgs(
        'Say what to change for the target: set, clear, setFrom, add or '
        'remove.',
        path: 'target',
      );
    }
    if (rawTarget == null && patches.isEmpty) {
      throw invalidArgs(
        'Nothing to change: give a target with set/clear/setFrom/add/remove, '
        'or patches.',
      );
    }

    var targetIds = const <String>[];
    if (rawTarget != null) {
      final target = await resolveTarget(call, schema, rawTarget);
      targetIds = target.ids;
      checkCap(targetIds.length, kMaxTargetCards, what: 'update');
      checkExpectedCount(
        args['expectedCount'],
        targetIds.length,
        required:
            target.kind.isQuery && targetIds.length > kUnguardedUpdateCards,
        what: 'update',
      );
      if (targetIds.isEmpty) {
        throw invalidArgs(
          'The target matches no ${schema.name} cards.',
          path: 'target',
        );
      }
    } else if (args['expectedCount'] case final Object expected) {
      checkExpectedCount(
        expected,
        patches.length,
        required: false,
        what: 'update',
      );
    }
    final inTarget = targetIds.toSet();
    for (final (i, p) in patches.indexed) {
      if (inTarget.contains(p.id)) {
        throw invalidArgs(
          'Card ${p.id} is both in the target and patched; give it once.',
          path: 'patches[$i].id',
        );
      }
    }

    final derive = ops.needsDerivation ? _Derive(call, schema, ops) : null;
    final earlier = {
      for (final item in call.view.items.whereType<UpdateCardItem>())
        for (final c in item.changes) (item.cardId, c.fieldId),
    };
    final errors = InputErrors();
    final skipped = <String>[];
    final planned = <(MorkvaObject, MorkvaObject, List<String>)>[];
    void planOne(String id, Map<String, FieldValue>? fixed, String path) {
      _checkFree(call, schema, id, path);
      final before = call.view.object(schema.id, id)!;
      final after = <String, FieldValue>{};
      if (fixed != null) {
        after.addAll(fixed);
      } else {
        final computed = ops.apply(before, derive, call, schema);
        if (computed == null) {
          skipped.add(id);
          return;
        }
        after.addAll(computed);
      }
      final touched = [
        for (final e in after.entries)
          if (!jsonEquals(
            (before[e.key] ?? schema.fieldById(e.key)!.emptyValue()).toJson(),
            e.value.toJson(),
          ))
            e.key,
      ];
      if (touched.isEmpty) {
        call.note(_noOp(call, schema, before, after));
        return;
      }
      for (final fid in touched) {
        if (earlier.contains((id, fid))) {
          errors.add(
            ErrorDetail(
              path: path,
              code: ErrorCode.invalidArgs,
              message:
                  '${call.cardLabel(schema, before)}: '
                  '${schema.fieldById(fid)!.name} is already changed by '
                  'another call in this turn; change it once.',
            ),
          );
        }
      }
      final next = before.copyWith(values: {...before.values, ...after});
      validationDetails(
        schema,
        next,
        path: path,
        onlyFieldIds: touched.toSet(),
      ).forEach(errors.add);
      planned.add((before, next, touched));
    }

    for (final id in targetIds) {
      planOne(id, null, 'target');
    }
    for (final (i, p) in patches.indexed) {
      planOne(p.id, p.values, 'patches[$i].set');
    }
    errors.throwIfAny(hint: 'Fix every listed card and send the call again.');
    if (skipped.isNotEmpty && planned.isEmpty && patches.isEmpty) {
      throw HarnessException(
        HarnessError.fromDetails([
          for (final e in ops.failures.take(20)) e,
        ], hint: 'No card converts; check the source field or formula.'),
      );
    }
    for (final e in ops.failures) {
      call.note('${e.path}: ${e.message} Skipped.');
    }

    final risk = planned.length > kUnguardedUpdateCards
        ? Risk.medium
        : Risk.low;
    for (final (before, after, touched) in planned) {
      final changes = [
        for (final fid in touched)
          () {
            final f = schema.fieldById(fid)!;
            final b = before[fid] ?? f.emptyValue();
            final a = after[fid]!;
            return FieldChange(
              fieldId: fid,
              field: call.name(f.name),
              before: b.toJson(),
              after: a.toJson(),
              beforeText: call.valueText(f, b),
              afterText: call.valueText(f, a),
            );
          }(),
      ];
      call.add(
        UpdateCardItem(
          itemId: call.nextItemId(),
          callId: call.callId,
          collectionId: schema.id,
          targetId: before.id,
          label: call.cardLabel(schema, before),
          risk: risk,
          changes: changes,
          dependsOn: call.dependencies(
            schema.id,
            fieldIds: touched,
            cardIds: [
              for (final fid in touched)
                ...call.linkedCards(schema.fieldById(fid)!, after[fid]!),
            ],
          ),
        ),
      );
      call.changes.putUpdated(after);
    }
    call.title(_title(call, schema));
  });
}

/// Refuses a card this turn already creates, deletes or changes in the
/// same field (one item per card key keeps commit and undo simple).
void _checkFree(PlanCall call, Collection schema, String id, String path) {
  if (call.view.isCreated(schema.id, id)) {
    throw invalidArgs(
      'Card $id is created in this turn; put its values in that '
      'cards.create call instead.',
      path: path,
    );
  }
  if (call.view.isDeleted(schema.id, id)) {
    throw invalidArgs('Card $id is deleted in this turn.', path: path);
  }
}

String _noOp(
  PlanCall call,
  Collection schema,
  MorkvaObject before,
  Map<String, FieldValue> after,
) {
  final label = call.cardLabel(schema, before);
  if (after.length == 1) {
    final f = schema.fieldById(after.keys.single)!;
    final text = call.valueText(f, after.values.single);
    return text == null
        ? '$label: ${call.name(f.name)} is already empty — skipped'
        : '$label is already $text — skipped';
  }
  return '$label already has these values — skipped';
}

String _title(PlanCall call, Collection schema) {
  final items = call.changes.items.whereType<UpdateCardItem>().toList();
  final n = call.cards(schema, items.length);
  final first = items.first.changes;
  final shared =
      first.length == 1 &&
      items.every(
        (i) =>
            i.changes.length == 1 &&
            i.changes.single.fieldId == first.single.fieldId &&
            i.changes.single.afterText == first.single.afterText,
      );
  if (!shared) return 'Update $n';
  final c = first.single;
  return c.afterText == null
      ? 'Clear ${c.field} · $n'
      : 'Set ${c.field} to ${c.afterText} · $n';
}

typedef _Patch = ({String id, Map<String, FieldValue> values});

List<_Patch> _patches(
  Map<String, Object?> args,
  Collection schema,
  PlanCall call,
) {
  final raw = listArg<Object?>(args['patches'], 'patches');
  if (raw.length > kMaxPatches) {
    throw invalidArgs('At most $kMaxPatches patches.', path: 'patches');
  }
  final refs = call.resolver();
  final codec = ValueCodec(refs);
  final errors = InputErrors();
  final out = <_Patch>[];
  final seen = <String>{};
  for (final (i, p) in raw.indexed) {
    final patch = mapArg(p, 'patches[$i]');
    final id = errors.guard(
      () => refs.card(schema, patch['id']! as String, path: 'patches[$i].id'),
    );
    final values = codec.decodeValues(
      schema,
      mapArg(patch['set'], 'patches[$i].set'),
      path: 'patches[$i].set',
      errors: errors,
    );
    if (id == null) continue;
    if (!seen.add(id)) {
      errors.add(
        ErrorDetail(
          path: 'patches[$i].id',
          code: ErrorCode.invalidArgs,
          message: 'Card $id is patched twice; merge its values.',
        ),
      );
      continue;
    }
    out.add((id: id, values: values));
  }
  errors.throwIfAny(hint: 'Fix every listed patch and send the call again.');
  return out;
}

/// One `setFrom` entry: the field it fills and how.
final class _SetFrom {
  _SetFrom(this.field, this.path, {this.source, this.formula, this.expression});

  final FieldDefinition field;
  final String path;
  final FieldDefinition? source;
  final CompiledFormula? formula;

  /// The formula in storage form (`{f_price} * 1.1`).
  final String? expression;

  /// The synthetic calculated field the formula is evaluated as.
  late final CalculatedFieldDefinition? synthetic = formula == null
      ? null
      : CalculatedFieldDefinition(
          id: '@setFrom:$path',
          name: 'setFrom',
          declaredOutputType: formula!.type.fieldType,
          expression: expression,
        );
}

/// The target-wide changes of one `cards.update`: fixed values (`set`,
/// `clear`), list edits (`add`, `remove`) and computed ones (`setFrom`).
final class _TargetOps {
  _TargetOps._(this.fixed, this.add, this.remove, this.setFrom);

  /// Field id → value for every target card (`set`, `clear`).
  final Map<String, FieldValue> fixed;
  final Map<String, FieldValue> add;
  final Map<String, FieldValue> remove;
  final List<_SetFrom> setFrom;

  /// Per-card `setFrom` results that did not convert.
  final List<ErrorDetail> failures = [];

  bool get isEmpty =>
      fixed.isEmpty && add.isEmpty && remove.isEmpty && setFrom.isEmpty;

  bool get needsDerivation => setFrom.any(
    (s) => s.formula != null || s.source is CalculatedFieldDefinition,
  );

  static _TargetOps parse(
    Map<String, Object?> args,
    Collection schema,
    PlanCall call,
  ) {
    final refs = call.resolver();
    final codec = ValueCodec(refs);
    final errors = InputErrors();
    final owners = <String, String>{};
    void claim(String fieldId, String path, {bool list = false}) {
      final earlier = owners[fieldId];
      if (earlier != null && !(list && earlier.startsWith('add/remove'))) {
        errors.add(
          ErrorDetail(
            path: path,
            code: ErrorCode.invalidArgs,
            message:
                '${schema.fieldById(fieldId)!.name} is changed twice ($earlier '
                'and $path); give it once.',
          ),
        );
      }
      owners[fieldId] = list ? 'add/remove' : path;
    }

    final fixed = <String, FieldValue>{};
    final set = args['set'];
    if (set != null) {
      final values = codec.decodeValues(
        schema,
        mapArg(set, 'set'),
        path: 'set',
        errors: errors,
      );
      for (final e in values.entries) {
        claim(e.key, 'set');
        fixed[e.key] = e.value;
      }
    }
    for (final (i, ref) in listArg<String>(args['clear'], 'clear').indexed) {
      final path = 'clear[$i]';
      final field = errors.guard(() => refs.field(schema, ref, path: path));
      if (field == null) continue;
      final empty = errors.guard(
        () => codec.decode(schema, field, null, path: path),
      );
      if (empty == null) continue;
      claim(field.id, path);
      fixed[field.id] = empty;
    }

    Map<String, FieldValue> listEdit(String key) {
      final raw = args[key];
      if (raw == null) return const {};
      final values = codec.decodeValues(
        schema,
        mapArg(raw, key),
        path: key,
        errors: errors,
      );
      for (final fid in values.keys) {
        final f = schema.fieldById(fid)!;
        final multi =
            f is MultiSelectFieldDefinition ||
            (f is ReferenceFieldDefinition && f.multiple);
        if (!multi) {
          errors.add(
            ErrorDetail(
              path: '$key.${f.name}',
              code: ErrorCode.invalidArgs,
              message:
                  '$key works on multi-select and multi-link fields; '
                  '"${f.name}" holds one value, so use set.',
            ),
          );
        }
        claim(fid, '$key.${f.name}', list: true);
      }
      return values;
    }

    final add = listEdit('add');
    final remove = listEdit('remove');

    final raw = listArg<Object?>(args['setFrom'], 'setFrom');
    if (raw.length > kMaxSetFrom) {
      errors.add(
        const ErrorDetail(
          path: 'setFrom',
          code: ErrorCode.invalidArgs,
          message: 'At most $kMaxSetFrom setFrom entries.',
        ),
      );
    }
    errors.throwIfAny(hint: 'Fix every listed change and send the call again.');
    // Parsed one by one, unguarded: a formula error keeps its offset.
    final setFrom = <_SetFrom>[];
    for (final (i, r) in raw.indexed) {
      final entry = _parseSetFrom(
        mapArg(r, 'setFrom[$i]'),
        'setFrom[$i]',
        schema,
        call,
      );
      claim(entry.field.id, entry.path);
      setFrom.add(entry);
    }
    errors.throwIfAny(hint: 'Fix every listed change and send the call again.');
    return _TargetOps._(fixed, add, remove, setFrom);
  }

  /// The new values of [card]'s touched keys, or null when a `setFrom`
  /// result does not convert (the card is skipped; see [failures]).
  Map<String, FieldValue>? apply(
    MorkvaObject card,
    _Derive? derive,
    PlanCall call,
    Collection schema,
  ) {
    final out = <String, FieldValue>{...fixed};
    for (final e in add.entries) {
      out[e.key] = _merge(card[e.key], e.value, add: true);
    }
    for (final e in remove.entries) {
      out[e.key] = _merge(out[e.key] ?? card[e.key], e.value, add: false);
    }
    final codec = call.codec();
    for (final s in setFrom) {
      final friendly = s.formula != null
          ? derive!.formula(card, s)
          : _friendly(
              s.source!,
              s.source is CalculatedFieldDefinition
                  ? derive!.value(card, s.source! as CalculatedFieldDefinition)
                  : card[s.source!.id] ?? s.source!.emptyValue(),
              s.field,
              call,
            );
      try {
        out[s.field.id] = codec.decode(schema, s.field, friendly, path: s.path);
      } on HarnessException catch (e) {
        failures.add(
          ErrorDetail(
            path: call.cardLabel(schema, card),
            code: e.error.code,
            message: e.error.message,
          ),
        );
        return null;
      }
    }
    return out;
  }
}

_SetFrom _parseSetFrom(
  Map<String, Object?> raw,
  String path,
  Collection schema,
  PlanCall call,
) {
  final refs = call.resolver();
  final field = refs.field(
    schema,
    raw['field']! as String,
    path: '$path.field',
  );
  // A read-only target fails here, before any card is read.
  ValueCodec(refs).decode(schema, field, null, path: '$path.field');
  final from = raw['from'];
  final formula = raw['formula'];
  if ((from == null) == (formula == null)) {
    throw invalidArgs('Give exactly one of "from" or "formula".', path: path);
  }
  if (from != null) {
    final source = refs.field(schema, from as String, path: '$path.from');
    if (source.id == field.id) {
      throw invalidArgs('A field cannot be copied onto itself.', path: path);
    }
    _checkCompatible(_kindOf(source), source.name, field, '$path.from');
    if (source case ReferenceFieldDefinition(:final targetCollectionId)
        when field is ReferenceFieldDefinition &&
            field.targetCollectionId != targetCollectionId) {
      throw HarnessException.of(
        ErrorCode.wrongType,
        '"${source.name}" and "${field.name}" link to different collections.',
        path: '$path.from',
      );
    }
    return _SetFrom(field, path, source: source);
  }
  final stored = formulaToStorage(formula! as String, schema.fields);
  final compiled = compileFormula(stored, schema.fields);
  final error = compiled.error;
  if (error != null) {
    throw HarnessException(
      HarnessError(
        code: ErrorCode.formulaError,
        message: 'The formula does not compile: ${error.message}.',
        path: '$path.formula',
        offset: error.offset,
        hint: 'Name fields in braces: {Price} * 1.1.',
      ),
    );
  }
  _checkCompatible(
    compiled.formula!.type.name,
    'The formula (${compiled.formula!.type.label})',
    field,
    '$path.formula',
  );
  return _SetFrom(field, path, formula: compiled.formula, expression: stored);
}

/// The kind of value [field] presents: text, number, boolean, date,
/// select, multi, reference or file.
String _kindOf(FieldDefinition field) =>
    switch (presentedAs(field, field.emptyValue()).$1) {
      NumberFieldDefinition() || AutoNumberFieldDefinition() => 'number',
      BooleanFieldDefinition() => 'boolean',
      DateFieldDefinition() => 'date',
      SingleSelectFieldDefinition() => 'select',
      MultiSelectFieldDefinition() => 'multi',
      ReferenceFieldDefinition() => 'reference',
      FileFieldDefinition() => 'file',
      _ => 'text',
    };

/// Refuses a source kind that can never fill [target] (a number into a
/// yes/no, a date into a link); text sources convert per card.
void _checkCompatible(
  String kind,
  String sourceName,
  FieldDefinition target,
  String path,
) {
  final targetKind = _kindOf(target);
  final ok =
      kind != 'file' &&
      (kind == targetKind ||
          kind == 'text' ||
          targetKind == 'text' ||
          (kind == 'select' && targetKind == 'multi') ||
          (kind == 'multi' && targetKind == 'select'));
  if (ok) return;
  throw HarnessException.of(
    ErrorCode.wrongType,
    '$sourceName ($kind) cannot fill "${target.name}" ($targetKind).',
    path: path,
    hint: 'Copy between fields of the same kind, or from/into a text field.',
  );
}

/// [value] of [source] as the friendly input the value codec reads for
/// [target].
Object? _friendly(
  FieldDefinition source,
  FieldValue value,
  FieldDefinition target,
  PlanCall call,
) {
  final (f, v) = presentedAs(source, value);
  if (v.isEmpty) return null;
  if (target is TextFieldDefinition &&
      f is! TextFieldDefinition &&
      f is! NumberFieldDefinition) {
    return formatFieldValue(
      f,
      v,
      referenceLabels: switch (f) {
        ReferenceFieldDefinition(:final targetCollectionId) => objectLabels(
          call.schemaOf(targetCollectionId),
          call.view.objectsOf(targetCollectionId),
        ),
        _ => const {},
      },
    );
  }
  return switch ((f, v)) {
    (_, TextFieldValue(:final text)) => text,
    (_, NumberFieldValue(:final value)) => value,
    (_, AutoNumberFieldValue(:final sequence)) => sequence,
    (_, BooleanFieldValue(:final value)) => value,
    (final DateFieldDefinition d, DateFieldValue(value: final dt?)) =>
      d.includeTime
          ? dt.toUtc().toIso8601String()
          : isoDay(calendarDayOf(d, dt)),
    (
      SingleSelectFieldDefinition(:final options),
      SingleSelectFieldValue(:final optionId),
    ) =>
      options.where((o) => o.id == optionId).firstOrNull?.label,
    (
      MultiSelectFieldDefinition(:final options),
      MultiSelectFieldValue(:final optionIds),
    ) =>
      [
        for (final o in options)
          if (optionIds.contains(o.id)) o.label,
      ],
    (_, ReferenceFieldValue(:final objectIds)) => objectIds,
    _ => null,
  };
}

/// [current] with [edit]'s entries added to or removed from its list.
FieldValue _merge(FieldValue? current, FieldValue edit, {required bool add}) {
  List<String> apply(List<String> list, List<String> by) => add
      ? [...list, ...by.where((id) => !list.contains(id))]
      : [...list.where((id) => !by.contains(id))];
  return switch ((current, edit)) {
    (MultiSelectFieldValue(:final optionIds), MultiSelectFieldValue e) =>
      MultiSelectFieldValue(apply(optionIds, e.optionIds)),
    (null, MultiSelectFieldValue e) => MultiSelectFieldValue(
      apply(const [], e.optionIds),
    ),
    (ReferenceFieldValue(:final objectIds), ReferenceFieldValue e) =>
      ReferenceFieldValue(apply(objectIds, e.objectIds)),
    (null, ReferenceFieldValue e) => ReferenceFieldValue(
      apply(const [], e.objectIds),
    ),
    _ => edit,
  };
}

/// Calculated values for `setFrom`: one [Derivation] over the pending
/// workspace, with each formula added to the schema as a synthetic
/// calculated field.
final class _Derive {
  _Derive(this.call, Collection schema, _TargetOps ops)
    : _schema = schema.copyWith(
        fields: [...schema.fields, for (final s in ops.setFrom) ?s.synthetic],
      ) {
    final all = call.view.collections;
    _derivation = Derivation(
      collections: _schema.withWorkspace(all),
      objects: {
        for (final id in {
          _schema.id,
          ...Derivation.sourcesOf(_schema.id, _schema.withWorkspace(all)),
        })
          id: call.view.objectsOf(id),
      },
      today: call.ctx.today,
    );
  }

  final PlanCall call;
  final Collection _schema;
  late final Derivation _derivation;

  FieldValue value(MorkvaObject card, CalculatedFieldDefinition field) =>
      _derivation.valueOf(_schema, card, field);

  /// The formula's result for [card] in friendly form.
  Object? formula(MorkvaObject card, _SetFrom s) {
    final result = _derivation.valueOf(_schema, card, s.synthetic!).cached;
    // Dates come back as UTC-midnight ISO instants; the day is what counts.
    if (s.formula!.type == FormulaType.date && result is String) {
      return result.length >= 10 ? result.substring(0, 10) : result;
    }
    return result;
  }
}
