import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart';

import '../../core/agent/llm_client.dart';
import 'gemini_errors.dart';

/// Turns one streamed Gemini response into [LlmChunk]s, in the order
/// [LlmClient.generate] promises: [LlmText] (and [LlmBlocked]) as they
/// arrive, then one [LlmCalls], one [LlmModelContent], [LlmUsage] and the
/// final [LlmFinish].
///
/// - Parts are read one by one and `.text` is never called (it throws on a
///   blocked response).
/// - Function calls are collected across **all** chunks: Gemini sends each
///   call in its own chunk, then a final chunk with the finish reason.
/// - Every original [Part] is kept, in order and never rebuilt, so private
///   thought signatures survive into the next round's history.
/// - Errors end the stream as an [LlmFailure]. Cancelling the subscription
///   is **Stop**: it cancels the request stream, and any error after that is
///   swallowed as [LlmStopped] (nobody listens any more).
final class GeminiStreamAggregator
    extends StreamTransformerBase<GenerateContentResponse, LlmChunk> {
  const GeminiStreamAggregator();

  @override
  Stream<LlmChunk> bind(Stream<GenerateContentResponse> source) {
    StreamSubscription<GenerateContentResponse>? upstream;
    var stopped = false;
    final response = _Response();
    late final StreamController<LlmChunk> out;
    out = StreamController<LlmChunk>(
      onListen: () {
        upstream = source.listen(
          (chunk) => response.add(chunk, out.add),
          onError: (Object error, StackTrace stack) {
            if (stopped) return;
            out.addError(mapGeminiError(error), stack);
            out.close();
          },
          onDone: () {
            if (stopped) return;
            response.finish(out.add);
            out.close();
          },
          cancelOnError: true,
        );
      },
      onPause: () => upstream?.pause(),
      onResume: () => upstream?.resume(),
      onCancel: () async {
        stopped = true;
        try {
          await upstream?.cancel();
        } on Object {
          // A torn-down connection reports itself here (ClientException on
          // IO); after Stop every error is just "stopped".
        }
      },
    );
    return out.stream;
  }
}

/// The state of one response while its chunks arrive.
final class _Response {
  final _parts = <Part>[];
  final _calls = <LlmCall>[];
  FinishReason? _finish;
  UsageMetadata? _usage;
  var _blocked = false;

  void add(GenerateContentResponse chunk, void Function(LlmChunk) emit) {
    _usage = chunk.usageMetadata ?? _usage;
    if (chunk.promptFeedback case PromptFeedback(
      :final blockReason?,
      :final blockReasonMessage,
    )) {
      _block(_reason(blockReason.name, blockReasonMessage), emit);
    }
    final candidate = chunk.candidates.firstOrNull;
    if (candidate == null) return;
    for (final part in candidate.content.parts) {
      _parts.add(part);
      if (part.isThought == true) continue;
      switch (part) {
        case TextPart(:final text) when text.isNotEmpty:
          emit(LlmText(text));
        case FunctionCall(:final name, :final args, :final id):
          _calls.add(LlmCall(name: name, args: args, geminiId: id));
        default:
      }
    }
    if (candidate.finishReason case final reason?) {
      _finish = reason;
      if (_blockingReasons.contains(reason)) {
        _block(_reason(reason.name, candidate.finishMessage), emit);
      }
    }
  }

  void finish(void Function(LlmChunk) emit) {
    // A cut-short response's calls may have truncated args: drop them, and
    // their parts too, so the history never holds a call with no answer.
    final cutShort = _finish == FinishReason.maxTokens;
    if (_calls.isNotEmpty && !cutShort) {
      emit(LlmCalls(List.unmodifiable(_calls)));
    }
    emit(
      LlmModelContent(
        Content.model([
          for (final part in _parts)
            if (!(cutShort && part is FunctionCall)) part,
        ]),
      ),
    );
    if (_usage case final usage?) {
      emit(
        LlmUsage(
          promptTokens: usage.promptTokenCount ?? 0,
          outputTokens:
              (usage.candidatesTokenCount ?? 0) +
              (usage.thoughtsTokenCount ?? 0),
        ),
      );
    }
    emit(LlmFinish(_blocked ? FinishKind.other : _kind(_finish)));
  }

  void _block(String reason, void Function(LlmChunk) emit) {
    if (_blocked) return;
    _blocked = true;
    emit(LlmBlocked(reason));
  }
}

const _blockingReasons = {
  FinishReason.safety,
  FinishReason.recitation,
  FinishReason.prohibitedContent,
  FinishReason.blocklist,
  FinishReason.spii,
  FinishReason.imageSafety,
  FinishReason.imageProhibitedContent,
  FinishReason.imageRecitation,
};

String _reason(String code, String? message) =>
    message == null || message.isEmpty ? code : '$code: $message';

FinishKind _kind(FinishReason? reason) => switch (reason) {
  null || FinishReason.stop => FinishKind.stop,
  FinishReason.maxTokens => FinishKind.maxTokens,
  FinishReason.malformedFunctionCall => FinishKind.malformedCall,
  FinishReason.unexpectedToolCall => FinishKind.unexpectedToolCall,
  FinishReason.tooManyToolCalls => FinishKind.tooManyToolCalls,
  FinishReason.missingThoughtSignature => FinishKind.missingThoughtSignature,
  _ => FinishKind.other,
};
