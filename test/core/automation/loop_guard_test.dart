import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/api/data/data_repository.dart';
import 'package:morkva_crm/core/automation/loop_guard.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';

var _writes = 0;

CardChange _change({
  WriteKind kind = WriteKind.ui,
  int depth = 0,
  List<String> chain = const [],
  String? commitId = 'commit_1',
  String? runId,
  String? writeId,
}) => CardChange(
  collectionId: 'c_orders',
  cardId: 'b_${_writes++}',
  before: null,
  after: null,
  writeId: writeId ?? 'w_${_writes++}',
  origin: WriteOrigin(
    kind: kind,
    depth: depth,
    chain: chain,
    commitId: commitId,
    runId: runId,
  ),
);

void main() {
  late DateTime now;
  late LoopGuard guard;

  setUp(() {
    now = DateTime.utc(2026, 11, 12, 12);
    guard = LoopGuard(now: () => now);
  });

  LoopVerdict check(
    String id,
    CardChange change, {
    int queued = 0,
    int total = 0,
  }) => guard.checkEvent(
    id,
    change,
    queuedOfAutomation: queued,
    queuedTotal: total,
  );

  RunReason? reasonOf(LoopVerdict v) => switch (v) {
    LoopRefused(:final reason) => reason,
    LoopAdmitted() => null,
  };

  test('an event run extends the change\'s depth and chain', () {
    final v = check(
      'a_2',
      _change(kind: WriteKind.automation, depth: 1, chain: ['a_1']),
    );
    expect(v, isA<LoopAdmitted>());
    expect(v.lineage.depth, 2);
    expect(v.lineage.chain, ['a_1', 'a_2']);

    final ui = check('a_1', _change());
    expect(ui.lineage.depth, 1);
    expect(ui.lineage.chain, ['a_1']);
  });

  test('once per (automation, writeId); not persisted', () {
    final c = _change();
    expect(check('a_1', c), isA<LoopAdmitted>());
    final again = check('a_1', c) as LoopRefused;
    expect(again.reason, RunReason.duplicate);
    expect(again.persist, isFalse);
    // Another automation may run on the same write.
    expect(check('a_2', c), isA<LoopAdmitted>());
  });

  test('the duplicate memory forgets the oldest key past 10,000', () {
    final first = _change();
    check('a_1', first);
    for (var i = 0; i < LoopGuard.kSeenCap; i++) {
      check('a_1', _change(commitId: 'c_$i'));
    }
    expect(check('a_1', first), isA<LoopAdmitted>());
  });

  test('re-entry: a direct self-trigger is not persisted and names its '
      'parent run; an indirect loop is', () {
    final direct =
        check(
              'a_1',
              _change(
                kind: WriteKind.automation,
                depth: 1,
                chain: ['a_1'],
                runId: 'run_9',
              ),
            )
            as LoopRefused;
    expect(direct.reason, RunReason.loop);
    expect(direct.persist, isFalse);
    expect(direct.parentRunId, 'run_9');

    final indirect =
        check(
              'a_1',
              _change(
                kind: WriteKind.automation,
                depth: 2,
                chain: ['a_1', 'a_2'],
              ),
            )
            as LoopRefused;
    expect(indirect.reason, RunReason.loop);
    expect(indirect.persist, isTrue);
    expect(indirect.lineage.chain, ['a_1', 'a_2', 'a_1']);
  });

  test('depth 3 runs, depth 4 is depth_limit', () {
    expect(
      check(
        'a_3',
        _change(kind: WriteKind.automation, depth: 2, chain: ['a_1', 'a_2']),
      ),
      isA<LoopAdmitted>(),
    );
    final v = check(
      'a_4',
      _change(
        kind: WriteKind.automation,
        depth: 3,
        chain: ['a_1', 'a_2', 'a_3'],
      ),
    );
    expect(reasonOf(v), RunReason.depthLimit);
    expect(v.lineage.depth, 4);
  });

  test('fan-out: 100 runs per automation per commit, across chunks; the rest '
      'are counted for one row', () {
    // Two 450-write chunks of one plan share its commitId.
    for (var i = 0; i < 100; i++) {
      expect(check('a_1', _change(commitId: 'plan_1')), isA<LoopAdmitted>());
    }
    final first = check('a_1', _change(commitId: 'plan_1')) as LoopRefused;
    expect(first.reason, RunReason.fanOut);
    expect(first.dropped, 1);
    final second = check('a_1', _change(commitId: 'plan_1')) as LoopRefused;
    expect(second.dropped, 2);

    // Per automation and per commit.
    expect(check('a_2', _change(commitId: 'plan_1')), isA<LoopAdmitted>());
    expect(check('a_1', _change(commitId: 'plan_2')), isA<LoopAdmitted>());
    // No commit id: no fan-out key.
    expect(check('a_1', _change(commitId: null)), isA<LoopAdmitted>());
  });

  test('a refused run does not count toward the fan-out cap', () {
    for (var i = 0; i < 100; i++) {
      check(
        'a_1',
        _change(commitId: 'p'),
        queued: LoopGuard.kQueuePerAutomation,
      );
    }
    expect(check('a_1', _change(commitId: 'p')), isA<LoopAdmitted>());
  });

  group('rate breaker', () {
    CardChange chained() => _change(
      kind: WriteKind.automation,
      depth: 1,
      chain: ['a_root'],
      commitId: null,
    );

    test('counts depth >= 2 runs only: 30 per automation pass, the 31st '
        'trips loop_suspected', () {
      for (var i = 0; i < 200; i++) {
        expect(check('a_1', _change(commitId: null)), isA<LoopAdmitted>());
      }
      for (var i = 0; i < 30; i++) {
        expect(check('a_1', chained()), isA<LoopAdmitted>(), reason: '$i');
      }
      expect(reasonOf(check('a_1', chained())), RunReason.loopSuspected);
      // Another automation has its own window.
      expect(check('a_2', chained()), isA<LoopAdmitted>());
    });

    test('the window slides over 60 s', () {
      for (var i = 0; i < 30; i++) {
        check('a_1', chained());
      }
      now = now.add(const Duration(seconds: 59));
      expect(reasonOf(check('a_1', chained())), RunReason.loopSuspected);
      now = now.add(const Duration(seconds: 1));
      expect(check('a_1', chained()), isA<LoopAdmitted>());
    });

    test('120 chained runs per workspace pass, the 121st trips', () {
      for (var i = 0; i < 120; i++) {
        expect(check('a_${i % 6}', chained()), isA<LoopAdmitted>());
      }
      expect(reasonOf(check('a_9', chained())), RunReason.loopSuspected);
    });

    test('resume starts the automation\'s window over', () {
      for (var i = 0; i < 30; i++) {
        check('a_1', chained());
      }
      guard.resume('a_1');
      expect(check('a_1', chained()), isA<LoopAdmitted>());
    });
  });

  test('queue caps: 100 per automation, 500 per workspace, buttons too', () {
    expect(
      check('a_1', _change(), queued: 99, total: 499),
      isA<LoopAdmitted>(),
    );
    expect(reasonOf(check('a_1', _change(), queued: 100)), RunReason.queueFull);
    expect(reasonOf(check('a_1', _change(), total: 500)), RunReason.queueFull);

    final button = guard.checkManual(
      'a_1',
      queuedOfAutomation: 0,
      queuedTotal: 0,
    );
    expect(button, isA<LoopAdmitted>());
    expect(button.lineage.depth, 1);
    expect(button.lineage.chain, ['a_1']);
    expect(
      reasonOf(
        guard.checkManual('a_1', queuedOfAutomation: 100, queuedTotal: 0),
      ),
      RunReason.queueFull,
    );
  });

  test('auto budget: 1,000 items per sliding 10 min', () {
    expect(guard.takeAutoBudget(600), isTrue);
    now = now.add(const Duration(minutes: 5));
    expect(guard.takeAutoBudget(400), isTrue);
    expect(guard.takeAutoBudget(1), isFalse);
    now = now.add(const Duration(minutes: 5));
    // The first 600 left the window.
    expect(guard.takeAutoBudget(600), isTrue);
    expect(guard.takeAutoBudget(1), isFalse);
  });

  test('reset forgets everything', () {
    final c = _change();
    check('a_1', c);
    expect(guard.takeAutoBudget(1000), isTrue);
    guard.reset();
    expect(check('a_1', c), isA<LoopAdmitted>());
    expect(guard.takeAutoBudget(1000), isTrue);
  });
}
