import 'dart:collection';
import 'dart:convert';

/// One stored read result, named by [handle]: the spec that produced it, the
/// data generations it was computed over and its ordered card ids (plus the
/// groups of an aggregate). The UI renders full tables and charts from it;
/// paging reads it in O(page).
final class StoredResult {
  StoredResult._({
    required this.handle,
    required this.thread,
    required this.spec,
    required Map<String, int> generations,
    required List<String> orderedIds,
    this.groups,
    required String key,
  }) : generations = Map.unmodifiable(generations),
       orderedIds = List.unmodifiable(orderedIds),
       _key = key;

  /// Opaque, unique for the store's lifetime.
  final String handle;

  /// The conversation thread (or other caller scope) that owns it.
  final String thread;

  /// The canonical, resolved spec (ids, not names): re-running it gives the
  /// same result while [generations] hold.
  final Map<String, Object?> spec;

  /// Collection id → snapshot generation the result was computed over.
  final Map<String, int> generations;

  /// The matching card ids, in result order.
  final List<String> orderedIds;

  /// An aggregate's groups, in the shape the aggregate engine stores.
  final Object? groups;

  final String _key;

  int get total => orderedIds.length;

  /// Whether the data it was computed over is unchanged in [current]
  /// (generations by collection id).
  bool isCurrent(Map<String, int> current) =>
      generations.entries.every((g) => current[g.key] == g.value);
}

/// The result handles of a session: an LRU of at most [perThread] per thread
/// and [capacity] overall. Handles are not persisted (the spec is, on the
/// chat message), so an evicted handle simply re-runs from its spec.
final class ResultStore {
  ResultStore({this.perThread = 32, this.capacity = 64})
    : assert(perThread > 0 && capacity >= perThread);

  final int perThread;
  final int capacity;

  /// Least recently used first.
  final LinkedHashMap<String, StoredResult> _byHandle = LinkedHashMap();
  final Map<String, String> _handleByKey = {};
  int _minted = 0;

  int get length => _byHandle.length;

  /// Stores a result, or returns the stored one for the same [thread],
  /// [spec] and [generations] (a repeated query reuses its handle). Either
  /// way it becomes the most recently used; the oldest results beyond the
  /// caps are evicted.
  StoredResult put({
    required String thread,
    required Map<String, Object?> spec,
    required Map<String, int> generations,
    required List<String> orderedIds,
    Object? groups,
  }) {
    final key =
        '$thread\u0000${_canonical(spec)}\u0000'
        '${_canonical(generations)}';
    if (_handleByKey[key] case final handle?) return get(handle)!;
    final result = StoredResult._(
      handle: 'h_${++_minted}',
      thread: thread,
      spec: spec,
      generations: generations,
      orderedIds: orderedIds,
      groups: groups,
      key: key,
    );
    _byHandle[result.handle] = result;
    _handleByKey[key] = result.handle;
    _evict(thread);
    return result;
  }

  /// The result [handle] names, marked most recently used; null when it was
  /// evicted, dropped or never existed, or when [thread] is given and does
  /// not own it.
  StoredResult? get(String handle, {String? thread}) {
    final result = _byHandle[handle];
    if (result == null || (thread != null && result.thread != thread)) {
      return null;
    }
    _byHandle
      ..remove(handle)
      ..[handle] = result;
    return result;
  }

  /// Drops every result of [thread] (the user switched away from it).
  void dropThread(String thread) => _removeWhere((r) => r.thread == thread);

  /// Drops everything (sign-out or a workspace switch).
  void clear() {
    _byHandle.clear();
    _handleByKey.clear();
  }

  void _evict(String thread) {
    final owned = [
      for (final r in _byHandle.values)
        if (r.thread == thread) r,
    ];
    if (owned.length > perThread) {
      owned.take(owned.length - perThread).forEach(_remove);
    }
    while (_byHandle.length > capacity) {
      _remove(_byHandle.values.first);
    }
  }

  void _removeWhere(bool Function(StoredResult) test) =>
      _byHandle.values.where(test).toList().forEach(_remove);

  void _remove(StoredResult r) {
    _byHandle.remove(r.handle);
    _handleByKey.remove(r._key);
  }

  /// [value] as JSON with map keys sorted, so equal specs give equal keys.
  static String _canonical(Object? value) => jsonEncode(_sorted(value));

  static Object? _sorted(Object? value) => switch (value) {
    Map() => {
      for (final k in value.keys.map((k) => '$k').toList()..sort())
        k: _sorted(value[k]),
    },
    List() => [for (final v in value) _sorted(v)],
    _ => value,
  };
}
