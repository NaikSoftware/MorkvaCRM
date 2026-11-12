import 'dart:convert';

import 'manifest.dart';
import 'manifest_parser.dart';

/// The `*.morkva.json` file format version.
const int kBundleFormat = 1;

/// Module code is at most this many UTF-8 bytes (the rules backstop it at
/// 262144 characters).
const int kCodeMaxBytes = 256 * 1024;

/// A whole `*.morkva.json` file is at most this many UTF-8 bytes.
const int kBundleFileMaxBytes = 300 * 1024;

/// A module as it travels outside Firestore: `{morkva: 1, manifest, code}`.
/// Import holds it in memory until the user installs it.
final class ModuleBundle {
  const ModuleBundle({
    required this.manifestJson,
    required this.code,
    required this.manifest,
  });

  /// [manifestJson] parsed; throws [ManifestProblems] like the decoder.
  factory ModuleBundle.of(Map<String, Object?> manifestJson, String code) {
    final problems = <AutomationProblem>[?codeSizeProblem(code)];
    ModuleManifest? manifest;
    try {
      manifest = parseManifest(manifestJson);
    } on ManifestProblems catch (e) {
      problems.addAll(e.problems);
    }
    if (problems.isNotEmpty) throw ManifestProblems(problems);
    return ModuleBundle(
      manifestJson: manifestJson,
      code: code,
      manifest: manifest!,
    );
  }

  /// The manifest exactly as the author wrote it (what the hash covers).
  final Map<String, Object?> manifestJson;
  final String code;
  final ModuleManifest manifest;

  int get codeBytes => utf8.encode(code).length;

  /// The file text: the manifest pretty-printed, the code as stored.
  String encode() => const JsonEncoder.withIndent(
    '  ',
  ).convert({'morkva': kBundleFormat, 'manifest': manifestJson, 'code': code});
}

/// Parses a `*.morkva.json` file. Throws [ManifestProblems] with every
/// problem: not a module file, sizes, then the manifest's own problems.
ModuleBundle decodeModuleBundle(String text) {
  final bytes = utf8.encode(text).length;
  if (bytes > kBundleFileMaxBytes) {
    throw ManifestProblems([
      AutomationProblem(
        '',
        'too_large',
        'The file is ${_kb(bytes)}; the limit is 300 KB.',
      ),
    ]);
  }
  Object? json;
  try {
    json = jsonDecode(text);
  } on FormatException {
    json = null;
  }
  if (json is! Map<String, Object?> ||
      json['morkva'] != kBundleFormat ||
      json['manifest'] is! Map<String, Object?> ||
      json['code'] is! String ||
      json.keys.any((k) => !const {'morkva', 'manifest', 'code'}.contains(k))) {
    throw ManifestProblems(const [
      AutomationProblem('', 'invalid', 'This isn\'t a Morkva module file.'),
    ]);
  }
  return ModuleBundle.of(
    json['manifest'] as Map<String, Object?>,
    json['code'] as String,
  );
}

/// The code size problem, or null when [code] fits.
AutomationProblem? codeSizeProblem(String code) {
  final bytes = utf8.encode(code).length;
  if (bytes <= kCodeMaxBytes) return null;
  return AutomationProblem(
    'code',
    'too_large',
    'The code is ${_kb(bytes)}; the limit is 256 KB.',
  );
}

/// JSON with object keys sorted at every level and no whitespace. Whole
/// doubles are written as ints, so the VM (`2.0`) and the web (`2`) agree and
/// a bundle hashes the same on every device.
String canonicalJson(Object? value) => jsonEncode(_canonical(value));

Object? _canonical(Object? value) => switch (value) {
  final Map<Object?, Object?> map => {
    for (final key in map.keys.map((k) => '$k').toList()..sort())
      key: _canonical(map[key]),
  },
  final List<Object?> list => [for (final v in list) _canonical(v)],
  final double d when d.isFinite && d == d.truncateToDouble() => d.toInt(),
  _ => value,
};

String _kb(int bytes) => '${(bytes / 1024).ceil()} KB';
