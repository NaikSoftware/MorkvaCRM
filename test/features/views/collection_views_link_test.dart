import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/features/collections/util/id_generator.dart';
import 'package:morkva_crm/features/views/collection_views_cubit.dart';
import 'package:morkva_crm/features/views/collection_views_state.dart';
import 'package:morkva_crm/features/views/view_link.dart';

import '../collections/fake_data_repository.dart';
import 'views_fixtures.dart';

class _SeqIds extends IdGenerator {
  int _n = 0;
  @override
  String viewId() => 'v${++_n}';
}

const _wonOnly = ViewFilter(
  fieldId: 'stage',
  op: FilterOp.anyOf,
  operand: ['won', 'lead'],
);

void main() {
  late FakeDataRepository repo;

  CollectionViewsCubit cubitFor() {
    repo = FakeDataRepository([deals, companies]);
    repo.seedObjects('deals', sampleDeals());
    repo.seedObjects('companies', [
      company('k1', 'Zeta Corp', 0),
      company('k2', 'Alpha Ltd', 1),
    ]);
    final cubit = CollectionViewsCubit(
      repo,
      'deals',
      idGenerator: _SeqIds(),
      clock: () => DateTime(2026, 11, 10, 9),
    );
    addTearDown(cubit.close);
    return cubit;
  }

  ViewsReady stateOf(CollectionViewsCubit c) => c.state as ViewsReady;
  List<String> ids(CollectionViewsCubit c) => [
    for (final o in stateOf(c).objects) o.id,
  ];

  final stageWonOrLead = encodeLinkFilter([
    {
      'field': 'Stage',
      'op': 'anyOf',
      'value': ['Won', 'Lead'],
    },
  ]);

  test('a link opened before loading applies once the data is in', () async {
    final c = cubitFor();
    c.openLink(viewId: 'board', filter: stageWonOrLead);
    expect(c.state, isA<ViewsLoading>());
    c.initialize();
    await pumpEventQueue();
    final s = stateOf(c);
    expect(s.activeViewId, 'board');
    expect(s.transientFilters, [_wonOnly]);
    expect(s.effectiveFilters, [_wonOnly]);
    expect(ids(c), ['d1', 'd2', 'd3']);
    expect(s.totalCount, 5);
    // Not saved.
    expect(repo.saveViewsCount, 0);
    expect(s.activeView.filters, isEmpty);
  });

  test('a filter naming a card waits for that collection to load', () async {
    // The board neither shows nor filters on Company, so nothing else loads
    // the companies: resolving "Zeta Corp" before they arrive would fail.
    final c = cubitFor()
      ..openLink(
        viewId: 'board',
        filter: encodeLinkFilter([
          {'field': 'Company', 'op': 'anyOf', 'value': 'Zeta Corp'},
        ]),
      )
      ..initialize();
    await pumpEventQueue();
    expect(stateOf(c).activeViewId, 'board');
    expect(stateOf(c).transientFilters, [
      const ViewFilter(fieldId: 'company', op: FilterOp.anyOf, operand: ['k1']),
    ]);
    expect(ids(c), ['d2']);
    expect(stateOf(c).writeError, isNull);
  });

  test('an invalid filter is dropped and reported', () async {
    final c = cubitFor()..initialize();
    await pumpEventQueue();
    c.openLink(
      viewId: 'board',
      filter: encodeLinkFilter([
        {'field': 'Stage', 'op': 'anyOf', 'value': 'Nope'},
      ]),
    );
    final s = stateOf(c);
    expect(s.activeViewId, 'board');
    expect(s.transientFilters, isEmpty);
    expect(s.objects, hasLength(5));
    expect(s.writeError, "This link's filter isn't valid");
    expect(s.writeErrorSeq, 1);
  });

  test('an unknown view id keeps the current view', () async {
    final c = cubitFor()..initialize();
    await pumpEventQueue();
    c.openLink(viewId: 'nope', filter: stageWonOrLead);
    expect(stateOf(c).activeViewId, 'all');
    expect(stateOf(c).transientFilters, [_wonOnly]);
  });

  test('showing another view drops the transient filters', () async {
    final c = cubitFor()..initialize();
    await pumpEventQueue();
    c.openLink(filter: stageWonOrLead);
    expect(ids(c), ['d1', 'd2', 'd3']);
    c.selectView('board');
    expect(stateOf(c).transientFilters, isEmpty);
    c.selectView('all');
    expect(stateOf(c).transientFilters, isEmpty);
    expect(ids(c), hasLength(5));
  });

  test('a link with only a card keeps the transient filters', () async {
    final c = cubitFor()..initialize();
    await pumpEventQueue();
    c.openLink(filter: stageWonOrLead);
    c.openLink();
    expect(stateOf(c).transientFilters, [_wonOnly]);
  });

  test('clearTransientFilters shows the view as saved', () async {
    final c = cubitFor()..initialize();
    await pumpEventQueue();
    c.openLink(filter: stageWonOrLead);
    c.clearTransientFilters();
    expect(stateOf(c).transientFilters, isEmpty);
    expect(ids(c), hasLength(5));
  });

  test('saveTransientAsView saves a filtered copy and selects it', () async {
    final c = cubitFor()..initialize();
    await pumpEventQueue();
    c.openLink(viewId: 'board', filter: stageWonOrLead);
    final id = await c.saveTransientAsView();
    expect(id, 'v1');
    final s = stateOf(c);
    expect(s.activeViewId, 'v1');
    expect(s.transientFilters, isEmpty);
    expect(ids(c), ['d1', 'd2', 'd3']);
    final saved = (await repo.getCollection('deals'))!.views;
    expect([for (final v in saved) v.id], ['all', 'board', 'v1']);
    expect(saved.last.name, 'Pipeline · filtered');
    expect(saved.last.mode, ViewModeIds.board);
    expect(saved.last.layoutFieldId, 'stage');
    expect(saved.last.filters, [_wonOnly]);
  });

  test('a failed save keeps the transient filters on the view', () async {
    final c = cubitFor()..initialize();
    await pumpEventQueue();
    c.openLink(filter: stageWonOrLead);
    repo.saveError = () => StateError('offline');
    expect(await c.saveTransientAsView(), isNull);
    expect(stateOf(c).activeViewId, 'all');
    expect(stateOf(c).transientFilters, [_wonOnly]);
  });

  test('findObject finds a card the filters hide', () async {
    final c = cubitFor()..initialize();
    await pumpEventQueue();
    c.openLink(filter: stageWonOrLead);
    expect(stateOf(c).objectById('d4'), isNull);
    expect(c.findObject('d4')?.id, 'd4');
  });
}
