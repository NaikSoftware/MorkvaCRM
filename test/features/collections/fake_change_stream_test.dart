import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/api/data/data_repository.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/features/collections/list/collections_list_cubit.dart';
import 'package:morkva_crm/features/views/collection_views_cubit.dart';

import '../views/views_fixtures.dart';
import 'fake_data_repository.dart';

// The fake mirrors the real repository's `changes` (D5), and the UI callers
// tag their writes with the right origin.
void main() {
  late FakeDataRepository repo;
  late List<CardChange> changes;

  setUp(() {
    repo = FakeDataRepository([deals, companies]);
    repo.seedObjects('deals', sampleDeals());
    changes = [];
    final sub = repo.changes.listen(changes.add);
    addTearDown(sub.cancel);
  });

  MorkvaObject stored(String id) =>
      repo.objectsOf('deals').firstWhere((o) => o.id == id);

  group('the fake', () {
    test('saveObject: create, update, no-op update', () async {
      final fresh = deal('d9', 9, name: 'New');
      await repo.saveObject(fresh, schema: deals);
      final d1 = stored('d1');
      await repo.saveObject(
        d1.copyWith(values: {'amount': const NumberFieldValue(7)}),
        schema: deals,
      );
      await repo.saveObject(
        d1.copyWith(values: {'amount': const NumberFieldValue(7)}),
        schema: deals,
      );
      await pumpEventQueue();

      final [created, updated] = changes;
      expect(created.before, isNull);
      expect(created.after!.id, 'd9');
      expect(updated.before, same(d1));
      expect(updated.after!['amount'], const NumberFieldValue(7));
      expect(updated.after!['name'], d1['name']);
      expect(created.origin.commitId, isNot(updated.origin.commitId));
      expect(created.writeId, startsWith('w_'));
    });

    test('deleteObject: given before, else the stored one', () async {
      final given = stored('d1');
      final d2 = stored('d2');
      await repo.deleteObject('deals', 'd1', before: given);
      await repo.deleteObject('deals', 'd2');
      await repo.deleteObject('deals', 'missing');
      await pumpEventQueue();

      final [a, b] = changes;
      expect(repo.deleteBefores, [same(given), null, null]);
      expect(a.before, same(given));
      expect(b.before, same(d2));
      expect([a.after, b.after], [null, null]);
    });

    test('a failed write emits nothing', () async {
      repo.objectWriteError = () => Exception('offline');
      await expectLater(
        repo.saveObject(deal('d9', 9), schema: deals),
        throwsException,
      );
      await pumpEventQueue();
      expect(changes, isEmpty);
    });

    test('saveObjectsBatch: before only from the write, one commit', () async {
      final d1 = stored('d1');
      const plan = WriteOrigin(kind: WriteKind.plan, commitId: 'p1');
      await repo.saveObjectsBatch(
        [
          ObjectCreate(deal('d9', 9)),
          ObjectUpdate(
            collectionId: 'deals',
            id: 'd1',
            values: const {'amount': 9},
            before: d1,
          ),
          // No before: written, not emitted (the real repository can't).
          const ObjectUpdate(
            collectionId: 'deals',
            id: 'd2',
            values: {'amount': 9},
          ),
          const ObjectDelete(collectionId: 'deals', id: 'd3'),
          ObjectUpdate(
            collectionId: 'deals',
            id: 'd4',
            values: {'stage': stored('d4')['stage']!.toJson()},
            before: stored('d4'),
          ),
        ],
        schemas: {'deals': deals},
        origin: plan,
      );
      await pumpEventQueue();

      final [created, updated] = changes;
      expect(created.after!.id, 'd9');
      expect(updated.before, same(d1));
      expect(updated.after!['amount'], const NumberFieldValue(9));
      expect(updated.after!.updatedAt, stored('d1').updatedAt);
      expect(changes.map((c) => c.origin), everyElement(same(plan)));
    });

    test('an unacked batch emits nothing', () async {
      repo.batchNeverCompletes = true;
      unawaited(
        repo.saveObjectsBatch(
          [ObjectCreate(deal('d9', 9))],
          schemas: {'deals': deals},
        ),
      );
      await pumpEventQueue();
      expect(changes, isEmpty);
    });

    test('writes after dispose are dropped', () async {
      await repo.dispose();
      await repo.saveObject(deal('d9', 9), schema: deals);
      await repo.deleteObject('deals', 'd1');
      expect(changes, isEmpty);
    });

    test('a failed batch chunk emits nothing', () async {
      await repo.saveObjectsBatch(
        [
          ObjectUpdate(
            collectionId: 'deals',
            id: 'gone',
            values: const {'amount': 1},
            before: deal('gone', 0),
          ),
        ],
        schemas: {'deals': deals},
      );
      await pumpEventQueue();
      expect(changes, isEmpty);
    });
  });

  group('views origins', () {
    Future<CollectionViewsCubit> ready() async {
      final cubit = CollectionViewsCubit(repo, 'deals')..initialize();
      addTearDown(cubit.close);
      await pumpEventQueue();
      return cubit;
    }

    test('a move is ui; its undo is undo', () async {
      final c = await ready();
      c.selectView('board');
      final undo = c.moveToGroup('d3', 'won')!;
      await pumpEventQueue();
      await undo();
      await pumpEventQueue();

      expect(
        [for (final e in changes) e.origin.kind],
        [WriteKind.ui, WriteKind.undo],
      );
    });

    test('quick add is ui', () async {
      final c = await ready();
      c.quickAdd('Call');
      await pumpEventQueue();
      expect(changes.single.origin.kind, WriteKind.ui);
      expect(changes.single.before, isNull);
    });

    test('delete passes the object; its undo is undo', () async {
      final c = await ready();
      final undo = c.deleteObject('d1')!;
      await pumpEventQueue();
      await undo();
      await pumpEventQueue();

      final [deleted, restored] = changes;
      expect(repo.deleteBefores.single!.id, 'd1');
      expect(deleted.before!.id, 'd1');
      expect(deleted.after, isNull);
      expect(deleted.origin.kind, WriteKind.ui);
      expect(restored.before, isNull);
      expect(restored.origin.kind, WriteKind.undo);
    });
  });

  test('a template import is template', () async {
    final empty = FakeDataRepository();
    final events = <CardChange>[];
    final sub = empty.changes.listen(events.add);
    addTearDown(sub.cancel);
    final cubit = CollectionsListCubit(empty)..initialize();
    addTearDown(cubit.close);
    final template = WorkspaceTemplate.fromJson(
      jsonDecode(
            File('assets/templates/orders_pipeline.json').readAsStringSync(),
          )
          as Map<String, dynamic>,
    );

    await cubit.importTemplate(template);
    await pumpEventQueue();

    expect(events, isNotEmpty);
    expect(events.map((e) => e.origin.kind), everyElement(WriteKind.template));
  });
}
