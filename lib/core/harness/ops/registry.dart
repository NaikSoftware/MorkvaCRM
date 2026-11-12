import '../api/api_version.dart';
import '../api/operation.dart';
import '../schema/json_schema.dart';

/// The ops a `Harness` serves, by id.
///
/// Each op module registers its ops through its own function in its own file,
/// so no two modules edit the same path:
/// - `protocol_ops.dart` → `registerProtocolOps` (`harness.describe`)
/// - `read_ops.dart` → `registerReadOps`
/// - `ui_ops.dart` → `registerUiOps`
/// - `plan_protocol_ops.dart` → `registerPlanOps` (schema, card and protocol
///   plan ops)
/// - `view_ops.dart` → `registerViewOps`
/// - `host_ops.dart` → `registerHostOps` (commit ops)
/// - `module_ops.dart` → `registerModuleOps` (`modules.*`, `automations.*`,
///   `runs.*`)
///
/// The host composes them; each takes the registry plus whatever services
/// its ops need.
final class OperationRegistry {
  final Map<String, Operation<Object?>> _ops = {};

  /// Dotted lower-camel segments: `cards.query`, `plans.retryFailed`.
  static final RegExp idPattern = RegExp(
    r'^[a-z][a-zA-Z0-9]*(\.[a-z][a-zA-Z0-9]*)+$',
  );

  /// What Gemini accepts as a function name.
  static final RegExp toolNamePattern = RegExp(r'^[a-zA-Z0-9_-]{1,63}$');

  /// The model-facing name of an op id (`cards.query` → `cards_query`).
  static String toolName(String opId) => opId.replaceAll('.', '_');

  /// Adds [op]. Throws [ArgumentError] when its id is malformed or taken, its
  /// `since` is newer than this harness, or a schema is outside the subset
  /// `JsonSchema` supports, so a bad descriptor never reaches a caller.
  void register(Operation<Object?> op) {
    final d = op.descriptor;
    final problems = <String>[
      if (!idPattern.hasMatch(d.id)) 'id must be dotted lower camel',
      if (!toolNamePattern.hasMatch(toolName(d.id)))
        'tool name "${toolName(d.id)}" is not a valid function name',
      if (_ops.containsKey(d.id)) 'already registered',
      if (!_supported(d.since))
        'since "${d.since}" is newer than $kHarnessVersion',
      if (d.summary.trim().isEmpty) 'summary is empty',
      if (d.argsSchema['type'] != 'object') 'args schema must be an object',
      if (d.resultSchema['type'] != 'object') 'result schema must be an object',
      ...JsonSchema.check(d.argsSchema, at: 'args'),
      ...JsonSchema.check(d.resultSchema, at: 'result'),
    ];
    if (problems.isNotEmpty) {
      throw ArgumentError.value(d.id, 'op', problems.join('; '));
    }
    _ops[d.id] = op;
  }

  Operation<Object?>? lookup(String id) => _ops[id];

  bool contains(String id) => _ops.containsKey(id);

  /// Every registered op id, sorted.
  List<String> get ids => _ops.keys.toList()..sort();

  /// Every descriptor, sorted by id (a stable order for the golden and for
  /// tool declarations).
  List<OperationDescriptor> get descriptors => [
    for (final id in ids) _ops[id]!.descriptor,
  ];

  static bool _supported(String since) {
    final parts = since.split('.');
    if (parts.length != 2) return false;
    final major = int.tryParse(parts[0]);
    final minor = int.tryParse(parts[1]);
    if (major == null || minor == null) return false;
    return major < kHarnessApiVersion ||
        (major == kHarnessApiVersion && minor <= kHarnessMinor);
  }
}
