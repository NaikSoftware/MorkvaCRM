import '../../../domain/domain.dart';
import '../../input/input_errors.dart';
import '../plan.dart';
import 'collection_planners.dart';
import 'field_builder.dart';
import 'plan_call.dart';
import 'targets.dart';

/// The most fields one `fields.add` adds.
const int kMaxAddFields = 20;

/// The most fields one `fields.delete` removes.
const int kMaxDeleteFields = 10;

/// `fields.add {collection, fields: [FieldSpec], after?}`: one `addField` per
/// field, placed after [after] (else at the end), with the editor's recipe:
/// new fields appended to every view (`withNewFieldsInViews`) and the
/// layout reconciled. Each item records the views and layout it changes.
Future<void> planFieldsAdd(Map<String, Object?> args, PlanCall call) async {
  final collection = call.collection(args['collection']! as String);
  await call.leased([collection.id], () async {
    final before = call.schemaOf(collection.id);
    final errors = InputErrors();
    final builder = FieldBuilder(call, errors);
    final specs = listArg<Object?>(args['fields'], 'fields');
    final added = <FieldDefinition>[];
    final calculated = <(int, Map<String, Object?>, String)>[];
    for (final (i, raw) in specs.indexed) {
      final path = 'fields[$i]';
      final spec = mapArg(raw, path);
      final field = builder.plain(spec, path: path);
      if (field == null) continue;
      if (field is CalculatedFieldDefinition) {
        calculated.add((added.length, spec, path));
      }
      added.add(field);
    }
    errors.throwIfAny(hint: 'Fix every listed field and send the call again.');

    var index = before.fields.length;
    if (args['after'] case final String ref) {
      final after = call.resolver().field(before, ref, path: 'after');
      index = before.fields.indexOf(after) + 1;
    }
    List<FieldDefinition> place(List<FieldDefinition> fields) => [
      ...before.fields.take(index),
      ...fields,
      ...before.fields.skip(index),
    ];
    call.changes.putDraft(before.copyWith(fields: place(added)));
    for (final (at, spec, path) in calculated) {
      final field = builder.calculated(
        spec,
        added[at] as CalculatedFieldDefinition,
        call.schemaOf(before.id),
        path: path,
      );
      if (field == null) continue;
      added[at] = field;
      call.changes.putDraft(before.copyWith(fields: place(added)));
    }
    errors.throwIfAny(hint: 'Fix every listed field and send the call again.');

    final fields = place(added);
    final draft = before
        .copyWith(
          fields: fields,
          layout: before.layout.reconcile([for (final f in fields) f.id]),
        )
        .withNewFieldsInViews(before);
    addSchemaIssues(
      validateCollectionSchema(
        draft,
        saved: before,
        collectionIds: {for (final c in call.view.collections) c.id},
        strict: true,
      ),
      draft,
      errors,
      path: 'fields',
    );
    checkCycles(draft, [for (final f in added) f.id], errors, path: 'fields');
    errors.throwIfAny(hint: 'Fix every listed field and send the call again.');
    call.changes.putDraft(draft);

    final count = call.view.objectsOf(before.id).length;
    // Minted up front so a field can depend on one listed after it.
    final itemIds = {
      for (final f in added) (before.id, f.id): call.nextItemId(),
    };
    for (final f in added) {
      // Each item records only its own field's effect, so undoing one add
      // leaves the others' view and layout entries alone.
      final solo = before
          .copyWith(
            fields: [...before.fields, f],
            layout: before.layout.reconcile([
              for (final x in before.fields) x.id,
              f.id,
            ]),
          )
          .withNewFieldsInViews(before);
      call.add(
        AddFieldItem(
          itemId: itemIds[(before.id, f.id)]!,
          callId: call.callId,
          collectionId: before.id,
          label: call.name(f.name),
          risk: Risk.low,
          field: f,
          index: fields.indexOf(f),
          views: viewEntries(before.views, solo.views),
          layoutBefore: before.layout,
          layoutAfter: solo.layout,
          detail: typeTag(call, f, draft),
          dependsOn: call.fieldDependencies(draft, f, reserved: itemIds),
        ),
      );
      if (f.isRequired && count > 0) {
        call.warn(
          'required_empty',
          '${call.cards(before, count)} have no ${call.name(f.name)}; they '
              'stay as they are but will fail validation when edited.',
        );
      }
    }
    call.title(
      added.length == 1
          ? 'Add field ${call.quoted(added.single.name)} to '
                '${call.name(before.name)}'
          : 'Add ${added.length} fields to ${call.name(before.name)}',
    );
  });
}

