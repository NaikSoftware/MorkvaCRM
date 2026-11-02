import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/features/collections/util/id_generator.dart';
import 'package:morkva_crm/features/views/collection_views_cubit.dart';
import 'package:morkva_crm/features/views/collection_views_state.dart';

import '../collections/fake_data_repository.dart';
import 'views_fixtures.dart';

class _SeqIds extends IdGenerator {
  int _n = 0;
  @override
  String viewId() => 'v${++_n}';
  @override
  String objectId() => 'o${++_n}';
}

final _now = DateTime.utc(2026, 4, 1, 12);

void main() {
  late FakeDataRepository repo;

  FakeDataRepository seeded([List<MorkvaObject>? objects]) {
    final r = FakeDataRepository([deals, companies]);
    r.seedObjects('deals', objects ?? sampleDeals());
    r.seedObjects('companies', [
      company('k1', 'Zeta Corp', 0),
      company('k2', 'Alpha Ltd', 1),
      company('k3', 'Mid Inc', 2),
    ]);
    return r;
  }

  Future<CollectionViewsCubit> ready([FakeDataRepository? r]) async {
    repo = r ?? seeded();
    final cubit = CollectionViewsCubit(
      repo,
      'deals',
      idGenerator: _SeqIds(),
      clock: () => _now,
    )..initialize();
    addTearDown(cubit.close);
    await pumpEventQueue();
    expect(cubit.state, isA<ViewsReady>());
    return cubit;
  }

  ViewsReady stateOf(CollectionViewsCubit c) => c.state as ViewsReady;
  List<String> ids(CollectionViewsCubit c) => [
    for (final o in stateOf(c).objects) o.id,
  ];
  MorkvaObject stored(String id) =>
      repo.objectsOf('deals').firstWhere((o) => o.id == id);

  group('loading', () {
    blocTest<CollectionViewsCubit, CollectionViewsState>(
      'emits Ready with the first view applied',
      build: () => CollectionViewsCubit(seeded(), 'deals'),
      act: (c) => c.initialize(),
      wait: Duration.zero,
      verify: (c) {
        final s = c.state as ViewsReady;
        expect(s.activeViewId, 'all');
        expect(s.totalCount, 5);
        expect(s.objects.map((o) => o.id), ['d1', 'd2', 'd3', 'd4', 'd5']);
        expect(s.groups, isNull);
        expect(s.days, isNull);
      },
    );

    blocTest<CollectionViewsCubit, CollectionViewsState>(
      'missing collection → NotFound',
      build: () => CollectionViewsCubit(seeded(), 'nope'),
      act: (c) => c.initialize(),
      wait: Duration.zero,
      expect: () => [const ViewsNotFound()],
    );

    test(
      'a collection without views gets the default view in memory',
      () async {
        final r = FakeDataRepository([deals.copyWith(views: const [])]);
        r.seedObjects('deals', sampleDeals());
        final c = await ready(r);
        expect(stateOf(c).activeView.id, ViewDefinition.defaultId);
        expect(stateOf(c).activeView.fieldIds.first, 'name');
        expect(r.saveCount + r.saveViewsCount, 0);
      },
    );

    test('stream error → ViewsError, retry recovers', () async {
      final c = await ready();
      repo.failObjects('deals', StateError('offline'));
      await pumpEventQueue();
      expect(c.state, isA<ViewsError>());
      repo.seedObjects('deals', sampleDeals());
      await c.retry();
      await pumpEventQueue();
      expect(stateOf(c).totalCount, 5);
    });

    test('the collection being deleted → NotFound', () async {
      final c = await ready();
      await repo.deleteCollection('deals');
      await pumpEventQueue();
      expect(c.state, const ViewsNotFound());
    });
  });

  group('views', () {
    test('selectView switches and computes groups', () async {
      final c = await ready();
      c.selectView('board');
      final s = stateOf(c);
      expect(s.activeViewId, 'board');
      expect([for (final g in s.groups!) g.key], ['lead', 'won', 'lost', null]);
      expect([for (final o in s.groups!.first.objects) o.id], ['d1', 'd3']);
      expect(s.groups!.last.objects.single.id, 'd5');
      c.selectView('unknown');
      expect(stateOf(c).activeViewId, 'board');
    });

    test('a date layout field yields day buckets', () async {
      final c = await ready(
        seeded([deal('a', 0, due: DateTime.utc(2026, 5, 2)), deal('b', 1)]),
      );
      await c.setLayoutField('due');
      final days = stateOf(c).days!;
      expect(days.days.keys.single, DateTime(2026, 5, 2));
      expect(days.undated.single.id, 'b');
    });

    test('createView appends, selects and saves', () async {
      final c = await ready();
      final id = await c.createView(
        ' Board ',
        mode: ViewModeIds.board,
        layoutFieldId: 'stage',
      );
      expect(id, 'v1');
      final s = stateOf(c);
      expect(s.activeViewId, 'v1');
      expect(s.activeView.name, 'Board');
      expect(s.activeView.mode, ViewModeIds.board);
      expect(s.activeView.fieldIds, ['name', 'amount', 'stage', 'company']);
      final saved = await repo.getCollection('deals');
      expect(saved!.views.map((v) => v.id), ['all', 'board', 'v1']);
    });

    test('renameView trims; a blank name is ignored', () async {
      final c = await ready();
      await c.renameView('board', '  Funnel ');
      expect(stateOf(c).collection.views[1].name, 'Funnel');
      final saves = repo.saveViewsCount;
      await c.renameView('board', '   ');
      expect(repo.saveViewsCount, saves);
    });

    test(
      'duplicateView inserts the copy after the source and selects it',
      () async {
        final c = await ready();
        final id = await c.duplicateView('all');
        final views = stateOf(c).collection.views;
        expect(views.map((v) => v.id), ['all', id, 'board']);
        expect(views[1].name, 'All deals copy');
        expect(views[1].fieldIds, tableView.fieldIds);
        expect(stateOf(c).activeViewId, id);
      },
    );

    test('deleteView never deletes the last view', () async {
      final c = await ready();
      c.selectView('board');
      expect(await c.deleteView('board'), isTrue);
      expect(stateOf(c).activeViewId, 'all');
      expect(await c.deleteView('all'), isFalse);
      expect(stateOf(c).collection.views.single.id, 'all');
    });

    test('deleting the first active view selects the next one', () async {
      final c = await ready();
      expect(await c.deleteView('all'), isTrue);
      expect(stateOf(c).activeViewId, 'board');
    });

    test('setFilters filters and keeps totalCount', () async {
      final c = await ready();
      await c.setFilters(const [
        ViewFilter(fieldId: 'stage', op: FilterOp.anyOf, operand: ['lead']),
      ]);
      expect(ids(c), ['d1', 'd3']);
      expect(stateOf(c).totalCount, 5);
      expect(stateOf(c).isFiltered, isTrue);
      final saved = await repo.getCollection('deals');
      expect(saved!.views.first.filters, hasLength(1));
    });

    test('setSort sorts; null returns to manual order', () async {
      final c = await ready();
      await c.setSort(const ViewSort(fieldId: 'amount', ascending: false));
      expect(ids(c), ['d1', 'd2', 'd3', 'd4', 'd5']);
      await c.setSort(const ViewSort(fieldId: 'amount'));
      expect(ids(c), ['d3', 'd2', 'd1', 'd4', 'd5']);
      await c.setSort(null);
      expect(stateOf(c).activeView.sort, isNull);
    });

    test(
      'setFieldIds, setLayoutField and setMode edit the active view',
      () async {
        final c = await ready();
        await c.setFieldIds(['amount', 'name']);
        expect(stateOf(c).activeView.fieldIds, ['amount', 'name']);
        await c.setLayoutField('ghost');
        expect(stateOf(c).activeView.layoutFieldId, isNull);
        await c.setMode(ViewModeIds.board, layoutFieldId: 'stage');
        expect(stateOf(c).activeView.mode, ViewModeIds.board);
        expect(stateOf(c).layoutField, stageField);
        await c.setLayoutField(null);
        expect(stateOf(c).activeView.layoutFieldId, isNull);
        expect(stateOf(c).groups, isNull);
      },
    );

    test('setMode sets the layout field exactly, in one save', () async {
      final c = await ready();
      await c.setMode(ViewModeIds.calendar, layoutFieldId: 'due');
      expect(stateOf(c).activeView.layoutFieldId, 'due');
      final saves = repo.saveViewsCount;
      await c.setMode(ViewModeIds.list);
      expect(stateOf(c).activeView.mode, ViewModeIds.list);
      expect(stateOf(c).activeView.layoutFieldId, isNull);
      expect(repo.saveViewsCount, saves + 1);
    });

    test('an unchanged view is not saved again', () async {
      final c = await ready();
      await c.setFieldIds(tableView.fieldIds);
      expect(repo.saveViewsCount, 0);
    });

    test('a failed view save reverts and reports', () async {
      final c = await ready();
      repo.saveError = () => StateError('denied');
      await c.renameView('all', 'Nope');
      final s = stateOf(c);
      expect(s.activeView.name, 'All deals');
      expect(s.writeError, isNotNull);
      expect(s.writeErrorSeq, 1);
    });
  });

  group('object commands', () {
    test('moveToGroup writes the value; undo restores it', () async {
      final c = await ready();
      c.selectView('board');
      final undo = c.moveToGroup('d3', 'won');
      expect(undo, isNotNull);
      // Optimistic: moved before the write lands.
      expect(stateOf(c).groups![1].objects.map((o) => o.id), contains('d3'));
      await pumpEventQueue();
      expect(stored('d3')['stage'], const SingleSelectFieldValue('won'));
      expect(stored('d3').updatedAt, _now);

      await undo!();
      await pumpEventQueue();
      expect(stored('d3')['stage'], const SingleSelectFieldValue('lead'));
      expect(stateOf(c).groups!.first.objects.map((o) => o.id), ['d1', 'd3']);
    });

    test('moveToGroup to the none group clears the value', () async {
      final c = await ready();
      c.selectView('board');
      c.moveToGroup('d1', null);
      await pumpEventQueue();
      expect(stored('d1')['stage'], const SingleSelectFieldValue(null));
    });

    test('moveToGroup with beforeId saves the manual order', () async {
      final c = await ready();
      c.selectView('board');
      c.moveToGroup('d3', 'won', beforeId: 'd2');
      await pumpEventQueue();
      expect(stateOf(c).groups![1].objects.map((o) => o.id), ['d3', 'd2']);
      final saved = await repo.getCollection('deals');
      final order = saved!.views[1].manualOrder;
      expect(order.indexOf('d3'), lessThan(order.indexOf('d2')));
    });

    test('moveToGroup into its own group at the end is a no-op', () async {
      final c = await ready();
      c.selectView('board');
      expect(c.moveToGroup('d3', 'lead'), isNull);
      expect(repo.saveViewsCount, 0);
    });

    test('moveToGroup needs a groupable layout field', () async {
      final c = await ready();
      expect(c.moveToGroup('d1', 'won'), isNull);
    });

    test('moveToGroup on a reference board writes the reference', () async {
      final c = await ready();
      c.selectView('board');
      await c.setLayoutField('company');
      await pumpEventQueue();
      c.moveToGroup('d3', 'k3');
      await pumpEventQueue();
      expect(stored('d3')['company'], const ReferenceFieldValue(['k3']));
    });

    test('moveToDay keeps the time of day; null clears; undo', () async {
      final meeting = DateTime(2026, 5, 2, 14, 30).toUtc();
      final c = await ready(seeded([deal('a', 0, meeting: meeting)]));
      await c.setLayoutField('meeting');
      final undo = c.moveToDay('a', DateTime(2026, 5, 9));
      await pumpEventQueue();
      final moved = (stored('a')['meeting'] as DateFieldValue).value!.toLocal();
      expect([moved.day, moved.hour, moved.minute], [9, 14, 30]);
      expect(stateOf(c).days!.days.keys.single, DateTime(2026, 5, 9));

      await undo!();
      await pumpEventQueue();
      expect(stored('a')['meeting'], DateFieldValue(meeting));

      c.moveToDay('a', null);
      await pumpEventQueue();
      expect(stored('a')['meeting'], const DateFieldValue(null));
      expect(c.moveToDay('a', null), isNull);
    });

    test('moveToDay needs a date layout field', () async {
      final c = await ready();
      expect(c.moveToDay('d1', DateTime(2026, 1, 1)), isNull);
    });

    test('reorder saves the manual order; undo restores it', () async {
      final c = await ready();
      final undo = c.reorder('d5', beforeId: 'd1');
      await pumpEventQueue();
      expect(ids(c), ['d5', 'd1', 'd2', 'd3', 'd4']);
      await undo!();
      await pumpEventQueue();
      expect(ids(c), ['d1', 'd2', 'd3', 'd4', 'd5']);
    });

    test(
      'reorder in a sorted view switches to manual from the sorted order; undo brings the sort back',
      () async {
        final c = await ready();
        await c.setSort(const ViewSort(fieldId: 'amount'));
        expect(ids(c), ['d3', 'd2', 'd1', 'd4', 'd5']);
        final undo = c.reorder('d1', beforeId: 'd3');
        await pumpEventQueue();
        expect(stateOf(c).activeView.sort, isNull);
        expect(ids(c), ['d1', 'd3', 'd2', 'd4', 'd5']);
        await undo!();
        await pumpEventQueue();
        expect(stateOf(c).activeView.sort, const ViewSort(fieldId: 'amount'));
      },
    );

    test(
      'reorder on a board without beforeId goes to the end of its group',
      () async {
        final c = await ready();
        c.selectView('board');
        c.reorder('d1');
        await pumpEventQueue();
        expect(stateOf(c).groups!.first.objects.map((o) => o.id), ['d3', 'd1']);
        expect(c.reorder('d1'), isNull);
      },
    );

    test('quickAdd saves the title and the group value', () async {
      final c = await ready();
      c.selectView('board');
      final id = c.quickAdd('  New lead ', groupKey: 'won');
      expect(id, 'o1');
      expect(stateOf(c).groups![1].objects.map((o) => o.id), contains('o1'));
      await pumpEventQueue();
      final o = stored('o1');
      expect(o['name'], const TextFieldValue('New lead'));
      expect(o['stage'], const SingleSelectFieldValue('won'));
      expect(o.createdAt, _now);
      expect(o.values.keys, containsAll(['amount', 'due']));
    });

    test('quickAdd with a day pre-fills the date layout field', () async {
      final c = await ready();
      await c.setLayoutField('due');
      c.quickAdd('Call', day: DateTime(2026, 6, 3));
      await pumpEventQueue();
      expect(stored('o1')['due'], DateFieldValue(DateTime.utc(2026, 6, 3)));
    });

    test(
      'quickAdd uses the first text field when the title is not text',
      () async {
        final c = await ready();
        await c.setFieldIds(['amount', 'name']);
        c.quickAdd('Hello');
        await pumpEventQueue();
        expect(stored('o1')['name'], const TextFieldValue('Hello'));
      },
    );

    test('deleteObject removes it at once; undo restores it', () async {
      final c = await ready();
      final undo = c.deleteObject('d2');
      expect(ids(c), isNot(contains('d2')));
      expect(stateOf(c).totalCount, 4);
      await pumpEventQueue();
      expect(repo.objectsOf('deals').map((o) => o.id), isNot(contains('d2')));
      await undo!();
      await pumpEventQueue();
      expect(ids(c), ['d1', 'd2', 'd3', 'd4', 'd5']);
      expect(stored('d2').createdAt, t0.add(const Duration(minutes: 1)));
    });

    test('a failed object write puts the object back and reports', () async {
      final c = await ready();
      c.selectView('board');
      repo.objectWriteError = () => StateError('denied');
      c.moveToGroup('d3', 'won');
      await pumpEventQueue();
      final s = stateOf(c);
      expect(s.groups!.first.objects.map((o) => o.id), ['d1', 'd3']);
      expect(s.writeError, isNotNull);
      expect(s.writeErrorSeq, 1);

      repo.objectWriteError = () => StateError('denied');
      c.deleteObject('d1');
      await pumpEventQueue();
      expect(ids(c), contains('d1'));
      expect(stateOf(c).writeErrorSeq, 2);
    });
  });

  group('reference labels', () {
    test(
      'a reference board gets columns from the target, in its order',
      () async {
        final c = await ready();
        c.selectView('board');
        await c.setLayoutField('company');
        await pumpEventQueue();
        final groups = stateOf(c).groups!;
        expect(
          [for (final g in groups) g.label],
          ['Alpha Ltd', 'Mid Inc', 'Zeta Corp', 'No Company'],
        );
        expect(groups.first.objects.single.id, 'd1');
      },
    );

    test('the table shows target labels for its reference column', () async {
      final c = await ready();
      await pumpEventQueue();
      expect(stateOf(c).referenceLabels, {
        'k1': 'Zeta Corp',
        'k2': 'Alpha Ltd',
        'k3': 'Mid Inc',
      });
    });

    test('each stream is subscribed once across view switches', () async {
      final c = await ready();
      for (var i = 0; i < 3; i++) {
        c.selectView('board');
        await c.setLayoutField('company');
        c.selectView('all');
        await pumpEventQueue();
      }
      expect(repo.watchObjectsCalls, {'deals': 1, 'companies': 1});
    });

    test('a reference filter on a hidden field gets target labels', () async {
      final c = await ready();
      c.selectView('board'); // shows name, amount; lays out by stage
      await c.setFilters(const [
        ViewFilter(fieldId: 'company', op: FilterOp.anyOf, operand: ['k1']),
      ]);
      await pumpEventQueue();
      expect(stateOf(c).referenceLabels['k1'], 'Zeta Corp');
    });

    FakeDataRepository boardOnly(List<MorkvaObject> targets) {
      final r = FakeDataRepository([
        deals.copyWith(views: const [boardView]),
        companies,
      ]);
      r.seedObjects('deals', sampleDeals());
      r.seedObjects('companies', targets);
      return r;
    }

    test('loadReferenceChoices watches the target on demand, once', () async {
      final c = await ready(
        boardOnly([
          company('k1', 'Zeta Corp', 0),
          company('k2', 'Alpha Ltd', 1),
          company('k3', 'Mid Inc', 2),
        ]),
      );
      expect(repo.watchObjectsCalls['companies'], isNull);
      c.loadReferenceChoices('company');
      expect(stateOf(c).referenceChoices, isEmpty, reason: 'still loading');
      await pumpEventQueue();
      expect(stateOf(c).referenceChoices, {
        'company': {'k2': 'Alpha Ltd', 'k3': 'Mid Inc', 'k1': 'Zeta Corp'},
      });
      c.loadReferenceChoices('company');
      c.loadReferenceChoices('stage');
      c.loadReferenceChoices('missing');
      await pumpEventQueue();
      expect(repo.watchObjectsCalls['companies'], 1);
      expect(stateOf(c).referenceChoices.keys, ['company']);
    });

    test('removing a field forgets its requested choices', () async {
      final repo = boardOnly([company('k1', 'Zeta Corp', 0)]);
      final c = CollectionViewsCubit(repo, 'deals')..initialize();
      addTearDown(c.close);
      await pumpEventQueue();
      c.loadReferenceChoices('company');
      await pumpEventQueue();
      expect(stateOf(c).referenceChoices.keys, ['company']);
      final full = (await repo.getCollection('deals'))!;
      await repo.saveCollection(
        full.copyWith(
          fields: [
            for (final f in full.fields)
              if (f.id != 'company') f,
          ],
        ),
      );
      await pumpEventQueue();
      await repo.saveCollection(full);
      await pumpEventQueue();
      expect(stateOf(c).referenceChoices, isEmpty);
    });

    test('an empty target still emits (loaded, nothing to pick)', () async {
      final c = await ready(boardOnly(const []));
      final states = <CollectionViewsState>[];
      final sub = c.stream.listen(states.add);
      addTearDown(sub.cancel);
      c.loadReferenceChoices('company');
      await pumpEventQueue();
      expect(stateOf(c).referenceChoices, {'company': <String, String>{}});
      expect(states, isNotEmpty);
    });

    test('a failing choice target settles as empty', () async {
      final c = await ready(boardOnly(const []));
      repo.failObjects('companies', StateError('denied'));
      c.loadReferenceChoices('company');
      await pumpEventQueue();
      expect(stateOf(c).referenceChoices['company'], isEmpty);
    });

    test('loadReferenceChoices after close is a no-op', () async {
      final c = await ready(boardOnly(const []));
      await c.close();
      c.loadReferenceChoices('company');
      expect(repo.watchObjectsCalls['companies'], isNull);
    });

    test('labels follow target changes', () async {
      final c = await ready();
      await pumpEventQueue();
      repo.seedObjects('companies', [company('k1', 'Renamed', 0)]);
      await pumpEventQueue();
      expect(stateOf(c).referenceLabels, {'k1': 'Renamed'});
    });
  });

  group('fix round 1', () {
    test(
      'a move keeps stored values of fields it was not decoded with',
      () async {
        final r = seeded([deal('d1', 0, name: 'Acme', stage: 'lead')]);
        // A value of a field this client's schema doesn't know (yet).
        final raw = r.objectsOf('deals').single;
        r.seedObjects('deals', [
          raw.copyWith(
            values: {...raw.values, 'extra': const TextFieldValue('x')},
          ),
        ]);
        final c = await ready(r);
        c.selectView('board');
        c.moveToGroup('d1', 'won');
        await pumpEventQueue();
        expect(stored('d1')['extra'], const TextFieldValue('x'));
        expect(stored('d1')['stage'], const SingleSelectFieldValue('won'));
      },
    );

    test('a failing reference target is reported once', () async {
      final c = await ready();
      await pumpEventQueue();
      repo.failObjects('companies', StateError('denied'));
      repo.failObjects('companies', StateError('denied'));
      await pumpEventQueue();
      expect(stateOf(c).writeErrorSeq, 1);
      expect(stateOf(c).writeError, contains('Companies'));
    });

    test('a target failing again after retry is reported again', () async {
      final c = await ready();
      await pumpEventQueue();
      repo.failObjects('companies', StateError('denied'));
      await pumpEventQueue();
      expect(stateOf(c).writeErrorSeq, 1);
      await c.retry();
      await pumpEventQueue();
      repo.failObjects('companies', StateError('denied'));
      await pumpEventQueue();
      expect(stateOf(c).writeErrorSeq, 2);
    });

    test('retry cancels its old subscriptions first', () async {
      final c = await ready();
      await pumpEventQueue();
      final live = repo.liveListeners;
      expect(live, 3); // collections, deals, companies
      for (var i = 0; i < 3; i++) {
        await c.retry();
        await pumpEventQueue();
      }
      expect(repo.liveListeners, live);
      await c.close();
      expect(repo.liveListeners, 0);
    });

    test('retry clears the previous write error', () async {
      final c = await ready();
      repo.objectWriteError = () => StateError('denied');
      c.deleteObject('d1');
      await pumpEventQueue();
      expect(stateOf(c).writeError, isNotNull);
      await c.retry();
      await pumpEventQueue();
      expect(stateOf(c).writeError, isNull);
    });

    test('undo waits for the write it reverts', () async {
      final c = await ready();
      c.selectView('board');
      final undo = c.moveToGroup('d3', 'won')!;
      // Undo right away, before the move's write has landed.
      await undo();
      await pumpEventQueue();
      expect(stored('d3')['stage'], const SingleSelectFieldValue('lead'));

      final undoDelete = c.deleteObject('d2')!;
      await undoDelete();
      await pumpEventQueue();
      expect(repo.objectsOf('deals').map((o) => o.id), contains('d2'));
    });

    test('createView / duplicateView failing keep the old selection', () async {
      final c = await ready();
      c.selectView('board');
      repo.saveError = () => StateError('denied');
      expect(await c.createView('X'), isNull);
      expect(stateOf(c).activeViewId, 'board');
      expect(await c.duplicateView('board'), isNull);
      expect(stateOf(c).activeViewId, 'board');
      expect(stateOf(c).collection.views.map((v) => v.id), ['all', 'board']);
    });

    test(
      'quickAddTitleField follows the view, else the first text field',
      () async {
        final c = await ready();
        expect(c.quickAddTitleField()?.id, 'name');
        await c.setFieldIds(['amount', 'name']);
        expect(c.quickAddTitleField()?.id, 'name');
      },
    );
  });

  group('final fixes', () {
    const priority = SingleSelectFieldDefinition(
      id: 'priority',
      name: 'Priority',
      options: [
        SelectOption(id: 'hi', label: 'High'),
        SelectOption(id: 'lo', label: 'Low'),
      ],
    );
    Collection withPriority(Collection c) =>
        c.copyWith(fields: [...c.fields, priority]);

    test('a field added in Build re-opens the objects stream', () async {
      final c = await ready();
      expect(repo.watchObjectsCalls['deals'], 1);
      final states = <CollectionViewsState>[];
      final sub = c.stream.listen(states.add);
      addTearDown(sub.cancel);
      await repo.saveCollection(withPriority(deals));
      await pumpEventQueue();
      expect(repo.watchObjectsCalls['deals'], 2);
      expect(states, everyElement(isA<ViewsReady>()));
      expect(stateOf(c).objects.first.values.containsKey('priority'), isTrue);
      // The same fields again: no new subscription.
      await repo.saveCollection(withPriority(deals).copyWith(name: 'Deals 2'));
      await pumpEventQueue();
      expect(repo.watchObjectsCalls['deals'], 2);
      await c.close();
      expect(repo.liveListeners, 0);
    });

    test('a move onto a field added in Build persists and sticks', () async {
      final c = await ready();
      await repo.saveCollection(withPriority(deals));
      await pumpEventQueue();
      await c.setLayoutField('priority');
      c.moveToGroup('d1', 'hi');
      await pumpEventQueue();
      expect(stored('d1')['priority'], const SingleSelectFieldValue('hi'));
      final hi = stateOf(c).groups!.firstWhere((g) => g.key == 'hi');
      expect([for (final o in hi.objects) o.id], ['d1']);
    });

    test('a target whose fields change is watched again', () async {
      final c = await ready();
      await pumpEventQueue();
      expect(repo.watchObjectsCalls['companies'], 1);
      await repo.saveCollection(
        companies.copyWith(
          fields: [
            ...companies.fields,
            const NumberFieldDefinition(id: 'size', name: 'Size'),
          ],
        ),
      );
      await pumpEventQueue();
      expect(repo.watchObjectsCalls['companies'], 2);
      expect(stateOf(c).referenceLabels['k2'], 'Alpha Ltd');
    });

    test(
      'a Build change between two unacknowledged view saves survives',
      () async {
        final c = await ready();
        repo.collectionAck = Completer<void>(); // offline: writes never ack
        unawaited(c.setSort(const ViewSort(fieldId: 'amount')));
        await pumpEventQueue();
        unawaited(repo.saveCollection(withPriority(deals)));
        await pumpEventQueue();
        unawaited(c.setFilters(const []));
        unawaited(c.renameView('all', 'Everything'));
        await pumpEventQueue();
        final storedDeals = (await repo.getCollection('deals'))!;
        expect(storedDeals.fieldById('priority'), isNotNull);
        expect(storedDeals.views.first.name, 'Everything');
        expect(storedDeals.views.first.sort?.fieldId, 'amount');
        expect(stateOf(c).collection.fieldById('priority'), isNotNull);
        expect(repo.saveCount, 1); // only Build's own save
      },
    );

    test('a failed objects stream stays failed until retry', () async {
      final c = await ready();
      repo.failObjects('deals', StateError('offline'));
      await pumpEventQueue();
      expect(c.state, isA<ViewsError>());
      await repo.saveCollection(deals.copyWith(name: 'Renamed'));
      await pumpEventQueue();
      expect(c.state, isA<ViewsError>());
      repo.seedObjects('deals', sampleDeals());
      await c.retry();
      await pumpEventQueue();
      expect(c.state, isA<ViewsReady>());
    });

    test('a failed deleteView keeps the selection and returns false', () async {
      final c = await ready();
      c.selectView('board');
      repo.saveError = () => StateError('denied');
      expect(await c.deleteView('board'), isFalse);
      expect(stateOf(c).activeViewId, 'board');
      expect(stateOf(c).collection.views.map((v) => v.id), ['all', 'board']);
      expect(stateOf(c).writeError, isNotNull);
    });

    test('undoing a move writes back only the moved field', () async {
      final c = await ready();
      c.selectView('board');
      final undo = c.moveToGroup('d1', 'won')!;
      await pumpEventQueue();
      // Someone renames it meanwhile.
      await repo.saveObject(
        stored(
          'd1',
        ).copyWith(values: {'name': const TextFieldValue('Renamed')}),
        schema: deals,
      );
      await pumpEventQueue();
      await undo();
      await pumpEventQueue();
      expect(stored('d1')['stage'], const SingleSelectFieldValue('lead'));
      expect(stored('d1')['name'], const TextFieldValue('Renamed'));
    });

    test('undoing a day move writes back only the date', () async {
      final c = await ready(
        seeded([deal('a', 0, name: 'A', due: DateTime.utc(2026, 5, 2))]),
      );
      await c.setLayoutField('due');
      final undo = c.moveToDay('a', DateTime(2026, 5, 9))!;
      await pumpEventQueue();
      await repo.saveObject(
        stored('a').copyWith(values: {'name': const TextFieldValue('B')}),
        schema: deals,
      );
      await pumpEventQueue();
      await undo();
      await pumpEventQueue();
      expect(stored('a')['due'], DateFieldValue(DateTime.utc(2026, 5, 2)));
      expect(stored('a')['name'], const TextFieldValue('B'));
    });
  });
}
