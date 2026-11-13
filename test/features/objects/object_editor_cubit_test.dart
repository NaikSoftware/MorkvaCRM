import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/api/data/data_repository.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/features/collections/util/id_generator.dart';
import 'package:morkva_crm/features/objects/object_editor_cubit.dart';
import 'package:morkva_crm/l10n/l10n.dart';

import '../collections/fake_data_repository.dart';
import '../views/views_fixtures.dart';

final _en = lookupAppLocalizations(const Locale('en'));

/// Records what [saveObject] was given (before the fake merges it).
class _RecordingRepo extends FakeDataRepository {
  _RecordingRepo(super.initial);

  final saved = <MorkvaObject>[];

  @override
  Future<void> saveObject(
    MorkvaObject object, {
    required Collection schema,
    WriteOrigin origin = const WriteOrigin.ui(),
  }) {
    saved.add(object);
    return super.saveObject(object, schema: schema, origin: origin);
  }
}

class _FailingCollectionsRepo extends FakeDataRepository {
  _FailingCollectionsRepo(super.initial);

  @override
  Future<List<Collection>> getCollections() async => throw Exception('offline');
}

/// [getCollections] waits for [collections]; cancelling the deals object watch
/// waits for [cancelled].
class _SlowCollectionsRepo extends FakeDataRepository {
  _SlowCollectionsRepo(super.initial);

  final collections = Completer<void>();
  final cancelled = Completer<void>();

  @override
  Stream<MorkvaObject?> watchObject(
    String collectionId,
    String objectId, {
    required Collection schema,
  }) => collectionId == 'deals'
      ? (StreamController<MorkvaObject?>(
          onCancel: () => cancelled.future,
        )).stream
      : super.watchObject(collectionId, objectId, schema: schema);

  @override
  Future<List<Collection>> getCollections() async {
    await collections.future;
    return super.getCollections();
  }
}

class _FixedIds extends IdGenerator {
  @override
  String objectId() => 'new1';
}

/// Deals plus a required name, a bounded probability and an auto number.
final _strict = deals.copyWith(
  fields: [
    const TextFieldDefinition(
      id: 'name',
      name: 'Name',
      isRequired: true,
      maxLength: 20,
    ),
    ...deals.fields.skip(1),
    const NumberFieldDefinition(id: 'prob', name: 'Probability', max: 100),
    const AutoNumberFieldDefinition(id: 'no', name: 'Deal #'),
  ],
);

final _now = DateTime.utc(2026, 11, 3, 12);

