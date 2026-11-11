/// The model seam of the agent layer: a pure-Dart [LlmClient] interface, the
/// request it takes and the chunks and failures it produces. The Gemini
/// adapter (`lib/api/ai`) is the only implementation that talks to a model;
/// nothing here imports Flutter, Firebase or `firebase_ai`.
library;

/// One model provider. Implementations are stateless per request.
abstract interface class LlmClient {
  /// Streams one model response for [request].
  ///
  /// Chunks arrive in order: any number of [LlmText] and [LlmCalls], then one
  /// [LlmModelContent] (the response's original parts, to append to the
  /// history), [LlmUsage] when the provider reports it, and a final
  /// [LlmFinish]. A response the provider blocks yields [LlmBlocked] instead
  /// of (or after) the text. Failures end the stream with an [LlmFailure]
  /// error.
  ///
  /// **Stop** is cancelling the subscription: the client aborts the request
  /// and treats any error after that as [LlmStopped].
  Stream<LlmChunk> generate(LlmRequest request);

  /// The provider JSON (`{role, parts: [...]}` for Gemini) of [content], for
  /// persisting a turn as one `jsonEncode` string. [LlmRawContent.json]
  /// round-trips through it unchanged.
  Map<String, Object?> encodeContent(LlmContent content);
}

/// How much the model may think before answering. `off` is the lowest level
/// the model supports (`ThinkingLevel.minimal` on Gemini 3.x).
enum LlmThinking { off, low, medium, high }

/// Which tools the model may call in this round.
enum LlmToolMode {
  /// The model decides.
  auto,

  /// No calls: the model must answer in text (the last round).
  none,

  /// The model must call a tool.
  any,
}

/// One tool declared to the model: a harness op projected to a provider
/// name (`cards_query`) with its JSON Schema for args.
final class LlmTool {
  const LlmTool({
    required this.name,
    required this.description,
    required this.parametersJsonSchema,
  });

  /// `[a-zA-Z0-9_-]{1,63}`: the op id with `.` replaced by `_`.
  final String name;
  final String description;

  /// The JSON Schema of the args (`$defs` already inlined).
  final Map<String, Object?> parametersJsonSchema;
}

/// One model request: the whole conversation resent every round.
final class LlmRequest {
  const LlmRequest({
    required this.model,
    required this.systemInstruction,
    required this.contents,
    this.tools = const [],
    this.toolMode = LlmToolMode.auto,
    this.thinking = LlmThinking.off,
    this.temperature = 0.2,
    int? maxOutputTokens,
  }) : _maxOutputTokens = maxOutputTokens;

  /// The model id, e.g. `gemini-3.5-flash-lite`.
  final String model;

  /// The byte-stable rules for the thread (no counts, dates or names).
  final String systemInstruction;

  /// The context message (today, digest) first, then the history in order.
  final List<LlmContent> contents;

  final List<LlmTool> tools;
  final LlmToolMode toolMode;
  final LlmThinking thinking;
  final double temperature;
  final int? _maxOutputTokens;

  /// 2048, or 4096 when thinking is `medium` or higher (thinking tokens count
  /// against it), unless set explicitly.
  int get maxOutputTokens =>
      _maxOutputTokens ??
      (thinking.index >= LlmThinking.medium.index ? 4096 : 2048);
}

// ---------------------------------------------------------------------------
// Conversation contents.

/// One entry of the conversation sent to the model.
sealed class LlmContent {
  const LlmContent();
}

/// A user-role text message (the user's prompt with its screen line, the
/// context message, or a nudge after an invalid call).
final class LlmUserText extends LlmContent {
  const LlmUserText(this.text);

  final String text;
}

/// The answers to one round's calls, in call order.
final class LlmFunctionResponses extends LlmContent {
  const LlmFunctionResponses(this.responses);

  final List<LlmFunctionResponse> responses;
}

/// The answer to one [LlmCall].
final class LlmFunctionResponse {
  const LlmFunctionResponse({
    required this.name,
    required this.response,
    this.geminiId,
  });

  /// The called tool's name (as the model sent it).
  final String name;

  /// Plain JSON: the budgeted harness result, error or plan outcome.
  final Map<String, Object?> response;

  /// The provider's call id, echoed when the call carried one.
  final String? geminiId;
}

