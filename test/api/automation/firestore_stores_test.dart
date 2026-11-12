import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/api/automation/firestore_automation_store.dart';
import 'package:morkva_crm/api/automation/firestore_docs.dart';
import 'package:morkva_crm/api/automation/firestore_grant_store.dart';
import 'package:morkva_crm/api/automation/firestore_module_store.dart';
import 'package:morkva_crm/api/automation/firestore_run_store.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';

import '../../core/domain/automation/fixtures.dart';

const _wid = 'ws-1';
const _uid = 'u1';
const _code = 'export const actions = {};';

RunRecord _run(
  String id, {
  required DateTime startedAt,
  RunStatus status = RunStatus.succeeded,
  RunReason? reason,
  int count = 1,
}) => RunRecord(
  id: id,
  status: status,
  reason: reason,
  moduleId: 'stamp-shipped-date',
  moduleName: 'Stamp shipped date',
  moduleVersion: '1.0.0',
  codeHash: 'sha256:abc',
  actionId: 'stamp',
  actionLabel: 'Stamp shipped date',
  automationId: 'a_1',
  automationName: 'Stamp date when shipped',
  trigger: RunTrigger(
    kind: TriggerKind.cardUpdated,
    collectionId: 'c_orders',
    cardId: 'b_1',
    cardLabel: '#1042',
    changedFields: const ['f_status'],
    before: const {'f_status': 'o_packed'},
    changedAt: startedAt,
  ),
  params: const {'dateField': 'f_shipped'},
  apply: ApplyMode.ask,
  by: 'user:$_uid',
  device: 'web',
  sessionId: 't_1',
  chain: const ['a_1'],
  count: count,
  startedAt: startedAt,
  endedAt: startedAt.add(const Duration(milliseconds: 412)),
  durationMs: 412,
  log: const RunLog(
    triggerEval: 'whereB=false whereA=true changed=[Status]',
    plan: [
      PlanLine(
        kind: 'updateCard',
        label: '#1042',
        change: 'Shipped on: — → 2026-11-12',
      ),
    ],
  ),
);