/// `fields.update {collection, field, patch}`: one `updateField` (type,
/// target and option ids locked). `removeOptions` also plans an
/// `updateCard` per card using a removed option (cleared, or taken out of
/// its list) and takes the option out of view filters; `required: true`
/// warns how many cards are empty.
Future<void> planFieldsUpdate(Map<String, Object?> args, PlanCall call) async {
  final collection = call.collection(args['collection']! as String);
  await call.leased([collection.id], () async {
    final before = call.schemaOf(collection.id);
    final field = call.resolver().field(
      before,
      args['field']! as String,
      path: 'field',
    );
    final errors = InputErrors();
    final patched = FieldBuilder(
      call,
      errors,
    ).patch(before, field, mapArg(args['patch'], 'patch'));
    errors.throwIfAny(hint: 'Fix the patch and send the call again.');
    final after = patched!.field;
    final removed = patched.removedOptions;

    final views = [
      for (final v in before.views)
        removed.isEmpty
            ? v
            : v.copyWith(
                filters: [
                  for (final f in v.filters)
                    if (f.fieldId != field.id || f.operand is! List)
                      f
                    else if (_without(f.operand! as List, removed)
                        case final left when left.isNotEmpty)
                      f.copyWith(operand: left),
                ],
              ),
    ];
    final draft = before.copyWith(
      fields: [for (final f in before.fields) f.id == field.id ? after : f],
      views: views,
    );
    addSchemaIssues(
      validateCollectionSchema(
        draft,
        saved: before,
        collectionIds: {for (final c in call.view.collections) c.id},
        strict: true,
      ),
      draft,
      errors,
      path: 'patch',
    );
    if (after is CalculatedFieldDefinition) {
      checkCycles(draft, [after.id], errors, path: 'patch');
    }
    errors.throwIfAny(hint: 'Fix the patch and send the call again.');
    final changes = _fieldChanges(call, field, after, removed);
    if (changes.isEmpty) return;
    call.changes.putDraft(draft);

    final fieldItem = call.nextItemId();
    call.add(
      UpdateFieldItem(
        itemId: fieldItem,
        callId: call.callId,
        collectionId: before.id,
        label: call.name(field.name),
        risk: Risk.medium,
        before: field,
        after: after,
        views: viewEntries(before.views, views),
        changes: changes,
        detail: typeTag(call, after, draft),
        dependsOn: {
          ...call.dependencies(before.id, fieldIds: [field.id]),
          ...call.fieldDependencies(draft, after),
        }.toList(),
      ),
    );

    final cards = call.view.objectsOf(before.id);
    if (removed.isNotEmpty) {
      _clearRemoved(call, before, field, after, removed, fieldItem);
    }
    if (after.isRequired && !field.isRequired) {
      final empty = cards.where((o) => (o[field.id]?.isEmpty ?? true)).length;
      if (empty > 0) {
        call.warn(
          'required_empty',
          '${call.cards(before, empty)} have no ${call.name(field.name)}; '
              'they stay as they are but will fail validation when edited.',
        );
      }
    }
    call.title(
      'Change field ${call.quoted(field.name)} in ${call.name(before.name)}',
    );
  });
}

