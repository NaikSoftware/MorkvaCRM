import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/core/harness/cache/workspace_cache.dart';
import 'package:morkva_crm/core/harness/input/ref_resolver.dart';
import 'package:morkva_crm/core/harness/query/cache_workspace_reader.dart';

import 'query_fixture.dart';

void main() {
  final seed = SeedWorkspace();
  late WorkspaceCache cache;
  late WorkspaceReader reader;

  setUp(() async {
    cache = WorkspaceCache(seed.repository())..initialize('w1');
    reader = CacheWorkspaceReader(cache);
    await cache.ready;
  });
  tearDown(() => cache.reset());

  test('collections come with their lookups resolved', () {
    final orders = reader.collections.firstWhere((c) => c.id == SeedIds.orders);
    final city =
        orders.fieldById(OrderFields.clientCity)! as CalculatedFieldDefinition;
    expect(city.outputField, isA<SingleSelectFieldDefinition>());
  });

  test('cards are those of held collections; others read empty', () async {
    expect(reader.objectsOf(SeedIds.orders), isEmpty);
    final lease = await cache.lease([SeedIds.orders]);
    addTearDown(lease.release);
    expect(reader.objectsOf(SeedIds.orders), hasLength(24));
    expect(reader.objectsOf(SeedIds.clients), isEmpty);
  });

  test(
    'a ref resolver over it resolves card titles of leased collections',
    () async {
      final lease = await cache.lease([SeedIds.clients]);
      addTearDown(lease.release);
      final refs = RefResolver(reader, context());
      final clients = refs.collection('Clients');
      expect(refs.card(clients, 'olena bondar'), SeedCards.olena);
    },
  );
}
