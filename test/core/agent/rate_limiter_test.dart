import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/agent/llm_client.dart';
import 'package:morkva_crm/core/agent/rate_limiter.dart';

void main() {
  final start = DateTime.utc(2026, 11, 10, 12);
  late DateTime now;

  setUp(() => now = start);

  RateLimiter limiter({int rpm = 12, int? tpm}) =>
      RateLimiter(rpm: rpm, tpm: tpm, now: () => now);

  group('the requests-per-minute bucket', () {
    test('lets a full minute of requests through at once', () {
      final l = limiter(rpm: 3);

      expect([for (var i = 0; i < 3; i++) l.acquire()], everyElement(isNull));
    });

    test('paces the next request by the refill rate', () {
      final l = limiter(rpm: 3);
      for (var i = 0; i < 3; i++) {
        l.acquire();
      }

      final wait = l.acquire()!;

      expect(wait.scope, RateLimitScope.rpm);
      expect(wait.until, start.add(const Duration(seconds: 20)));
    });

    test('queues requests behind each other while in debt', () {
      final l = limiter(rpm: 3);
      for (var i = 0; i < 4; i++) {
        l.acquire();
      }

      expect(l.acquire()!.until, start.add(const Duration(seconds: 40)));
    });

    test('refills over time, up to the bucket size', () {
      final l = limiter(rpm: 3);
      for (var i = 0; i < 3; i++) {
        l.acquire();
      }
      now = start.add(const Duration(minutes: 10));

      expect([for (var i = 0; i < 3; i++) l.acquire()], everyElement(isNull));
      expect(l.acquire(), isNotNull);
    });
  });

  group('the tokens-per-minute bucket', () {
    test('does not exist without a tpm limit', () {
      final l = limiter(rpm: 100);

      expect(l.acquire(tokens: 1000000), isNull);
      expect(l.tpm, isNull);
    });

    test('holds a request back when the prompt does not fit', () {
      final l = limiter(rpm: 100, tpm: 6000);
      expect(l.acquire(tokens: 5000), isNull);

      final wait = l.acquire(tokens: 4000)!;

      expect(wait.scope, RateLimitScope.tpm);
      // 3000 tokens of debt at 100 tokens a second.
      expect(wait.until, start.add(const Duration(seconds: 30)));
    });

    test('lets a prompt bigger than the whole bucket go when it is full', () {
      final l = limiter(rpm: 100, tpm: 1000);

      expect(l.acquire(tokens: 50000), isNull);
    });

    test('is corrected by the reported prompt size', () {
      final l = limiter(rpm: 100, tpm: 6000);
      l.acquire(tokens: 1000);
      l.recordUsage(estimated: 1000, actual: 9000);

      final wait = l.acquire(tokens: 1000)!;

      // 6000 - 1000 - 8000 - 1000 = -4000 → 40 s.
      expect(wait.scope, RateLimitScope.tpm);
      expect(wait.until, start.add(const Duration(seconds: 40)));
    });
  });

  test('configure applies new limits and keeps what is left', () {
    final l = limiter(rpm: 3);
    l.acquire();
    l.acquire();

    l.configure(rpm: 1, tpm: 500);

    expect(l.rpm, 1);
    expect(l.tpm, 500);
    expect(l.acquire(), isNull);
    expect(l.acquire()!.until, start.add(const Duration(minutes: 1)));
  });
}
