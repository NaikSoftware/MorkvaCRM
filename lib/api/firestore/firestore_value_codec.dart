import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:morkva_crm/core/domain/domain.dart';

/// Translates a domain field's canonical JSON value to and from the native
/// Firestore representation.
///
/// Most field types are pure pass-through (their canonical JSON is already a
/// native Firestore type). The only non-trivial mapping is `date`: an ISO-8601
/// string ↔ a Firestore [Timestamp]. The codec operates per-field because the
/// [FieldDefinition] determines how the value is interpreted.
abstract interface class FirestoreValueCodec {
  /// Encodes [jsonValue] (canonical JSON for [field]) into a value Firestore can
  /// store natively. Tolerates `null`.
  Object? encode(FieldDefinition field, Object? jsonValue);

  /// Decodes [firestoreValue] (a native Firestore value for [field]) back into
  /// the canonical JSON representation. Tolerates `null`.
  Object? decode(FieldDefinition field, Object? firestoreValue);
}
