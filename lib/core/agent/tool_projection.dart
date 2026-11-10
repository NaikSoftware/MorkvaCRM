import 'dart:convert';

import '../harness/harness.dart';
import 'llm_client.dart';

/// The tools one turn declares to the model: every model-visible harness op
/// the actor's grants allow, projected to a provider-safe name
/// (`cards.query` → `cards_query`), plus the way back from a called name to
/// its op.
///
/// Commit ops and the protocol ops (`harness.describe`, `plans.seal`,
/// `plans.get`) are never model-visible, so the model has no name to call
/// them by.
final class ToolSet {
  ToolSet._(this.tools, this._byName);

  /// Projects [descriptors] (sorted by id, as the registry lists them) under
  /// [grants].
  factory ToolSet.project(
    Iterable<OperationDescriptor> descriptors,
    Grants grants,
  ) {
    final tools = <LlmTool>[];
    final byName = <String, OperationDescriptor>{};
    for (final d in descriptors) {
      final cap = d.capability;
      if (!d.modelVisible || d.kind == OpKind.commit || cap == null) continue;
      if (!grants.allows(cap)) continue;
      final name = OperationRegistry.toolName(d.id);
      byName[name] = d;
      tools.add(
        LlmTool(
          name: name,
          description: d.summary,
          parametersJsonSchema: lowerSchema(d.argsSchema),
        ),
      );
    }
    return ToolSet._(List.unmodifiable(tools), byName);
  }

  final List<LlmTool> tools;
  final Map<String, OperationDescriptor> _byName;

  /// The op behind a tool [name] the model called, or null when no declared
  /// tool has that name.
  OperationDescriptor? opFor(String name) => _byName[name];

  /// Rough size of the declarations in characters, for the token estimate.
  late final int chars = tools.fold(
    0,
    (sum, t) =>
        sum +
        t.name.length +
        t.description.length +
        jsonEncode(t.parametersJsonSchema).length,
  );
}

/// A deep copy of [schema] keeping only the keywords the harness schemas
/// use ([JsonSchema.keywords]), so whatever reaches the provider is the
/// supported subset. Harness schemas carry no `$defs` (shared shapes are
/// inlined by the builders), and the T0 spike showed Gemini accepts
/// `additionalProperties` and `anyOf` unchanged, so nothing else is lowered.
Map<String, Object?> lowerSchema(Map<String, Object?> schema) => {
  for (final MapEntry(:key, :value) in schema.entries)
    if (JsonSchema.keywords.contains(key)) key: _lowerValue(key, value),
};

Object? _lowerValue(String key, Object? value) => switch ((key, value)) {
  ('properties', final Map props) => {
    for (final MapEntry(:key, :value) in props.entries)
      '$key': value is Map ? lowerSchema(value.cast()) : value,
  },
  ('items' || 'additionalProperties', final Map sub) => lowerSchema(sub.cast()),
  ('anyOf', final List branches) => [
    for (final b in branches) b is Map ? lowerSchema(b.cast()) : b,
  ],
  (_, final List list) => List<Object?>.of(list),
  _ => value,
};
