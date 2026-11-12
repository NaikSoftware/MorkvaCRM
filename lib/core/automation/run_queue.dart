/// The serial run queue of one workspace (design spec, Run queue &
/// lifecycle): one run holds the slot at a time; manual runs (buttons, Run
/// again) wait ahead of event runs that have not started, each kind in
/// arrival order, so a commit's follow-up events land at the tail
/// (breadth-first).
///
/// The runner decides when the slot is released: at `awaiting_review` or a
/// terminal status, and for auto runs only after their commit settled.
final class RunQueue<T> {
  final List<T> _manual = [];
  final List<T> _events = [];
  T? _current;

  /// The run holding the slot, if any.
  T? get current => _current;

  /// The waiting runs in the order they will start.
  List<T> get waiting => [..._manual, ..._events];

  int get length => _manual.length + _events.length;

  void add(T run, {required bool manual}) =>
      (manual ? _manual : _events).add(run);

  /// Gives the slot to the next waiting run and returns it; null when the
  /// slot is taken or nothing waits.
  T? next() {
    if (_current != null) return null;
    final list = _manual.isNotEmpty ? _manual : _events;
    if (list.isEmpty) return null;
    return _current = list.removeAt(0);
  }

  /// Frees the slot if [run] holds it.
  void release(T run) {
    if (identical(_current, run)) _current = null;
  }

  /// Takes a waiting [run] out (Stop); false when it is not waiting.
  bool remove(T run) => _manual.remove(run) || _events.remove(run);

  /// Takes every waiting run that passes [test] out, in queue order.
  List<T> removeWhere(bool Function(T run) test) {
    final gone = waiting.where(test).toList();
    _manual.removeWhere(test);
    _events.removeWhere(test);
    return gone;
  }

  /// Runs that start before waiting [run], the slot's holder included
  /// ("Queued · 3 ahead"); null when [run] is not waiting.
  int? ahead(T run) {
    final i = waiting.indexOf(run);
    return i < 0 ? null : i + (_current == null ? 0 : 1);
  }

  /// Waiting runs that pass [test].
  int count(bool Function(T run) test) => waiting.where(test).length;

  /// Forgets everything, the slot included (sign-out).
  void clear() {
    _manual.clear();
    _events.clear();
    _current = null;
  }
}
