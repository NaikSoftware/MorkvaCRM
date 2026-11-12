import 'dart:convert';

import 'package:equatable/equatable.dart';

import 'capability_copy.dart';
import 'manifest.dart';

/// One problem with a manifest, a bundle or an automation draft, in the
/// multi-error shape of harness `invalid_args` details.
final class AutomationProblem extends Equatable {
  const AutomationProblem(this.path, this.code, this.message);

  /// Where, e.g. `permissions.capabilities[2]`; `''` for the whole input.
  final String path;

  /// `unknown_key`, `missing`, `invalid`, `not_grantable`, `reserved_name`,
  /// `duplicate`, `too_large` (or a harness error wire from validation).
  final String code;

  /// A sentence for the user.
  final String message;

  Map<String, Object?> toJson() => {
    'path': path,
    'code': code,
    'message': message,
  };

  @override
  String toString() => path.isEmpty ? message : '$path: $message';

  @override
  List<Object?> get props => [path, code, message];
}

/// Thrown by [parseManifest] (and the bundle decoder) with every problem
/// found, never just the first.
final class ManifestProblems implements Exception {
  ManifestProblems(List<AutomationProblem> problems)
    : problems = List.unmodifiable(problems);

  final List<AutomationProblem> problems;

  @override
  String toString() => 'ManifestProblems(${problems.join('; ')})';
}

/// The collection icon ids an action may use, copied from
/// `kCollectionIconIds` (the harness) so the domain stays below it; a test
/// keeps the two lists equal.
const List<String> kActionIconIds = [
  'cards',
  'grid',
  'box',
  'truck',
  'cart',
  'bag',
  'tag',
  'people',
  'person',
  'business',
  'store',
  'money',
  'receipt',
  'calendar',
  'task',
  'folder',
  'note',
  'star',
  'flag',
  'home',
  'car',
  'build',
  'pets',
  'restaurant',
];

/// Known capabilities that a module may never hold (refused as
/// `not_grantable` rather than unknown).
const Set<String> kNotGrantableToModules = {
  '*',
  'host:commit',
  'modules:read',
  'modules:write',
  'automations:write',
};

/// Manifest JSON encoded is at most this many UTF-8 bytes.
const int kManifestMaxBytes = 16 * 1024;

final RegExp _moduleId = RegExp(r'^[a-z][a-z0-9-]{2,39}$');
final RegExp _version = RegExp(r'^\d{1,4}\.\d{1,4}\.\d{1,4}$');
final RegExp _actionId = RegExp(r'^[a-zA-Z][a-zA-Z0-9_]{0,39}$');
final RegExp _reserved = RegExp('morkva|assistant', caseSensitive: false);

/// Parses a manifest as a strict allowlist (design spec, Module format):
/// returns the [ModuleManifest] or throws [ManifestProblems] listing every
/// problem (unknown keys at any level, unknown or ungrantable capabilities,
/// out-of-range values, reserved names). Never goes through
/// `Grants.fromJson`, which accepts `'*'`.
ModuleManifest parseManifest(Object? json) {
  final p = _Problems();
  final manifest = _manifest(json, p);
  if (p.list.isNotEmpty || manifest == null) throw ManifestProblems(p.list);
  return manifest;
}

final class _Problems {
  final list = <AutomationProblem>[];

  void add(String path, String code, String message) =>
      list.add(AutomationProblem(path, code, message));
}

