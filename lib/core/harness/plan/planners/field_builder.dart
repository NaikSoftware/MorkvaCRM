import '../../../domain/domain.dart';
import '../../api/envelope.dart';
import '../../input/input_errors.dart';
import '../../input/value_codec.dart';
import '../../schema/field_specs.dart';
import 'plan_call.dart';

/// The hint every locked-shape error carries.
const String kTypeLockedHint =
    'Add a new field, fill it with cards.update setFrom, then delete the old '
    'one.';

/// Builds domain [FieldDefinition]s from FieldSpecs (the friendly wire form:
/// `target` refs, option labels, formulas in name form) and from
/// `fields.update` patches. Problems go to [errors]; a spec that fails
/// yields null.
///
/// Two phases, because calculated fields read the others: [plain] builds
/// every spec (a calculated one as a stub), then, once the owner draft with
/// all of them is staged in the call's overlay, [calculated] resolves
/// formulas, aggregates and lookups against it.
final class FieldBuilder {
  FieldBuilder(this.call, this.errors);

  final PlanCall call;
  final InputErrors errors;

  /// FieldSpec `ref`s (`@client`) of the specs built so far → field id.
  final Map<String, String> aliases = {};

  /// [spec] as a definition with a fresh id; a calculated spec as a stub
  /// (number, no source) for [calculated] to finish.
  FieldDefinition? plain(Map<String, Object?> spec, {required String path}) {
    final problems = checkFieldSpec(spec, path: path);
    if (problems.isNotEmpty) {
      problems.forEach(errors.add);
      return null;
    }
    final id = call.ids.fieldId();
    final ref = (spec['ref'] as String?)?.trim();
    if (ref != null) {
      if (!ref.startsWith('@') || aliases.containsKey(ref)) {
        errors.add(
          ErrorDetail(
            path: '$path.ref',
            code: ErrorCode.invalidArgs,
            message: aliases.containsKey(ref)
                ? 'The field ref "$ref" is used twice.'
                : 'A field ref starts with "@" (e.g. "@client").',
          ),
        );
        return null;
      }
      aliases[ref] = id;
    }
    final type = spec['type']! as String;
    final json = <String, dynamic>{
      'id': id,
      'type': type,
      'name': (spec['name']! as String).trim(),
      if (spec['description'] case final String d when d.trim().isNotEmpty)
        'description': d.trim(),
      'required': spec['required'] ?? false,
    };
    if (!_config(json, type, spec, path)) return null;
    return _definition(json, path);
  }

  /// The calculated field [stub] completed from [spec]: formula (stored as
  /// `expression`), aggregate or lookup, always with `declaredOutputType`.
  /// [owner] is the draft holding every new field; it must be staged in the
  /// call's overlay so refs to it and to other new collections resolve.
  FieldDefinition? calculated(
    Map<String, Object?> spec,
    CalculatedFieldDefinition stub,
    Collection owner, {
    required String path,
  }) {
    final json = stub.toJson()
      ..remove('expression')
      ..remove('aggregate')
      ..remove('lookup');
    final ok = errors.guard(() {
      _calculatedSource(json, spec, owner, path);
      return true;
    });
    return ok == null ? null : _definition(json, path);
  }

