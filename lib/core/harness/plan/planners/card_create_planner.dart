import '../../../domain/domain.dart';
import '../../api/envelope.dart';
import '../../input/input_errors.dart';
import '../../input/value_codec.dart';
import '../../query/result_shaper.dart';
import '../plan.dart';
import 'plan_call.dart';

/// The most cards one `cards.create` (or `collections.create`'s seed
/// cards) may add.
const int kMaxCreateCards = 200;

/// One card to create: where it came from in the args.
typedef CardSpec = ({String? ref, Map<String, Object?> values, String path});

/// `cards.create {collection, cards: [{ref?, values}]}`: one `createCard`
/// per card. Auto-numbers are assigned on save; `@ref`s let later calls of
/// the turn (and other cards of this call) link to the new cards.
Future<void> planCardsCreate(Map<String, Object?> args, PlanCall call) async {
  final collection = call.collection(args['collection']! as String);
  final specs = [
    for (final (i, raw) in listArg<Object?>(args['cards'], 'cards').indexed)
      () {
        final card = mapArg(raw, 'cards[$i]');
        return (
          ref: card['ref'] as String?,
          values: mapArg(card['values'] ?? const {}, 'cards[$i].values'),
          path: 'cards[$i]',
        );
      }(),
  ];
  await call.leased([collection.id], () async {
    final created = stageCreates(call, {collection.id: specs});
    call.title('Add ${call.cards(collection, created.length)}');
  });
}

/// Mints, decodes and validates new cards per collection id, adds them to
/// the call's pending changes and items, and returns them. Every card's id
/// and `@ref` is known before any value is decoded, so cards of one call
/// can link to each other. All problems are thrown together.
List<MorkvaObject> stageCreates(
  PlanCall call,
  Map<String, List<CardSpec>> byCollection,
) {
  final total = byCollection.values.fold(0, (n, l) => n + l.length);
  if (total > kMaxCreateCards) {
    throw invalidArgs(
      'At most $kMaxCreateCards cards per call; this one has $total.',
      path: 'cards',
    );
  }
  final now = call.ctx.now;
  final errors = InputErrors();
  final minted = <(String, CardSpec, String)>[];
  for (final MapEntry(key: cid, value: specs) in byCollection.entries) {
    final schema = call.schemaOf(cid);
    for (final spec in specs) {
      final id = call.ids.objectId();
      final ref = spec.ref?.trim();
      if (ref != null) {
        if (!ref.startsWith('@') || ref.length < 2) {
          errors.add(_bad('A card ref starts with "@" (e.g. "@c1").', spec));
          continue;
        }
        if (call.view.cardAliases.containsKey(ref)) {
          errors.add(
            _bad('The ref "$ref" is already used in this turn.', spec),
          );
          continue;
        }
        call.changes.cardAliases[ref] = id;
      }
      call.changes.putCreated(
        MorkvaObject.create(
          id: id,
          collection: schema,
          createdAt: now,
          updatedAt: now,
        ),
      );
      minted.add((cid, spec, id));
    }
  }
  errors.throwIfAny();

  final codec = call.codec();
  final out = <MorkvaObject>[];
  for (final (cid, spec, id) in minted) {
    final schema = call.schemaOf(cid);
    final values = codec.decodeValues(
      schema,
      spec.values,
      path: '${spec.path}.values',
      errors: errors,
    );
    final object = MorkvaObject.create(
      id: id,
      collection: schema,
      values: values,
      createdAt: now,
      updatedAt: now,
    );
    final writable = {
      for (final f in schema.fields)
        if (f is! AutoNumberFieldDefinition && f is! CalculatedFieldDefinition)
          f.id,
    };
    validationDetails(
      schema,
      object,
      path: '${spec.path}.values',
      onlyFieldIds: writable,
    ).forEach(errors.add);
    call.changes.replaceCreated(object);
    out.add(object);
  }
  errors.throwIfAny(hint: 'Fix every listed card and send the call again.');

  for (final (i, object) in out.indexed) {
    final schema = call.schemaOf(object.collectionId);
    final set = [
      for (final f in schema.fields)
        if (object[f.id] case final v? when v.isNotEmpty) (f, v),
    ];
    call.add(
      CreateCardItem(
        itemId: call.nextItemId(),
        callId: call.callId,
        collectionId: schema.id,
        label: _label(call, schema, object),
        risk: Risk.low,
        object: object,
        ref: minted[i].$2.ref?.trim(),
        detail: schema.fields.any((f) => f is AutoNumberFieldDefinition)
            ? 'Number assigned on save'
            : null,
        changes: [
          for (final (f, v) in set)
            FieldChange(
              fieldId: f.id,
              field: call.name(f.name),
              after: v.toJson(),
              afterText: call.valueText(f, v),
            ),
        ],
        // Not on new fields: an unticked field only drops its value.
        dependsOn: call.dependencies(
          schema.id,
          cardIds: [for (final (f, v) in set) ...call.linkedCards(f, v)],
        ),
      ),
    );
  }
  return out;
}

String _label(PlanCall call, Collection schema, MorkvaObject object) {
  final title = cardTitle(schema, object);
  return title == 'Untitled'
      ? 'New ${call.cards(schema, 1).substring(2)}'
      : call.cardLabel(schema, object);
}

ErrorDetail _bad(String message, CardSpec spec) => ErrorDetail(
  path: '${spec.path}.ref',
  code: ErrorCode.invalidArgs,
  message: message,
);
