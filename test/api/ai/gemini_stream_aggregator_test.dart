import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:morkva_crm/api/ai/gemini_stream_aggregator.dart';
import 'package:morkva_crm/core/agent/llm_client.dart';

GenerateContentResponse _chunk(
  List<Part> parts, {
  FinishReason? finish,
  String? finishMessage,
}) => GenerateContentResponse([
  Candidate(Content.model(parts), null, null, finish, finishMessage),
], null);

Future<List<LlmChunk>> _aggregate(List<GenerateContentResponse> chunks) =>
    Stream.fromIterable(
      chunks,
    ).transform(const GeminiStreamAggregator()).toList();

List<Part> _modelParts(List<LlmChunk> chunks) =>
    (chunks.whereType<LlmModelContent>().single.opaque as Content).parts;

void main() {
  test(
    'collects calls that arrive in separate chunks (the T0 shape)',
    () async {
      final first = FunctionCall.forTest(
        'cards_query',
        {
          'collection': 'Orders',
          'where': [
            {'field': 'Status', 'op': 'eq', 'value': 'New'},
          ],
        },
        id: 'call_1300a',
        thoughtSignature: 'sig-1',
      );
      const second = FunctionCall('cards_aggregate', {
        'collection': 'Orders',
      }, id: 'call_1300b');

      final chunks = await _aggregate([
        _chunk([first]),
        _chunk([second]),
        _chunk([const TextPart('')], finish: FinishReason.stop),
      ]);

      expect(chunks.map((c) => c.runtimeType), [
        LlmCalls,
        LlmModelContent,
        LlmFinish,
      ]);
      final calls = chunks.whereType<LlmCalls>().single.calls;
      expect(calls.map((c) => (c.name, c.geminiId)), [
        ('cards_query', 'call_1300a'),
        ('cards_aggregate', 'call_1300b'),
      ]);
      expect(calls.first.args['where'], first.args['where']);
      expect((chunks.last as LlmFinish).kind, FinishKind.stop);
    },
  );

  test('keeps every original part so thought signatures survive', () async {
    final call = FunctionCall.forTest('cards_query', const {
      'collection': 'Orders',
    }, thoughtSignature: 'sig-1');
    const thought = TextPart('Let me look', isThought: true);

    final parts = _modelParts(
      await _aggregate([
        _chunk([thought, call]),
        _chunk([const TextPart('')], finish: FinishReason.stop),
      ]),
    );

    expect(parts, [same(thought), same(call), isA<TextPart>()]);
    expect(
      (parts[1].toJson() as Map<String, Object?>)['thoughtSignature'],
      'sig-1',
    );
  });

  test('streams visible text in order and leaves thoughts out', () async {
    final chunks = await _aggregate([
      _chunk([
        const TextPart('hidden', isThought: true),
        const TextPart('You '),
      ]),
      _chunk([const TextPart('have 12 orders.')], finish: FinishReason.stop),
    ]);

    expect(chunks.whereType<LlmText>().map((t) => t.text), [
      'You ',
      'have 12 orders.',
    ]);
    expect(chunks.whereType<LlmCalls>(), isEmpty);
    expect(chunks.first, isA<LlmText>());
  });

  test('a safety finish is blocked after the text it already sent', () async {
    final chunks = await _aggregate([
      _chunk([const TextPart('Sure, ')]),
      _chunk(const [], finish: FinishReason.safety, finishMessage: 'unsafe'),
    ]);

    expect(chunks.map((c) => c.runtimeType), [
      LlmText,
      LlmBlocked,
      LlmModelContent,
      LlmFinish,
    ]);
    expect(chunks.whereType<LlmBlocked>().single.reason, 'safety: unsafe');
    expect((chunks.last as LlmFinish).kind, FinishKind.other);
  });

  test('a blocked prompt yields Blocked with no candidates at all', () async {
    final chunks = await _aggregate([
      GenerateContentResponse(
        const [],
        PromptFeedback(BlockReason.safety, null, const []),
      ),
    ]);

    expect(chunks.whereType<LlmBlocked>().single.reason, 'safety');
    expect(_modelParts(chunks), isEmpty);
    expect((chunks.last as LlmFinish).kind, FinishKind.other);
  });

  test('a cut-short response keeps its text and drops its calls', () async {
    final chunks = await _aggregate([
      _chunk([const TextPart('Here is')]),
      _chunk([
        const FunctionCall('cards_update', {'collection': 'Ord'}),
      ], finish: FinishReason.maxTokens),
    ]);

    expect(chunks.whereType<LlmCalls>(), isEmpty);
    expect(_modelParts(chunks), [isA<TextPart>()]);
    expect((chunks.last as LlmFinish).kind, FinishKind.maxTokens);
  });

  test('maps the tool-call finish reasons for the nudge path', () async {
    for (final (reason, kind) in [
      (FinishReason.malformedFunctionCall, FinishKind.malformedCall),
      (FinishReason.unexpectedToolCall, FinishKind.unexpectedToolCall),
      (FinishReason.tooManyToolCalls, FinishKind.tooManyToolCalls),
      (
        FinishReason.missingThoughtSignature,
        FinishKind.missingThoughtSignature,
      ),
      (FinishReason.other, FinishKind.other),
    ]) {
      final chunks = await _aggregate([_chunk(const [], finish: reason)]);
      expect((chunks.last as LlmFinish).kind, kind, reason: '$reason');
    }
  });

  test('an error ends the stream as an LlmFailure', () async {
    final stream = Stream<GenerateContentResponse>.multi((c) {
      c.add(_chunk([const TextPart('Partial')]));
      c.addError(QuotaExceeded('requests per minute. Please retry in 5s.'));
      c.add(_chunk([const TextPart('never')]));
    }).transform(const GeminiStreamAggregator());

    final seen = <Object>[];
    final done = Completer<void>();
    stream.listen(seen.add, onError: seen.add, onDone: done.complete);
    await done.future;

    expect(seen, [
      isA<LlmText>(),
      isA<LlmRateLimited>().having(
        (f) => f.retryAfter,
        'retryAfter',
        const Duration(seconds: 5),
      ),
    ]);
  });

  group('Stop', () {
    test('cancels the request and swallows the torn-down connection', () async {
      var requestCancelled = false;
      final source = StreamController<GenerateContentResponse>(
        onCancel: () {
          requestCancelled = true;
          throw http.ClientException('Connection closed while receiving data');
        },
      );
      final seen = <Object>[];
      final subscription = source.stream
          .transform(const GeminiStreamAggregator())
          .listen(seen.add, onError: seen.add);

      source.add(_chunk([const TextPart('Working on')]));
      await pumpEventQueue();
      await subscription.cancel();
      await pumpEventQueue();

      expect(requestCancelled, isTrue);
      expect(seen, [isA<LlmText>()]);
    });

    test('an error racing the cancel is not reported', () async {
      final source = StreamController<GenerateContentResponse>();
      final seen = <Object>[];
      final subscription = source.stream
          .transform(const GeminiStreamAggregator())
          .listen(seen.add, onError: seen.add);
      await pumpEventQueue();

      final cancelled = subscription.cancel();
      source.addError(http.ClientException('aborted'));
      await cancelled;
      await pumpEventQueue();

      expect(seen, isEmpty);
    });
  });
}
