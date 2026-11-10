import 'package:firebase_ai/firebase_ai.dart';
import 'package:http/http.dart' as http;

import '../../core/agent/llm_client.dart';

/// Maps whatever a Gemini stream failed with to an [LlmFailure].
///
/// [stopped] wins over everything: once the user pressed Stop, any error
/// (typically a `ClientException` from the torn-down connection) is
/// [LlmStopped]. The quota rows parse the message text, because the SDK's
/// `parseError` keeps only the message (samples: the Epic 8 T0 findings).
LlmFailure mapGeminiError(Object error, {bool stopped = false}) {
  if (stopped) return const LlmStopped();
  return switch (error) {
    LlmFailure() => error,
    QuotaExceeded(:final message) => _quota(message),
    ServiceApiNotEnabled(:final message) ||
    InvalidApiKey(:final message) => LlmNotSetUp(message),
    UnsupportedUserLocation(:final message) => LlmUnavailable(message),
    ServerException(:final message) => _server(message),
    // Thrown by the SDK when an error body has no message: a malformed body.
    FirebaseAISdkException(:final message) => LlmTransient(message),
    FirebaseAIException(:final message)
        when message.startsWith('Server Error') =>
      LlmTransient(message),
    FirebaseAIException(:final message) => LlmUnknownFailure(message),
    http.ClientException(:final message) => LlmTransient(message),
    // The stream path `jsonDecode`s any non-200 body; an HTML error page
    // from a proxy surfaces as this.
    FormatException(:final message) => LlmTransient(message),
    _ => LlmUnknownFailure('$error'),
  };
}

final _retryIn = RegExp(r'retry in (\d+(?:\.\d+)?)s', caseSensitive: false);

LlmFailure _quota(String message) {
  final text = message.toLowerCase();
  if (text.contains('per day')) return const LlmDailyQuota();
  final seconds = double.tryParse(_retryIn.firstMatch(message)?[1] ?? '');
  return LlmRateLimited(
    retryAfter: seconds == null
        ? null
        : Duration(milliseconds: (seconds * 1000).ceil()),
    // "input token count per minute" also says "per minute": check it first.
    scope:
        text.contains('token count per minute') ||
            text.contains('tokens per minute')
        ? RateLimitScope.tpm
        : RateLimitScope.rpm,
  );
}

LlmFailure _server(String message) {
  final text = message.toLowerCase();
  if (text.contains('app check') ||
      text.contains('api key not valid') ||
      (text.contains('generative language api') &&
          (text.contains('disabled') || text.contains('not been used')))) {
    return LlmNotSetUp(message);
  }
  if (text.contains('thought_signature') ||
      text.contains('thought signature')) {
    return const LlmMissingSignature();
  }
  // A 400 the request itself caused: retrying sends the same request.
  if (text.contains('invalid argument') ||
      text.contains('invalid json payload')) {
    return LlmUnknownFailure(message);
  }
  return LlmTransient(message);
}
