import 'package:equatable/equatable.dart';

import 'capability_copy.dart';

/// A module's parsed manifest (`parseManifest`). The stored doc keeps the raw
/// JSON (`ModuleRecord.manifestJson`); this is never written back, so the
/// bundle hash always covers exactly what the author shipped.
final class ModuleManifest extends Equatable {
  const ModuleManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.capabilities,
    required this.actions,
    this.description,
    this.author,
    this.timeoutMs = kDefaultTimeoutMs,
  });

  static const int kDefaultTimeoutMs = 20000;
  static const int kMinTimeoutMs = 1000;
  static const int kMaxTimeoutMs = 60000;

  final String id;
  final String name;
  final String version;
  final String? description;

  /// Free text from the file; the UI always labels it as the file's.
  final String? author;

  /// The run timeout, clamped to 1–60 s.
  final int timeoutMs;

  /// Capability wires (`data:read`, …), in manifest order, each one of
  /// [kCapabilityCopy]'s keys.
  final List<String> capabilities;
  final List<ActionSpec> actions;

  ActionSpec? action(String id) {
    for (final a in actions) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// Whether this module's changes may ever auto-apply: it writes cards and
  /// asks for nothing that always needs review.
  bool get autoApplyEligible =>
      capabilities.contains('data:write') &&
      !capabilities.any(kReviewOnlyCapabilities.contains);

  @override
  List<Object?> get props => [
    id,
    name,
    version,
    description,
    author,
    timeoutMs,
    capabilities,
    actions,
  ];
}

/// Where an action may be bound.
enum ActionScope {
  /// Card buttons and card events.
  card,

  /// Collection buttons only.
  collection,

  /// Both.
  any;

  bool get onCard => this != collection;
  bool get onCollection => this != card;
}

/// One entry point of a module (`morkva.action(id, fn)`).
final class ActionSpec extends Equatable {
  const ActionSpec({
    required this.id,
    required this.label,
    required this.scope,
    this.description,
    this.icon,
    this.input,
  });

  final String id;
  final String label;
  final ActionScope scope;
  final String? description;

  /// A collection icon id (`kActionIconIds`).
  final String? icon;
  final InputSpec? input;

  @override
  List<Object?> get props => [id, label, scope, description, icon, input];
}

/// The type of one action input.
enum InputType { string, number, integer, boolean }

/// A picker the editor shows for a string input; it stores the picked id.
enum InputFormat { field, collection }

/// An action's `input`: the automation params it takes.
final class InputSpec extends Equatable {
  const InputSpec({required this.properties, this.required = const []});

  /// In manifest order.
  final Map<String, InputProperty> properties;
  final List<String> required;

  /// The harness JSON Schema subset that validates params at save and at run
  /// start (`JsonSchema.validate`): `title`, `default` and `format` dropped.
  Map<String, Object?> toJsonSchema() => {
    'type': 'object',
    'properties': {
      for (final MapEntry(:key, :value) in properties.entries)
        key: value.toJsonSchema(),
    },
    if (required.isNotEmpty) 'required': required,
    'additionalProperties': false,
  };

  /// [params] with the declared defaults filled in for absent keys.
  Map<String, Object?> withDefaults(Map<String, Object?> params) => {
    for (final MapEntry(:key, :value) in properties.entries)
      if (!params.containsKey(key) && value.hasDefault) key: value.defaultValue,
    ...params,
  };

  @override
  List<Object?> get props => [properties, required];
}

final class InputProperty extends Equatable {
  const InputProperty({
    required this.type,
    this.title,
    this.description,
    this.enumValues,
    this.minimum,
    this.maximum,
    this.hasDefault = false,
    this.defaultValue,
    this.format,
  });

  final InputType type;
  final String? title;
  final String? description;
  final List<String>? enumValues;
  final num? minimum;
  final num? maximum;

  /// Whether the manifest gave a `default` ([defaultValue] may be null only
  /// when it did not).
  final bool hasDefault;
  final Object? defaultValue;
  final InputFormat? format;

  Map<String, Object?> toJsonSchema() => {
    'type': type.name,
    'description': ?description,
    'enum': ?enumValues,
    'minimum': ?minimum,
    'maximum': ?maximum,
  };

  @override
  List<Object?> get props => [
    type,
    title,
    description,
    enumValues,
    minimum,
    maximum,
    hasDefault,
    defaultValue,
    format,
  ];
}