/// Plans the companion `updateCard`s of a `removeOptions`: every card using
/// a removed option loses it, so no card shows an unknown option.
void _clearRemoved(
  PlanCall call,
  Collection schema,
  FieldDefinition field,
  FieldDefinition after,
  Set<String> removed,
  String fieldItem,
) {
  final earlier = {
    for (final item in call.view.items.whereType<UpdateCardItem>())
      for (final c in item.changes) (item.cardId, c.fieldId),
  };
  final using = <(MorkvaObject, FieldValue, FieldValue)>[];
  for (final o in call.view.objectsOf(schema.id)) {
    final value = o[field.id] ?? field.emptyValue();
    final cleared = switch (value) {
      SingleSelectFieldValue(:final optionId?)
          when removed.contains(optionId) =>
        const SingleSelectFieldValue(null),
      MultiSelectFieldValue(:final optionIds)
          when optionIds.any(removed.contains) =>
        MultiSelectFieldValue(_without(optionIds, removed)),
      _ => null,
    };
    if (cleared == null) continue;
    if (call.view.isCreated(schema.id, o.id)) {
      throw invalidArgs(
        '${call.cardLabel(schema, o)} is created in this turn with a removed '
        'option; create the card without that option, or remove the option '
        'in a later turn.',
        path: 'patch.removeOptions',
      );
    }
    if (earlier.contains((o.id, field.id))) {
      throw invalidArgs(
        '${call.cardLabel(schema, o)}: ${field.name} is already changed by '
        'another call in this turn; remove the option in a later turn.',
        path: 'patch.removeOptions',
      );
    }
    using.add((o, value, cleared));
  }
  if (using.isEmpty) return;
  final risk = using.length > kUnguardedUpdateCards ? Risk.medium : Risk.low;
  for (final (o, value, cleared) in using) {
    call.add(
      UpdateCardItem(
        itemId: call.nextItemId(),
        callId: call.callId,
        collectionId: schema.id,
        targetId: o.id,
        label: call.cardLabel(schema, o),
        risk: risk,
        changes: [
          FieldChange(
            fieldId: field.id,
            field: call.name(after.name),
            before: value.toJson(),
            after: cleared.toJson(),
            beforeText: call.valueText(field, value),
            afterText: call.valueText(after, cleared),
          ),
        ],
        dependsOn: [fieldItem],
      ),
    );
    call.changes.putUpdated(
      o.copyWith(values: {...o.values, field.id: cleared}),
    );
  }
  call.warn(
    'options_in_use',
    '${call.cards(schema, using.length)} use the removed '
        'option${removed.length == 1 ? '' : 's'}; it is cleared from them.',
  );
}

List<String> _without(List<Object?> ids, Set<String> removed) => [
  for (final id in ids)
    if (id is String && !removed.contains(id)) id,
];

/// What a field patch changes, as display rows: name, description,
/// required, options (added, renamed, removed) and other settings.
List<FieldChange> _fieldChanges(
  PlanCall call,
  FieldDefinition before,
  FieldDefinition after,
  Set<String> removed,
) {
  final out = <FieldChange>[];
  void text(String label, Object? from, Object? to) {
    if (jsonEquals(from, to)) return;
    out.add(
      FieldChange(
        field: label,
        before: from,
        after: to,
        beforeText: _show(call, from),
        afterText: _show(call, to),
      ),
    );
  }

  text('Name', before.name, after.name);
  text('Description', before.description, after.description);
  text('Required', before.isRequired, after.isRequired);
  final was = _options(before);
  final now = _options(after);
  for (final o in was) {
    final next = now.where((n) => n.id == o.id).firstOrNull;
    if (next == null) {
      out.add(
        FieldChange(
          field: 'Options',
          before: o.toJson(),
          beforeText: call.name(o.label),
        ),
      );
    } else if (next != o) {
      out.add(
        FieldChange(
          field: 'Options',
          before: o.toJson(),
          after: next.toJson(),
          beforeText: call.name(o.label),
          afterText: call.name(next.label),
        ),
      );
    }
  }
  for (final o in now) {
    if (was.any((w) => w.id == o.id)) continue;
    out.add(
      FieldChange(
        field: 'Options',
        after: o.toJson(),
        afterText: call.name(o.label),
      ),
    );
  }
  final a = before.configToJson();
  final b = after.configToJson();
  for (final key in {...a.keys, ...b.keys}) {
    if (key == 'options') continue;
    text(_settingLabel(key), a[key], b[key]);
  }
  return out;
}

List<SelectOption> _options(FieldDefinition f) => switch (f) {
  SingleSelectFieldDefinition(:final options) ||
  MultiSelectFieldDefinition(:final options) => options,
  _ => const [],
};

String? _show(PlanCall call, Object? value) => switch (value) {
  null => null,
  true => 'Yes',
  false => 'No',
  final Map m => call.name('${m['label'] ?? m}'),
  _ => call.name('$value'),
};

/// `decimalPlaces` → `Decimal places`.
String _settingLabel(String key) {
  final words = key
      .replaceAllMapped(RegExp('([A-Z])'), (m) => ' ${m[1]!.toLowerCase()}')
      .trim();
  return words[0].toUpperCase() + words.substring(1);
}