  /// `fields.update`: [before] with [patch] applied. Option edits keep every
  /// option id (the option-id lock); `type`, `target` and `options` cannot
  /// change (`type_locked`), and `multiple` / `includeTime` flips are caught
  /// by the strict schema check.
  FieldPatch? patch(
    Collection owner,
    FieldDefinition before,
    Map<String, Object?> patch, {
    String path = 'patch',
  }) {
    final problems = errors.details.length;
    for (final key in const ['type', 'target', 'options']) {
      if (patch[key] == null) continue;
      errors.add(
        ErrorDetail(
          path: '$path.$key',
          code: ErrorCode.typeLocked,
          message: key == 'options'
              ? 'Options keep their ids; use addOptions, renameOptions and '
                    'removeOptions instead of options.'
              : 'The $key of "${before.name}" is locked after save. '
                    '$kTypeLockedHint',
        ),
      );
    }
    const optionEdits = ['addOptions', 'renameOptions', 'removeOptions'];
    final isSelect =
        before is SingleSelectFieldDefinition ||
        before is MultiSelectFieldDefinition;
    for (final key in optionEdits) {
      if (patch[key] != null && !isSelect) {
        errors.add(
          ErrorDetail(
            path: '$path.$key',
            code: ErrorCode.invalidArgs,
            message:
                '"${before.name}" is not a select field; $key applies '
                'to select and multi-select fields.',
          ),
        );
      }
    }
    final config = {
      for (final e in patch.entries)
        if (!optionEdits.contains(e.key) &&
            !const ['type', 'target', 'options'].contains(e.key))
          e.key: e.value,
    };
    final hasSource = kCalculatedSourceKeys.any((k) => config[k] != null);
    for (final p in checkFieldSpec({
      ...config,
      'name': config['name'] ?? before.name,
      'type': before.type,
    }, path: path)) {
      // A patch may leave a calculated field's source as it is.
      if (before is CalculatedFieldDefinition && !hasSource && p.path == path) {
        continue;
      }
      errors.add(p);
    }
    if (errors.details.length > problems) return null;

    final json = before.toJson();
    if (config['name'] case final String name) json['name'] = name.trim();
    if (config.containsKey('description')) {
      final d = (config['description'] as String?)?.trim();
      if (d == null || d.isEmpty) {
        json.remove('description');
      } else {
        json['description'] = d;
      }
    }
    if (config['required'] case final bool r) json['required'] = r;
    if (!_config(json, before.type, config, path, patching: true)) return null;

    final removed = <String>{};
    if (isSelect) {
      final options = [
        for (final o in (json['options'] as List).cast<Map<String, dynamic>>())
          {...o},
      ];
      _optionEdits(before, options, patch, removed, path);
      json['options'] = options;
    }
    if (before is CalculatedFieldDefinition && hasSource) {
      json
        ..remove('expression')
        ..remove('aggregate')
        ..remove('lookup');
      final ok = errors.guard(() {
        _calculatedSource(json, config, owner, path, selfId: before.id);
        return true;
      });
      if (ok == null) return null;
    }
    final after = _definition(json, path);
    if (after == null) return null;
    checkOptionIds(before, after, removed, path: path, errors: errors);
    if (errors.details.length > problems) return null;
    return (field: after, removedOptions: removed);
  }

  // ---------------------------------------------------------------------------

  FieldDefinition? _definition(Map<String, dynamic> json, String path) {
    try {
      return call.services.registry.definitionFromJson(json);
    } on Object catch (e) {
      errors.add(
        ErrorDetail(
          path: path,
          code: ErrorCode.invalidArgs,
          message: 'The field does not build: $e',
        ),
      );
      return null;
    }
  }

  /// Copies [spec]'s per-type config into domain [json]; false on a
  /// problem (recorded).
  bool _config(
    Map<String, dynamic> json,
    String type,
    Map<String, Object?> spec,
    String path, {
    bool patching = false,
  }) {
    final before = errors.details.length;
    void copy(List<String> keys) {
      for (final key in keys) {
        if (spec.containsKey(key)) json[key] = spec[key];
      }
    }

    switch (type) {
      case kTextFieldType:
        copy(const ['multiline', 'maxLength']);
      case kNumberFieldType:
        copy(const ['decimalPlaces', 'unitLabel', 'min', 'max']);
      case kDateFieldType:
        copy(const ['includeTime']);
        for (final key in const ['min', 'max']) {
          if (spec[key] case final String raw) {
            final at = parseInstant(raw, call.ctx.today);
            if (at == null) {
              errors.add(
                ErrorDetail(
                  path: '$path.$key',
                  code: ErrorCode.invalidArgs,
                  message: '"$key" is YYYY-MM-DD or ISO-8601; got "$raw".',
                ),
              );
            } else {
              json[key] = at.toIso8601String();
            }
          }
        }
      case kSingleSelectFieldType || kMultiSelectFieldType:
        if (!patching) {
          json['options'] = _options(
            listArg<Object?>(spec['options'], '$path.options'),
            '$path.options',
          );
        }
      case kReferenceFieldType:
        copy(const ['multiple']);
        if (!patching) {
          final target = spec['target'];
          if (target is! String) {
            errors.add(
              ErrorDetail(
                path: '$path.target',
                code: ErrorCode.invalidArgs,
                message: 'A reference field needs a "target" collection.',
              ),
            );
          } else {
            final id = errors.guard(
              () => call.collection(target, path: '$path.target').id,
            );
            if (id != null) json['targetCollectionId'] = id;
          }
        }
      case kFileFieldType:
        copy(const ['multiple']);
        if (spec['allowedExtensions'] case final List exts) {
          json['allowedExtensions'] = [
            for (final e in exts)
              '$e'.trim().toLowerCase().replaceFirst(RegExp(r'^\.'), ''),
          ];
        }
      case kAutoNumberFieldType:
        copy(const ['prefix', 'padding', 'start']);
      case kCalculatedFieldType:
        copy(const ['decimalPlaces', 'unitLabel']);
        json['declaredOutputType'] ??= kNumberFieldType;
    }
    return errors.details.length == before;
  }

