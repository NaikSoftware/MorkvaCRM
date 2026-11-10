import '../api/envelope.dart';

/// A tiny JSON Schema builder and validator for exactly the subset the harness
/// emits and Gemini's `parametersJsonSchema` accepts (T0):
/// `type, properties, required, items, enum, description, minimum, maximum,
/// minItems, maxItems, anyOf, additionalProperties`.
///
/// There is no `$ref`/`$defs`: shared shapes are Dart functions that return
/// schema maps, so composing them inlines them.
///
/// Two deliberate leniencies, both safe: an `integer` accepts an integral
/// double (`20.0`, as JSON decoders and Gemini produce), and an object
/// property whose value is `null` counts as absent (so a required one is
/// reported missing).
abstract final class JsonSchema {
  /// The supported keywords. [check] rejects anything else.
  static const Set<String> keywords = {
    'type',
    'properties',
    'required',
    'items',
    'enum',
    'description',
    'minimum',
    'maximum',
    'minItems',
    'maxItems',
    'anyOf',
    'additionalProperties',
  };

  /// The supported `type` values.
  static const Set<String> types = {
    'string',
    'number',
    'integer',
    'boolean',
    'object',
    'array',
  };

  // ---------------------------------------------------------------- builders

  static Map<String, Object?> string({String? description}) => {
    'type': 'string',
    'description': ?description,
  };

  /// A string limited to [values]; a miss lists them as candidates.
  static Map<String, Object?> enumOf(
    Iterable<String> values, {
    String? description,
  }) => {
    'type': 'string',
    'enum': values.toList(growable: false),
    'description': ?description,
  };

  static Map<String, Object?> integer({
    String? description,
    int? minimum,
    int? maximum,
  }) => {
    'type': 'integer',
    'description': ?description,
    'minimum': ?minimum,
    'maximum': ?maximum,
  };

  static Map<String, Object?> number({
    String? description,
    num? minimum,
    num? maximum,
  }) => {
    'type': 'number',
    'description': ?description,
    'minimum': ?minimum,
    'maximum': ?maximum,
  };

  static Map<String, Object?> boolean({String? description}) => {
    'type': 'boolean',
    'description': ?description,
  };

  static Map<String, Object?> array(
    Map<String, Object?> items, {
    String? description,
    int? minItems,
    int? maxItems,
  }) => {
    'type': 'array',
    'items': items,
    'description': ?description,
    'minItems': ?minItems,
    'maxItems': ?maxItems,
  };

  /// A closed object: unknown keys are errors, so typos never pass silently.
  static Map<String, Object?> object(
    Map<String, Map<String, Object?>> properties, {
    List<String> required = const [],
    String? description,
  }) => {
    'type': 'object',
    'properties': properties,
    if (required.isNotEmpty) 'required': required,
    'additionalProperties': false,
    'description': ?description,
  };

  /// A free-form map whose values all match [values] (`{fieldName: value}`).
  static Map<String, Object?> mapOf(
    Map<String, Object?> values, {
    String? description,
  }) => {
    'type': 'object',
    'additionalProperties': values,
    'description': ?description,
  };

  static Map<String, Object?> anyOf(
    List<Map<String, Object?>> schemas, {
    String? description,
  }) => {'anyOf': schemas, 'description': ?description};

  // --------------------------------------------------------------- validator

  /// Every way [value] fails [schema], with paths like `filters[0].field`
  /// relative to [path] (empty = the root). Empty when valid. All problems
  /// carry `invalid_args`; unknown keys and enum misses list the valid
  /// choices as candidates.
  static List<ErrorDetail> validate(
    Map<String, Object?> schema,
    Object? value, {
    String path = '',
  }) {
    final problems = <ErrorDetail>[];
    _validate(schema, value, path, problems);
    return problems;
  }

