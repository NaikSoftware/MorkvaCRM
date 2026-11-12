/// The transport-neutral harness envelope: requests, responses, errors and
/// out-of-band events. Everything here round-trips through plain JSON (strings,
/// numbers, bools, null, lists and maps), so the same shapes serve the Dart
/// agent loop today and a JS plugin bridge later.
library;

import 'api_version.dart';

/// The closed set of error codes. Adding one is a minor version bump.
///
/// [wire] is the snake_case string that crosses the boundary. The first eight
/// are domain validation codes passed through verbatim.
enum ErrorCode {
  // Domain validation codes.
  requiredValue('required'),
  outOfRange('out_of_range'),
  tooLong('too_long'),
  invalidOption('invalid_option'),
  invalidReference('invalid_reference'),
  tooManyReferences('too_many_references'),
  tooManyFiles('too_many_files'),
  invalidExtension('invalid_extension'),
  // Harness codes.
  invalidArgs('invalid_args'),

  /// A plan call that would change nothing: information, not a failure.
  noChange('no_change'),
  unsupportedVersion('unsupported_version'),
  unknownOp('unknown_op'),
  notPermitted('not_permitted'),
  wrongType('wrong_type'),
  unknownCollection('unknown_collection'),
  unknownField('unknown_field'),
  unknownView('unknown_view'),
  unknownOption('unknown_option'),
  unknownObject('unknown_object'),
  ambiguousReference('ambiguous_reference'),
  invalidFilter('invalid_filter'),
  readOnlyField('read_only_field'),
  typeLocked('type_locked'),
  schemaInvalid('schema_invalid'),
  formulaError('formula_error'),
  formulaCycle('formula_cycle'),
  countMismatch('count_mismatch'),
  lastView('last_view'),
  limitExceeded('limit_exceeded'),
  planExpired('plan_expired'),
  stalePreview('stale_preview'),
  offline('offline'),
  conflict('conflict'),
  unsupported('unsupported'),
  internal('internal');

  const ErrorCode(this.wire);

  final String wire;

  /// Whether the same call may succeed if simply repeated later.
  bool get retryableByDefault => this == offline || this == conflict;

  /// The code for [wire], or null when it is not one of ours (a field type's
  /// own validation code, say). Callers decide how to map those.
  static ErrorCode? fromWire(String wire) {
    for (final code in values) {
      if (code.wire == wire) return code;
    }
    return null;
  }
}

/// One problem among many, for ops that validate many rows at once.
final class ErrorDetail {
  const ErrorDetail({
    required this.path,
    required this.code,
    required this.message,
    this.candidates,
  });

  factory ErrorDetail.fromJson(Map<String, Object?> json) => ErrorDetail(
    path: _string(json, 'path'),
    code: _code(json),
    message: _string(json, 'message'),
    candidates: _listOrNull(json, 'candidates'),
  );

  /// Where the problem is, e.g. `cards[7].values.Total`. Empty for the root.
  final String path;
  final ErrorCode code;

  /// Written for a model reader: names the bad value and how to fix it.
  final String message;

  /// Valid alternatives: names, ids or `{id, title}` maps.
  final List<Object?>? candidates;

  Map<String, Object?> toJson() => {
    'path': path,
    'code': code.wire,
    'message': message,
    if (candidates != null) 'candidates': candidates,
  };

  @override
  String toString() => 'ErrorDetail($path, ${code.wire}: $message)';
}

/// A failed call's error. Messages are written for a model reader: they name
/// the bad value, list the valid alternatives and say how to fix it.
final class HarnessError {
  HarnessError({
    required this.code,
    required this.message,
    this.path,
    this.candidates,
    bool? retryable,
    this.hint,
    this.details,
    this.moreErrors,
    this.offset,
    this.expected,
    this.actual,
  }) : retryable = retryable ?? code.retryableByDefault;

