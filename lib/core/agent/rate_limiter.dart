import 'dart:math' as math;

import 'llm_client.dart';

/// How long the loop must wait before its next model request, and which
/// bucket is empty.
final class RateWait {
  const RateWait(this.until, this.scope);

  final DateTime until;
  final RateLimitScope scope;

  @override
  String toString() => 'RateWait(${scope.name} until $until)';
}

/// The client-side pacing of model requests: a requests-per-minute bucket
/// and, when [tpm] is set, a tokens-per-minute bucket fed from the prompt
/// token counts the model reports.
///
/// Both are continuously refilling token buckets that start full. A request
/// always takes its share at once ([acquire]); when a bucket runs short it
/// goes into debt and the request is told how long to wait, so requests
/// queued behind it wait longer. **Advisory only**: the counters are per
/// tab, while the real quota is per project and enforced server-side.
final class RateLimiter {
  RateLimiter({required int rpm, int? tpm, DateTime Function()? now})
    : _now = now ?? DateTime.now,
      _rpm = math.max(1, rpm),
      _tpm = tpm == null ? null : math.max(1, tpm) {
    _requests = _rpm.toDouble();
    _tokens = (_tpm ?? 0).toDouble();
    _refilledAt = _now();
  }

  /// The wait after a 429 that carried no "retry in N s" hint.
  static const Duration defaultRetryAfter = Duration(seconds: 20);

  /// The waits before the retries of a dropped connection or a 5xx.
  static const List<Duration> transientBackoff = [
    Duration(seconds: 2),
    Duration(seconds: 6),
  ];

  final DateTime Function() _now;
  int _rpm;
  int? _tpm;
  late double _requests;
  late double _tokens;
  late DateTime _refilledAt;

  int get rpm => _rpm;

  /// Null when there is no tokens-per-minute bucket.
  int? get tpm => _tpm;

  /// Applies new limits (a config change), keeping what is left in each
  /// bucket up to its new size.
  void configure({required int rpm, int? tpm}) {
    _refill();
    _rpm = math.max(1, rpm);
    _requests = math.min(_requests, _rpm.toDouble());
    final hadTpm = _tpm != null;
    _tpm = tpm == null ? null : math.max(1, tpm);
    _tokens = switch (_tpm) {
      null => 0,
      final t when !hadTpm => t.toDouble(),
      final t => math.min(_tokens, t.toDouble()),
    };
  }

  /// Takes one request and [tokens] (the estimated prompt size) from the
  /// buckets. Returns null when the request may go now, else when it may go
  /// and the bucket that holds it up the longest.
  RateWait? acquire({int tokens = 0}) {
    final now = _refill();
    _requests -= 1;
    var wait = _waitFor(_requests, _rpm);
    var scope = RateLimitScope.rpm;
    if (_tpm case final tpm?) {
      // A prompt bigger than the whole bucket could never go otherwise.
      _tokens -= math.min(tokens, tpm);
      final tokenWait = _waitFor(_tokens, tpm);
      if (tokenWait > wait) {
        wait = tokenWait;
        scope = RateLimitScope.tpm;
      }
    }
    return wait == Duration.zero ? null : RateWait(now.add(wait), scope);
  }

  /// Corrects the token bucket once the model reported the real prompt size
  /// of a request that [acquire] estimated at [estimated] tokens.
  void recordUsage({required int estimated, required int actual}) {
    if (_tpm == null) return;
    _refill();
    _tokens -= actual - estimated;
  }

  /// How long until a bucket at [level] with [perMinute] refill is back at 0.
  static Duration _waitFor(double level, int perMinute) {
    if (level >= 0) return Duration.zero;
    final micros = -level / perMinute * Duration.microsecondsPerMinute;
    return Duration(microseconds: micros.ceil());
  }

  DateTime _refill() {
    final now = _now();
    final elapsed = now.difference(_refilledAt).inMicroseconds;
    if (elapsed > 0) {
      final minutes = elapsed / Duration.microsecondsPerMinute;
      _requests = math.min(_rpm.toDouble(), _requests + minutes * _rpm);
      if (_tpm case final tpm?) {
        _tokens = math.min(tpm.toDouble(), _tokens + minutes * tpm);
      }
      _refilledAt = now;
    }
    return now;
  }
}
