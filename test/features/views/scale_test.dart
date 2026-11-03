import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/api/data/firestore_data_repository.dart';
import 'package:morkva_crm/api/firestore/firestore_value_codec_impl.dart';
import 'package:morkva_crm/api/sync/sync_status_cubit.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/features/views/views.dart';

import 'views_fixtures.dart';
import 'work_page_harness.dart';

/// Every mode builds widgets only for what is on screen, so a collection of
/// thousands stays smooth: the built titles stay bounded at 3000 deals.
void main() {
  final now = DateTime.now();
  // Spread over the stages (and none) and the days of the current month.
  final many = [
    for (var i = 0; i < 3000; i++)
      deal(
        'd$i',
        i,
        name: 'Deal $i',
        amount: i,
        stage: const ['lead', 'won', 'lost', null][i % 4],
        due: DateTime.utc(now.year, now.month, 1 + i % 28),
      ),
  ];

  int builtTitles() => find.textContaining('Deal ').evaluate().length;

  testWidgets('3000 objects: every mode builds only what is in view', (
    tester,
  ) async {
    final cubit = await pumpWorkPage(
      tester,
      repository: workRepository(objects: many),
    );
    await tester.pumpAndSettle();
    expect((cubit.state as ViewsReady).objects, hasLength(3000));
    expect(builtTitles(), inInclusiveRange(1, 60), reason: 'table');

    cubit.selectView('board');
    await tester.pumpAndSettle();
    expect(
      find.byType(ObjectCard).evaluate().length,
      inInclusiveRange(4, 100),
      reason: 'board',
    );

    await cubit.createView('List', mode: ViewModeIds.list);
    await tester.pumpAndSettle();
    expect(builtTitles(), inInclusiveRange(1, 60), reason: 'list');

    await cubit.setLayoutField('stage');
    await tester.pumpAndSettle();
    expect(builtTitles(), inInclusiveRange(1, 60), reason: 'grouped list');

    await cubit.setMode(ViewModeIds.calendar, layoutFieldId: 'due');
    await tester.pumpAndSettle();
    // A month grid caps each day's pills ("+N more").
    expect(builtTitles(), inInclusiveRange(1, 200), reason: 'calendar');
  });
  test('a one-object change re-decodes that object only', () async {
    final codec = _CountingCodec();
    final sync = SyncStatusCubit();
    addTearDown(sync.close);
    final repository = FirestoreDataRepository(
      firestore: FakeFirebaseFirestore(),
      syncStatus: sync,
      codec: codec,
    );
    await repository.initialize('ws');
    addTearDown(repository.dispose);
    await repository.saveCollection(deals);
    for (final o in many.take(300)) {
      await repository.saveObject(o, schema: deals);
    }
    final cubit = CollectionViewsCubit(repository, 'deals')..initialize();
    addTearDown(cubit.close);
    final before =
        await cubit.stream
                .where((s) => s is ViewsReady && s.totalCount == 300)
                .first
            as ViewsReady;

    cubit.selectView('board');
    codec.decodes = 0;
    cubit.moveToGroup('d1', 'lost');
    await pumpEventQueue();
    final after = cubit.state as ViewsReady;

    expect(
      after.objectById('d1')?['stage'],
      const SingleSelectFieldValue('lost'),
    );
    expect(codec.decodes, deals.fields.length);
    final kept = {for (final o in before.objects) o.id: o};
    expect(
      after.objects.where((o) => o.id != 'd1' && !identical(o, kept[o.id])),
      isEmpty,
    );
  });
}

/// The standard codec, counting [decode] calls.
class _CountingCodec extends FirestoreValueCodecImpl {
  int decodes = 0;

  @override
  Object? decode(FieldDefinition field, Object? firestoreValue) {
    decodes++;
    return super.decode(field, firestoreValue);
  }
}
