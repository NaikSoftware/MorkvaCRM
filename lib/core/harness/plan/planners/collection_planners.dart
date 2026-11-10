import '../../../domain/domain.dart';
import '../../api/envelope.dart';
import '../../input/input_errors.dart';
import '../plan.dart';
import '../plan_store.dart';
import 'card_create_planner.dart';
import 'field_builder.dart';
import 'plan_call.dart';

/// The most collections one `collections.create` makes.
const int kMaxNewCollections = 5;

/// The most fields one new collection (or one `fields.add`) takes.
const int kMaxNewFields = 40;

/// `collections.create {collections: [{ref, name, description?, icon?,
/// fields}], cards?}`: a `createCollection` per collection, an `addField`
/// per field (depending on it) and a `createCard` per seed card.
///
/// Ids are minted here (`c_`, `f_`, `o_`, `v_`, `b_`), so `@x` refs never
/// reach stored data: a ref is a key of the turn's alias map, not a string
/// rewritten inside the schema. A collection without a text field gets a
/// `Name` field first (the app's recipe), then `CardLayout.synthesize` and
/// `ViewDefinition.defaultFor`.
Future<void> planCollectionsCreate(
  Map<String, Object?> args,
  PlanCall call,
) async {
  final raw = listArg<Object?>(args['collections'], 'collections');
  final errors = InputErrors();
  final made = <({String id, String? ref, Map<String, Object?> spec})>[];
  for (final (i, r) in raw.indexed) {
    final spec = mapArg(r, 'collections[$i]');
    final id = call.ids.collectionId();
    final ref = (spec['ref'] as String?)?.trim();
    if (ref != null) {
      if (!ref.startsWith('@') || ref.length < 2) {
        errors.add(
          ErrorDetail(
            path: 'collections[$i].ref',
            code: ErrorCode.invalidArgs,
            message: 'A collection ref starts with "@" (e.g. "@suppliers").',
          ),
        );
        continue;
      }
      if (call.view.collectionAlias(ref) != null) {
        errors.add(
          ErrorDetail(
            path: 'collections[$i].ref',
            code: ErrorCode.invalidArgs,
            message: 'The ref "$ref" is already used in this turn.',
          ),
        );
        continue;
      }
      call.changes.collectionAliases[ref] = id;
    }
    final name = (spec['name']! as String).trim();
    final description = (spec['description'] as String?)?.trim();
    call.changes.putDraft(
      Collection(
        id: id,
        name: name,
        description: description == null || description.isEmpty
            ? null
            : description,
        icon: spec['icon'] as String?,
      ),
      isNew: true,
    );
    made.add((id: id, ref: ref, spec: spec));
  }
  errors.throwIfAny();

  // Plain fields first, so formulas, lookups and aggregates (of any new
  // collection) can name them.
  final builder = FieldBuilder(call, errors);
  final calculated = <(String, int, Map<String, Object?>, String)>[];
  for (final (i, m) in made.indexed) {
    final fields = <FieldDefinition>[];
    final specs = listArg<Object?>(m.spec['fields'], 'collections[$i].fields');
    for (final (j, f) in specs.indexed) {
      final path = 'collections[$i].fields[$j]';
      final spec = mapArg(f, path);
      final field = builder.plain(spec, path: path);
      if (field == null) continue;
      if (field is CalculatedFieldDefinition) {
        calculated.add((m.id, fields.length, spec, path));
      }
      fields.add(field);
    }
    if (!fields.any((f) => f is TextFieldDefinition)) {
      fields.insert(
        0,
        TextFieldDefinition(id: call.ids.fieldId(), name: 'Name'),
      );
      for (var k = 0; k < calculated.length; k++) {
        final (cid, at, spec, path) = calculated[k];
        if (cid == m.id) calculated[k] = (cid, at + 1, spec, path);
      }
    }
    call.changes.putDraft(
      call.changes.drafts[m.id]!.copyWith(fields: fields),
      isNew: true,
    );
  }
  errors.throwIfAny(hint: 'Fix every listed field and send the call again.');
  for (final (cid, at, spec, path) in calculated) {
    final draft = call.changes.drafts[cid]!;
    final field = builder.calculated(
      spec,
      draft.fields[at] as CalculatedFieldDefinition,
      call.schemaOf(cid),
      path: path,
    );
    if (field == null) continue;
    call.changes.putDraft(
      draft.copyWith(fields: [...draft.fields]..[at] = field),
      isNew: true,
    );
  }
  errors.throwIfAny(hint: 'Fix every listed field and send the call again.');

  final ids = {for (final c in call.view.collections) c.id};
  for (final (i, m) in made.indexed) {
    final fields = call.changes.drafts[m.id]!.fields;
    final draft = call.changes.drafts[m.id]!.copyWith(
      layout: CardLayout.synthesize([for (final f in fields) f.id]),
      views: [ViewDefinition.defaultFor(fields)],
    );
    call.changes.putDraft(draft, isNew: true);
    addSchemaIssues(
      validateCollectionSchema(draft, collectionIds: ids, strict: true),
      draft,
      errors,
      path: 'collections[$i]',
    );
    checkCycles(
      draft,
      fields.map((f) => f.id),
      errors,
      path: 'collections[$i]',
    );
  }
  errors.throwIfAny(hint: 'Fix every listed field and send the call again.');

  // Minted up front (in item order) so a field can depend on a collection
  // or field this call adds later.
  final itemIds = <Object, String>{};
  for (final m in made) {
    itemIds[m.id] = call.nextItemId();
    for (final f in call.changes.drafts[m.id]!.fields) {
      itemIds[(m.id, f.id)] = call.nextItemId();
    }
  }
  for (final m in made) {
    final draft = call.changes.drafts[m.id]!;
    call.add(
      CreateCollectionItem(
        itemId: itemIds[m.id]!,
        callId: call.callId,
        label: call.name(draft.name),
        risk: Risk.low,
        collection: draft,
        ref: m.ref,
        detail:
            'Collection · ${draft.fields.length} '
            'field${draft.fields.length == 1 ? '' : 's'}',
      ),
    );
    for (final (k, f) in draft.fields.indexed) {
      call.add(
        AddFieldItem(
          itemId: itemIds[(draft.id, f.id)]!,
          callId: call.callId,
          collectionId: draft.id,
          label: call.name(f.name),
          risk: Risk.low,
          field: f,
          index: k,
          newCollection: true,
          detail: typeTag(call, f, draft),
          dependsOn: call.fieldDependencies(draft, f, reserved: itemIds),
        ),
      );
    }
  }

  final cards = <String, List<CardSpec>>{};
  for (final (i, r) in listArg<Object?>(args['cards'], 'cards').indexed) {
    final card = mapArg(r, 'cards[$i]');
    final c = call.collection(
      card['collection']! as String,
      path: 'cards[$i].collection',
    );
    if (!call.changes.newCollections.contains(c.id)) {
      throw invalidArgs(
        'Seed cards go into the collections this call creates; use '
        'cards.create for ${c.name}.',
        path: 'cards[$i].collection',
      );
    }
    (cards[c.id] ??= []).add((
      ref: card['ref'] as String?,
      values: mapArg(card['values'] ?? const {}, 'cards[$i].values'),
      path: 'cards[$i]',
    ));
  }
  var seeded = 0;
  if (cards.isNotEmpty) {
    await call.leased([for (final m in made) m.id], () async {
      seeded = stageCreates(call, cards).length;
    });
  }

  final first = call.changes.drafts[made.first.id]!;
  final head = made.length == 1
      ? 'Create ${call.quoted(first.name)} · ${first.fields.length} '
            'field${first.fields.length == 1 ? '' : 's'}'
      : 'Create ${made.length} collections';
  call.title(
    seeded == 0 ? head : '$head · $seeded card${seeded == 1 ? '' : 's'}',
  );
}