  /// One error standing for all of [problems] (at least one): the first sets
  /// the top-level code, path and message; when there are several, `details`
  /// lists up to [maxDetails] and `moreErrors` counts the rest, so the caller
  /// can fix every row in one round.
  factory HarnessError.fromDetails(
    List<ErrorDetail> problems, {
    String? hint,
    int maxDetails = 20,
  }) {
    if (problems.isEmpty) {
      throw ArgumentError.value(problems, 'problems', 'must not be empty');
    }
    final first = problems.first;
    final many = problems.length > 1;
    final extra = problems.length - maxDetails;
    return HarnessError(
      code: first.code,
      message: first.message,
      path: first.path,
      candidates: first.candidates,
      hint: hint,
      details: many ? problems.take(maxDetails).toList() : null,
      moreErrors: many && extra > 0 ? extra : null,
    );
  }

  factory HarnessError.fromJson(Map<String, Object?> json) {
    final details = _listOrNull(json, 'details');
    return HarnessError(
      code: _code(json),
      message: _string(json, 'message'),
      path: json['path'] as String?,
      candidates: _listOrNull(json, 'candidates'),
      retryable: json['retryable'] as bool?,
      hint: json['hint'] as String?,
      details: details
          ?.map((d) => ErrorDetail.fromJson(_map(d, 'details[]')))
          .toList(),
      moreErrors: json['moreErrors'] as int?,
      offset: json['offset'] as int?,
      expected: json['expected'] as int?,
      actual: json['actual'] as int?,
    );
  }

  final ErrorCode code;
  final String message;
  final String? path;
  final List<Object?>? candidates;
  final bool retryable;
  final String? hint;
  final List<ErrorDetail>? details;

  /// How many problems beyond [details] were found.
  final int? moreErrors;

  /// The character offset of a `formula_error`.
  final int? offset;

  /// The expected and live match counts of a `count_mismatch`.
  final int? expected;
  final int? actual;

  Map<String, Object?> toJson() => {
    'code': code.wire,
    'message': message,
    if (path != null) 'path': path,
    if (candidates != null) 'candidates': candidates,
    'retryable': retryable,
    if (hint != null) 'hint': hint,
    if (details != null) 'details': [for (final d in details!) d.toJson()],
    if (moreErrors != null) 'moreErrors': moreErrors,
    if (offset != null) 'offset': offset,
    if (expected != null) 'expected': expected,
    if (actual != null) 'actual': actual,
  };

  @override
  String toString() =>
      'HarnessError(${code.wire}${path == null ? '' : ' at $path'}: $message)';
}

/// Thrown inside the harness (by ops, resolvers, planners) to fail a call with
/// a structured [error]. `Harness.call` turns it into a [HarnessFailure];
/// it never escapes to the transport.
final class HarnessException implements Exception {
  HarnessException(this.error);

  /// Shorthand for a single-problem error.
  HarnessException.of(
    ErrorCode code,
    String message, {
    String? path,
    List<Object?>? candidates,
    String? hint,
  }) : error = HarnessError(
         code: code,
         message: message,
         path: path,
         candidates: candidates,
         hint: hint,
       );

  final HarnessError error;

  @override
  String toString() => 'HarnessException($error)';
}

/// One call into the harness.
///
/// The transport sets `actor`, `grants`, `today`/`now` and the event sink on
/// the `HarnessContext` itself; none of them is ever read from here.
final class HarnessRequest {
  const HarnessRequest({
    required this.op,
    this.args = const {},
    required this.callId,
    this.turnId,
    this.v = kHarnessApiVersion,
  });

  /// Parses a request from a transport. Throws [FormatException] when the
  /// envelope itself is malformed (args are checked later, by schema).
  factory HarnessRequest.fromJson(Map<String, Object?> json) {
    final v = json['v'];
    if (v is! int) throw const FormatException('"v" must be an integer');
    final args = json['args'];
    if (args != null && args is! Map) {
      throw const FormatException('"args" must be an object');
    }
    return HarnessRequest(
      v: v,
      op: _string(json, 'op'),
      args: args == null ? const {} : _map(args, 'args'),
      callId: _string(json, 'callId'),
      turnId: json['turnId'] as String?,
    );
  }

  /// The protocol major version the caller speaks.
  final int v;

  /// The dotted op id, e.g. `cards.query`.
  final String op;
  final Map<String, Object?> args;

  /// The caller's id for this call (`r2.1` from the agent loop, `h.4` from the
  /// host); echoed in progress events.
  final String callId;