  List<Map<String, Object?>> _options(List<Object?> raw, String path) {
    final out = <Map<String, Object?>>[];
    final seen = <String>{};
    for (final (i, o) in raw.indexed) {
      final (label, color) = switch (o) {
        final String s => (s, null),
        {'label': final String l} => (l, (o as Map)['color'] as String?),
        _ => ('', null),
      };
      final at = '$path[$i]';
      if (!_addOption(out, seen, label, color, at)) continue;
    }
    return out;
  }

  bool _addOption(
    List<Map<String, Object?>> out,
    Set<String> seen,
    String label,
    String? color,
    String path,
  ) {
    final clean = label.trim();
    if (clean.isEmpty || !seen.add(clean.toLowerCase())) {
      errors.add(
        ErrorDetail(
          path: path,
          code: ErrorCode.invalidArgs,
          message: clean.isEmpty
              ? 'An option needs a label.'
              : 'The option "$clean" is listed twice.',
        ),
      );
      return false;
    }
    out.add({'id': call.ids.optionId(), 'label': clean, 'color': ?color});
    return true;
  }

  void _optionEdits(
    FieldDefinition before,
    List<Map<String, dynamic>> options,
    Map<String, Object?> patch,
    Set<String> removed,
    String path,
  ) {
    final refs = call.resolver();
    final current = switch (before) {
      SingleSelectFieldDefinition(:final options) ||
      MultiSelectFieldDefinition(:final options) => options,
      _ => const <SelectOption>[],
    };
    for (final (i, r) in listArg<Object?>(
      patch['removeOptions'],
      '$path.removeOptions',
    ).indexed) {
      final o = errors.guard(
        () => refs.option(
          before.name,
          current,
          '$r',
          path: '$path.removeOptions[$i]',
        ),
      );
      if (o != null) removed.add(o.id);
    }
    for (final (i, r) in listArg<Object?>(
      patch['renameOptions'],
      '$path.renameOptions',
    ).indexed) {
      final at = '$path.renameOptions[$i]';
      final rename = mapArg(r, at);
      final o = errors.guard(
        () => refs.option(
          before.name,
          current,
          rename['option']! as String,
          path: '$at.option',
        ),
      );
      final label = (rename['label']! as String).trim();
      if (o == null) continue;
      if (label.isEmpty) {
        errors.add(
          ErrorDetail(
            path: '$at.label',
            code: ErrorCode.invalidArgs,
            message: 'An option needs a label.',
          ),
        );
        continue;
      }
      options.firstWhere((m) => m['id'] == o.id)['label'] = label;
    }
    options.removeWhere((m) => removed.contains(m['id']));
    final seen = <String>{};
    for (final m in options) {
      final key = (m['label'] as String).toLowerCase();
      if (!seen.add(key)) {
        errors.add(
          ErrorDetail(
            path: '$path.renameOptions',
            code: ErrorCode.invalidArgs,
            message: 'Two options would be called "${m['label']}".',
          ),
        );
      }
    }
    for (final (i, a) in listArg<Object?>(
      patch['addOptions'],
      '$path.addOptions',
    ).indexed) {
      final add = mapArg(a, '$path.addOptions[$i]');
      _addOption(
        options,
        seen,
        add['label']! as String,
        add['color'] as String?,
        '$path.addOptions[$i]',
      );
    }
    if (options.isEmpty) {
      errors.add(
        ErrorDetail(
          path: '$path.removeOptions',
          code: ErrorCode.invalidArgs,
          message: '"${before.name}" needs at least one option.',
        ),
      );
    }
  }

