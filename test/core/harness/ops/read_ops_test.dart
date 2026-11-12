import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/core/harness/cache/result_store.dart';
import 'package:morkva_crm/core/harness/harness.dart';
import 'package:morkva_crm/core/harness/ops/read_ops.dart';
import 'package:morkva_crm/core/harness/query/result_shaper.dart';
import 'package:morkva_crm/core/harness/query/workspace_digest.dart';

import 'ops_fixture.dart';

void main() {
  late OpsHarness h;

  setUp(() => h = OpsHarness());
  tearDown(() => h.dispose());

  /// The unpaid orders whose labels match "dress" (the [unpaidDresses]
  /// screen), computed apart from the ops.
  Future<Set<String>> shownOnScreen() async {
    final snapshot = await h.q.cache.read(SeedIds.orders);
    final hits = {for (final hit in snapshot.labels.search('dress')) hit.id};
    return where(
      h.q.derived(SeedIds.orders),
      (o) =>
          (o[OrderFields.paid] as BooleanFieldValue).value != true &&
          hits.contains(o.id),
    ).toSet();
  }

  group('registration', () {
    test('registers the 8 read ops and ui.open, all model-visible with '
        'Gemini-valid names', () {
      expect(h.registry.ids, [
        'cards.aggregate',
        'cards.distinct',
        'cards.find',
        'cards.get',
        'cards.page',
        'cards.query',
        'collections.get',
        'ui.open',
        'workspace.describe',
      ]);
      for (final d in h.registry.descriptors) {
        expect(
          OperationRegistry.toolNamePattern.hasMatch(
            OperationRegistry.toolName(d.id),
          ),
          isTrue,
          reason: d.id,
        );
        expect(d.modelVisible, isTrue, reason: d.id);
        expect(d.kind, d.id == 'ui.open' ? OpKind.ui : OpKind.read);
        expect(d.capability, switch (d.id) {
          'ui.open' => Capability.uiNavigate,
          'workspace.describe' || 'collections.get' => Capability.schemaRead,
          _ => Capability.dataRead,
        });
      }
    });

    test('every card read but cards.page takes from "@screen" without a '
        'collection', () {
      for (final d in h.registry.descriptors) {
        if (!d.id.startsWith('cards.') || d.id == 'cards.page') continue;
        final props = d.argsSchema['properties']! as Map;
        expect(props['from'], isNotNull, reason: d.id);
        expect(
          (d.argsSchema['required'] as List?) ?? const [],
          isNot(contains('collection')),
          reason: d.id,
        );
      }
    });
  });

  group('workspace.describe', () {
    test('lists every collection; counts only where the cache holds the '
        'cards', () async {
      await h.q.cache.read(SeedIds.orders);

      final r = await h.ok('workspace.describe', const {});

      expect(r['apiVersion'], kHarnessVersion);
      expect(r['today'], '2026-11-10');
      final collections = (r['collections']! as List).cast<Map>();
      expect(
        [for (final c in collections) c['name']],
        ['Clients', 'Orders', 'Fabrics'],
      );
      final orders = collections[1];
      expect(orders['count'], 24);
      expect(collections[0].containsKey('count'), isFalse);
      final fields = {
        for (final f in (orders['fields']! as List).cast<Map>()) f['name']: f,
      };
      expect(fields['Status'], {
        'id': OrderFields.status,
        'name': 'Status',
        'type': 'single_select',
        'options': ['New', 'Packing', 'Shipped', 'Done'],
      });
      expect(fields['Client']!['target'], SeedIds.clients);
      expect(fields['Fabrics']!['multiple'], isTrue);
      expect(fields['No']!['readOnly'], isTrue);
      expect(fields['Total']!['calc'], '{Price} * {Qty}');
      expect(fields['Total']!['output'], 'number');
      expect(fields['Total']!['unit'], '₴');
      expect(
        orders['views'],
        contains(
          equals({'id': 'v_or_unpaid', 'name': 'Unpaid', 'mode': 'board'}),
        ),
      );
      expect(r['summary'], '3 collections');
      // It never leases what it describes.
      expect(h.q.repo.watchObjectsCalls.containsKey(SeedIds.clients), isFalse);
    });

    test('detail full adds option ids; collections narrows', () async {
      final r = await h.ok('workspace.describe', {
        'collections': ['orders'],
        'detail': 'full',
      });

      final collections = (r['collections']! as List).cast<Map>();
      expect(collections.single['id'], SeedIds.orders);
      final status = (collections.single['fields']! as List)
          .cast<Map>()
          .firstWhere((f) => f['id'] == OrderFields.status);
      expect((status['options']! as List).first, {
        'id': SeedOptions.statusNew,
        'label': 'New',
      });
    });

    test('collections outside the grants are invisible', () async {
      final grants = Grants(Capability.values, collections: [SeedIds.orders]);

      final r = await h.ok('workspace.describe', const {}, grants: grants);
      final orders = (r['collections']! as List).cast<Map>().single;
      expect(orders['id'], SeedIds.orders);
      final city = (orders['fields']! as List).cast<Map>().firstWhere(
        (f) => f['id'] == OrderFields.clientCity,
      );
      expect(city['redacted'], isTrue);
      expect(city.containsKey('calc'), isFalse);
      final client = (orders['fields']! as List).cast<Map>().firstWhere(
        (f) => f['id'] == OrderFields.client,
      );
      expect(client.containsKey('target'), isFalse);

      final error = await h.fails('workspace.describe', {
        'collections': ['Clients'],
      }, grants: grants);
      expect(error.code, ErrorCode.unknownCollection);
      expect(error.path, 'collections[0]');
    });

    test('a bad detail is refused by the schema', () async {
      final error = await h.fails('workspace.describe', {'detail': 'all'});
      expect(error.code, ErrorCode.invalidArgs);
      expect(error.path, 'detail');
    });
  });

  group('collections.get', () {
    test('the full schema with count, operators and name-form '
        'formulas', () async {
      final r = await h.ok('collections.get', {'collection': 'Orders'});

      expect(r['id'], SeedIds.orders);
      expect(r['count'], 24);
      expect(r.containsKey('layout'), isFalse);
      final fields = {
        for (final f in (r['fields']! as List).cast<Map>()) f['id']: f,
      };
      expect(fields.keys, containsAll([OrderFields.no, OrderFields.due]));
      expect(fields[OrderFields.total]!['expression'], '{Price} * {Qty}');
      expect(fields[OrderFields.total]!['declaredOutputType'], 'number');
      expect(fields[OrderFields.total]!['readOnly'], isTrue);
      expect(fields[OrderFields.paid]!['operators'], ['isTrue', 'isFalse']);
      expect(fields[OrderFields.status]!['operators'], [
        'anyOf',
        'noneOf',
        'isEmpty',
        'isNotEmpty',
      ]);
      expect(
        fields[OrderFields.client]!['targetCollectionId'],
        SeedIds.clients,
      );
      for (final v in (r['views']! as List).cast<Map>()) {
        expect(v.containsKey('manualOrder'), isFalse);
      }
      final unpaid = (r['views']! as List).cast<Map>().firstWhere(
        (v) => v['id'] == 'v_or_unpaid',
      );
      expect(unpaid['filters'], [
        {'fieldId': OrderFields.paid, 'op': 'isFalse'},
      ]);
      expect(r['summary'], startsWith('Orders: 20 fields, 24 cards'));
    });

    test('fields narrows by name; an unknown one gets candidates', () async {
      final r = await h.ok('collections.get', {
        'collection': 'Orders',
        'fields': ['status', 'Total'],
      });
      expect(
        [for (final f in (r['fields']! as List).cast<Map>()) f['name']],
        ['Status', 'Total'],
      );

      final error = await h.fails('collections.get', {
        'collection': 'Orders',
        'fields': ['Totl'],
      });
      expect(error.code, ErrorCode.unknownField);
      expect(error.path, 'fields[0]');
      expect(error.candidates, contains('Total'));
    });

    test('a field reading an ungranted collection is redacted', () async {
      final r = await h.ok('collections.get', {
        'collection': 'Orders',
      }, grants: Grants(Capability.values, collections: [SeedIds.orders]));
      final city = (r['fields']! as List).cast<Map>().firstWhere(
        (f) => f['id'] == OrderFields.clientCity,
      );
      expect(city['redacted'], isTrue);
      expect(city.containsKey('lookup'), isFalse);
    });

    test('a schema over the budget is cut, never silently', () async {
      final ops = OperationRegistry();
      registerReadOps(
        ops,
        queries: h.q.queries,
        aggregates: h.q.aggregates,
        thread: (_) => 't1',
        digest: const WorkspaceDigest(shaper: ResultShaper(schemaBudget: 2000)),
      );
      final r = await Harness(ops).call(
        const HarnessRequest(
          op: 'collections.get',
          args: {'collection': 'Orders'},
          callId: 'c1',
        ),
        context(),
      );

      final result = (r as HarnessOk).result;
      expect(r.meta.truncated, isTrue);
      expect(result['truncated'], isTrue);
      expect(result['hint'], contains('collections.get'));
      final kept = (result['fields']! as List).length;
      expect(kept + (result['moreFields']! as List).length, 20);
    });

    test('a collection is required', () async {
      final error = await h.fails('collections.get', const {});
      expect(error.code, ErrorCode.invalidArgs);
    });
  });

  group('card reads through the harness', () {
    test('cards.query from the screen, with present', () async {
      final expected = await shownOnScreen();

      final r = await h.ok('cards.query', {
        'from': '@screen',
        'limit': 100,
        'present': 'table',
      }, focus: unpaidDresses());

      expect(r['total'], expected.length);
      expect(idsOf(r['rows']).toSet(), expected);
      expect(r['handle'], isA<String>());
    });

    test('cards.query rejects unknown args before running', () async {
      final error = await h.fails('cards.query', {
        'collection': 'Orders',
        'filter': const [],
      });
      expect(error.code, ErrorCode.invalidArgs);
      expect(error.path, 'filter');
    });

    test('cards.page pages the handle of the current thread only', () async {
      final first = await h.ok('cards.query', {
        'collection': 'Orders',
        'limit': 10,
      });
      final next = await h.ok('cards.page', {
        'handle': first['handle'],
        'cursor': first['nextCursor'],
      });
      expect(next['handle'], first['handle']);
      expect(next['rows'], hasLength(10));

      h.thread = 't2';
      final error = await h.fails('cards.page', {
        'handle': first['handle'],
        'cursor': first['nextCursor'],
      });
      expect(error.code, ErrorCode.invalidArgs);
      expect(error.path, 'handle');
    });

    test('cards.get reads the open card from the screen', () async {
      final r = await h.ok('cards.get', {
        'from': '@screen',
        'ids': ['@card'],
      }, focus: unpaidDresses(openCardId: SeedCards.order(1003)));
      expect(idsOf(r['rows']), [SeedCards.order(1003)]);
      expect(r['missing'], isEmpty);
    });

    test('cards.find from the screen searches only the shown cards', () async {
      final shown = await shownOnScreen();
      final snapshot = await h.q.cache.read(SeedIds.orders);
      final everywhere = {
        for (final hit in snapshot.labels.search('linen')) hit.id,
      };

      final r = await h.ok('cards.find', {
        'text': 'linen',
        'from': '@screen',
        'limit': 20,
      }, focus: unpaidDresses());

      final hits = (r['hits']! as List).cast<Map>();
      final ids = {for (final hit in hits) hit['id']};
      expect(ids, everywhere.intersection(shown));
      expect(ids.length, lessThan(everywhere.length));
      expect(hits.first['collection'], SeedIds.orders);
      expect(hits.first['matchedField'], isA<String>());
      expect(r['searched'], [SeedIds.orders]);
    });

    test('cards.find takes from or collections, not both; nothing on '
        'screen is invalid_args', () async {
      final both = await h.fails('cards.find', {
        'text': 'linen',
        'from': '@screen',
        'collections': ['Orders'],
      }, focus: unpaidDresses());
      expect(both.code, ErrorCode.invalidArgs);
      expect(both.path, 'collections');

      final blank = await h.fails('cards.find', {
        'text': 'linen',
        'from': '@screen',
      });
      expect(blank.code, ErrorCode.invalidArgs);
      expect(blank.path, 'from');
    });

    test('cards.find without from searches the named collections', () async {
      final r = await h.ok('cards.find', {
        'text': 'Olena',
        'collections': ['Clients'],
      });
      expect((r['hits']! as List).cast<Map>().first['id'], SeedCards.olena);
    });

    test('cards.aggregate from the screen, grouped, with a chart', () async {
      final expected = await shownOnScreen();

      final r = await h.ok('cards.aggregate', {
        'from': '@screen',
        'groupBy': {'field': 'Status'},
        'metrics': [
          {'op': 'count'},
          {'op': 'sum', 'field': 'Total'},
        ],
        'present': 'bar',
      }, focus: unpaidDresses());

      expect(r['total'], expected.length);
      expect(r['handle'], isA<String>());
      final counted = (r['groups']! as List).cast<Map>().fold<int>(
        0,
        (sum, g) => sum + (g['count'] as int),
      );
      expect(counted, expected.length);
    });

    test('cards.aggregate checks metric ops in the schema', () async {
      final error = await h.fails('cards.aggregate', {
        'collection': 'Orders',
        'metrics': [
          {'op': 'median', 'field': 'Total'},
        ],
      });
      expect(error.code, ErrorCode.invalidArgs);
      expect(error.path, 'metrics[0].op');
    });

    test('cards.distinct from the screen', () async {
      final expected = await shownOnScreen();

      final r = await h.ok('cards.distinct', {
        'from': '@screen',
        'field': 'Status',
      }, focus: unpaidDresses());

      expect(r['total'], expected.length);
      final values = (r['values']! as List).cast<Map>();
      expect(
        values.fold<int>(0, (n, v) => n + (v['count'] as int)) +
            ((r['empty'] as int?) ?? 0),
        expected.length,
      );
    });

    test('reads need data:read', () async {
      final error = await h.fails('cards.query', {
        'collection': 'Orders',
      }, grants: Grants([Capability.schemaRead]));
      expect(error.code, ErrorCode.notPermitted);
    });
  });
  group('result threads and pools', () {
    test('the thread is read from each call\'s context', () async {
      final ops = OperationRegistry();
      registerReadOps(
        ops,
        queries: h.q.queries,
        aggregates: h.q.aggregates,
        thread: (ctx) =>
            ctx.actor.kind == ActorKind.plugin ? 'run:${ctx.actor.id}' : 't1',
      );
      final harness = Harness(ops);
      Future<String> handleAs(Actor actor) async {
        final r = await harness.call(
          const HarnessRequest(
            op: 'cards.query',
            args: {'collection': 'Orders'},
            callId: 'c1',
          ),
          HarnessContext(
            workspaceId: 'w1',
            actor: actor,
            grants: Grants(kModuleGrantable),
            now: DateTime(2026, 11, 10, 14, 30),
            today: today,
          ),
        );
        return (r as HarnessOk).result['handle']! as String;
      }

      final chat = await handleAs(Actor.assistant);
      final run = await handleAs(const Actor.plugin('invoices'));

      expect(h.q.results.get(chat, thread: 't1'), isNotNull);
      expect(h.q.results.get(run, thread: 'run:invoices'), isNotNull);
      expect(h.q.results.get(run, thread: 't1'), isNull);
    });

    test('module runs and chats never evict each other\'s handles', () {
      final store = ResultStore(perThread: 2, capacity: 3, runCapacity: 2);
      String put(String thread, int n) => store
          .put(
            thread: thread,
            spec: {'n': n},
            generations: const {},
            orderedIds: const [],
          )
          .handle;

      final chats = [put('t1', 1), put('t1', 2), put('t2', 3)];
      final runs = [for (var i = 0; i < 5; i++) put('run:r${i % 3}', i)];

      expect(chats.every((c) => store.get(c) != null), isTrue);
      expect(
        [for (final r in runs) store.get(r) != null],
        [false, false, false, true, true],
      );

      put('t3', 4);
      expect(store.get(chats.first), isNull, reason: 'the oldest chat goes');
      expect(store.get(runs.last), isNotNull);
      expect(store.length, 5);

      store.dropThread('run:r1');
      expect(store.get(runs[4]), isNull);
      expect(store.get(runs[3]), isNotNull);
    });
  });
}
