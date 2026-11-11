import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';

import 'assistant_config.dart';

/// Watches the assistant's effective [AssistantConfig]: the global
/// `config/assistant` doc (admin-written, read-only to clients) ∪ the user's
/// `featureFlags/{uid}` ∪ the workspace consent at
/// `workspaces/{wid}/config/assistant`, over compiled defaults.
///
/// Bind it to a signed-in user with [initialize] before [watch] or
/// [grantConsent] (the always-provided `late final` + `initialize` pattern).
class AssistantConfigRepository {
  AssistantConfigRepository({
    required FirebaseFirestore firestore,
    DateTime Function()? now,
  }) : _db = firestore,
       _now = now ?? DateTime.now;

  final FirebaseFirestore _db;
  final DateTime Function() _now;

  String? _workspaceId;
  String? _uid;

  /// Binds the repository to [workspaceId] and the member [uid].
  void initialize({required String workspaceId, required String uid}) {
    _workspaceId = workspaceId;
    _uid = uid;
  }

  /// The effective config, re-emitted whenever one of the three docs changes.
  ///
  /// A missing doc, or one that can't be read (e.g. rules not deployed yet),
  /// counts as absent, so it never blocks the assistant: the stream does not
  /// error.
  Stream<AssistantConfig> watch() {
    final (wid, uid) = _bound;
    return Rx.combineLatest3(
      _data(_db.collection('config').doc('assistant')),
      _data(_db.collection('featureFlags').doc(uid)),
      _data(_consentDoc(wid)),
      (global, flags, consent) => AssistantConfig.resolve(
        global: global,
        userFlags: flags,
        consent: _consentFrom(consent),
      ),
    ).distinct();
  }

  /// Records that the current user enabled the assistant for the workspace.
  Future<void> grantConsent() {
    final (wid, uid) = _bound;
    return _consentDoc(wid).set({
      'consentedBy': uid,
      'consentedAt': _now().toUtc().toIso8601String(),
    }, SetOptions(merge: true));
  }

  (String, String) get _bound {
    final wid = _workspaceId;
    final uid = _uid;
    if (wid == null || uid == null) {
      throw StateError('AssistantConfigRepository used before initialize().');
    }
    return (wid, uid);
  }

  DocumentReference<Map<String, dynamic>> _consentDoc(String wid) => _db
      .collection('workspaces')
      .doc(wid)
      .collection('config')
      .doc('assistant');

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

  static AssistantConsent? _consentFrom(Map<String, Object?>? data) {
    final by = data?['consentedBy'];
    if (by is! String || by.isEmpty) return null;
    // An admin may set the date in the console as a Timestamp.
    final at = switch (data?['consentedAt']) {
      final Timestamp t => t.toDate().toUtc(),
      final String s => DateTime.tryParse(s)?.toUtc(),
      _ => null,
    };
    return AssistantConsent(consentedBy: by, consentedAt: at);
  }
}
