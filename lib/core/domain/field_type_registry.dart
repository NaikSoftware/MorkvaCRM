import 'field_definition.dart';

/// Builds a [FieldDefinition] from its JSON map (which includes the `"type"`
/// discriminator). One factory is registered per field type.
typedef FieldDefinitionFactory = FieldDefinition Function(
    Map<String, dynamic> json);

/// Thrown when a field type cannot be resolved or is malformed.
class FieldTypeException implements Exception {
  FieldTypeException(this.message);
  final String message;
  @override
  String toString() => 'FieldTypeException: $message';
}

/// Maps field-type discriminators to the factories that reconstruct their
/// [FieldDefinition]s from JSON.
///
/// This is the single open-for-extension point of the type system: a new field
/// type is enabled by registering its factory, with no edits to existing types
/// or to [Collection] deserialization. Pass a populated registry to
/// [Collection.fromJson].
class FieldTypeRegistry {
  FieldTypeRegistry();

  final Map<String, FieldDefinitionFactory> _factories = {};

  /// Registers [factory] for the given [type] discriminator, replacing any
  /// previously registered factory for that type.
  void register(String type, FieldDefinitionFactory factory) {
    _factories[type] = factory;
  }

  bool isRegistered(String type) => _factories.containsKey(type);

  Iterable<String> get registeredTypes => _factories.keys;

  /// Reconstructs a [FieldDefinition] from its JSON map by dispatching on the
  /// `"type"` key. Throws [FieldTypeException] if the type is missing or not
  /// registered.
  FieldDefinition definitionFromJson(Map<String, dynamic> json) {
    final type = json['type'];
    if (type is! String) {
      throw FieldTypeException('Field definition is missing a string "type".');
    }
    final factory = _factories[type];
    if (factory == null) {
      throw FieldTypeException(
          'Unknown field type "$type". Register it on the FieldTypeRegistry.');
    }
    return factory(json);
  }
}
