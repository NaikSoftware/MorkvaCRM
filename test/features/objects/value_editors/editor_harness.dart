import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/features/objects/value_editors/built_in_value_editors.dart';
import 'package:morkva_crm/features/objects/value_editors/field_value_editor.dart';

/// Hosts one value editor like the form does: holds the value, feeds it back
/// through a fresh [ValueEditorContext] and records what the editor reports.
class EditorHarness {
  EditorHarness(this.field, FieldValue? initial)
    : value = initial ?? field.emptyValue();

  final FieldDefinition field;
  FieldValue value;
  final changes = <FieldValue>[];
  final inputErrors = <String?>[];

  String? get inputError => inputErrors.lastOrNull;

  Future<void> pump(
    WidgetTester tester, {
    FieldValueEditorRegistry? registry,
    String? error,
    bool enabled = true,
    ReferenceChoices references = ReferenceChoices.none,
  }) async {
    final editor = (registry ?? defaultValueEditorRegistry()).editorFor(
      field.type,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: StatefulBuilder(
              builder: (context, setState) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  editor.build(
                    context,
                    ValueEditorContext(
                      field: field,
                      value: value,
                      error: error,
                      enabled: enabled,
                      references: references,
                      onChanged: (v) => setState(() {
                        value = v;
                        changes.add(v);
                      }),
                      onInputError: inputErrors.add,
                    ),
                  ),
                  // Something to move focus to (blur).
                  const TextField(key: Key('elsewhere')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> blur(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('elsewhere')));
  await tester.pump();
}