  static void _validate(
    Map<String, Object?> schema,
    Object? value,
    String path,
    List<ErrorDetail> out,
  ) {
    final anyOf = schema['anyOf'];
    if (anyOf is List) {
      List<ErrorDetail>? closest;
      var matched = false;
      for (final branch in anyOf.cast<Map<String, Object?>>()) {
        final errors = <ErrorDetail>[];
        _validate(branch, value, path, errors);
        if (errors.isEmpty) {
          matched = true;
          break;
        }
        // The branch of the right type explains the failure best.
        if (closest == null && _hasType(branch, value)) closest = errors;
      }
      if (!matched) {
        out.addAll(
          closest ??
              [
                _problem(
                  path,
                  'Expected ${_describeTypes(anyOf)} at ${_where(path)}, '
                  'got ${_jsonType(value)}.',
                ),
              ],
        );
        return;
      }
    }

    final type = schema['type'];
    if (type is String && !_isType(value, type)) {
      out.add(
        _problem(
          path,
          'Expected ${_article(type)} at ${_where(path)}, '
          'got ${_jsonType(value)}.',
        ),
      );
      return;
    }

    final allowed = schema['enum'];
    if (allowed is List && !allowed.contains(value)) {
      out.add(
        _problem(
          path,
          '${_quote(value)} is not allowed at ${_where(path)}. '
          'Use one of: ${allowed.join(', ')}.',
          candidates: allowed,
        ),
      );
    }

    if (value is num) {
      final min = schema['minimum'];
      final max = schema['maximum'];
      if (min is num && value < min) {
        out.add(_problem(path, '${_where(path)} must be at least $min.'));
      }
      if (max is num && value > max) {
        out.add(_problem(path, '${_where(path)} must be at most $max.'));
      }
    }

    if (value is List) {
      final minItems = schema['minItems'];
      final maxItems = schema['maxItems'];
      if (minItems is int && value.length < minItems) {
        out.add(
          _problem(
            path,
            '${_where(path)} needs at least $minItems '
            '${minItems == 1 ? 'item' : 'items'}.',
          ),
        );
      }
      if (maxItems is int && value.length > maxItems) {
        out.add(
          _problem(
            path,
            '${_where(path)} takes at most $maxItems items '
            '(got ${value.length}); split the call.',
          ),
        );
      }
      final items = schema['items'];
      if (items is Map<String, Object?>) {
        for (var i = 0; i < value.length; i++) {
          _validate(items, value[i], '$path[$i]', out);
        }
      }
    }

    if (value is Map) {
      final properties =
          (schema['properties'] as Map<String, Object?>?) ?? const {};
      final required = (schema['required'] as List?) ?? const [];
      for (final key in required) {
        if (value[key] == null) {
          out.add(
            _problem(
              _child(path, '$key'),
              'Missing required ${_where(_child(path, '$key'))}.',
            ),
          );
        }
      }
      final additional = schema['additionalProperties'];
      for (final MapEntry(:key, value: child) in value.entries) {
        final childPath = _child(path, '$key');
        final propertySchema = properties[key];
        if (propertySchema is Map<String, Object?>) {
          // A missing required key was reported above.
          if (child == null) continue;
          _validate(propertySchema, child, childPath, out);
        } else if (additional == false) {
          out.add(
            _problem(
              childPath,
              'Unknown argument "$key"'
              '${path.isEmpty ? '' : ' in $path'}. '
              '${properties.isEmpty ? 'It takes no arguments.' : 'Allowed: ${properties.keys.join(', ')}.'}',
              candidates: properties.isEmpty ? null : properties.keys.toList(),
            ),
          );
        } else if (additional is Map<String, Object?>) {
          _validate(additional, child, childPath, out);
        }
      }
    }
  }

  static bool _hasType(Map<String, Object?> schema, Object? value) {
    final type = schema['type'];
    return type is String && _isType(value, type);
  }

  static bool _isType(Object? value, String type) => switch (type) {
    'string' => value is String,
    'number' => value is num && value.isFinite,
    'integer' => value is int || (value is double && value == value.truncate()),
    'boolean' => value is bool,
    'object' => value is Map,
    'array' => value is List,
    _ => false,
  };

  static String _jsonType(Object? value) => switch (value) {
    null => 'null',
    String() => 'a string',
    bool() => 'a boolean',
    int() => 'an integer',
    num() => 'a number',
    List() => 'an array',
    Map() => 'an object',
    _ => 'a ${value.runtimeType}',
  };