  /// Resolves [spec]'s formula, aggregate or lookup into [json] (throws).
  void _calculatedSource(
    Map<String, dynamic> json,
    Map<String, Object?> spec,
    Collection owner,
    String path, {
    String? selfId,
  }) {
    final id = selfId ?? json['id'] as String;
    final refs = call.resolver();
    FieldDefinition fieldOf(Collection c, String ref, String at) {
      final alias = aliases[ref.trim()];
      final byAlias = alias == null ? null : c.fieldById(alias);
      return byAlias ?? refs.field(c, ref, path: at);
    }

    if (spec['formula'] case final String formula) {
      final stored = formulaToStorage(formula, owner.fields);
      final compiled = compileFormula(stored, owner.fields, selfId: id);
      if (compiled.error case final e?) {
        throw HarnessException(
          HarnessError(
            code: ErrorCode.formulaError,
            message: 'The formula does not compile: ${e.message}.',
            path: '$path.formula',
            offset: e.offset,
            hint: 'Name fields in braces: {Price} * {Qty}.',
          ),
        );
      }
      json['expression'] = stored;
      json['declaredOutputType'] = compiled.formula!.type.fieldType;
      return;
    }
    if (spec['lookup'] case final Map raw) {
      final lookup = raw.cast<String, Object?>();
      final via = fieldOf(owner, lookup['via']! as String, '$path.lookup.via');
      if (via is! ReferenceFieldDefinition) {
        throw invalidArgs(
          'lookup.via must be a link field of ${owner.name}; '
          '"${via.name}" is not.',
          path: '$path.lookup.via',
        );
      }
      final target = call.schemaOf(via.targetCollectionId);
      final shown = switch (lookup['field']) {
        final String ref => fieldOf(target, ref, '$path.lookup.field'),
        _ =>
          target.fields.whereType<TextFieldDefinition>().firstOrNull ??
              (throw invalidArgs(
                'Name the field of ${target.name} to show in lookup.field.',
                path: '$path.lookup.field',
              )),
      };
      if (!isLookupable(shown)) {
        throw invalidArgs(
          'A lookup cannot show "${shown.name}" (links and files).',
          path: '$path.lookup.field',
        );
      }
      json['lookup'] = Lookup(
        referenceFieldId: via.id,
        fieldId: shown.id,
      ).toJson();
      json['declaredOutputType'] = presentedAs(
        shown,
        shown.emptyValue(),
      ).$1.type;
      return;
    }
    final aggregate = mapArg(spec['aggregate'], '$path.aggregate');
    final at = '$path.aggregate';
    final source = AggregateSource.values.asNameMap()[aggregate['source']]!;
    final op = AggregateOp.values.asNameMap()[aggregate['op']]!;
    final collection = call.collection(
      aggregate['collection']! as String,
      path: '$at.collection',
    );
    String? referenceFieldId;
    switch (source) {
      case AggregateSource.linkedFrom:
        final ref = aggregate['referenceField'];
        if (ref is! String) {
          throw invalidArgs(
            'linkedFrom needs referenceField: the link field of '
            '${collection.name} that points here.',
            path: '$at.referenceField',
          );
        }
        final f = fieldOf(collection, ref, '$at.referenceField');
        if (f is! ReferenceFieldDefinition ||
            f.targetCollectionId != owner.id) {
          throw invalidArgs(
            '"${f.name}" of ${collection.name} does not link to ${owner.name}.',
            path: '$at.referenceField',
          );
        }
        referenceFieldId = f.id;
      case AggregateSource.linked:
        final ref = aggregate['referenceField'];
        if (ref is! String) {
          throw invalidArgs(
            'linked needs referenceField: the link field of ${owner.name}.',
            path: '$at.referenceField',
          );
        }
        final f = fieldOf(owner, ref, '$at.referenceField');
        if (f is! ReferenceFieldDefinition ||
            f.targetCollectionId != collection.id) {
          throw invalidArgs(
            '"${f.name}" of ${owner.name} does not link to ${collection.name}.',
            path: '$at.referenceField',
          );
        }
        referenceFieldId = f.id;
      case AggregateSource.all:
        break;
    }
    String? fieldId;
    if (op.needsField) {
      final ref = aggregate['field'];
      if (ref is! String) {
        throw invalidArgs(
          '${op.name} needs "field": what to ${op.name} in '
          '${collection.name}.',
          path: '$at.field',
        );
      }
      final f = fieldOf(collection, ref, '$at.field');
      final shown = presentedAs(f, f.emptyValue()).$1;
      final numeric =
          shown is NumberFieldDefinition || shown is AutoNumberFieldDefinition;
      final dated = shown is DateFieldDefinition;
      final fits = op == AggregateOp.min || op == AggregateOp.max
          ? numeric || dated
          : numeric;
      if (!fits) {
        throw invalidArgs(
          '${op.name} needs a number${op == AggregateOp.min || op == AggregateOp.max ? ' or date' : ''} '
          'field; "${f.name}" is not.',
          path: '$at.field',
        );
      }
      fieldId = f.id;
    }
    final where = aggregate['where'];
    final filters = where == null
        ? const <ViewFilter>[]
        : call.compiler().compile(
            collection,
            listArg<Object?>(where, '$at.where'),
            path: '$at.where',
          );
    final aggregation = Aggregation(
      source: source,
      collectionId: collection.id,
      referenceFieldId: referenceFieldId,
      op: op,
      fieldId: fieldId,
      filters: filters,
    );
    json['aggregate'] = aggregation.toJson();
    json['declaredOutputType'] = aggregateOutputType(
      aggregation,
      owner,
      call.view.collections,
    );
  }
}