ModuleManifest? _manifest(Object? json, _Problems p) {
  if (json is! Map) {
    p.add('', 'invalid', 'The manifest must be a JSON object.');
    return null;
  }
  final int bytes;
  try {
    bytes = utf8.encode(jsonEncode(json)).length;
  } on JsonUnsupportedObjectError {
    p.add('', 'invalid', 'The manifest must be plain JSON.');
    return null;
  }
  if (bytes > kManifestMaxBytes) {
    p.add(
      '',
      'too_large',
      'The manifest is ${_kb(bytes)}; the limit is 16 KB.',
    );
  }
  _keys(json, '', const {
    'id',
    'name',
    'version',
    'description',
    'author',
    'apiVersion',
    'timeoutMs',
    'permissions',
    'actions',
  }, p);
  final id = _string(json, 'id', '', p, required: true);
  if (id != null && !_moduleId.hasMatch(id)) {
    p.add(
      'id',
      'invalid',
      'Use 3–40 lowercase letters, digits or dashes, starting with a letter.',
    );
  }
  final name = _string(json, 'name', '', p, required: true, max: 60);
  _notReserved(name, 'name', p);
  final version = _string(json, 'version', '', p, required: true);
  if (version != null && !_version.hasMatch(version)) {
    p.add('version', 'invalid', 'Use a version like 1.0.0.');
  }
  final description = _string(json, 'description', '', p, max: 500);
  final author = _string(json, 'author', '', p, max: 80);
  _notReserved(author, 'author', p);
  if (!json.containsKey('apiVersion')) {
    p.add('apiVersion', 'missing', 'Required.');
  } else if (_integral(json['apiVersion']) != 2) {
    p.add('apiVersion', 'invalid', 'Must be 2.');
  }
  var timeoutMs = ModuleManifest.kDefaultTimeoutMs;
  if (json.containsKey('timeoutMs')) {
    final t = _integral(json['timeoutMs']);
    if (t == null ||
        t < ModuleManifest.kMinTimeoutMs ||
        t > ModuleManifest.kMaxTimeoutMs) {
      p.add(
        'timeoutMs',
        'invalid',
        'Must be a whole number from 1000 to 60000.',
      );
    } else {
      timeoutMs = t;
    }
  }
  final capabilities = _capabilities(json['permissions'], p);
  final actions = _actions(json['actions'], p);
  if (id == null || name == null || version == null) return null;
  return ModuleManifest(
    id: id,
    name: name,
    version: version,
    description: description,
    author: author,
    timeoutMs: timeoutMs,
    capabilities: capabilities,
    actions: actions,
  );
}

List<String> _capabilities(Object? permissions, _Problems p) {
  if (permissions == null) {
    p.add('permissions', 'missing', 'Required.');
    return const [];
  }
  if (permissions is! Map) {
    p.add('permissions', 'invalid', 'Must be an object.');
    return const [];
  }
  _keys(permissions, 'permissions', const {'capabilities'}, p);
  final raw = permissions['capabilities'];
  const at = 'permissions.capabilities';
  if (raw is! List || raw.isEmpty) {
    p.add(at, raw == null ? 'missing' : 'invalid', 'List at least one.');
    return const [];
  }
  final caps = <String>[];
  for (final (i, cap) in raw.indexed) {
    final path = '$at[$i]';
    if (cap is String && kNotGrantableToModules.contains(cap)) {
      p.add(path, 'not_grantable', '"$cap" can\'t be granted to a module.');
    } else if (cap is! String || !kCapabilityCopy.containsKey(cap)) {
      p.add(path, 'invalid', '"$cap" isn\'t a capability.');
    } else if (caps.contains(cap)) {
      p.add(path, 'duplicate', '"$cap" is listed twice.');
    } else {
      caps.add(cap);
    }
  }
  void needs(List<String> caps0, String prerequisite) {
    for (final cap in caps0) {
      if (caps.contains(cap) && !caps.contains(prerequisite)) {
        p.add(at, 'invalid', '"$cap" needs "$prerequisite".');
      }
    }
  }

  needs(const ['data:write', 'data:delete'], 'data:read');
  needs(const ['schema:write', 'schema:delete', 'views:write'], 'schema:read');
  return caps;
}

List<ActionSpec> _actions(Object? raw, _Problems p) {
  if (raw == null) {
    p.add('actions', 'missing', 'Required.');
    return const [];
  }
  if (raw is! List || raw.isEmpty || raw.length > 20) {
    p.add('actions', 'invalid', 'List 1 to 20 actions.');
    if (raw is! List) return const [];
  }
  final actions = <ActionSpec>[];
  for (final (i, a) in raw.indexed) {
    final action = _action(a, 'actions[$i]', p);
    if (action == null) continue;
    if (actions.any((x) => x.id == action.id)) {
      p.add('actions[$i].id', 'duplicate', '"${action.id}" is used twice.');
    }
    actions.add(action);
  }
  return actions;
}

