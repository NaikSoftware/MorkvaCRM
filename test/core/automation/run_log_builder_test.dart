import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/automation/engine/protocol.dart';
import 'package:morkva_crm/core/automation/run_log_builder.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';

import '../harness/plan/plan_fixture.dart';

void main() {
  var clock = DateTime(2026, 11, 12, 12);
  RunLogBuilder builder() => RunLogBuilder(now: () => clock);

  group('calls', () {
    test('rows carry summaries, never values; no_change is not a failure', () {
      final b = builder();
      clock = clock.add(const Duration(milliseconds: 12));
      b.call(
        op: 'cards.update',
        kind: 'plan',
        args: {
          'collection': 'Orders',
          'target': {
            'ids': ['b_1', 'b_2'],
          },
          'set': {'Notes': 'secret customer note', 'Status': 'Shipped'},
          'expectedCount': 2,
        },
        result: {'summary': 'Planned 2 changes', 'items': []},
        ms: 4,
      );
      b.call(
        op: 'cards.update',
        kind: 'plan',
        error: {'code': 'no_change', 'message': 'Nothing would change.'},
      );
      b.call(
        op: 'cards.get',
        kind: 'read',
        args: {
          'ids': ['b_1'],
        },
        error: {'code': 'not_permitted', 'message': 'Collection not available'},
      );
      final calls = b.build().calls;
      expect(calls[0].t, 12);
      expect(
        calls[0].args,
        'collection: Orders · target: {ids} · set: {Notes, Status} · '
        'expectedCount: 2',
      );
      expect(calls[0].args, isNot(contains('secret')));
      expect(
        (calls[0].ok, calls[0].result, calls[0].ms),
        (true, 'Planned 2 changes', 4),
      );
      expect((calls[1].ok, calls[1].result), (true, kNoChangeText));
      expect(
        (calls[2].ok, calls[2].result),
        (false, 'not_permitted — Collection not available'),
      );
      expect(calls[2].args, 'ids: [1]');
    });

    test('ui.open results become links', () {
      final b = builder();
      b.call(
        op: 'ui.open',
        kind: 'ui',
        result: {
          'collectionId': 'c_orders',
          'cardId': 'b_1',
          'label': '#1042',
          'summary': 'Linked #1042',
        },
      );
      b.call(
        op: 'ui.open',
        kind: 'ui',
        result: {
          'collectionId': 'c_orders',
          'viewId': 'v_1',
          'label': 'Orders › Unpaid',
        },
      );
      b.call(
        op: 'ui.open',
        kind: 'ui',
        result: {'collectionId': 'c_orders', 'label': 'Orders'},
      );
      expect(b.links, const [
        UiLink(kind: 'card', ref: 'c_orders/b_1', label: '#1042'),
        UiLink(kind: 'view', ref: 'c_orders/v_1', label: 'Orders › Unpaid'),
        UiLink(kind: 'collection', ref: 'c_orders', label: 'Orders'),
      ]);
      expect(b.build().ui, b.links);
    });
  });

  test('console keeps $kMaxLogLinesPerRun lines and counts the rest; log '
      'reads as info; lines are cut and single-line', () {
    final b = builder();
    b.console('log', ['a', 'b\nc']);
    b.console('warn', ['x' * 900]);
    for (var i = 0; i < kMaxLogLinesPerRun; i++) {
      b.console('debug', ['$i']);
    }
    final log = b.build();
    expect(log.console, hasLength(kMaxLogLinesPerRun));
    expect(log.dropped.console, 2);
    expect((log.console[0].level, log.console[0].text), ('info', 'a b c'));
    expect(log.console[1].text.length, kMaxLogLineChars);
    expect(log.console[1].text, endsWith('…'));
  });

  group('return value', () {
    test('a string is the summary, cut to 200', () {
      final b = builder()..returned('Stamped 3 cards');
      expect(b.summary, 'Stamped 3 cards');
      b.returned('y' * 300);
      expect(b.summary!.length, 200);
    });

    test('{message} is the summary and the other keys are kept', () {
      final b = builder()..returned({'message': 'Done', 'count': 3});
      expect(b.summary, 'Done');
      expect(b.build().returned, {'count': 3});
    });

    test('over 16 KB only the summary stays, with a log line', () {
      final b = builder()..returned({'message': 'Done', 'blob': 'z' * 17000});
      final log = b.build();
      expect(b.summary, 'Done');
      expect(log.returned, isNull);
      expect(log.console.single.level, 'warn');
    });

    test('anything else leaves the summary to the host', () {
      final b = builder()..returned(42);
      expect(b.summary, isNull);
      b.returned({'count': 2});
      expect(b.summary, isNull);
      expect(b.build().returned, {'count': 2});
    });
  });

  test('plan rows read before → after per change', () async {
    final h = PlanHarness();
    addTearDown(h.dispose);
    await h.ok('cards.update', {
      'collection': 'Orders',
      'target': {
        'ids': [SeedCards.order(1001)],
      },
      'set': {'Qty': 9},
    });
    final plan = await h.sealPlan();
    final b = builder()..plan(plan);
    final row = b.build().plan.single;
    expect(row.kind, 'updateCard');
    expect(row.label, plan.items.single.label);
    expect(row.change, matches(RegExp(r'^Qty: \d+ → 9$')));
    // The pills' parts, kept beside the words.
    expect(row.changes.single.field, 'Qty');
    expect(row.changes.single.after, '9');
    expect(row.changes.single.before, isNotNull);
  });

  test('a large log encodes within the run doc budget', () {
    final b = builder();
    for (var i = 0; i < kMaxCallsPerRun; i++) {
      b.call(
        op: 'cards.get',
        kind: 'read',
        args: {'collection': 'x' * 400},
        result: {'summary': 's' * 400},
      );
    }
    for (var i = 0; i < kMaxLogLinesPerRun; i++) {
      b.console('info', ['l' * 600]);
    }
    final encoded = encodeRunLog(b.build());
    expect(utf8.encode(encoded).length, lessThanOrEqualTo(kRunLogMaxBytes));
    final decoded = decodeRunLog(encoded);
    expect(decoded.dropped.console, greaterThan(0));
  });
}
