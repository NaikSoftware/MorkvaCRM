import 'package:equatable/equatable.dart';

import 'capability_copy.dart';
import 'codec.dart';

/// How a consent was given.
enum GrantVia {
  consentSheet('consent_sheet'),
  assistantPlan('assistant_plan');

  const GrantVia(this.wire);

  final String wire;
}

/// A member's consent for one module:
/// `workspaces/{wid}/members/{uid}/grants/{moduleId}`.
///
/// Pinned to [codeHash] (`bundleHashOf` of the bundle the user saw), so new
/// code or a new manifest needs consent again. Dates are [DateTime] in
/// [toJson]/[fromJson]; the store converts Timestamps.
final class GrantRecord extends Equatable {
  const GrantRecord({
    required this.moduleId,
    required this.codeHash,
    required this.version,
    required this.codeBytes,
    required this.caps,
    required this.collections,
    required this.autoApply,
    required this.grantedAt,
    required this.via,
  });

  /// Parses with the module capability allowlist (never `Grants.fromJson`):
  /// `'*'`, an unknown wire or any malformed key throws [FormatException],
  /// which the store treats as no consent.
  factory GrantRecord.fromJson(Map<String, Object?> json) {
    if (json['schema'] != 1) throw const FormatException('Unknown schema');
    final caps = readStrings(json, 'caps');
    for (final cap in caps) {
      if (!kCapabilityCopy.containsKey(cap)) {
        throw FormatException('Not a module capability "$cap"');
      }
    }
    final via = readEnum(json, 'via', GrantVia.values, (v) => v.wire);
    final autoApply = readBool(json, 'autoApply');
    if (via == GrantVia.assistantPlan && autoApply) {
      throw const FormatException('A plan never grants auto-apply');
    }
    return GrantRecord(
      moduleId: readString(json, 'moduleId'),
      codeHash: readString(json, 'codeHash'),
      version: readString(json, 'version'),
      codeBytes: readInt(json, 'codeBytes'),
      caps: caps,
      collections: readStringsOrNull(json, 'collections'),
      autoApply: autoApply,
      grantedAt: readDate(json, 'grantedAt'),
      via: via,
    );
  }

  final String moduleId;
  final String codeHash;

  /// The module version consented to (shown as "v1.0.0 → v1.1.0").
  final String version;
  final int codeBytes;

  /// Capability wires.
  final List<String> caps;

  /// Collection ids; null = all collections.
  final List<String>? collections;
  final bool autoApply;
  final DateTime grantedAt;
  final GrantVia via;

  GrantRecord copyWith({
    List<String>? Function()? collections,
    bool? autoApply,
  }) => GrantRecord(
    moduleId: moduleId,
    codeHash: codeHash,
    version: version,
    codeBytes: codeBytes,
    caps: caps,
    collections: collections == null ? this.collections : collections(),
    autoApply: autoApply ?? this.autoApply,
    grantedAt: grantedAt,
    via: via,
  );

  Map<String, Object?> toJson() => {
    'schema': 1,
    'moduleId': moduleId,
    'codeHash': codeHash,
    'version': version,
    'codeBytes': codeBytes,
    'caps': caps,
    'collections': collections,
    'autoApply': autoApply,
    'grantedAt': grantedAt,
    'via': via.wire,
  };

  @override
  List<Object?> get props => [
    moduleId,
    codeHash,
    version,
    codeBytes,
    caps,
    collections,
    autoApply,
    grantedAt,
    via,
  ];
}