ActionSpec? _action(Object? json, String at, _Problems p) {
  if (json is! Map) {
    p.add(at, 'invalid', 'Must be an object.');
    return null;
  }
  _keys(json, at, const {
    'id',
    'label',
    'description',
    'scope',
    'icon',
    'input',
  }, p);
  final id = _string(json, 'id', at, p, required: true);
  if (id != null && !_actionId.hasMatch(id)) {
    p.add(
      '$at.id',
      'invalid',
      'Use up to 40 letters, digits or underscores, starting with a letter.',
    );
  }
  final label = _string(json, 'label', at, p, required: true, max: 40);
  final description = _string(json, 'description', at, p, max: 300);
  final scopeWire = json['scope'];
  final scope = ActionScope.values.where((s) => s.name == scopeWire).toList();
  if (scope.isEmpty) {
    p.add(
      '$at.scope',
      scopeWire == null ? 'missing' : 'invalid',
      'Must be card, collection or any.',
    );
  }
  final icon = json['icon'];
  if (icon != null && (icon is! String || !kActionIconIds.contains(icon))) {
    p.add('$at.icon', 'invalid', '"$icon" isn\'t a collection icon.');
  }
  // `input: {}` (a natural "no settings") means the same as leaving it out.
  final rawInput = json['input'];
  final input = rawInput != null && !(rawInput is Map && rawInput.isEmpty)
      ? _input(rawInput, '$at.input', p)
      : null;
  if (id == null || label == null || scope.isEmpty) return null;
  return ActionSpec(
    id: id,
    label: label,
    scope: scope.single,
    description: description,
    icon: icon is String ? icon : null,
    input: input,
  );
}

InputSpec? _input(Object? json, String at, _Problems p) {
  if (json is! Map) {
    p.add(at, 'invalid', 'Must be an object.');
    return null;
  }
  _keys(json, at, const {'type', 'required', 'properties'}, p);
  // `type` may be left out; any other value than "object" is refused.
  if (json.containsKey('type') && json['type'] != 'object') {
    p.add('$at.type', 'invalid', 'Must be "object".');
  }
  final rawProps = json['properties'];
  final props = <String, InputProperty>{};
  if (rawProps is! Map) {
    p.add(
      '$at.properties',
      rawProps == null ? 'missing' : 'invalid',
      'Must be an object.',
    );
  } else {
    if (rawProps.length > 12) {
      p.add('$at.properties', 'invalid', 'At most 12 inputs.');
    }
    for (final MapEntry(:key, :value) in rawProps.entries) {
      final prop = _property(value, '$at.properties.$key', p);
      if (prop != null) props['$key'] = prop;
    }
  }
  final rawRequired = json['required'] ?? const [];
  final required = <String>[];
  if (rawRequired is! List) {
    p.add('$at.required', 'invalid', 'Must be a list of input names.');
  } else {
    for (final (i, r) in rawRequired.indexed) {
      if (r is! String || rawProps is! Map || !rawProps.containsKey(r)) {
        p.add('$at.required[$i]', 'invalid', '"$r" isn\'t one of the inputs.');
      } else if (!required.contains(r)) {
        required.add(r);
      }
    }
  }
  return InputSpec(properties: props, required: required);
}