void main() {
  late FakeFirebaseFirestore firestore;
  late AutomationWorkspace workspace;

  CollectionReference<Map<String, dynamic>> raw(String path) =>
      firestore.collection('workspaces').doc(_wid).collection(path);

  CollectionReference<Map<String, dynamic>> rawGrants() =>
      raw('members').doc(_uid).collection('grants');

  setUp(() {
    firestore = FakeFirebaseFirestore();
    workspace = AutomationWorkspace(firestore: firestore)
      ..initialize(workspaceId: _wid);
  });

  test('a store used before initialize throws', () {
    final unbound = FirestoreModuleStore(
      AutomationWorkspace(firestore: firestore),
    );
    expect(() => unbound.get('x'), throwsStateError);
  });

  group('FirestoreModuleStore', () {
    late FirestoreModuleStore store;
    late ModuleRecord module;

    setUp(() {
      store = FirestoreModuleStore(workspace);
      module = ModuleRecord.fromBundle(
        ModuleBundle.of(stampManifest(), _code),
        source: ModuleSource.import,
        createdBy: 'user:$_uid',
        now: fixtureNow,
      );
    });

    test('round trips with dates stored as Timestamps', () async {
      await store.save(module);

      expect(await store.get(module.id), module);
      final doc = (await raw('modules').doc(module.id).get()).data()!;
      expect(doc['createdAt'], Timestamp.fromDate(fixtureNow));
      expect(doc['manifest'], stampManifest());
      expect(await store.watch().first, [module]);
    });

    test('a malformed doc reads as absent and is left out of watch', () async {
      await store.save(module);
      await raw('modules').doc('bad').set({'schema': 1, 'code': 42});

      expect(await store.get('bad'), isNull);
      expect(await store.get('missing'), isNull);
      expect(await store.watch().first, [module]);
    });

    test('delete removes the doc', () async {
      await store.save(module);
      await store.delete(module.id);
      expect(await store.get(module.id), isNull);
    });
  });

  group('FirestoreAutomationStore', () {
    late FirestoreAutomationStore store;

    setUp(() => store = FirestoreAutomationStore(workspace));

    test('round trips an event automation', () async {
      final event = automation(apply: ApplyMode.auto, autoBy: _uid);
      await store.save(event);

      expect(await store.get('a_1'), event);
      expect(await store.watch().first, [event]);
      final doc = (await raw('automations').doc('a_1').get()).data()!;
      expect(doc['updatedAt'], Timestamp.fromDate(fixtureNow));
    });

    test('save replaces the doc; delete removes it', () async {
      await store.save(automation());
      final button = automation(
        trigger: const ButtonTrigger(
          scope: ButtonScope.card,
          collectionId: 'c_orders',
        ),
      );
      await store.save(button);

      expect(await store.get('a_1'), button);
      final doc = (await raw('automations').doc('a_1').get()).data()!;
      expect((doc['trigger'] as Map).containsKey('where'), isFalse);

      await store.delete('a_1');
      expect(await store.watch().first, isEmpty);
    });

    test('an auto automation without autoBy reads as absent', () async {
      final json = automation().toJson()..['apply'] = 'auto';
      await raw('automations').doc('a_2').set(encodeDoc(json));
      expect(await store.get('a_2'), isNull);
      expect(await store.watch().first, isEmpty);
    });
  });

  group('FirestoreGrantStore', () {
    late FirestoreGrantStore store;

    setUp(() => store = FirestoreGrantStore(workspace));

    test('round trips under the member, null collections included', () async {
      final all = consent().copyWith(collections: () => null);
      await store.save(_uid, all);

      expect(await store.get(_uid, all.moduleId), all);
      final doc = (await rawGrants().doc(all.moduleId).get()).data()!;
      expect(doc.containsKey('collections'), isTrue);
      expect(doc['grantedAt'], Timestamp.fromDate(fixtureNow));
      expect(await store.watch(_uid).first, {all.moduleId: all});
      expect(await store.get('someone-else', all.moduleId), isNull);

      await store.delete(_uid, all.moduleId);
      expect(await store.get(_uid, all.moduleId), isNull);
    });

    final malformed = <String, Map<String, Object?> Function()>{
      'caps "*"': () => encodeDoc(consent().toJson()..['caps'] = '*'),
      'an unknown capability': () =>
          encodeDoc(consent().toJson()..['caps'] = ['data:read', 'hostCommit']),
      'auto-apply from an assistant plan': () => encodeDoc(
        consent().toJson()
          ..['via'] = 'assistant_plan'
          ..['autoApply'] = true,
      ),
      'no collections key': () =>
          encodeDoc(consent().toJson()..remove('collections')),
      'a moduleId other than the doc id': () =>
          encodeDoc(consent().toJson()..['moduleId'] = 'other'),
    };
    for (final MapEntry(key: name, value: doc) in malformed.entries) {
      test('$name is no consent', () async {
        await rawGrants().doc('stamp-shipped-date').set(doc());
        expect(await store.get(_uid, 'stamp-shipped-date'), isNull);
        expect(await store.watch(_uid).first, isEmpty);
      });
    }
  });

  group('FirestoreRunStore', () {
    late FirestoreRunStore store;

    setUp(() => store = FirestoreRunStore(workspace));

    test('round trips with nested dates as Timestamps', () async {
      final run = _run('run_1', startedAt: fixtureNow);
      await store.create(run);

      expect(await store.get('run_1'), run);
      final doc = (await raw('runs').doc('run_1').get()).data()!;
      expect(doc['startedAt'], Timestamp.fromDate(fixtureNow));
      expect(
        (doc['trigger'] as Map)['changedAt'],
        Timestamp.fromDate(fixtureNow),
      );
      expect(doc['log'], isA<String>());

      await raw('runs').doc('run_2').set({...doc, 'status': 'running'});
      expect(await store.get('run_2'), isNull);
      expect(await store.watchRecent().first, [run]);
    });

    test('a coalesced row update writes count and endedAt only', () async {
      final run = _run(
        'run_1',
        startedAt: fixtureNow,
        status: RunStatus.skipped,
        reason: RunReason.reviewBacklog,
      );
      await store.create(run);
      final before = (await raw('runs').doc('run_1').get()).data()!;
      // Fields not named must not be written, even when they differ.
      final later = fixtureNow.add(const Duration(minutes: 5));
      final bumped = run.copyWith(
        count: 2,
        endedAt: () => later,
        summary: () => 'not written',
      );

      await store.update(bumped, fields: {'count', 'endedAt'});

      final after = (await raw('runs').doc('run_1').get()).data()!;
      expect(after['count'], 2);
      expect(after['endedAt'], Timestamp.fromDate(later));
      expect(
        {...after}..removeWhere((k, _) => k == 'count' || k == 'endedAt'),
        {...before}..removeWhere((k, _) => k == 'count' || k == 'endedAt'),
      );
    });

    test('applyStartedAt is set and cleared', () async {
      final run = _run(
        'run_1',
        startedAt: fixtureNow,
        status: RunStatus.awaitingReview,
      );
      await store.create(run);
      final applying = run.copyWith(applyStartedAt: () => fixtureNow);

      await store.update(applying, fields: {'applyStartedAt'});
      expect((await store.get('run_1'))!.applyStartedAt, fixtureNow);

      await store.update(
        applying.copyWith(applyStartedAt: () => null),
        fields: {'applyStartedAt'},
      );
      final doc = (await raw('runs').doc('run_1').get()).data()!;
      expect(doc.containsKey('applyStartedAt'), isTrue);
      expect(doc['applyStartedAt'], isNull);
    });

    test('watchRecent loads the newest 200 by startedAt', () async {
      for (var i = 0; i < RunStore.kWindow + 1; i++) {
        await store.create(
          _run('run_$i', startedAt: fixtureNow.add(Duration(minutes: i))),
        );
      }

      final recent = await store.watchRecent().first;
      expect(recent, hasLength(RunStore.kWindow));
      expect(recent.first.id, 'run_${RunStore.kWindow}');
      expect(recent.last.id, 'run_1');
    });

    group('prune', () {
      Future<void> seed(int n, RunStatus Function(int i) statusOf) async {
        for (var i = 0; i < n; i++) {
          await store.create(
            _run(
              'run_$i',
              startedAt: fixtureNow.add(Duration(minutes: i)),
              status: statusOf(i),
            ),
          );
        }
      }

      Future<Set<String>> ids() async => {
        for (final d in (await raw('runs').get()).docs) d.id,
      };

      test('does nothing within the window', () async {
        await seed(5, (_) => RunStatus.succeeded);
        expect(await store.prune(keep: 5), 0);
        expect(await ids(), hasLength(5));
      });

      test('drops the oldest succeeded and skipped rows first', () async {
        // Oldest first: failed, awaiting_review, applying, then 5 plain rows.
        await seed(
          8,
          (i) => switch (i) {
            0 => RunStatus.failed,
            1 => RunStatus.awaitingReview,
            2 => RunStatus.applying,
            4 => RunStatus.skipped,
            _ => RunStatus.succeeded,
          },
        );

        expect(await store.prune(keep: 5), 3);

        expect(await ids(), {'run_0', 'run_1', 'run_2', 'run_6', 'run_7'});
      });

      test(
        'then the oldest failed and awaiting rows, never applying',
        () async {
          await seed(
            6,
            (i) => switch (i) {
              0 => RunStatus.applying,
              1 => RunStatus.failed,
              5 => RunStatus.succeeded,
              _ => RunStatus.awaitingReview,
            },
          );

          expect(await store.prune(keep: 3), 3);

          expect(await ids(), {'run_0', 'run_3', 'run_4'});
        },
      );

      test('reads past a full window of 200', () async {
        await seed(RunStore.kWindow + 3, (i) {
          return i == 0 ? RunStatus.failed : RunStatus.succeeded;
        });

        expect(await store.prune(), 3);

        final left = await ids();
        expect(left, hasLength(RunStore.kWindow));
        expect(left, containsAll(['run_0', 'run_4']));
        expect(left, isNot(contains('run_3')));
      });
    });
  });
}
