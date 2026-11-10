import 'package:firebase_ai/firebase_ai.dart';

/// A function declaration that sends a JSON Schema as is, as
/// `parametersJsonSchema`, instead of the SDK's own `Schema` builder (which
/// cannot express `anyOf` of scalars or `additionalProperties`).
///
/// The Epic 8 T0 spike confirmed Gemini accepts the harness schemas
/// unchanged, so [stripClosedObjects] is off by default; it is the
/// adapter-local escape hatch should a model reject `additionalProperties:
/// false` (the harness keeps enforcing it either way).
final class RawFunctionDeclaration extends FunctionDeclaration {
  RawFunctionDeclaration(
    super.name,
    super.description, {
    required this.parametersJsonSchema,
    this.stripClosedObjects = false,
  }) : super(parameters: const {});

  final Map<String, Object?> parametersJsonSchema;

  /// Drop every `additionalProperties: false` before sending.
  final bool stripClosedObjects;

  @override
  Map<String, Object?> toJson() => {
    'name': name,
    'description': description,
    'parametersJsonSchema': stripClosedObjects
        ? _stripClosed(parametersJsonSchema) as Map<String, Object?>
        : parametersJsonSchema,
  };
}

Object? _stripClosed(Object? node) => switch (node) {
  Map() => {
    for (final MapEntry(:key, :value) in node.entries)
      if (!(key == 'additionalProperties' && value == false))
        key as String: _stripClosed(value),
  },
  List() => [for (final item in node) _stripClosed(item)],
  _ => node,
};
