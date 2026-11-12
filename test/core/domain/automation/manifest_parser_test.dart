import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';
import 'package:morkva_crm/core/harness/api/capability.dart';
import 'package:morkva_crm/core/harness/schema/field_specs.dart';
import 'package:morkva_crm/core/harness/schema/json_schema.dart';

import 'fixtures.dart';

/// The problems [json] parses to, as `path code` strings.
List<String> problemsOf(Object? json) {
  try {
    parseManifest(json);
    return const [];
  } on ManifestProblems catch (e) {
    return [for (final p in e.problems) '${p.path} ${p.code}'];
  }
}

Map<String, Object?> withKey(String key, Object? value) =>
    stampManifest()..[key] = value;

Map<String, Object?> withAction(
  Map<String, Object?> Function(Map<String, Object?>) edit,
) {
  final m = stampManifest();
  final action = Map<String, Object?>.of(
    (m['actions']! as List).single as Map<String, Object?>,
  );
  m['actions'] = [edit(action)];
  return m;
}

Map<String, Object?> withCaps(List<Object?> caps) =>
    withKey('permissions', {'capabilities': caps});

void main() {
  test('parses a valid manifest', () {
    final m = parseManifest(stampManifest());
    expect(m.id, 'stamp-shipped-date');
    expect(m.timeoutMs, 20000);
    expect(m.capabilities, ['schema:read', 'data:read', 'data:write']);
    expect(m.autoApplyEligible, isTrue);
    final action = m.action('stamp')!;
    expect(action.scope, ActionScope.card);
    expect(action.scope.onCard && !action.scope.onCollection, isTrue);
    expect(action.icon, 'truck');
    final input = action.input!;
    expect(input.required, ['dateField']);
    expect(input.properties['dateField']!.format, InputFormat.field);
    expect(input.properties['days']!.defaultValue, 1);
    expect(input.withDefaults({'dateField': 'f_x'}), {
      'overwrite': false,
      'days': 1,
      'mode': 'today',
      'dateField': 'f_x',
    });
  });

  test('accepts whole doubles where integers are asked (web and VM)', () {
    final m = parseManifest(
      withKey('apiVersion', 2.0)..['timeoutMs'] = 30000.0,
    );
    expect(m.timeoutMs, 30000);
    expect(problemsOf(withKey('timeoutMs', 1500.5)), ['timeoutMs invalid']);
  });

  group('rejects', () {
    test('a non-object', () {
      expect(problemsOf('nope'), [' invalid']);
      expect(problemsOf(null), [' invalid']);
    });

    test('unknown keys at every level, network included', () {
      expect(problemsOf(withKey('network', {'domains': []})), [
        'network unknown_key',
      ]);
      expect(
        problemsOf(
          withKey('permissions', {
            'capabilities': ['schema:read'],
            'extra': 1,
          }),
        ),
        ['permissions.extra unknown_key'],
      );
      expect(problemsOf(withAction((a) => a..['handler'] = 'x')), [
        'actions[0].handler unknown_key',
      ]);
      expect(
        problemsOf(
          withAction(
            (a) => a
              ..['input'] = {
                'type': 'object',
                'properties': {
                  'x': {'type': 'string', 'pattern': '.*'},
                },
              },
          ),
        ),
        ['actions[0].input.properties.x.pattern unknown_key'],
      );
    });

    test('missing required keys, listing all of them', () {
      expect(problemsOf(<String, Object?>{}), [
        'id missing',
        'name missing',
        'version missing',
        'apiVersion missing',
        'permissions missing',
        'actions missing',
      ]);
    });

    test('bad ids, versions, lengths and apiVersion', () {
      expect(problemsOf(withKey('id', 'Stamp')), ['id invalid']);
      expect(problemsOf(withKey('id', 'ab')), ['id invalid']);
      expect(problemsOf(withKey('version', '1.0')), ['version invalid']);
      expect(problemsOf(withKey('name', 'x' * 61)), ['name invalid']);
      expect(problemsOf(withKey('name', ' ')), ['name invalid']);
      expect(problemsOf(withKey('description', 'x' * 501)), [
        'description invalid',
      ]);
      expect(problemsOf(withKey('apiVersion', 1)), ['apiVersion invalid']);
      expect(problemsOf(withKey('timeoutMs', 999)), ['timeoutMs invalid']);
      expect(problemsOf(withKey('timeoutMs', 60001)), ['timeoutMs invalid']);
    });

    test('names and authors that read as Morkva or the assistant', () {
      expect(problemsOf(withKey('name', 'Morkva helper')), [
        'name reserved_name',
      ]);
      expect(problemsOf(withKey('author', 'The ASSISTANT')), [
        'author reserved_name',
      ]);
    });

    test('ungrantable and unknown capabilities', () {
      for (final cap in [
        '*',
        'host:commit',
        'modules:read',
        'modules:write',
        'automations:write',
      ]) {
        expect(problemsOf(withCaps(['schema:read', cap])), [
          'permissions.capabilities[1] not_grantable',
        ], reason: cap);
      }
      expect(problemsOf(withCaps(['schema:read', 'net:fetch'])), [
        'permissions.capabilities[1] invalid',
      ]);
      expect(problemsOf(withCaps(['schema:read', 'schema:read'])), [
        'permissions.capabilities[1] duplicate',
      ]);
      expect(problemsOf(withCaps([])), ['permissions.capabilities invalid']);
    });

    test('the not-grantable message matches the import sheet', () {
      try {
        parseManifest(withCaps(['schema:read', 'data:read', '*']));
        fail('parsed');
      } on ManifestProblems catch (e) {
        expect(
          e.problems.single.toString(),
          'permissions.capabilities[2]: "*" can\'t be granted to a module.',
        );
      }
    });

    test('capabilities without their read prerequisite', () {
      expect(problemsOf(withCaps(['schema:read', 'data:write'])), [
        'permissions.capabilities invalid',
      ]);
      expect(problemsOf(withCaps(['schema:read', 'data:delete'])), [
        'permissions.capabilities invalid',
      ]);
      expect(problemsOf(withCaps(['data:read', 'data:delete'])), isEmpty);
      expect(problemsOf(withCaps(['views:write'])), [
        'permissions.capabilities invalid',
      ]);
      expect(problemsOf(withCaps(['data:read', 'schema:write'])), [
        'permissions.capabilities invalid',
      ]);
    });

    test('bad actions', () {
      expect(problemsOf(withKey('actions', [])), ['actions invalid']);
      expect(problemsOf(withAction((a) => a..['scope'] = 'view')), [
        'actions[0].scope invalid',
      ]);
      expect(problemsOf(withAction((a) => a..['id'] = '1x')), [
        'actions[0].id invalid',
      ]);
      expect(problemsOf(withAction((a) => a..['label'] = 'x' * 41)), [
        'actions[0].label invalid',
      ]);
      expect(problemsOf(withAction((a) => a..['icon'] = 'rocket')), [
        'actions[0].icon invalid',
      ]);
      final twice = stampManifest();
      final action = (twice['actions']! as List).single;
      twice['actions'] = [action, action];
      expect(problemsOf(twice), ['actions[1].id duplicate']);
      final many = stampManifest()
        ..['actions'] = [
          for (var i = 0; i < 21; i++)
            {'id': 'a$i', 'label': 'A', 'scope': 'any'},
        ];
      expect(problemsOf(many), ['actions invalid']);
    });

    test('bad inputs', () {
      Map<String, Object?> input(
        Map<String, Object?> props, [
        List<Object?>? required,
      ]) => withAction(
        (a) => a
          ..['input'] = {
            'type': 'object',
            'properties': props,
            'required': ?required,
          },
      );
      expect(
        problemsOf(
          input(
            {
              'x': {'type': 'string'},
            },
            ['y'],
          ),
        ),
        ['actions[0].input.required[0] invalid'],
      );
      expect(
        problemsOf(
          input({
            'x': {'type': 'date'},
          }),
        ),
        ['actions[0].input.properties.x.type invalid'],
      );
      expect(
        problemsOf(
          input({
            'x': {'type': 'number', 'format': 'field'},
          }),
        ),
        ['actions[0].input.properties.x.format invalid'],
      );
      expect(
        problemsOf(
          input({
            'x': {'type': 'integer', 'default': 1.5},
          }),
        ),
        ['actions[0].input.properties.x.default invalid'],
      );
      expect(
        problemsOf(
          input({
            'x': {
              'type': 'string',
              'enum': ['a'],
              'default': 'b',
            },
          }),
        ),
        ['actions[0].input.properties.x.default invalid'],
      );
      expect(
        problemsOf(
          input({
            'x': {'type': 'number', 'maximum': 5, 'default': 6},
          }),
        ),
        ['actions[0].input.properties.x.default invalid'],
      );
      expect(
        problemsOf(
          input({
            'x': {'type': 'string', 'enum': []},
          }),
        ),
        ['actions[0].input.properties.x.enum invalid'],
      );
      expect(
        problemsOf(
          input({
            'x': {'type': 'boolean', 'minimum': 1},
          }),
        ),
        ['actions[0].input.properties.x.minimum invalid'],
      );
      // Past 2^53 the VM and the web encode differently (the hash would split).
      expect(
        problemsOf(
          input({
            'x': {'type': 'number', 'minimum': -1e21, 'maximum': 1e300},
            'y': {'type': 'integer', 'default': 9007199254740994},
          }),
        ),
        [
          'actions[0].input.properties.x.minimum invalid',
          'actions[0].input.properties.x.maximum invalid',
          'actions[0].input.properties.y.default invalid',
        ],
      );
      expect(
        problemsOf(
          input({
            for (var i = 0; i < 13; i++) 'p$i': {'type': 'string'},
          }),
        ),
        ['actions[0].input.properties invalid'],
      );
    });

    test('a manifest over 16 KB', () {
      expect(problemsOf(withKey('description', 'x' * 17000)), [
        ' too_large',
        'description invalid',
      ]);
    });
  });

  test('input converts to the harness JSON Schema subset', () {
    final schema = parseManifest(
      stampManifest(),
    ).actions.single.input!.toJsonSchema();
    expect(JsonSchema.check(schema), isEmpty);
    expect(schema['required'], ['dateField']);
    final props = schema['properties']! as Map<String, Object?>;
    expect(props['dateField'], {'type': 'string'});
    expect(props['days'], {'type': 'integer', 'minimum': 0, 'maximum': 30});
    expect(props['mode'], {
      'type': 'string',
      'enum': ['today', 'tomorrow'],
    });
    expect(
      JsonSchema.validate(schema, {'dateField': 'f_x', 'days': 3}),
      isEmpty,
    );
    expect(JsonSchema.validate(schema, {'days': 31}), isNotEmpty);
  });

  test('the capability allowlist and icon ids track the harness', () {
    for (final wire in kCapabilityCopy.keys) {
      expect(Capability.fromWire(wire), isNotNull, reason: wire);
    }
    expect(kCapabilityCopy.keys, hasLength(8));
    expect(kCapabilityCopy['data:write']!.title, 'Create and change cards');
    expect(kActionIconIds, kCollectionIconIds);
  });
}
