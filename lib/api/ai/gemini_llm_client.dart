import 'package:firebase_ai/firebase_ai.dart';

import '../../core/agent/llm_client.dart';
import 'gemini_stream_aggregator.dart';
import 'raw_function_declaration.dart';

/// Everything one Gemini request is built from: the model's settings and
/// the conversation to stream.
final class GeminiCall {
  const GeminiCall({
    required this.model,
    required this.systemInstruction,
    required this.contents,
    required this.tools,
    required this.toolConfig,
    required this.generationConfig,
  });

  final String model;
  final Content systemInstruction;
  final List<Content> contents;

  /// Empty when the request declares no tools ([toolConfig] is then null).
  final List<Tool> tools;
  final ToolConfig? toolConfig;
  final GenerationConfig generationConfig;
}

/// Opens the response stream of one [GeminiCall]. The default goes through
/// Firebase AI Logic; tests pass a fake stream (`GenerativeModel` is final
/// and `firebase_ai` 3.13.1 exports no `httpClient` seam).
typedef GeminiStreamOpener =
    Stream<GenerateContentResponse> Function(GeminiCall call);

/// [LlmClient] over Gemini through Firebase AI Logic (the Gemini Developer
/// API). The only `firebase_ai` importer of the app, with
/// [RawFunctionDeclaration], [GeminiStreamAggregator] and `gemini_errors`.
///
/// Stop is cancelling the [generate] subscription; `client.close()` is never
/// used (an http `BrowserClient` cannot abort an SSE body once headers
/// arrived).
final class GeminiLlmClient implements LlmClient {
  GeminiLlmClient({GeminiStreamOpener? open, this.stripClosedObjects = false})
    : _open = open ?? _firebaseOpener;

  final GeminiStreamOpener _open;

  /// Adapter-local schema lowering (see [RawFunctionDeclaration]); off,
  /// because T0 showed Gemini accepts the harness schemas unchanged.
  final bool stripClosedObjects;

  @override
  Stream<LlmChunk> generate(LlmRequest request) {
    Stream<GenerateContentResponse> responses;
    try {
      responses = _open(buildCall(request));
    } on Object catch (error, stack) {
      // No Firebase app, a bad opaque content: fail the stream, not the call.
      responses = Stream.error(error, stack);
    }
    return responses.transform(const GeminiStreamAggregator());
  }

  /// The Gemini request for [request]; public for tests.
  GeminiCall buildCall(LlmRequest request) => GeminiCall(
    model: request.model,
    systemInstruction: Content.system(request.systemInstruction),
    contents: [
      for (final content in request.contents)
        if (_toContent(content) case final c when c.parts.isNotEmpty) c,
    ],
    tools: [
      if (request.tools.isNotEmpty)
        Tool.functionDeclarations([
          for (final tool in request.tools)
            RawFunctionDeclaration(
              tool.name,
              tool.description,
              parametersJsonSchema: tool.parametersJsonSchema,
              stripClosedObjects: stripClosedObjects,
            ),
        ]),
    ],
    toolConfig: request.tools.isEmpty
        ? null
        : ToolConfig(
            functionCallingConfig: switch (request.toolMode) {
              LlmToolMode.auto => FunctionCallingConfig.auto(),
              LlmToolMode.none => FunctionCallingConfig.none(),
              LlmToolMode.any => FunctionCallingConfig.any({
                for (final tool in request.tools) tool.name,
              }),
            },
          ),
    generationConfig: GenerationConfig(
      temperature: request.temperature,
      maxOutputTokens: request.maxOutputTokens,
      thinkingConfig: thinkingConfig(request.model, request.thinking),
    ),
  );

  @override
  Map<String, Object?> encodeContent(LlmContent content) => switch (content) {
    // Verbatim: `UnknownPart.toJson` would add `thought: false` to each part.
    LlmRawContent(:final json) => json,
    _ => _toContent(content).toJson(),
  };
}

/// Thinking for [model]: 3.x models take a level (`off` is `minimal`;
/// omitting the config would mean dynamic, high thinking), 2.x models a
/// token budget. Thoughts are never included: they are not shown.
ThinkingConfig thinkingConfig(String model, LlmThinking thinking) {
  if (model.startsWith('gemini-2')) {
    return ThinkingConfig.withThinkingBudget(switch (thinking) {
      LlmThinking.off => 0,
      LlmThinking.low => 512,
      LlmThinking.medium => 2048,
      LlmThinking.high => -1,
    }, includeThoughts: false);
  }
  return ThinkingConfig.withThinkingLevel(switch (thinking) {
    LlmThinking.off => ThinkingLevel.minimal,
    LlmThinking.low => ThinkingLevel.low,
    LlmThinking.medium => ThinkingLevel.medium,
    LlmThinking.high => ThinkingLevel.high,
  }, includeThoughts: false);
}

Content _toContent(LlmContent content) => switch (content) {
  LlmUserText(:final text) => Content.text(text),
  LlmFunctionResponses(:final responses) => Content.functionResponses([
    for (final r in responses)
      FunctionResponse(r.name, r.response, id: r.geminiId),
  ]),
  // Restored as UnknownParts, which replay the JSON (and its thought
  // signatures) unchanged.
  LlmRawContent(:final json) => Content(json['role'] as String?, [
    for (final part in json['parts'] as List? ?? const [])
      UnknownPart(Map<String, Object?>.from(part as Map)),
  ]),
  LlmModelContent(:final opaque) => switch (opaque) {
    final Content c => c,
    _ => throw ArgumentError.value(opaque, 'opaque', 'not a Gemini Content'),
  },
};

/// Firebase AI Logic on the Gemini Developer API. Auth and App Check are
/// not passed in (those parameters are deprecated): the SDK looks both up
/// per request, so the ID token is attached once signed in and the App
/// Check token once the app has activated App Check.
Stream<GenerateContentResponse> _firebaseOpener(GeminiCall call) =>
    FirebaseAI.googleAI()
        .generativeModel(
          model: call.model,
          systemInstruction: call.systemInstruction,
          tools: call.tools.isEmpty ? null : call.tools,
          toolConfig: call.toolConfig,
          generationConfig: call.generationConfig,
        )
        .generateContentStream(call.contents);