/// `fields.delete {collection, fields}`: one `deleteField` per field with
/// the view and layout entries it changes (filters, sort, shown fields and
/// the layout field go with it), and warnings for the formulas, lookups,
/// aggregates and views that read it. Stored card values are left in place.
Future<void> planFieldsDelete(Map<String, Object?> args, PlanCall call) async {
  final collection = call.collection(args['collection']! as String);
  final before = call.schemaOf(collection.id);
  final refs = call.resolver();
  final fields = <FieldDefinition>[];
  for (final (i, ref) in listArg<String>(args['fields'], 'fields').indexed) {
    final f = refs.field(before, ref, path: 'fields[$i]');
    if (fields.contains(f)) continue;
    if (call.view.items.any(
      (it) => it is AddFieldItem && it.field.id == f.id,
    )) {
      throw invalidArgs(
        '"${f.name}" is added in this turn; leave it out of fields.add '
        'instead.',
        path: 'fields[$i]',
      );
    }
    fields.add(f);
  }
  final gone = {for (final f in fields) f.id};
  final remaining = [
    for (final f in before.fields)
      if (!gone.contains(f.id)) f.id,
  ];
  call.changes.putDraft(
    before.copyWith(
      fields: [
        for (final f in before.fields)
          if (!gone.contains(f.id)) f,
      ],
      views: [for (final v in before.views) v.reconcile(remaining)],
      layout: before.layout.reconcile(remaining),
    ),
  );

  for (final f in fields) {
    final keep = [
      for (final x in before.fields)
        if (x.id != f.id) x.id,
    ];
    final views = [for (final v in before.views) v.reconcile(keep)];
    call.add(
      DeleteFieldItem(
        itemId: call.nextItemId(),
        callId: call.callId,
        collectionId: before.id,
        label: call.name(f.name),
        risk: Risk.high,
        before: f,
        index: before.fields.indexOf(f),
        views: viewEntries(before.views, views),
        layoutBefore: before.layout,
        layoutAfter: before.layout.reconcile(keep),
        detail: typeTag(call, f, before),
        dependsOn: call.dependencies(before.id),
      ),
    );
    _dependents(call, before, f);
  }
  call.title(
    fields.length == 1
        ? 'Delete field ${call.quoted(fields.single.name)} from '
              '${call.name(before.name)}'
        : 'Delete ${fields.length} fields from ${call.name(before.name)}',
  );
}

/// Warns about everything that reads [field] of [owner]: formulas,
/// lookups and aggregates (in any collection) and views laid out by it.
void _dependents(PlanCall call, Collection owner, FieldDefinition field) {
  final readers = <String>[];
  // The owner as it was: the pending draft no longer has the field.
  for (final c in owner.withWorkspace(call.view.collections)) {
    for (final f in c.fields.whereType<CalculatedFieldDefinition>()) {
      if (f.id == field.id) continue;
      final reads = switch (f) {
        CalculatedFieldDefinition(:final lookup?) =>
          (c.id == owner.id && lookup.referenceFieldId == field.id) ||
              (lookup.fieldId == field.id &&
                  switch (c.fieldById(lookup.referenceFieldId)) {
                    ReferenceFieldDefinition(:final targetCollectionId) =>
                      targetCollectionId == owner.id,
                    _ => false,
                  }),
        CalculatedFieldDefinition(:final aggregate?) =>
          (c.id == owner.id && aggregate.referenceFieldId == field.id) ||
              (aggregate.collectionId == owner.id &&
                  (aggregate.fieldId == field.id ||
                      aggregate.referenceFieldId == field.id ||
                      aggregate.filters.any((x) => x.fieldId == field.id))),
        CalculatedFieldDefinition(:final expression?) =>
          c.id == owner.id &&
              formulaFieldIds(expression, c.fields).contains(field.id),
        _ => false,
      };
      if (reads) {
        readers.add(
          c.id == owner.id
              ? call.name(f.name)
              : '${call.name(c.name)} › ${call.name(f.name)}',
        );
      }
    }
  }
  if (readers.isNotEmpty) {
    call.warn(
      'breaks_calculations',
      '${readers.join(', ')} read${readers.length == 1 ? 's' : ''} '
          '${call.quoted(field.name)} and will show blanks.',
    );
  }
  for (final v in owner.views) {
    if (v.layoutFieldId != field.id) continue;
    call.warn(
      'breaks_views',
      'View ${call.quoted(v.name)} is laid out by ${call.quoted(field.name)} '
          'and will need another field.',
    );
  }
}
