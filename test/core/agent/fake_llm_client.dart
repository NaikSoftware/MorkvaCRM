import 'dart:async';
import 'dart:collection';

import 'package:morkva_crm/core/agent/llm_client.dart';

/// One scripted model response for [FakeLlmClient].
final class FakeReply {
  /// A normal response: [text] pieces, then [calls], the model content, the
  /// usage and the finish (the contract's chunk order).
  const FakeReply({
    this.text = const [],
    this.calls = const [],
    this.finish = FinishKind.stop,
    this.promptTokens = 100,
    this.outputTokens = 10,
    this.blocked,
  }) : failure = null,
       hold = false;

  /// A response that ends with [failure] (after any [text]).
  const FakeReply.fail(this.failure, {this.text = const []})
    : calls = const [],
      finish = FinishKind.stop,
      promptTokens = 0,
      outputTokens = 0,
      blocked = null,
      hold = false;

  /// A response that streams [text] and then never ends (until cancelled).
  const FakeReply.hold({this.text = const []})
    : calls = const [],
      finish = FinishKind.stop,
      promptTokens = 0,
      outputTokens = 0,
      blocked = null,
      failure = null,
      hold = true;

  final List<String> text;
  final List<LlmCall> calls;
  final FinishKind finish;
  final int promptTokens;
  final int outputTokens;
  final String? blocked;
  final LlmFailure? failure;
  final bool hold;
}

/// The model content a [FakeLlmClient] response carries (what Gemini keeps
/// as original parts).
final class FakeModelContent {
  const FakeModelContent(this.text, this.calls);

  final String text;
  final List<LlmCall> calls;

  @override
  String toString() => 'FakeModelContent($text, $calls)';
}

/// A scripted [LlmClient] (`GenerativeModel` is a final class, so the agent
/// is tested against this). Each [generate] takes the next [FakeReply] and
/// records its [LlmRequest].
final class FakeLlmClient implements LlmClient {
  FakeLlmClient([Iterable<FakeReply> replies = const []]) {
    _replies.addAll(replies);
  }

  final Queue<FakeReply> _replies = Queue();

  /// Every request, in order.
  final List<LlmRequest> requests = [];

  /// How many held streams were cancelled (Stop).
  int cancelled = 0;

  void add(FakeReply reply) => _replies.add(reply);

  void addAll(Iterable<FakeReply> replies) => _replies.addAll(replies);

  int get remaining => _replies.length;

  @override
  Stream<LlmChunk> generate(LlmRequest request) {
    requests.add(request);
    if (_replies.isEmpty) {
      throw StateError('No scripted reply for request ${requests.length}');
    }
    final reply = _replies.removeFirst();
    if (reply.hold) {
      final controller = StreamController<LlmChunk>(
        onCancel: () => cancelled++,
      );
      for (final t in reply.text) {
        controller.add(LlmText(t));
      }
      return controller.stream;
    }
    return _stream(reply);
  }

  Stream<LlmChunk> _stream(FakeReply reply) async* {
    for (final t in reply.text) {
      yield LlmText(t);
    }
    if (reply.failure case final failure?) throw failure;
    if (reply.blocked case final reason?) {
      yield LlmBlocked(reason);
      yield const LlmFinish(FinishKind.other);
      return;
    }
    if (reply.calls.isNotEmpty) yield LlmCalls(reply.calls);
    yield LlmModelContent(FakeModelContent(reply.text.join(), reply.calls));
    yield LlmUsage(
      promptTokens: reply.promptTokens,
      outputTokens: reply.outputTokens,
    );
    yield LlmFinish(reply.finish);
  }

  @override
  Map<String, Object?> encodeContent(LlmContent content) => switch (content) {
    LlmUserText(:final text) => {
      'role': 'user',
      'parts': [
        {'text': text},
      ],
    },
    LlmFunctionResponses(:final responses) => {
      'role': 'user',
      'parts': [
        for (final r in responses)
          {
            'functionResponse': {
              'name': r.name,
              'response': r.response,
              'id': ?r.geminiId,
            },
          },
      ],
    },
    LlmModelContent(:final opaque) => {
      'role': 'model',
      'parts': [
        {'fake': '$opaque'},
      ],
    },
    LlmRawContent(:final json) => json,
  };
}

/// A call the model makes.
LlmCall call(String name, [Map<String, Object?> args = const {}, String? id]) =>
    LlmCall(name: name, args: args, geminiId: id);
