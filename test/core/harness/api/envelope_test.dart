import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/harness/harness.dart';

/// Round-trips [json] through a JSON string, as a transport would.
Map<String, Object?> _wire(Map<String, Object?> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, Object?>;

ErrorDetail _detail(int row) => ErrorDetail(
  path: 'cards[$row].values.Total',
  code: ErrorCode.wrongType,
  message: 'Row $row: "12 USD" is not a number.',
);

void main() {
  group('ErrorCode', () {
    test('wire names are unique snake_case and round-trip', () {
      final wires = [for (final c in ErrorCode.values) c.wire];
      expect(wires.toSet(), hasLength(wires.length));
      for (final c in ErrorCode.values) {
        expect(c.wire, matches(RegExp(r'^[a-z]+(_[a-z]+)*$')));
        expect(ErrorCode.fromWire(c.wire), c);
      }
      expect(ErrorCode.fromWire('teapot'), isNull);
    });

    test('domain validation codes pass through verbatim', () {
      for (final wire in const [
        'required',
        'out_of_range',
        'too_long',
        'invalid_option',
        'invalid_reference',
        'too_many_references',
        'too_many_files',
        'invalid_extension',
      ]) {
        expect(ErrorCode.fromWire(wire), isNotNull, reason: wire);
      }
    });

    test('no_change is information: its own code, not retryable', () {
      expect(ErrorCode.fromWire('no_change'), ErrorCode.noChange);
      expect(ErrorCode.noChange.retryableByDefault, isFalse);
    });

    test('only offline and conflict are retryable by default', () {
      expect(
        [
          for (final c in ErrorCode.values)
            if (c.retryableByDefault) c,
        ],
        [ErrorCode.offline, ErrorCode.conflict],
      );
      expect(
        HarnessError(code: ErrorCode.offline, message: 'm').retryable,
        isTrue,
      );
      expect(
        HarnessError(code: ErrorCode.internal, message: 'm').retryable,
        isFalse,
      );
    });
  });

  group('HarnessError.fromDetails', () {
    test('one problem becomes a plain error without details', () {
      final error = HarnessError.fromDetails([_detail(2)]);
      expect(error.code, ErrorCode.wrongType);
      expect(error.path, 'cards[2].values.Total');
      expect(error.details, isNull);
      expect(error.moreErrors, isNull);
    });

    test('3 bad rows come back together, the first on top', () {
      final error = HarnessError.fromDetails([
        _detail(7),
        _detail(42),
        _detail(199),
      ], hint: 'Send numbers without units.');
      expect(error.path, 'cards[7].values.Total');
      expect(error.details, hasLength(3));
      expect(error.moreErrors, isNull);
      expect(error.hint, 'Send numbers without units.');
    });

    test('details are capped at 20 and moreErrors counts the rest', () {
      final error = HarnessError.fromDetails([
        for (var i = 0; i < 26; i++) _detail(i),
      ]);
      expect(error.details, hasLength(20));
      expect(error.moreErrors, 6);
    });

    test('needs at least one problem', () {
      expect(() => HarnessError.fromDetails([]), throwsArgumentError);
    });
  });

  group('JSON round trips', () {
    test('a request', () {
      const request = HarnessRequest(
        op: 'cards.query',
        args: {
          'collection': 'Orders',
          'where': [
            {'field': 'Paid', 'op': 'isFalse'},
          ],
        },
        callId: 'r2.1',
        turnId: 't_9f',
      );
      final back = HarnessRequest.fromJson(_wire(request.toJson()));
      expect(back.toJson(), request.toJson());
      expect(back.v, kHarnessApiVersion);
    });

    test('a request without args gets an empty map', () {
      final request = HarnessRequest.fromJson({
        'v': 2,
        'op': 'harness.describe',
        'callId': 'h.1',
      });
      expect(request.args, isEmpty);
      expect(request.turnId, isNull);
    });

    test('a malformed request envelope is a FormatException', () {
      expect(
        () => HarnessRequest.fromJson({'op': 'x', 'callId': 'c'}),
        throwsFormatException,
      );
      expect(
        () => HarnessRequest.fromJson({
          'v': 2,
          'op': 'x',
          'callId': 'c',
          'args': [],
        }),
        throwsFormatException,
      );
      expect(
        () => HarnessRequest.fromJson({'v': 2, 'callId': 'c'}),
        throwsFormatException,
      );
    });

    test('an ok response', () {
      const response = HarnessOk({
        'total': 5,
        'summary': 'Filtered 148 → 5 Orders',
      }, ResponseMeta(ms: 3, generation: 41));
      final json = _wire(response.toJson());
      expect(json, {
        'ok': true,
        'result': {'total': 5, 'summary': 'Filtered 148 → 5 Orders'},
        'meta': {'ms': 3, 'generation': 41, 'truncated': false},
      });
      final back = HarnessResponse.fromJson(json) as HarnessOk;
      expect(back.result['total'], 5);
      expect(back.meta.generation, 41);
    });

    test('a failure with every optional field', () {
      final error = HarnessError(
        code: ErrorCode.countMismatch,
        message: 'Expected 12 cards, 14 match now.',
        path: 'expectedCount',
        candidates: const [
          {'id': 'b_1', 'title': '#1042'},
        ],
        hint: 'Query again and pass the new count.',
        details: [_detail(1), _detail(2)],
        moreErrors: 3,
        offset: 7,
        expected: 12,
        actual: 14,
      );
      final json = _wire(HarnessFailure(error).toJson());
      expect(json['ok'], isFalse);
      expect((json['error']! as Map)['code'], 'count_mismatch');
      final back = HarnessResponse.fromJson(json) as HarnessFailure;
      expect(back.error.toJson(), _wire(error.toJson()));
    });

    test('a progress event', () {
      const event = ProgressEvent(callId: 'h.4', done: 120, total: 200);
      expect(event.toJson(), {
        'event': 'progress',
        'callId': 'h.4',
        'done': 120,
        'total': 200,
      });
      final back =
          HarnessEvent.fromJson(_wire(event.toJson())) as ProgressEvent;
      expect([back.callId, back.done, back.total], ['h.4', 120, 200]);
      expect(HarnessEvent.names, ['progress']);
      expect(
        () => HarnessEvent.fromJson({'event': 'boom'}),
        throwsFormatException,
      );
    });
  });
}