/// `collections.update {collection, name?, description?, icon?}`: one
/// `updateCollection` with the keys that change.
Future<void> planCollectionsUpdate(
  Map<String, Object?> args,
  PlanCall call,
) async {
  final before = call.schemaOf(
    call.collection(args['collection']! as String).id,
  );
  final keys = <String, ({Object? before, Object? after})>{};
  final changes = <FieldChange>[];
  void key(String key, String label, Object? from, Object? to) {
    if (from == to) return;
    keys[key] = (before: from, after: to);
    changes.add(
      FieldChange(
        field: label,
        before: from,
        after: to,
        beforeText: from == null ? null : call.name('$from'),
        afterText: to == null ? null : call.name('$to'),
      ),
    );
  }

  var draft = before;
  if (args['name'] case final String raw) {
    final name = raw.trim();
    if (name.isEmpty) {
      throw invalidArgs('A collection needs a name.', path: 'name');
    }
    key('name', 'Name', before.name, name);
    draft = draft.copyWith(name: name);
  }
  if (args.containsKey('description')) {
    final d = (args['description'] as String?)?.trim();
    final description = d == null || d.isEmpty ? null : d;
    key('description', 'Description', before.description, description);
    draft = draft.copyWith(description: description);
  }
  if (args['icon'] case final String icon) {
    key('icon', 'Icon', before.icon, icon);
    draft = draft.copyWith(icon: icon);
  }
  if (keys.isEmpty) return;
  call.changes.putDraft(draft);
  call.add(
    UpdateCollectionItem(
      itemId: call.nextItemId(),
      callId: call.callId,
      collectionId: before.id,
      label: call.name(before.name),
      risk: Risk.low,
      changes: changes,
      keys: keys,
      dependsOn: call.dependencies(before.id),
    ),
  );
  call.title(
    keys.containsKey('name')
        ? 'Rename ${call.quoted(before.name)} to ${call.quoted(draft.name)}'
        : 'Update collection ${call.quoted(before.name)}',
  );
}