InputProperty? _property(Object? json, String at, _Problems p) {
  if (json is! Map) {
    p.add(at, 'invalid', 'Must be an object.');
    return null;
  }
  _keys(json, at, const {
    'type',
    'title',
    'description',
    'enum',
    'minimum',
    'maximum',
    'default',
    'format',
  }, p);
  final typeWire = json['type'];
  final types = InputType.values.where((t) => t.name == typeWire).toList();
  if (types.isEmpty) {
    p.add(
      '$at.type',
      typeWire == null ? 'missing' : 'invalid',
      'Must be string, number, integer or boolean.',
    );
  }
  final type = types.isEmpty ? null : types.single;
  final title = _string(json, 'title', at, p, max: 40);
  final description = _string(json, 'description', at, p, max: 200);
  List<String>? enumValues;
  if (json.containsKey('enum')) {
    final raw = json['enum'];
    if (raw is! List ||
        raw.isEmpty ||
        raw.length > 30 ||
        raw.any((v) => v is! String)) {
      p.add('$at.enum', 'invalid', 'List 1 to 30 strings.');
    } else if (type != InputType.string) {
      p.add('$at.enum', 'invalid', 'Only string inputs take a list of values.');
    } else {
      enumValues = raw.cast<String>().toList(growable: false);
    }
  }
  final numeric = type == InputType.number || type == InputType.integer;
  num? bound(String key) {
    if (!json.containsKey(key)) return null;
    final v = json[key];
    if (v is! num || !numeric) {
      p.add('$at.$key', 'invalid', 'Only number inputs take a $key number.');
      return null;
    }
    if (!_safeNumber(v)) {
      p.add('$at.$key', 'invalid', 'Keep it within ±2^53.');
      return null;
    }
    return v;
  }

  final minimum = bound('minimum');
  final maximum = bound('maximum');
  InputFormat? format;
  if (json.containsKey('format')) {
    final raw = json['format'];
    final formats = InputFormat.values.where((f) => f.name == raw).toList();
    if (formats.isEmpty) {
      p.add('$at.format', 'invalid', 'Must be field or collection.');
    } else if (type != InputType.string) {
      p.add('$at.format', 'invalid', 'Only string inputs take a format.');
    } else {
      format = formats.single;
    }
  }
  final hasDefault = json.containsKey('default');
  final defaultValue = json['default'];
  if (hasDefault && type != null) {
    final ok = switch (type) {
      InputType.string =>
        defaultValue is String &&
            (enumValues == null || enumValues.contains(defaultValue)),
      InputType.boolean => defaultValue is bool,
      InputType.number => defaultValue is num,
      InputType.integer => _integral(defaultValue) != null,
    };
    final inRange =
        defaultValue is! num ||
        ((minimum == null || defaultValue >= minimum) &&
            (maximum == null || defaultValue <= maximum));
    if (defaultValue is num && !_safeNumber(defaultValue)) {
      p.add('$at.default', 'invalid', 'Keep it within ±2^53.');
    } else if (!ok || !inRange) {
      p.add('$at.default', 'invalid', 'Doesn\'t match the input\'s type.');
    }
  }
  if (type == null) return null;
  return InputProperty(
    type: type,
    title: title,
    description: description,
    enumValues: enumValues,
    minimum: minimum,
    maximum: maximum,
    hasDefault: hasDefault,
    defaultValue: type == InputType.integer && defaultValue is num
        ? defaultValue.toInt()
        : defaultValue,
    format: format,
  );
}

void _keys(Map json, String at, Set<String> allowed, _Problems p) {
  for (final key in json.keys) {
    if (!allowed.contains(key)) {
      p.add(
        at.isEmpty ? '$key' : '$at.$key',
        'unknown_key',
        'Unknown key "$key".',
      );
    }
  }
}

String? _string(
  Map json,
  String key,
  String at,
  _Problems p, {
  bool required = false,
  int? max,
}) {
  final path = at.isEmpty ? key : '$at.$key';
  final v = json[key];
  if (v == null) {
    if (required) p.add(path, 'missing', 'Required.');
    return null;
  }
  if (v is! String || (required && v.trim().isEmpty)) {
    p.add(
      path,
      'invalid',
      required ? 'Must be a non-empty string.' : 'Must be a string.',
    );
    return null;
  }
  if (max != null && v.length > max) {
    p.add(path, 'invalid', 'At most $max characters.');
  }
  return v;
}

void _notReserved(String? text, String path, _Problems p) {
  if (text != null && _reserved.hasMatch(text)) {
    p.add(
      path,
      'reserved_name',
      'Modules can\'t be named after Morkva or the assistant.',
    );
  }
}

/// [v] as an int when it is a whole number (a VM-decoded `2.0` and a web
/// number both count), else null.
/// Within ±2^53 (NaN and infinities fail): past it the VM's `toInt` saturates
/// while the web keeps the double, so a bundle would hash differently.
bool _safeNumber(num v) => v >= -9007199254740992 && v <= 9007199254740992;

int? _integral(Object? v) =>
    v is num && v.isFinite && v == v.truncateToDouble() ? v.toInt() : null;

String _kb(int bytes) => '${(bytes / 1024).ceil()} KB';
