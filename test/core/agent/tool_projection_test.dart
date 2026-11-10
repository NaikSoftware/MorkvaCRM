import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/agent/tool_projection.dart';
import 'package:morkva_crm/core/harness/harness.dart';

import 'fake_harness.dart';

void main() {
  final harness = fakeHarness([
    FakeOp('cards.query'),
    FakeOp('workspace.describe', capability: Capability.schemaRead),
    FakeOp('cards.update', kind: OpKind.plan, capability: Capability.dataWrite),
    FakeOp('ui.open', kind: OpKind.ui, capability: Capability.uiNavigate),
    FakeOp(
      'harness.describe',
      capability: Capability.schemaRead,
      modelVisible: false,
    ),
    fakeSeal(),
  ]);

  test('declares model-visible ops only, never commit or protocol ops', () {
    final tools = ToolSet.project(harness.descriptors, Grants.all());

    expect(
      [for (final t in tools.tools) t.name],
      ['cards_query', 'cards_update', 'ui_open', 'workspace_describe'],
    );
    expect(tools.opFor('plans_commit'), isNull);
    expect(tools.opFor('plans_seal'), isNull);
    expect(tools.opFor('harness_describe'), isNull);
  });

  test('every name is a valid Gemini function name', () {
    final tools = ToolSet.project(harness.descriptors, Grants.all());

    for (final t in tools.tools) {
      expect(OperationRegistry.toolNamePattern.hasMatch(t.name), isTrue);
    }
  });

  test('declares only what the grants allow', () {
    final tools = ToolSet.project(
      harness.descriptors,
      Grants(const [Capability.dataRead, Capability.schemaRead]),
    );

    expect(
      [for (final t in tools.tools) t.name],
      ['cards_query', 'workspace_describe'],
    );
  });

  test('maps a called name back to its op, camel-case ids included', () {
    final registry = OperationRegistry()
      ..register(FakeOp('cards.retryLater', kind: OpKind.read));
    final tools = ToolSet.project(registry.descriptors, Grants.all());

    expect(tools.opFor('cards_retryLater')?.id, 'cards.retryLater');
    expect(tools.tools.single.description, 'Fake cards.retryLater.');
  });

  group('lowerSchema', () {
    final schema = <String, Object?>{
      'type': 'object',
      'properties': {
        // A property may be named like a keyword.
        'items': {'type': 'string', 'title': 'dropped'},
        'values': {
          'type': 'object',
          'additionalProperties': {
            'anyOf': [
              {'type': 'string'},
              {'type': 'number', 'examples': 'dropped'},
            ],
          },
        },
      },
      'required': ['items'],
      'additionalProperties': false,
      r'$comment': 'dropped',
    };

    test('keeps the supported subset, deep', () {
      expect(lowerSchema(schema), {
        'type': 'object',
        'properties': {
          'items': {'type': 'string'},
          'values': {
            'type': 'object',
            'additionalProperties': {
              'anyOf': [
                {'type': 'string'},
                {'type': 'number'},
              ],
            },
          },
        },
        'required': ['items'],
        'additionalProperties': false,
      });
    });

    test('copies, so the harness schema never changes', () {
      final lowered = lowerSchema(schema);
      (lowered['required']! as List).add('x');
      ((lowered['properties']! as Map)['items'] as Map)['type'] = 'number';

      expect(schema['required'], ['items']);
      expect(
        ((schema['properties']! as Map)['items'] as Map)['type'],
        'string',
      );
    });
  });
}
