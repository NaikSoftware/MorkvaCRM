import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';

import 'assistant_config.dart';

/// Watches the assistant's effective [AssistantConfig]: the global
/// `config/assistant` doc (admin-written, read-only to clients) ∪ the user's
/// `featureFlags/{uid}`, over compiled defaults.
///
/// Bind it to a signed-in user with [initialize] before [watch] (the
/// always-provided `late final` + `initialize` pattern).
class AssistantConfigRepository {
  AssistantConfigRepository({required FirebaseFirestore firestore})
    : _db = firestore;

  final FirebaseFirestore _db;

  String? _uid;

  /// Binds the repository to the member [uid].
  void initialize({required String uid}) => _uid = uid;

  /// The effective config, re-emitted whenever one of the two docs changes.
  ///
  /// A missing doc, or one that can't be read (e.g. rules not deployed yet),
  /// counts as absent, so it never blocks the assistant: the stream does not
  /// error.
  Stream<AssistantConfig> watch() {
    final uid =
        _uid ??
        (throw StateError(
          'AssistantConfigRepository used before initialize().',
        ));
    return Rx.combineLatest2(
      _data(_db.collection('config').doc('assistant')),
      _data(_db.collection('featureFlags').doc(uid)),
      (global, flags) =>
          AssistantConfig.resolve(global: global, userFlags: flags),
    ).distinct();
  }

  Stream<Map<String, Object?>?> _data(
    DocumentReference<Map<String, dynamic>> ref,
  ) => ref
      .snapshots()
      .map<Map<String, Object?>?>((snapshot) => snapshot.data())
      .onErrorReturnWith((error, _) {
        developer.log(
          'Reading ${ref.path} failed; using defaults',
          name: 'assistant',
          error: error,
        );
        return null;
      });
}
