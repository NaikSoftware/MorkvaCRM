import '../../../domain/domain.dart';
import '../../input/value_codec.dart';
import '../plan.dart';
import 'plan_call.dart';
import 'targets.dart';

/// `cards.delete {collection, target, expectedCount?}`: one `deleteCard` per
/// card with its before-image, so undo re-creates it with the same id and
/// auto-number. A `where` or screen target needs `expectedCount`; cards
/// other collections link to are counted in a `breaks_references` warning.
Future<void> planCardsDelete(Map<String, Object?> args, PlanCall call) async {
  final collection = call.collection(args['collection']! as String);
  final inbound = [
    for (final c in call.view.collections)
      if (call.ctx.grants.allowsCollection(c.id) &&
          c.fields.any(
            (f) =>
                f is ReferenceFieldDefinition &&
                f.targetCollectionId == collection.id,
          ))
        c.id,
  ];
  await call.leased([collection.id, ...inbound], () async {
    final schema = call.schemaOf(collection.id);
    final target = await resolveTarget(call, schema, args['target']);
    checkCap(target.ids.length, kMaxTargetCards, what: 'delete');
    checkExpectedCount(
      args['expectedCount'],
      target.ids.length,
      required: target.kind.isQuery,
      what: 'delete',
    );
    if (target.ids.isEmpty) {
      throw invalidArgs(
        'The target matches no ${schema.name} cards.',
        path: 'target',
      );
    }
    final changed = {
      for (final item in call.view.items.whereType<UpdateCardItem>())
        if (item.collectionId == schema.id) item.cardId,
    };
    for (final id in target.ids) {
      if (call.view.isCreated(schema.id, id) || changed.contains(id)) {
        throw invalidArgs(
          'Card $id is created or changed by another call in this turn; '
          'leave it out of one of them.',
          path: 'target',
        );
      }
    }

    final risk = target.ids.length > kUnguardedUpdateCards
        ? Risk.high
        : Risk.medium;
    for (final id in target.ids) {
      final card = call.view.object(schema.id, id)!;
      call.add(
        DeleteCardItem(
          itemId: call.nextItemId(),
          callId: call.callId,
          collectionId: schema.id,
          targetId: id,
          label: call.cardLabel(schema, card),
          risk: risk,
          before: card,
          detail: isoDay(card.createdAt.toLocal()),
        ),
      );
      call.changes.putDeleted(schema.id, id);
    }

    final ids = target.ids.toSet();
    for (final cid in inbound) {
      final source = call.schemaOf(cid);
      final refs = source.fields.whereType<ReferenceFieldDefinition>().where(
        (f) => f.targetCollectionId == schema.id,
      );
      final linking = call.view
          .objectsOf(cid)
          .where(
            (o) =>
                !ids.contains(o.id) &&
                refs.any(
                  (f) => switch (o[f.id]) {
                    ReferenceFieldValue(:final objectIds) => objectIds.any(
                      ids.contains,
                    ),
                    _ => false,
                  },
                ),
          );
      final n = linking.length;
      if (n > 0) {
        call.warn(
          'breaks_references',
          '${call.cards(source, n)} link to these; the links will show as '
              'missing.',
        );
      }
    }
    call.title('Delete ${call.cards(schema, target.ids.length, prep: 'from')}');
  });
}