/// A persisted content in provider JSON (`{role, parts}`), restored from a
/// thread and replayed verbatim (Gemini: as `UnknownPart`s, which keeps
/// thought signatures).
final class LlmRawContent extends LlmContent {
  const LlmRawContent(this.json);

  final Map<String, Object?> json;
}

// ---------------------------------------------------------------------------
// Response chunks.

sealed class LlmChunk {
  const LlmChunk();
}

/// Visible (non-thought) answer text, in arrival order.
final class LlmText extends LlmChunk {
  const LlmText(this.text);

  final String text;
}

/// Function calls collected from the response (they may span chunks).
final class LlmCalls extends LlmChunk {
  const LlmCalls(this.calls);

  final List<LlmCall> calls;
}

/// One function call the model made.
final class LlmCall {
  const LlmCall({required this.name, required this.args, this.geminiId});

  final String name;

  /// Already parsed JSON args.
  final Map<String, Object?> args;

  /// The provider's call id, when it sent one (echoed in the response).
  final String? geminiId;

  @override
  String toString() => 'LlmCall($name, $args)';
}

/// The response was blocked (prompt feedback or a safety-type finish).
final class LlmBlocked extends LlmChunk {
  const LlmBlocked(this.reason);

  final String reason;
}

/// Why the model stopped.
enum FinishKind {
  stop,
  maxTokens,
  malformedCall,
  unexpectedToolCall,
  tooManyToolCalls,
  missingThoughtSignature,
  other,
}

final class LlmFinish extends LlmChunk {
  const LlmFinish(this.kind);

  final FinishKind kind;
}

/// Token usage of the response (the last value the provider reported).
final class LlmUsage extends LlmChunk {
  const LlmUsage({required this.promptTokens, required this.outputTokens});

  final int promptTokens;
  final int outputTokens;
}

/// The response's original parts as one model-role content, replayed
/// verbatim in the next round's history so private thought signatures
/// survive. [opaque] is the provider's own object; only its client reads it.
final class LlmModelContent extends LlmChunk implements LlmContent {
  const LlmModelContent(this.opaque);

  final Object opaque;
}

// ---------------------------------------------------------------------------
// Failures.

/// Which per-minute bucket a rate limit hit.
enum RateLimitScope { rpm, tpm }

/// Why a model request failed; the error an [LlmClient.generate] stream ends
/// with.
sealed class LlmFailure implements Exception {
  const LlmFailure();

  /// Text for logs, never shown verbatim to the user.
  String get message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The user stopped the request (any error after Stop maps here).
final class LlmStopped extends LlmFailure {
  const LlmStopped();

  @override
  String get message => 'stopped';
}

/// A per-minute quota (requests or tokens) was hit; worth retrying.
final class LlmRateLimited extends LlmFailure {
  const LlmRateLimited({this.retryAfter, this.scope = RateLimitScope.rpm});

  /// The provider's "retry in N s" hint, when it sent one.
  final Duration? retryAfter;
  final RateLimitScope scope;

  @override
  String get message => 'rate limited (${scope.name}, retry in $retryAfter)';
}

/// The daily quota is used up; no retry until it resets.
final class LlmDailyQuota extends LlmFailure {
  const LlmDailyQuota();

  @override
  String get message => 'daily quota exhausted';
}

/// A dropped connection, a 5xx or a malformed body; retried with backoff
/// while no text streamed yet.
final class LlmTransient extends LlmFailure {
  const LlmTransient(this.message);

  @override
  final String message;
}

/// The AI backend is not enabled for this project (API disabled, bad key,
/// missing App Check).
final class LlmNotSetUp extends LlmFailure {
  const LlmNotSetUp(this.message);

  @override
  final String message;
}

/// The service refuses this user (for example an unsupported location).
final class LlmUnavailable extends LlmFailure {
  const LlmUnavailable(this.message);

  @override
  final String message;
}

/// The request was blocked by safety filters; not retried.
final class LlmBlockedFailure extends LlmFailure {
  const LlmBlockedFailure(this.reason);

  final String reason;

  @override
  String get message => 'blocked: $reason';
}

/// A resumed thread lost its thought signatures; rebuild the history with
/// text-only past turns and retry once.
final class LlmMissingSignature extends LlmFailure {
  const LlmMissingSignature();

  @override
  String get message => 'missing thought signature';
}

/// Anything else.
final class LlmUnknownFailure extends LlmFailure {
  const LlmUnknownFailure(this.message);

  @override
  final String message;
}
