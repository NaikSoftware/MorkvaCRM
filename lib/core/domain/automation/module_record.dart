import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';

import 'codec.dart';
import 'grant_record.dart';
import 'manifest.dart';
import 'manifest_parser.dart';
import 'module_bundle.dart';

/// `"sha256:" + hex(sha256(utf8(canonicalJson(manifest) + "\n" + code)))`:
/// pins the manifest and the code together, so a new name, action, scope or
/// timeout needs consent again just like new code.
String bundleHashOf(Map<String, Object?> manifestJson, String code) =>
    'sha256:${sha256.convert(utf8.encode('${canonicalJson(manifestJson)}\n$code'))}';

/// Who brought the module in.
enum ModuleSource { assistant, import }

/// `workspaces/{wid}/modules/{moduleId}`.
///
/// Dates are [DateTime] (UTC) in [toJson]/[fromJson]; Firestore stores them
/// as Timestamps and the store converts. [codeHash] is informational only:
/// anything that decides whether code may run hashes [manifestJson] + [code]
/// itself ([moduleStatusOf]).
final class ModuleRecord extends Equatable {
  ModuleRecord({
    required this.id,
    required this.manifestJson,
    required this.code,
    required this.codeHash,
    required this.source,
    required this.version,
    required this.name,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  /// A record for [bundle], hashed now.
  factory ModuleRecord.fromBundle(
    ModuleBundle bundle, {
    required ModuleSource source,
    required String createdBy,
    required DateTime now,
    DateTime? createdAt,
  }) => ModuleRecord(
    id: bundle.manifest.id,
    manifestJson: bundle.manifestJson,
    code: bundle.code,
    codeHash: bundleHashOf(bundle.manifestJson, bundle.code),
    source: source,
    version: bundle.manifest.version,
    name: bundle.manifest.name,
    createdBy: createdBy,
    createdAt: createdAt ?? now,
    updatedAt: now,
  );

  /// Throws [FormatException] on a doc that is not a module record. A
  /// manifest that no longer parses still loads (the module is `broken`).
  factory ModuleRecord.fromJson(String id, Map<String, Object?> json) =>
      ModuleRecord(
        id: id,
        manifestJson: readMap(json, 'manifest'),
        code: readString(json, 'code'),
        codeHash: readString(json, 'codeHash'),
        source: readEnum(json, 'source', ModuleSource.values, (s) => s.name),
        version: readString(json, 'version'),
        name: readString(json, 'name'),
        createdBy: readString(json, 'createdBy'),
        createdAt: readDate(json, 'createdAt'),
        updatedAt: readDate(json, 'updatedAt'),
      );

  final String id;

  /// The manifest exactly as shipped; re-parsed at every run.
  final Map<String, Object?> manifestJson;
  final String code;
  final String codeHash;
  final ModuleSource source;
  final String version;
  final String name;

  /// `user:<uid>` or `agent:assistant`.
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// The parsed manifest, or null when it no longer parses.
  late final ModuleManifest? manifest = _parse();

  /// The parser's problems when [manifest] is null.
  late final List<AutomationProblem> manifestProblems = _problems();

  /// [bundleHashOf] this record's own manifest + code (never [codeHash]),
  /// cached because status chips ask on every emit.
  late final String bundleHash = bundleHashOf(manifestJson, code);

  int get codeBytes => utf8.encode(code).length;

  ModuleBundle? get bundle => manifest == null
      ? null
      : ModuleBundle(
          manifestJson: manifestJson,
          code: code,
          manifest: manifest!,
        );

  ModuleManifest? _parse() {
    try {
      return parseManifest(manifestJson);
    } on ManifestProblems {
      return null;
    }
  }

  List<AutomationProblem> _problems() {
    try {
      parseManifest(manifestJson);
      return const [];
    } on ManifestProblems catch (e) {
      return e.problems;
    }
  }

  Map<String, Object?> toJson() => {
    'schema': 1,
    'manifest': manifestJson,
    'code': code,
    'codeHash': codeHash,
    'source': source.name,
    'version': version,
    'name': name,
    'createdBy': createdBy,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  @override
  List<Object?> get props => [
    id,
    manifestJson,
    code,
    codeHash,
    source,
    version,
    name,
    createdBy,
    createdAt,
    updatedAt,
  ];
}

/// A module's computed status (never stored).
enum ModuleStatus {
  ok('ok'),
  needsConsent('needs_consent'),
  broken('broken');

  const ModuleStatus(this.wire);

  final String wire;
}

/// First match wins: `broken` (the stored manifest no longer parses, or the
/// code is over the limit), `needsConsent` (no consent, a hash that differs
/// from [module]'s own manifest + code — never the stored `codeHash` — or a
/// capability the consent lacks), else `ok`.
ModuleStatus moduleStatusOf(ModuleRecord module, GrantRecord? consent) {
  final manifest = module.manifest;
  if (manifest == null || codeSizeProblem(module.code) != null) {
    return ModuleStatus.broken;
  }
  if (consent == null ||
      consent.codeHash != module.bundleHash ||
      !manifest.capabilities.every(consent.caps.contains)) {
    return ModuleStatus.needsConsent;
  }
  return ModuleStatus.ok;
}
