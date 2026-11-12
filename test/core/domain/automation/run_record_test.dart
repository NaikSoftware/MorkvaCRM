import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';

final _start = DateTime.utc(2026, 11, 12, 10);

RunRecord run({
  RunStatus status = RunStatus.succeeded,
  RunLog log = RunLog.empty,
  String? planTitle,
  Map<String, Object?>? before,
  Map<String, Object?>? params,
  String? summary,
  RunError? error,
  List<String> touched = const [],
}) => RunRecord(
  id: 'run_1',
  status: status,
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
    before: before ?? const {'f_status': 'o_packed'},
    changedAt: _start,
  ),
  params: params ?? const {'dateField': 'f_shipped'},
  apply: ApplyMode.ask,
  by: 'user:u1',
  device: 'web',
  sessionId: 't_1',
  chain: const ['a_1'],
  startedAt: _start,
  endedAt: _start.add(const Duration(milliseconds: 412)),
  durationMs: 412,
  planId: 'p_1',
  planTitle: planTitle ?? 'Set Shipped on to today · 1 order',
  receipt: const RunReceipt(applied: 1),
  journalId: 'j_1',
  touchedCardIds: touched,
  summary: summary ?? 'Stamped #1042',
  error: error,
  log: log,
);

RunLog bigLog(int n) => RunLog(
  triggerEval: 'whereB=false whereA=true changed=[Status]',
  plan: [
    for (var i = 0; i < n; i++)
      PlanLine(
        kind: 'updateCard',
        label: '#$i',
        change: 'Shipped on: — → 2026-11-12',
      ),
  ],
  calls: [
    for (var i = 0; i < n; i++)
      RunCall(
        t: i,
        op: 'cards.update',
        kind: 'plan',
        args: 'x' * 400,
        ok: true,
        result: 'planned 1 item',
        ms: 4,
      ),
  ],
  console: [
    for (var i = 0; i < n; i++)
      ConsoleLine(t: i, level: 'info', text: 'line $i ${'y' * 600}'),
  ],
  ui: const [UiLink(kind: 'open', ref: 'b_1', label: '#1042')],
  policy: 'review: 23 items > 20',
);

int _bytes(String s) => utf8.encode(s).length;

int _docBytes(Map<String, Object?> doc) => _bytes(
  jsonEncode(doc, toEncodable: (o) => (o as DateTime).toIso8601String()),
);

