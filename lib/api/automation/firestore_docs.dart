import 'package:cloud_firestore/cloud_firestore.dart';

/// The workspace the automation stores read and write under
/// (`workspaces/{wid}/…`). Built once with the stores and shared by all four;
/// the app binds it at sign-in, before the runner subscribes.
///
/// Store writes resolve on server ack (Firestore's offline queue holds them
/// meanwhile), as everywhere else in `lib/api`.
final class AutomationWorkspace {
  AutomationWorkspace({required FirebaseFirestore firestore}) : _db = firestore;

  final FirebaseFirestore _db;
  DocumentReference<Map<String, dynamic>>? _workspace;

  void initialize({required String workspaceId}) =>
      _workspace = _db.collection('workspaces').doc(workspaceId);

  FirebaseFirestore get db => _db;

  CollectionReference<Map<String, dynamic>> collection(String path) =>
      (_workspace ??
              (throw StateError('Automation stores used before initialize().')))
          .collection(path);
}

/// A record's `toJson()` with every [DateTime] (at any depth) as a
/// [Timestamp]; null-valued keys are kept.
Map<String, Object?> encodeDoc(Map<String, Object?> json) =>
    _deep(json, (v) => v is DateTime ? Timestamp.fromDate(v) : v)
        as Map<String, Object?>;

/// A stored doc with every [Timestamp] (at any depth) as a UTC [DateTime],
/// ready for a record's `fromJson`.
Map<String, Object?> decodeDoc(Map<String, Object?> data) =>
    _deep(data, (v) => v is Timestamp ? v.toDate().toUtc() : v)
        as Map<String, Object?>;

Object? _deep(Object? value, Object? Function(Object?) leaf) => switch (value) {
  final Map<Object?, Object?> m => <String, Object?>{
    for (final MapEntry(:key, :value) in m.entries)
      key! as String: _deep(value, leaf),
  },
  final List<Object?> l => [for (final v in l) _deep(v, leaf)],
  _ => leaf(value),
};

/// [snapshot]'s data as a record, or null when absent or malformed (a doc
/// that fails `fromJson` is left out, never an error).
T? readRecord<T>(
  DocumentSnapshot<Map<String, dynamic>> snapshot,
  T Function(String id, Map<String, Object?> json) fromJson,
) {
  final data = snapshot.data();
  if (data == null) return null;
  try {
    return fromJson(snapshot.id, decodeDoc(data));
  } on FormatException {
    return null;
  }
}

/// Every doc of [snapshot] that decodes, in snapshot order.
List<T> readRecords<T>(
  QuerySnapshot<Map<String, dynamic>> snapshot,
  T Function(String id, Map<String, Object?> json) fromJson,
) => [for (final doc in snapshot.docs) ?readRecord(doc, fromJson)];