  static String _article(String type) => switch (type) {
    'integer' || 'object' || 'array' => 'an $type',
    _ => 'a $type',
  };

  static String _describeTypes(List<Object?> branches) {
    final names = <String>{
      for (final b in branches)
        if (b is Map && b['type'] is String) _article(b['type'] as String),
    };
    return names.isEmpty ? 'a different value' : names.join(' or ');
  }

  static String _where(String path) => path.isEmpty ? 'args' : '"$path"';

  static String _child(String path, String key) =>
      path.isEmpty ? key : '$path.$key';

  static String _quote(Object? value) =>
      value is String ? '"$value"' : '$value';

  static ErrorDetail _problem(
    String path,
    String message, {
    List<Object?>? candidates,
  }) => ErrorDetail(
    path: path,
    code: ErrorCode.invalidArgs,
    message: message,
    candidates: candidates,
  );

  // ------------------------------------------------------------ meta-checker

  /// Problems that make [schema] fall outside the supported subset (unknown
  /// keywords, bad `type`, `required` naming a missing property, …), as
  /// human-readable lines. Empty when the schema is well-formed. Every
  /// descriptor schema must pass this before it is registered.
  static List<String> check(Object? schema, {String at = '#'}) {
    final out = <String>[];
    _check(schema, at, out);
    return out;
  }

  static void _check(Object? schema, String at, List<String> out) {
    if (schema is! Map<String, Object?>) {
      out.add('$at: a schema must be an object');
      return;
    }
    for (final key in schema.keys) {
      if (!keywords.contains(key)) out.add('$at: unsupported keyword "$key"');
    }
    final type = schema['type'];
    final anyOf = schema['anyOf'];
    if (type == null && anyOf == null) {
      out.add('$at: needs "type" or "anyOf"');
    }
    if (type != null && !types.contains(type)) {
      out.add('$at: unsupported type "$type"');
    }
    if (anyOf != null) {
      if (anyOf is! List || anyOf.isEmpty) {
        out.add('$at: "anyOf" must be a non-empty list');
      } else {
        for (var i = 0; i < anyOf.length; i++) {
          _check(anyOf[i], '$at/anyOf/$i', out);
        }
      }
    }
    final description = schema['description'];
    if (description != null && description is! String) {
      out.add('$at: "description" must be a string');
    }
    final allowed = schema['enum'];
    if (allowed != null &&
        (allowed is! List ||
            allowed.isEmpty ||
            allowed.any((v) => v is! String && v is! num && v is! bool))) {
      out.add('$at: "enum" must be a non-empty list of scalars');
    }
    for (final key in const ['minimum', 'maximum']) {
      if (schema[key] != null && schema[key] is! num) {
        out.add('$at: "$key" must be a number');
      }
    }
    for (final key in const ['minItems', 'maxItems']) {
      final n = schema[key];
      if (n != null && (n is! int || n < 0)) {
        out.add('$at: "$key" must be a non-negative integer');
      }
    }
    final items = schema['items'];
    if (items != null) {
      if (type != 'array') out.add('$at: "items" needs type "array"');
      _check(items, '$at/items', out);
    }
    if (type == 'array' && items == null) {
      out.add('$at: an array needs "items"');
    }
    final properties = schema['properties'];
    if (properties != null) {
      if (properties is! Map<String, Object?>) {
        out.add('$at: "properties" must be an object');
      } else {
        for (final MapEntry(:key, :value) in properties.entries) {
          _check(value, '$at/properties/$key', out);
        }
      }
    }
    final required = schema['required'];
    if (required != null) {
      final names = properties is Map
          ? properties.keys.toSet()
          : const <Object?>{};
      if (required is! List) {
        out.add('$at: "required" must be a list');
      } else {
        for (final name in required) {
          if (!names.contains(name)) {
            out.add('$at: required "$name" is not a property');
          }
        }
      }
    }
    final additional = schema['additionalProperties'];
    if (additional != null && additional is! bool) {
      _check(additional, '$at/additionalProperties', out);
    }
    if ((properties != null || required != null || additional != null) &&
        type != 'object') {
      out.add('$at: object keywords need type "object"');
    }
  }
}