  /// A turn minted by `Harness.openTurn` for the calling actor. Plan ops that
  /// share it merge into one plan.
  final String? turnId;

  Map<String, Object?> toJson() => {
    'v': v,
    'op': op,
    'args': args,
    'callId': callId,
    if (turnId != null) 'turnId': turnId,
  };
}

/// Per-response metadata.
final class ResponseMeta {
  const ResponseMeta({
    required this.ms,
    this.generation,
    this.truncated = false,
  });

  factory ResponseMeta.fromJson(Map<String, Object?> json) => ResponseMeta(
    ms: json['ms'] as int? ?? 0,
    generation: json['generation'] as int?,
    truncated: json['truncated'] as bool? ?? false,
  );

  /// Wall time spent in the harness.
  final int ms;

  /// The workspace-cache generation the result was computed from, when the op
  /// read cached data.
  final int? generation;

  /// Whether the result was cut to its byte budget.
  final bool truncated;

  Map<String, Object?> toJson() => {
    'ms': ms,
    if (generation != null) 'generation': generation,
    'truncated': truncated,
  };
}

/// The outcome of `Harness.call`: either [HarnessOk] or [HarnessFailure].
sealed class HarnessResponse {
  const HarnessResponse();

  factory HarnessResponse.fromJson(Map<String, Object?> json) {
    final ok = json['ok'];
    if (ok == true) {
      return HarnessOk(
        _map(json['result'] ?? const <String, Object?>{}, 'result'),
        json['meta'] == null
            ? const ResponseMeta(ms: 0)
            : ResponseMeta.fromJson(_map(json['meta'], 'meta')),
      );
    }
    if (ok == false) {
      return HarnessFailure(
        HarnessError.fromJson(_map(json['error'], 'error')),
      );
    }
    throw const FormatException('"ok" must be a bool');
  }

  bool get ok;

  Map<String, Object?> toJson();
}

final class HarnessOk extends HarnessResponse {
  const HarnessOk(this.result, this.meta);

  final Map<String, Object?> result;
  final ResponseMeta meta;

  @override
  bool get ok => true;

  @override
  Map<String, Object?> toJson() => {
    'ok': true,
    'result': result,
    'meta': meta.toJson(),
  };
}

final class HarnessFailure extends HarnessResponse {
  const HarnessFailure(this.error);

  final HarnessError error;

  @override
  bool get ok => false;

  @override
  Map<String, Object?> toJson() => {'ok': false, 'error': error.toJson()};
}

/// An out-of-band event sent through `HarnessContext.events` while a call
/// runs. Part of the protocol: `harness.describe` lists the event names.
sealed class HarnessEvent {
  const HarnessEvent();

  /// Every event name, as listed by `harness.describe`.
  static const List<String> names = [ProgressEvent.name];

  factory HarnessEvent.fromJson(Map<String, Object?> json) =>
      switch (json['event']) {
        ProgressEvent.name => ProgressEvent(
          callId: _string(json, 'callId'),
          done: json['done'] as int,
          total: json['total'] as int,
        ),
        final other => throw FormatException('Unknown harness event "$other"'),
      };

  Map<String, Object?> toJson();
}

/// Commit progress: [done] of [total] items written so far.
final class ProgressEvent extends HarnessEvent {
  const ProgressEvent({
    required this.callId,
    required this.done,
    required this.total,
  });

  static const String name = 'progress';

  final String callId;
  final int done;
  final int total;

  @override
  Map<String, Object?> toJson() => {
    'event': name,
    'callId': callId,
    'done': done,
    'total': total,
  };
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String) throw FormatException('"$key" must be a string');
  return value;
}

ErrorCode _code(Map<String, Object?> json) {
  final wire = _string(json, 'code');
  return ErrorCode.fromWire(wire) ??
      (throw FormatException('Unknown error code "$wire"'));
}

List<Object?>? _listOrNull(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! List) throw FormatException('"$key" must be a list');
  return value.cast<Object?>();
}

Map<String, Object?> _map(Object? value, String key) {
  if (value is! Map) throw FormatException('"$key" must be an object');
  return value.cast<String, Object?>();
}