void main() {
  test('a run round-trips, log included', () {
    final r = run(log: bigLog(3));
    final json = r.toJson();
    expect(json['log'], isA<String>());
    expect(json['status'], 'succeeded');
    final back = RunRecord.fromJson('run_1', json);
    // The log comes back cut to its caps.
    expect(back.log.calls.first.args, hasLength(300));
    expect(back.log.console.first.text, hasLength(500));
    expect(back.log.calls.first.args, endsWith('…'));
    expect(back.copyWith(log: r.log), r);
  });

  test('live statuses never reach a doc', () {
    for (final s in [RunStatus.queued, RunStatus.running, RunStatus.sealing]) {
      expect(() => run(status: s).toJson(), throwsStateError);
    }
    final json = run().toJson()..['status'] = 'running';
    expect(() => RunRecord.fromJson('run_1', json), throwsFormatException);
    expect(
      () => RunRecord.fromJson('run_1', run().toJson()..['reason'] = 'nope'),
      throwsFormatException,
    );
  });

  test('copyWith can clear nullable fields', () {
    final r = run(
      status: RunStatus.awaitingReview,
    ).copyWith(applyStartedAt: () => _start);
    expect(r.applyStartedAt, _start);
    expect(r.copyWith(applyStartedAt: () => null).applyStartedAt, isNull);
  });

  test('a malformed log reads as empty', () {
    expect(decodeRunLog('not json'), RunLog.empty);
    expect(decodeRunLog('{"calls": 1}'), RunLog.empty);
    expect(decodeRunLog(null), RunLog.empty);
  });

  group('log encoder', () {
    test('fills to 64 KB in order and counts the rest', () {
      final log = bigLog(200);
      final encoded = encodeRunLog(log);
      expect(_bytes(encoded), lessThanOrEqualTo(kRunLogMaxBytes));
      expect(_bytes(encoded), greaterThan(kRunLogMaxBytes - 1200));
      final back = decodeRunLog(encoded);
      expect(back.triggerEval, log.triggerEval);
      expect(back.policy, log.policy);
      expect(back.ui, log.ui);
      // Plan rows are capped at 50 and come first.
      expect(back.plan, hasLength(50));
      expect(back.calls.length + back.dropped.calls, 200);
      expect(back.console.length + back.dropped.console, 200);
      expect(back.dropped.plan, 150);
      expect(back.dropped.console, greaterThan(0));
      // Kept entries are the earliest ones.
      expect(back.calls.map((c) => c.t), [
        for (var i = 0; i < back.calls.length; i++) i,
      ]);
    });

    test('keeps drops the bridge already counted', () {
      final back = decodeRunLog(
        encodeRunLog(
          const RunLog(dropped: RunLogDropped(calls: 2, console: 3)),
        ),
      );
      expect(back.dropped, const RunLogDropped(calls: 2, console: 3));
    });

    test('a tiny budget still yields valid JSON with the counts', () {
      final encoded = encodeRunLog(bigLog(5), maxBytes: 64);
      final back = decodeRunLog(encoded);
      expect(back.calls, isEmpty);
      expect(back.dropped, const RunLogDropped(calls: 5, console: 5, plan: 5));
    });

    test('multi-byte text is budgeted in UTF-8 bytes', () {
      final log = RunLog(
        console: [
          for (var i = 0; i < 400; i++)
            ConsoleLine(t: i, level: 'info', text: 'ї' * 500),
        ],
      );
      expect(_bytes(encodeRunLog(log)), lessThanOrEqualTo(kRunLogMaxBytes));
    });
  });

  group('field caps', () {
    test('summary, error, touched ids, plan title', () {
      final json = run(
        summary: 's' * 300,
        error: RunError(
          code: 'module_error',
          message: 'm' * 2000,
          stack: 'k' * 5000,
        ),
        touched: [for (var i = 0; i < 80; i++) 'b_$i'],
      ).toJson();
      expect(json['summary'] as String, hasLength(kRunSummaryMaxChars));
      final error = json['error']! as Map<String, Object?>;
      expect(error['message'] as String, hasLength(kRunErrorMessageMaxChars));
      expect(error['stack'] as String, hasLength(kRunErrorStackMaxChars));
      expect(json['touchedCardIds'] as List, hasLength(kRunTouchedMax));
    });

    test(
      'before values over 2 KB are left out, the rest kept within 16 KB',
      () {
        final json = run(
          before: {
            'f_big': 'x' * 3000,
            for (var i = 0; i < 20; i++) 'f_$i': 'y' * 1000,
          },
        ).toJson();
        final before =
            (json['trigger']! as Map<String, Object?>)['before']! as Map;
        expect(before.containsKey('f_big'), isFalse);
        expect(before, isNotEmpty);
        expect(
          _bytes(jsonEncode(before)),
          lessThanOrEqualTo(kRunBeforeMaxBytes),
        );
      },
    );

    test('params over 4 KB are dropped', () {
      expect(run(params: {'p': 'x' * 5000}).toJson()['params'], isNull);
    });
  });

  test('the whole doc stays within 200 KB: the log goes first', () {
    final json = run(log: bigLog(200), planTitle: 'x' * 150 * 1024).toJson();
    // planTitle is cut; force the cap with a huge automation-independent field.
    expect(json['planTitle'] as String, hasLength(200));
    final huge = run(log: bigLog(200), summary: 'ok')
        .copyWith(
          touchedCardIds: [for (var i = 0; i < 50; i++) 'b_${'z' * 3000}_$i'],
        )
        .toJson();
    expect(_docBytes(huge), lessThanOrEqualTo(kRunDocMaxBytes));
    expect(_bytes(huge['log']! as String), lessThan(kRunLogMaxBytes));
    // The trigger snapshot and params survive while the log can shrink.
    expect((huge['trigger']! as Map)['before'], isNotNull);
    expect(huge['params'], isNotNull);

    // Still over with an empty log: the trigger snapshot goes next.
    final heavier =
        run(
              log: bigLog(200),
              before: {for (var i = 0; i < 10; i++) 'f_$i': 'y' * 1500},
            )
            .copyWith(
              touchedCardIds: [
                for (var i = 0; i < 50; i++) 'b_${'z' * 3800}_$i',
              ],
            )
            .toJson();
    expect(decodeRunLog(heavier['log']).calls, isEmpty);
    expect((heavier['trigger']! as Map)['before'], isNull);
    expect(heavier['params'], isNotNull);
    expect(_docBytes(heavier), lessThanOrEqualTo(kRunDocMaxBytes));

    // Still over without the snapshot: params go last.
    final heaviest =
        run(
              log: bigLog(200),
              before: {for (var i = 0; i < 10; i++) 'f_$i': 'y' * 1500},
              params: {'p': 'x' * 3900},
            )
            .copyWith(
              touchedCardIds: [
                for (var i = 0; i < 50; i++) 'b_${'z' * 4000}_$i',
              ],
            )
            .toJson();
    expect((heaviest['trigger']! as Map)['before'], isNull);
    expect(heaviest['params'], isNull);
    expect(_docBytes(heaviest), lessThanOrEqualTo(kRunDocMaxBytes));
  });
}
