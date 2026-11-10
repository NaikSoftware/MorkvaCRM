import 'package:bloc_test/bloc_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/api/assistant/firestore_thread_repository.dart';
import 'package:morkva_crm/features/assistant/bloc/assistant_panel_cubit.dart';
import 'package:morkva_crm/features/assistant/bloc/thread_list_cubit.dart';

import 'assistant_rig.dart';

void main() {
  group('AssistantPanelCubit', () {
    final changes = <bool>[];

    blocTest<AssistantPanelCubit, bool>(
      'show / hide / toggle, telling the session each change once',
      setUp: changes.clear,
      build: () => AssistantPanelCubit(onChanged: changes.add),
      act: (cubit) => cubit
        ..show()
        ..show()
        ..toggle()
        ..toggle()
        ..hide(),
      expect: () => [true, false, true, false],
      verify: (_) => expect(changes, [true, false, true, false]),
    );

    test('the session keeps leased collections warm while open', () async {
      final rig = AssistantRig();
      await rig.start();
      rig.session.panel.show();
      expect(rig.session.cache.panelOpen, isTrue);
      rig.session.panel.hide();
      expect(rig.session.cache.panelOpen, isFalse);
      await rig.dispose();
    });
  });

  group('ThreadListCubit', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreThreadRepository threads;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      threads = FirestoreThreadRepository(firestore: firestore)
        ..initialize(workspaceId: workspaceId, uid: user.uid);
    });

    blocTest<ThreadListCubit, ThreadListState>(
      'lists the newest threads first and follows new ones',
      build: () => ThreadListCubit(threads),
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        await threads.checkpoint(
          't1',
          seq: 0,
          message: const {'status': 'done'},
          thread: const {'title': 'Older', 'updatedAt': '2026-11-09T10:00:00Z'},
        );
        await Future<void>.delayed(Duration.zero);
        await threads.checkpoint(
          't2',
          seq: 0,
          message: const {'status': 'done'},
          thread: const {'title': 'Newer', 'updatedAt': '2026-11-10T10:00:00Z'},
        );
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => [
        const ThreadListState(loading: false),
        isA<ThreadListState>().having(
          (s) => [for (final t in s.threads) t['title']],
          'titles',
          ['Older'],
        ),
        isA<ThreadListState>().having(
          (s) => [for (final t in s.threads) t['id']],
          'ids',
          ['t2', 't1'],
        ),
      ],
    );
  });
}
