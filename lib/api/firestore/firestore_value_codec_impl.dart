import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:morkva_crm/core/domain/domain.dart';

import 'firestore_value_codec.dart';

/// Pure-function [FirestoreValueCodec] implementation.
///
/// Performs no Firestore I/O. The only non-pass-through mapping is `date`:
/// * encode: an ISO-8601 string ([DateFieldValue.toJson] output) →
///   [Timestamp.fromDate] of the parsed UTC instant.
/// * decode: a [Timestamp] → `toDate().toUtc().toIso8601String()`, which is
///   exactly the form [DateFieldDefinition.valueFromJson] re-parses to the same
///   normalized [DateTime] (date-only or full instant per `includeTime`).
///
/// Every other field type's canonical JSON is already a native Firestore value
/// (String/num/bool/List/Map/null), so it passes through unchanged.
class FirestoreValueCodecImpl implements FirestoreValueCodec {
  /// Creates a stateless codec.
  const FirestoreValueCodecImpl();

  @override
  Object? encode(FieldDefinition field, Object? jsonValue) {
    if (jsonValue == null) return null;
    if (field.type == kDateFieldType && jsonValue is String) {
      return Timestamp.fromDate(DateTime.parse(jsonValue).toUtc());
    }
    return jsonValue;
  }

  @override
  Object? decode(FieldDefinition field, Object? firestoreValue) {
    if (firestoreValue == null) return null;
    if (field.type == kDateFieldType && firestoreValue is Timestamp) {
      return firestoreValue.toDate().toUtc().toIso8601String();
    }
    return firestoreValue;
  }
}