/// A patched field and the option ids the patch removes.
typedef FieldPatch = ({FieldDefinition field, Set<String> removedOptions});

/// The option-id lock: every option of [before] keeps its id in [after],
/// unless it is in [removed]. `validateCollectionSchema` cannot tell a
/// changed id from a removed and added option, so the harness checks it.
void checkOptionIds(
  FieldDefinition before,
  FieldDefinition after,
  Set<String> removed, {
  required String path,
  required InputErrors errors,
}) {
  List<SelectOption> of(FieldDefinition f) => switch (f) {
    SingleSelectFieldDefinition(:final options) ||
    MultiSelectFieldDefinition(:final options) => options,
    _ => const [],
  };
  final kept = {for (final o in of(after)) o.id};
  for (final o in of(before)) {
    if (removed.contains(o.id) || kept.contains(o.id)) continue;
    errors.add(
      ErrorDetail(
        path: path,
        code: ErrorCode.typeLocked,
        message:
            'The option "${o.label}" of "${before.name}" would change its id; '
            'option ids are locked. Rename it with renameOptions or remove it '
            'with removeOptions.',
      ),
    );
  }
}

/// Every blocking issue of [validation] as an error detail (`type_locked`
/// for locked shapes, `invalid_args` otherwise), prefixed with [path].
void addSchemaIssues(
  SchemaValidation validation,
  Collection draft,
  InputErrors errors, {
  required String path,
}) {
  for (final issue in validation.blocking) {
    final field = issue.fieldId == null
        ? null
        : draft.fieldById(issue.fieldId!);
    errors.add(
      ErrorDetail(
        path: field == null ? path : '$path.${field.name}',
        code: issue.code == SchemaIssueCode.typeLocked
            ? ErrorCode.typeLocked
            : ErrorCode.invalidArgs,
        message: issue.code == SchemaIssueCode.typeLocked
            ? '${issue.message}. $kTypeLockedHint'
            : issue.message,
      ),
    );
  }
}

/// The type tag a plan row shows for [field] of [owner]: `Text · title`,
/// `Select · Kyiv, Lviv, Odesa`, `Link → Fabrics, many`.
String typeTag(PlanCall call, FieldDefinition field, Collection owner) {
  String options(List<SelectOption> options) {
    final shown = options.take(3).map((o) => o.label).join(', ');
    return options.length > 3 ? '$shown +${options.length - 3}' : shown;
  }

  final title = owner.fields.whereType<TextFieldDefinition>().firstOrNull;
  final tag = switch (field) {
    TextFieldDefinition() when field.id == title?.id => 'Text · title',
    TextFieldDefinition(:final multiline) => multiline ? 'Long text' : 'Text',
    NumberFieldDefinition(:final unitLabel?) when unitLabel.isNotEmpty =>
      'Number · $unitLabel',
    NumberFieldDefinition() => 'Number',
    BooleanFieldDefinition() => 'Yes / No',
    DateFieldDefinition(:final includeTime) =>
      includeTime ? 'Date & time' : 'Date',
    SingleSelectFieldDefinition(options: final o) =>
      o.isEmpty ? 'Select' : 'Select · ${options(o)}',
    MultiSelectFieldDefinition(options: final o) =>
      o.isEmpty ? 'Multi-select' : 'Multi-select · ${options(o)}',
    ReferenceFieldDefinition(:final targetCollectionId, :final multiple) =>
      'Link → ${call.view.collection(targetCollectionId)?.name ?? 'a collection'}'
          '${multiple ? ', many' : ''}',
    FileFieldDefinition(:final multiple) => multiple ? 'Files' : 'File',
    AutoNumberFieldDefinition() => 'Auto-number',
    CalculatedFieldDefinition(:final expression?) when !field.isAggregate =>
      'Formula · ${formulaToDisplay(expression, owner.fields)}',
    CalculatedFieldDefinition(:final aggregate?) =>
      '${aggregate.op.label} of '
          '${call.view.collection(aggregate.collectionId)?.name ?? 'cards'}',
    CalculatedFieldDefinition(isLookup: true) => 'Lookup',
    _ => field.type,
  };
  return PlanCall.shaper.label(tag);
}