void main() {
  late _RecordingRepo repo;

  setUp(() {
    repo = _RecordingRepo([_strict, companies]);
    repo.seedObjects('deals', sampleDeals());
    repo.seedObjects('companies', [
      company('k1', 'Zeta Corp', 0),
      company('k2', 'Alpha Ltd', 1),
    ]);
  });

  MorkvaObject d1() => repo.objectsOf('deals').firstWhere((o) => o.id == 'd1');

  Future<ObjectEditorCubit> edit([MorkvaObject? object]) async {
    final c = ObjectEditorCubit(
      repo,
      _strict,
      object: object ?? d1(),
      clock: () => _now,
    );
    addTearDown(c.close);
    await c.initialize();
    await pumpEventQueue();
    return c;
  }

  Future<ObjectEditorCubit> create({
    Map<String, FieldValue> prefill = const {},
  }) async {
    final c = ObjectEditorCubit(
      repo,
      _strict,
      prefill: prefill,
      idGenerator: _FixedIds(),
      clock: () => _now,
    );
    addTearDown(c.close);
    await c.initialize();
    await pumpEventQueue();
    return c;
  }

  group('edit', () {
    test('shows stored values, title and reference labels', () async {
      final c = await edit();
      expect(c.state.isCreate, isFalse);
      expect(c.state.title(_en), 'Acme renewal');
      expect(
        c.state.valueOf(_strict.fieldById('amount')!),
        const NumberFieldValue(1200),
      );
      expect(c.state.references.labelsFor(companyField), {
        'k2': 'Alpha Ltd',
        'k1': 'Zeta Corp',
      });
      expect(c.state.hasUnsavedChanges, isFalse);
    });

    test('change → dirty; back to the stored value → clean', () async {
      final c = await edit();
      c.change('amount', const NumberFieldValue(5));
      expect(c.state.changedFieldIds, {'amount'});
      expect(c.state.hasUnsavedChanges, isTrue);
      c.change('amount', const NumberFieldValue(1200));
      expect(c.state.changedFieldIds, isEmpty);
      expect(c.state.hasUnsavedChanges, isFalse);
    });

    test('save writes only the changed keys and updatedAt', () async {
      final c = await edit();
      c.change('amount', const NumberFieldValue(5));
      expect(await c.save(), isTrue);
      expect(repo.saved.single.values, {'amount': const NumberFieldValue(5)});
      expect(repo.saved.single.updatedAt, _now);
      expect(c.state.status, ObjectEditorStatus.saved);
      expect(c.state.savedId, 'd1');
      // The result carries the whole object, not just the written keys.
      expect(
        c.state.savedObject!['name'],
        const TextFieldValue('Acme renewal'),
      );
      // The fake merged it: other fields kept.
      expect(d1()['name'], const TextFieldValue('Acme renewal'));
      expect(d1()['amount'], const NumberFieldValue(5));
    });

    test('save without changes writes nothing', () async {
      final c = await edit();
      expect(await c.save(), isTrue);
      expect(repo.saved, isEmpty);
    });

    test('save failure keeps the draft and reports saveFailed', () async {
      final c = await edit();
      c.change('amount', const NumberFieldValue(5));
      repo.objectWriteError = () => Exception('offline');
      expect(await c.save(), isFalse);
      expect(c.state.status, ObjectEditorStatus.saveFailed);
      expect(c.state.draft, {'amount': const NumberFieldValue(5)});
      expect(await c.save(), isTrue);
    });

    test('read-only fields are never dirty and never error', () async {
      final c = await edit();
      c.change('no', const AutoNumberFieldValue(7));
      c.setInputError('no', 'bad');
      expect(c.state.changedFieldIds, isEmpty);
      expect(c.state.errors.containsKey('no'), isFalse);
    });

    test('live sync: untouched fields follow the stream', () async {
      final c = await edit();
      c.change('amount', const NumberFieldValue(5));
      await repo.saveObject(
        d1().copyWith(values: {'stage': const SingleSelectFieldValue('won')}),
        schema: _strict,
      );
      await pumpEventQueue();
      expect(c.state.valueOf(stageField), const SingleSelectFieldValue('won'));
      expect(c.state.conflictFieldIds, isEmpty);
      expect(c.state.draft, {'amount': const NumberFieldValue(5)});
    });

    test('live sync: a dirty field changed elsewhere is a conflict', () async {
      final c = await edit();
      c.change('amount', const NumberFieldValue(5));
      await repo.saveObject(
        d1().copyWith(values: {'amount': const NumberFieldValue(9)}),
        schema: _strict,
      );
      await pumpEventQueue();
      expect(c.state.conflictFieldIds, {'amount'});
      // Our value still shows and wins on save.
      expect(c.state.valueOf(_strict.fieldById('amount')!).toJson(), 5);
      expect(await c.save(), isTrue);
      expect(d1()['amount'], const NumberFieldValue(5));
    });

    test(
      'remote delete → remoteDeleted; save writes the whole object',
      () async {
        final c = await edit();
        c.change('amount', const NumberFieldValue(5));
        await repo.deleteObject('deals', 'd1');
        await pumpEventQueue();
        expect(c.state.remoteDeleted, isTrue);
        expect(await c.save(), isTrue);
        final written = repo.saved.single;
        expect(written.id, 'd1');
        expect(written.values['name'], const TextFieldValue('Acme renewal'));
        expect(written.values['amount'], const NumberFieldValue(5));
        expect(written.values.length, _strict.fields.length);
      },
    );

    blocTest<ObjectEditorCubit, ObjectEditorState>(
      'requestDelete → deleted, nothing written',
      build: () =>
          ObjectEditorCubit(repo, _strict, object: d1(), clock: () => _now),
      act: (c) => c.requestDelete(),
      verify: (c) {
        expect(c.state.status, ObjectEditorStatus.deleted);
        expect(c.state.hasUnsavedChanges, isFalse);
        expect(repo.objectsOf('deals'), hasLength(5));
      },
    );
  });

  group('validation', () {
    test('errors show for touched fields only, then all after save', () async {
      final c = await create();
      c.change('prob', const NumberFieldValue(120));
      expect(c.state.errors.keys, containsAll(['name', 'prob']));
      expect(c.state.visibleErrors, isEmpty);
      c.touch('prob');
      expect(c.state.visibleErrors.keys, ['prob']);
      expect(await c.save(), isFalse);
      expect(c.state.showAllErrors, isTrue);
      expect(c.state.visibleErrors.keys, containsAll(['name', 'prob']));
      expect(c.state.errorCount, 2);
      expect(repo.saved, isEmpty);
    });

    test('a number parse error blocks save until cleared', () async {
      final c = await edit();
      c.setInputError('amount', 'Enter a number');
      expect(c.state.hasUnsavedChanges, isTrue);
      expect(await c.save(), isFalse);
      expect(c.state.visibleErrors, {'amount': 'Enter a number'});
      c.setInputError('amount', null);
      expect(await c.save(), isTrue);
    });

    test('maxLength blocks save', () async {
      final c = await edit();
      c.change('name', const TextFieldValue('Far too long a name for it'));
      expect(await c.save(), isFalse);
      expect(c.state.visibleErrors.keys, ['name']);
      expect(repo.saved, isEmpty);
    });
  });

  group('create', () {
    test(
      'title is "New deal"; save writes the full object with prefill',
      () async {
        final c = await create(
          prefill: {'stage': const SingleSelectFieldValue('lead')},
        );
        expect(c.state.isCreate, isTrue);
        expect(c.state.title(_en), 'New deal');
        expect(c.state.hasUnsavedChanges, isFalse);
        c.change('name', const TextFieldValue('Hooli'));
        expect(await c.save(), isTrue);
        final written = repo.saved.single;
        expect(written.id, 'new1');
        expect(written.values.length, _strict.fields.length);
        expect(written.values['name'], const TextFieldValue('Hooli'));
        expect(written.values['stage'], const SingleSelectFieldValue('lead'));
        expect(written.createdAt, _now);
        expect(c.state.savedId, 'new1');
        expect(repo.objectsOf('deals'), hasLength(6));
      },
    );

    test('a prefilled value changed back is not dirty', () async {
      final c = await create(
        prefill: {'stage': const SingleSelectFieldValue('lead')},
      );
      c.change('stage', const SingleSelectFieldValue('won'));
      expect(c.state.hasUnsavedChanges, isTrue);
      c.change('stage', const SingleSelectFieldValue('lead'));
      expect(c.state.hasUnsavedChanges, isFalse);
    });

    test('requestDelete does nothing in create mode', () async {
      final c = await create();
      c.requestDelete();
      expect(c.state.status, ObjectEditorStatus.editing);
    });
  });

  test('a failed reference target yields empty choices', () async {
    repo.failObjects('companies', Exception('denied'));
    final c = await edit();
    expect(c.state.references.labelsFor(companyField), isEmpty);
  });

  group('missing reference targets', () {
    test('a deleted target collection counts as loaded and empty', () async {
      await repo.deleteCollection('companies');
      final c = await edit();
      expect(c.state.references.labelsFor(companyField), isEmpty);
      expect(c.state.references.targetOf(companyField), isNull);
    });

    test('getCollections failing counts every target as empty', () async {
      final failing = _FailingCollectionsRepo([_strict, companies]);
      failing.seedObjects('deals', sampleDeals());
      final c = ObjectEditorCubit(
        failing,
        _strict,
        object: failing.objectsOf('deals').first,
      );
      addTearDown(c.close);
      await c.initialize();
      await pumpEventQueue();
      expect(c.state.references.labelsFor(companyField), isEmpty);
    });
  });

  test(
    'follows its object with a single-object watch, not the collection',
    () async {
      final c = await edit();
      expect(repo.watchObjectCalls, {'d1': 1});
      expect(repo.watchObjectsCalls['deals'], isNull);
      expect(c.state.stored?.id, 'd1');
    },
  );

  group('remote delete', () {
    test('an object not yet in any snapshot is not "deleted"', () async {
      // Quick-added: committed later, so the stream lacks it at first.
      final pendingDeal = deal('d9', 9, name: 'Fresh');
      final c = await edit(pendingDeal);
      expect(c.state.remoteDeleted, isFalse);

      await repo.saveObject(pendingDeal, schema: _strict);
      await pumpEventQueue();
      expect(c.state.remoteDeleted, isFalse);

      await repo.deleteObject('deals', 'd9');
      await pumpEventQueue();
      expect(c.state.remoteDeleted, isTrue);
    });
  });

  test('closing while collections load subscribes nothing', () async {
    final slow = _SlowCollectionsRepo([_strict, companies]);
    slow.seedObjects('deals', sampleDeals());
    final c = ObjectEditorCubit(
      slow,
      _strict,
      object: slow.objectsOf('deals').first,
    );
    final init = c.initialize();
    await pumpEventQueue();
    final closing = c.close();
    // The targets resolve while close() is still cancelling.
    slow.collections.complete();
    await init;
    slow.cancelled.complete();
    await closing;
    await pumpEventQueue();
    expect(slow.liveListeners, 0);
  });

  test('close cancels every subscription', () async {
    final c = ObjectEditorCubit(repo, _strict, object: d1());
    await c.initialize();
    await pumpEventQueue();
    expect(repo.liveListeners, 2);
    await c.close();
    expect(repo.liveListeners, 0);
  });

  group('write origins', () {
    late List<CardChange> changes;

    setUp(() {
      changes = [];
      final sub = repo.changes.listen(changes.add);
      addTearDown(sub.cancel);
    });

    test('save is a ui write with the stored before', () async {
      final c = await edit();
      c.change('amount', const NumberFieldValue(5));
      expect(await c.save(), isTrue);
      await pumpEventQueue();

      final change = changes.single;
      expect(change.origin.kind, WriteKind.ui);
      expect(change.origin.commitId, isNotNull);
      expect(change.before!['amount'], const NumberFieldValue(1200));
      expect(change.after!['amount'], const NumberFieldValue(5));
    });

    test('deleting a child passes the item as before', () async {
      final company = repo
          .objectsOf('companies')
          .firstWhere((o) => o.id == 'k2');
      final c = ObjectEditorCubit(repo, companies, object: company);
      addTearDown(c.close);
      await c.initialize();
      await pumpEventQueue();
      final sublist = c.state.sublists.single;
      final item = sublist.items!.first;

      expect(await c.deleteChild(sublist, item), isTrue);
      await pumpEventQueue();

      expect(repo.deleteBefores.single, same(item));
      final change = changes.single;
      expect(change.before, same(item));
      expect(change.after, isNull);
      expect(change.origin.kind, WriteKind.ui);
    });
  });
}
