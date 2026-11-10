import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/agent/agent_event.dart';
import 'package:morkva_crm/core/agent/llm_client.dart';

void main() {
  group('Receipt', () {
    final json = <String, Object?>{
      'planId': 'p_1',
      'applied': ['i1', 'i2'],
      'queued': ['i4'],
      'declinedByUser': ['i6'],
      'stale': [
        {'itemId': 'i3', 'reason': 'changed_elsewhere'},
      ],
      'failed': [
        {'itemId': 'i5', 'code': 'offline', 'message': 'Needs a connection'},
      ],
      'journalId': 'j_1',
      'undoUntil': '2026-11-10T12:10:00.000Z',
      'summary': 'Updated 2 orders',
    };

    test('round-trips the harness JSON', () {
      final receipt = Receipt.fromJson(
        jsonDecode(jsonEncode(json)) as Map<String, Object?>,
      );

      expect(receipt.applied, ['i1', 'i2']);
      expect(receipt.stale.single.reason, StaleReason.changedElsewhere);
      expect(receipt.failed.single.code, 'offline');
      expect(receipt.undoUntil, DateTime.utc(2026, 11, 10, 12, 10));
      expect(receipt.toJson(), json);
      expect(Receipt.fromJson(receipt.toJson()), receipt);
    });

    test('counts what the user approved out of the whole plan', () {
      final receipt = Receipt.fromJson(json);

      expect(receipt.totalCount, 6);
      expect(receipt.approvedCount, 5);
    });

    test('tells the model counts, not ids, of what was applied', () {
      expect(Receipt.fromJson(json).toModelJson(), {
        'status': 'applied',
        'applied': 2,
        'queued': 1,
        'declinedByUser': ['i6'],
        'stale': [
          {'itemId': 'i3', 'reason': 'changed_elsewhere'},
        ],
        'failed': [
          {'itemId': 'i5', 'code': 'offline', 'message': 'Needs a connection'},
        ],
        'summary': 'Updated 2 orders',
      });
    });

    test('rejects a wrong shape', () {
      expect(() => Receipt.fromJson({'applied': []}), throwsFormatException);
      expect(
        () => Receipt.fromJson({'planId': 'p', 'applied': 'i1'}),
        throwsFormatException,
      );
      expect(
        () => Receipt.fromJson({
          'planId': 'p',
          'stale': [
            {'itemId': 'i1', 'reason': 'gone'},
          ],
        }),
        throwsFormatException,
      );
    });
  });

  test('a rejection reports a skip apart from a decision', () {
    expect(const Rejection(RejectReason.skipped).toModelJson(), {
      'status': 'rejected',
      'reason': 'skipped',
    });
    expect(const Rejection(RejectReason.stopped).toModelJson(), {
      'status': 'rejected',
      'reason': 'user',
    });
  });

  test('a compact plan needs its id', () {
    final plan = CompactPlan.fromJson({
      'planId': 'p_1',
      'title': 'Set Status to Shipped · 3 orders',
      'risk': 'low',
      'itemCount': 3,
    });

    expect(plan.planId, 'p_1');
    expect(plan.itemCount, 3);
    expect(() => CompactPlan.fromJson({'title': 'x'}), throwsFormatException);
  });

  test('token usage adds up and keeps the thread-doc shape', () {
    const a = TokenUsage(promptTokens: 300, outputTokens: 67);
    final sum = a + const TokenUsage(promptTokens: 100, outputTokens: 3);

    expect(sum, const TokenUsage(promptTokens: 400, outputTokens: 70));
    expect(TokenUsage.fromJson(sum.toJson()), sum);
  });

  test('output budget doubles once thinking is medium or higher', () {
    LlmRequest request(LlmThinking thinking) => LlmRequest(
      model: 'gemini-3.5-flash-lite',
      systemInstruction: '',
      contents: const [LlmUserText('hi')],
      thinking: thinking,
    );

    expect(request(LlmThinking.off).maxOutputTokens, 2048);
    expect(request(LlmThinking.low).maxOutputTokens, 2048);
    expect(request(LlmThinking.medium).maxOutputTokens, 4096);
  });
}
