import '../api/envelope.dart';

/// Collects every problem of a many-row input in one pass, so the caller
/// gets them all in one `details` list and fixes them in one round.
final class InputErrors {
  final List<ErrorDetail> _details = [];

  bool get isEmpty => _details.isEmpty;

  List<ErrorDetail> get details => List.unmodifiable(_details);

  void add(ErrorDetail detail) => _details.add(detail);

  /// Records [error] (and its own details, flattened).
  void addError(HarnessError error) {
    final nested = error.details;
    if (nested != null && nested.isNotEmpty) {
      _details.addAll(nested);
      return;
    }
    _details.add(
      ErrorDetail(
        path: error.path ?? '',
        code: error.code,
        message: error.message,
        candidates: error.candidates,
      ),
    );
  }

  /// Runs [body]; a [HarnessException] it throws is recorded and null is
  /// returned instead.
  T? guard<T>(T Function() body) {
    try {
      return body();
    } on HarnessException catch (e) {
      addError(e.error);
      return null;
    }
  }

  /// Throws one [HarnessException] standing for every recorded problem.
  void throwIfAny({String? hint}) {
    if (_details.isEmpty) return;
    throw HarnessException(HarnessError.fromDetails(_details, hint: hint));
  }
}
