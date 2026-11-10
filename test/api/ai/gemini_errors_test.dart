import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:morkva_crm/api/ai/gemini_errors.dart';
import 'package:morkva_crm/core/agent/llm_client.dart';

/// The per-minute 429 sample the T0 spike captured through AI Logic.
const _rpmSample =
    'You exceeded your current quota, please check your plan and billing '
    'details. For more information on this error, head to: '
    'https://ai.google.dev/gemini-api/docs/rate-limits.\n'
    '* Quota exceeded for metric: '
    'generativelanguage.googleapis.com/generate_content_free_tier_requests, '
    'limit: 15, model: gemini-3.5-flash-lite, description: Generate content '
    'requests per minute limit exceeded on Free Tier.\n'
    'Please retry in 58.536995658s.';

void main() {
  group('quota', () {
    test('the T0 per-minute sample is an RPM limit with its retry hint', () {
      final failure = mapGeminiError(QuotaExceeded(_rpmSample));

      expect(
        failure,
        isA<LlmRateLimited>()
            .having((f) => f.scope, 'scope', RateLimitScope.rpm)
            .having(
              (f) => f.retryAfter,
              'retryAfter',
              const Duration(milliseconds: 58537),
            ),
      );
    });

    test('an input-token per-minute limit is TPM, not RPM', () {
      final failure = mapGeminiError(
        QuotaExceeded(
          'Quota exceeded for metric: generate_content_free_tier_input_token_'
          'count, description: Input token count per minute limit exceeded. '
          'Please retry in 12s.',
        ),
      );

      expect(
        failure,
        isA<LlmRateLimited>()
            .having((f) => f.scope, 'scope', RateLimitScope.tpm)
            .having((f) => f.retryAfter, 'retryAfter', Duration(seconds: 12)),
      );
    });

    test('a per-day limit is the daily quota', () {
      expect(
        mapGeminiError(
          QuotaExceeded(
            'Quota exceeded for metric: generate_content_free_tier_requests, '
            'description: Generate content requests per day limit exceeded. '
            'Please retry in 3600s.',
          ),
        ),
        isA<LlmDailyQuota>(),
      );
    });

    test('any other quota error is an RPM limit with no hint', () {
      expect(
        mapGeminiError(QuotaExceeded('Resource has been exhausted (quota).')),
        isA<LlmRateLimited>()
            .having((f) => f.scope, 'scope', RateLimitScope.rpm)
            .having((f) => f.retryAfter, 'retryAfter', isNull),
      );
    });
  });

  group('set-up problems', () {
    test('a disabled API, a bad key or a missing App Check token', () {
      for (final error in [
        ServiceApiNotEnabled('projects/morkvacrm'),
        InvalidApiKey('API key not valid. Please pass a valid API key.'),
        ServerException('Firebase App Check token is invalid.'),
        ServerException(
          'Generative Language API has not been used in project 1 before or '
          'it is disabled.',
        ),
      ]) {
        expect(mapGeminiError(error), isA<LlmNotSetUp>(), reason: '$error');
      }
    });

    test('an unsupported location makes the assistant unavailable', () {
      expect(mapGeminiError(UnsupportedUserLocation()), isA<LlmUnavailable>());
    });
  });

  group('connection problems are transient', () {
    for (final (name, error) in [
      ('a 5xx', ServerException('The service is currently unavailable.')),
      (
        'an overloaded model',
        ServerException('The model is overloaded. Please try again later.'),
      ),
      ('an internal error', ServerException('Internal error encountered.')),
      ('a deadline', ServerException('Deadline exceeded')),
      ('a 500 body', ServerException('Internal server error')),
      ('a 502 body', ServerException('Bad Gateway')),
      ('a 504 body', ServerException('Gateway Timeout')),
      ('a dropped connection', http.ClientException('Connection closed')),
      ('a non-JSON body', const FormatException('Unexpected character')),
      ('an error body with no message', FirebaseAISdkException('Unhandled')),
      ('a plain server error', FirebaseAIException('Server Error [503]: x')),
    ]) {
      test(name, () => expect(mapGeminiError(error), isA<LlmTransient>()));
    }
  });

  test('a lost thought signature asks for a text-only retry', () {
    expect(
      mapGeminiError(
        ServerException(
          'Function call is missing a thought_signature in functionCall parts.',
        ),
      ),
      isA<LlmMissingSignature>(),
    );
  });

  group('a request Gemini rejects is not retried', () {
    for (final message in [
      'Request contains an invalid argument.',
      // The 400 the Ask Morkva e2e hit before function responses used 'user'.
      "Role 'function' is not supported. Please use a valid role: SYSTEM, "
          'USER, MODEL.',
      'Please ensure that function call turn comes immediately after a user '
          'turn or after a function response turn.',
      'Unable to submit request because it has an empty text parameter.',
    ]) {
      test(message, () {
        expect(
          mapGeminiError(ServerException(message)),
          isA<LlmUnknownFailure>().having((f) => f.message, 'message', message),
        );
      });
    }
  });

  test('an LlmFailure passes through and anything else is unknown', () {
    const failure = LlmDailyQuota();
    expect(mapGeminiError(failure), same(failure));
    expect(mapGeminiError(StateError('x')), isA<LlmUnknownFailure>());
  });

  test('after Stop every error is Stopped, whatever its type', () {
    for (final error in [
      http.ClientException('Connection closed while receiving data'),
      QuotaExceeded(_rpmSample),
      StateError('x'),
    ]) {
      expect(mapGeminiError(error, stopped: true), isA<LlmStopped>());
    }
  });
}
