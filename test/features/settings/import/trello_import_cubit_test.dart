import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/api/data/data_repository.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/core/domain/ids.dart';
import 'package:morkva_crm/core/import/trello/trello_board.dart';
import 'package:morkva_crm/core/import/trello/trello_mapper.dart';
import 'package:morkva_crm/features/settings/import/trello_import_cubit.dart';

import '../../collections/fake_data_repository.dart';

final _sample = File(
  'test/core/import/trello/fixtures/sample_board.json',
).readAsStringSync();

const _boardId = '64a1f0c2b1a2c3d4e5f60001';

/// The fixture as a different board (another id and name).
final _other = _sample
    .replaceAll(_boardId, '64a1f0c2b1a2c3d4e5f60099')
    .replaceAll('Sales Pipeline', 'Hiring');

void main() {
  late FakeDataRepository repo;

  setUp(() => repo = FakeDataRepository());

  TrelloImportCubit cubit({
    Duration sliceTimeout = const Duration(seconds: 30),
    int sliceSize = 450,
  }) =>
      TrelloImportCubit(repo, sliceTimeout: sliceTimeout, sliceSize: sliceSize);

  /// A cubit with the fixture added and moved to the choose step.
  TrelloImportCubit chosen({
    Duration sliceTimeout = const Duration(seconds: 30),
    int sliceSize = 450,
  }) {
    final c = cubit(sliceTimeout: sliceTimeout, sliceSize: sliceSize)
      ..addFiles([(name: 'board.json', text: _sample)])
      ..next();
    addTearDown(c.close);
    return c;
  }

  /// Ids sent in each saveObjectsBatch call, recorded by a spy that writes.
  List<List<String>> spyBatches() {
    final sent = <List<String>>[];
    repo.batchWriteError = (chunk) {
      sent.add([for (final w in chunk) w.id]);
      return null;
    };
    return sent;
  }

  group('add boards', () {
    test('a parsed file becomes a board, keeping its file name', () {
      final c = cubit()..addFiles([(name: 'board.json', text: _sample)]);
      addTearDown(c.close);
      expect(c.state.boards, hasLength(1));
      expect(c.state.boards.single.fileName, 'board.json');
      expect(c.state.boards.single.board.name, 'Sales Pipeline');
      expect(c.state.problems, isEmpty);
      expect(c.state.canContinue, isTrue);
    });

    test('a bad file is a problem row; the same board again is a note', () {
      final c = cubit()
        ..addFiles([
          (name: 'board.json', text: _sample),
          (name: 'notes.txt', text: 'not json'),
          (name: 'copy.json', text: _sample),
        ]);
      addTearDown(c.close);
      expect(c.state.boards, hasLength(1));
      expect(c.state.problems.map((p) => p.name), ['notes.txt', 'copy.json']);
      expect(c.state.problems.first.message, contains('Trello board export'));
      expect(c.state.problems.last.message, 'Already added');

      c.dismissProblem(0);
      expect(c.state.problems.map((p) => p.name), ['copy.json']);
    });

    test('pasted text adds a board and reports success', () {
      final c = cubit();
      addTearDown(c.close);
      expect(c.addPasted(_sample), isTrue);
      expect(c.state.boards.single.fileName, 'Pasted text');
      expect(c.addPasted('{'), isFalse);
      expect(c.addPasted(_sample), isFalse);
      expect(c.state.problems.map((p) => p.name), [
        'Pasted text',
        'Pasted text',
      ]);
      expect(c.state.boards, hasLength(1));
    });

    test('continue needs a board; next and back move between steps', () {
      final c = cubit();
      addTearDown(c.close);
      expect(c.state.canContinue, isFalse);
      c.next();
      expect(c.state.step, TrelloImportStep.add);

      c
        ..addFiles([(name: 'a.json', text: _sample)])
        ..next();
      expect(c.state.step, TrelloImportStep.choose);
      c.back();
      expect(c.state.step, TrelloImportStep.add);

      c.removeBoard(_boardId);
      expect(c.state.boards, isEmpty);
      expect(c.state.choices, isEmpty);
      expect(c.state.canContinue, isFalse);
    });
  });

  group('choose', () {
    test('defaults: board and children ticked, archived off', () {
      final c = chosen();
      final choice = c.state.choices[_boardId]!;
      expect(choice.board, isTrue);
      expect(choice.checklists, isTrue);
      expect(choice.comments, isTrue);
      expect(c.state.includeArchived, isFalse);
      expect(c.state.selectedCollectionCount, 3);
      expect(c.state.canImport, isTrue);
      expect(c.state.importBlockedReason, isNull);
    });

    test('summaries and counts follow includeArchived', () {
      final c = chosen();
      final off = c.state.summaries[_boardId]!;
      expect((off.cards, off.checklistItems, off.comments), (4, 3, 2));

      c.setIncludeArchived(true);
      final on = c.state.summaries[_boardId]!;
      expect((on.cards, on.checklistItems, on.comments), (6, 4, 3));

      c.setIncludeArchived(false);
      expect(c.state.summaries[_boardId], same(off), reason: 'cached');
    });

    test('children are inert while their board is unticked', () {
      final c = chosen()..select(_boardId, comments: false);
      expect(c.state.selectedCollectionCount, 2);
      c.select(_boardId, board: false);
      expect(c.state.selectedCollectionCount, 0);
      expect(c.state.canImport, isFalse);
      expect(c.state.importBlockedReason, 'Choose at least one collection');
      expect(c.state.choices[_boardId]!.checklists, isTrue);
    });

    test('offline blocks the import', () async {
      final c = chosen()..setOffline(true);
      expect(c.state.offline, isTrue);
      expect(c.state.canImport, isFalse);
      expect(c.state.importBlockedReason, "You're offline — connect to import");
      await c.startImport();
      expect(c.state.step, TrelloImportStep.choose);
      expect(repo.saveCount, 0);

      c.setOffline(false);
      expect(c.state.canImport, isTrue);
    });
  });

  group('import', () {
    test(
      'writes every collection, then its cards as template writes',
      () async {
        final c = chosen();
        final kinds = <WriteKind>[];
        final sub = repo.changes.listen((e) => kinds.add(e.origin.kind));
        addTearDown(sub.cancel);

        await c.startImport();
        await pumpEventQueue();

        expect(c.state.step, TrelloImportStep.done);
        final rows = c.state.rows;
        expect(rows.map((r) => r.kind), [
          ImportedKind.board,
          ImportedKind.checklistItems,
          ImportedKind.comments,
        ]);
        expect(rows.map((r) => (r.written, r.total)), [(4, 4), (3, 3), (2, 2)]);
        expect(rows.every((r) => r.status == ImportRowStatus.done), isTrue);
        expect(rows.length, c.state.selectedCollectionCount);
        expect(c.state.firstCollectionId, rows.first.collectionId);

        final saved = await repo.getCollections();
        expect(saved.map((s) => s.id), rows.map((r) => r.collectionId));
        expect(saved.first.name, 'Sales Pipeline');
        for (final r in rows) {
          expect(repo.objectsOf(r.collectionId), hasLength(r.total));
        }
        expect(kinds, hasLength(9));
        expect(kinds.toSet(), {WriteKind.template});

        // Cards keep their Trello creation time.
        final mapped = mapTrelloBoard(
          TrelloBoard.parse(_sample),
          includeArchived: false,
          checklists: true,
          comments: true,
          ids: IdGenerator(),
        ).first;
        expect(
          repo
              .objectsOf(rows.first.collectionId)
              .map((o) => o.createdAt)
              .toSet(),
          mapped.objects.map((o) => o.createdAt).toSet(),
        );
      },
    );

    test('only ticked collections are created', () async {
      final c = chosen()..select(_boardId, checklists: false);
      await c.startImport();
      expect(c.state.rows.map((r) => r.kind), [
        ImportedKind.board,
        ImportedKind.comments,
      ]);
      expect(await repo.getCollections(), hasLength(2));
    });

    test('slices objects and emits progress after each slice', () async {
      final c = chosen(sliceSize: 2);
      final sent = spyBatches();
      final written = <int>[];
      final sub = c.stream.listen((s) => written.add(s.writtenObjects));
      addTearDown(sub.cancel);

      await c.startImport();
      await pumpEventQueue();

      expect(sent.map((s) => s.length), [2, 2, 2, 1, 2]);
      expect(repo.batchCalls, 5);
      for (final n in [2, 4, 6, 7, 9]) {
        expect(written, contains(n));
      }
      expect(c.state.totalObjects, 9);
    });

    test('a stalled slice pauses; retry skips ids already on the server', () {
      fakeAsync((async) {
        final c = chosen(
          sliceSize: 2,
          sliceTimeout: const Duration(seconds: 5),
        );
        repo.batchNeverCompletes = true;
        unawaited(c.startImport());
        async.flushMicrotasks();
        expect(c.state.isWriting, isTrue);
        expect(c.state.rows.first.status, ImportRowStatus.running);

        async.elapse(const Duration(seconds: 5));
        expect(c.state.isWriting, isFalse);
        expect(c.state.stalled, isTrue);
        expect(c.state.failure, 'Import stalled — check your connection');
        expect(c.state.rows.first.status, ImportRowStatus.paused);
        expect(c.state.rows.first.written, 0);

        // The timed-out slice landed after all.
        final cardsId = c.state.rows.first.collectionId;
        final landed = repo.objectsOf(cardsId).map((o) => o.id).toSet();
        expect(landed, hasLength(2));

        repo.batchNeverCompletes = false;
        final sent = spyBatches();
        unawaited(c.retry());
        async.flushMicrotasks();

        expect(c.state.step, TrelloImportStep.done);
        expect(sent.expand((s) => s).toSet().intersection(landed), isEmpty);
        expect(sent.first, hasLength(2));
        expect(repo.objectsOf(cardsId), hasLength(4));
        expect(repo.saveCount, 3, reason: 'collections are not re-saved');
        expect(c.state.rows.first.written, 4);
      });
    });

    test(
      'a failed batch pauses; retry re-sends only what is missing',
      () async {
        final c = chosen();
        final failedIds = <String>[];
        repo.batchWriteError = (chunk) {
          failedIds.addAll(chunk.map((w) => w.id));
          return 'permission-denied';
        };

        await c.startImport();

        expect(c.state.step, TrelloImportStep.importing);
        expect(c.state.stalled, isFalse);
        expect(c.state.failure, isNotNull);
        expect(c.state.failure, isNot(contains('permission-denied')));
        expect(c.state.rows.first.status, ImportRowStatus.paused);
        expect(c.state.rows.skip(1).map((r) => r.status), [
          ImportRowStatus.pending,
          ImportRowStatus.pending,
        ]);
        expect(failedIds, hasLength(4));

        // Some cards reached the server anyway (e.g. another device's retry).
        final cardsId = c.state.rows.first.collectionId;
        final schema = (await repo.getCollection(cardsId))!;
        repo.seedObjects(cardsId, [
          for (final id in failedIds.take(3))
            MorkvaObject.create(
              id: id,
              collection: schema,
              createdAt: DateTime.utc(2024),
              updatedAt: DateTime.utc(2024),
            ),
        ]);

        final sent = spyBatches();
        await c.retry();

        expect(c.state.step, TrelloImportStep.done);
        expect(sent.first, [failedIds.last]);
        expect(repo.objectsOf(cardsId), hasLength(4));
        expect(repo.saveCount, 3);
      },
    );

    test('a failed server check keeps the import paused', () async {
      final c = chosen();
      repo.batchWriteError = (_) => 'unavailable';
      await c.startImport();

      repo
        ..batchWriteError = null
        ..serverReadError = StateError('offline');
      await c.retry();
      expect(c.state.failure, isNotNull);
      expect(repo.batchCalls, 1);

      repo.serverReadError = null;
      await c.retry();
      expect(c.state.step, TrelloImportStep.done);
    });

    test('a collection save that never acks stalls, then retries', () {
      fakeAsync((async) {
        final c = chosen(sliceTimeout: const Duration(seconds: 5));
        repo.collectionAck = Completer<void>();
        unawaited(c.startImport());
        async.elapse(const Duration(seconds: 5));
        expect(c.state.stalled, isTrue);
        expect(repo.batchCalls, 0);

        repo.collectionAck = null;
        unawaited(c.retry());
        async.flushMicrotasks();
        expect(c.state.step, TrelloImportStep.done);
        expect(repo.saveCount, 4, reason: 'only the unacked one is re-saved');
      });
    });

    test('start and retry are no-ops while writing', () {
      fakeAsync((async) {
        final c = chosen(sliceTimeout: const Duration(seconds: 5));
        repo.batchNeverCompletes = true;
        unawaited(c.startImport());
        async.flushMicrotasks();
        unawaited(c.startImport());
        unawaited(c.retry());
        async.flushMicrotasks();
        expect(repo.batchCalls, 1);
        async.elapse(const Duration(seconds: 5));
      });
    });

    test('closing mid-write never emits afterwards', () {
      fakeAsync((async) {
        final c = cubit(sliceTimeout: const Duration(seconds: 5))
          ..addFiles([(name: 'b.json', text: _sample)])
          ..next();
        repo.batchNeverCompletes = true;
        unawaited(c.startImport());
        async.flushMicrotasks();
        unawaited(c.close());
        async
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 10));
        expect(c.isClosed, isTrue);
      });
    });

    test('two boards import in board order', () async {
      final c = cubit()
        ..addFiles([
          (name: 'a.json', text: _sample),
          (name: 'b.json', text: _other),
        ])
        ..next();
      addTearDown(c.close);
      expect(c.state.selectedCollectionCount, 6);
      await c.startImport();
      expect(c.state.rows.map((r) => r.name).first, 'Sales Pipeline');
      expect(
        c.state.rows.where((r) => r.kind == ImportedKind.board).last.name,
        'Hiring',
      );
      expect(await repo.getCollections(), hasLength(6));
    });
  });
}