/// `collections.delete {collection}`: one `deleteCollection` with its card
/// count, warnings for every collection that links to it or calculates
/// from it, and no undo above [kMaxUndoableCards] cards. Always its own
/// plan.
Future<void> planCollectionsDelete(
  Map<String, Object?> args,
  PlanCall call,
) async {
  final collection = call.collection(args['collection']! as String);
  if (call.view.isNew(collection.id)) {
    throw invalidArgs(
      '${collection.name} is created in this turn; leave it out of '
      'collections.create instead.',
      path: 'collection',
    );
  }
  await call.leased([collection.id], () async {
    final schema = call.schemaOf(collection.id);
    final count = call.view.objectsOf(schema.id).length;
    for (final other in call.view.collections) {
      if (other.id == schema.id) continue;
      final links = [
        for (final f in other.fields)
          if (f is ReferenceFieldDefinition &&
              f.targetCollectionId == schema.id)
            f.name,
      ];
      final calcs = [
        for (final f in other.fields.whereType<CalculatedFieldDefinition>())
          if (f.aggregate?.collectionId == schema.id) f.name,
      ];
      if (links.isNotEmpty) {
        call.warn(
          'breaks_references',
          '${call.quoted(other.name)} links here (${links.map(call.name).join(', ')}); '
              'those links will show as missing.',
        );
      }
      if (calcs.isNotEmpty) {
        call.warn(
          'breaks_calculations',
          '${call.quoted(other.name)} calculates from it '
              '(${calcs.map(call.name).join(', ')}); those values will be blank.',
        );
      }
    }
    if (count > kMaxUndoableCards) {
      call.note(
        '${schema.name} has more than $kMaxUndoableCards cards, so this '
        'delete cannot be undone.',
      );
    }
    call.add(
      DeleteCollectionItem(
        itemId: call.nextItemId(),
        callId: call.callId,
        label: call.name(schema.name),
        risk: Risk.high,
        before: schema,
        cardCount: count,
        detail: '$count card${count == 1 ? '' : 's'}',
      ),
    );
    call.changes.deletesCollection = true;
    call.title(
      'Delete collection ${call.quoted(schema.name)} · '
      '$count card${count == 1 ? '' : 's'}',
    );
  });
}

/// A `formula_cycle` for every formula field of [draft] among [fieldIds]
/// that reads itself through other formulas.
void checkCycles(
  Collection draft,
  Iterable<String> fieldIds,
  InputErrors errors, {
  required String path,
}) {
  for (final id in fieldIds) {
    final cycle = formulaCycle(draft, id);
    if (cycle == null) continue;
    errors.add(
      ErrorDetail(
        path: '$path.${draft.fieldById(id)!.name}',
        code: ErrorCode.formulaCycle,
        message: 'The formulas loop: ${cycle.join(' → ')}.',
      ),
    );
  }
}
