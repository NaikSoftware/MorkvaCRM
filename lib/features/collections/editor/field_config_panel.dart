import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import '../field_editors/field_editor.dart';
import 'collection_editor_cubit.dart';

/// The configuration surface for the selected field.
///
/// Owns the **common envelope** (name, description, required) and hosts the
/// per-type config editor from the [FieldEditorRegistry]. Every edit — envelope
/// or per-type — is funnelled back through [CollectionEditorCubit.updateField]
/// as a replacement [FieldDefinition] (domain types are immutable).
///
/// Because field name/description/required live on every concrete
/// [FieldDefinition] subclass but there is no generic envelope `copyWith`, the
/// envelope edits rebuild the definition through a lossless JSON round-trip:
/// serialize, override the envelope key, re-parse via the canonical
/// [FieldTypeRegistry]. This keeps the panel free of any `switch (type)`. See
/// [_applyEnvelope].
///
/// The name field is keyed by field id so switching the selected field rebinds
/// its controller to the new value.
class FieldConfigPanel extends StatelessWidget {
  const FieldConfigPanel({
    super.key,
    required this.field,
    required this.editor,
    required this.collections,
    required this.editingCollectionId,
    required this.typeLocked,
  });

  final FieldDefinition field;
  final FieldEditor? editor;
  final List<Collection> collections;
  final String editingCollectionId;
  final bool typeLocked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cubit = context.read<CollectionEditorCubit>();
    final resolvedEditor = editor;

    return ListView(
      key: ValueKey('config_${field.id}'),
      padding: const EdgeInsets.all(Spacing.lg),
      children: [
        Row(
          children: [
            if (resolvedEditor != null) ...[
              Icon(resolvedEditor.icon, size: 20, color: scheme.primary),
              const SizedBox(width: Spacing.xs),
            ],
            Expanded(
              child: Text(
                resolvedEditor?.displayLabel ?? field.type,
                style: theme.textTheme.titleMedium,
              ),
            ),
          ],
        ),
        if (typeLocked) ...[
          const SizedBox(height: Spacing.sm),
          _TypeLockNote(),
        ],
        const SizedBox(height: Spacing.lg),

        // --- Common envelope ---
        _EnvelopeNameField(
          key: ValueKey('name_${field.id}'),
          field: field,
          onRebuild: cubit.updateField,
        ),
        const SizedBox(height: Spacing.md),
        _EnvelopeDescriptionField(
          key: ValueKey('desc_${field.id}'),
          field: field,
          onRebuild: cubit.updateField,
        ),
        const SizedBox(height: Spacing.xs),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Required'),
          subtitle: const Text('A value must be set before an object is valid.'),
          value: field.isRequired,
          onChanged: (value) =>
              cubit.updateField(_applyEnvelope(field, isRequired: value)),
        ),

        // --- Per-type config ---
        if (resolvedEditor != null) ...[
          const Divider(height: Spacing.xl),
          Text(
            'Options',
            style: theme.textTheme.titleSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: Spacing.sm),
          resolvedEditor.buildConfigEditor(
            context,
            field,
            (next) => cubit.updateField(next),
            collections: collections,
            editingCollectionId: editingCollectionId,
          ),
        ],
      ],
    );
  }
}

/// Rebuilds [field] with a changed envelope value (name / description /
/// required) without naming its concrete subclass.
///
/// Strategy: the domain stores every config key in `configToJson()` and the
/// envelope keys in the shared `toJson()`. We round-trip the definition through
/// JSON with the envelope key overridden, then re-parse via the canonical
/// [FieldTypeRegistry]. This is lossless (the schema guarantees round-trip
/// identity) and keeps the panel free of any `switch (type)`.
FieldDefinition _applyEnvelope(
  FieldDefinition field, {
  String? name,
  Object? description = _noChange,
  bool? isRequired,
}) {
  final json = field.toJson();
  if (name != null) json['name'] = name;
  if (!identical(description, _noChange)) {
    final value = description as String?;
    if (value == null || value.isEmpty) {
      json.remove('description');
    } else {
      json['description'] = value;
    }
  }
  if (isRequired != null) json['required'] = isRequired;
  return _envelopeRegistry.definitionFromJson(json);
}

/// A single canonical registry reused for every envelope round-trip, so we
/// don't rebuild the type table on each keystroke.
final FieldTypeRegistry _envelopeRegistry = defaultFieldTypeRegistry();

/// Sentinel so a null description (clear) is distinguishable from "unchanged".
const Object _noChange = Object();

/// The field-name input. Owns a controller seeded from the field name and
/// re-emits the whole definition (via the envelope merge) on every edit.
class _EnvelopeNameField extends StatefulWidget {
  const _EnvelopeNameField({
    super.key,
    required this.field,
    required this.onRebuild,
  });

  final FieldDefinition field;
  final ValueChanged<FieldDefinition> onRebuild;

  @override
  State<_EnvelopeNameField> createState() => _EnvelopeNameFieldState();
}

class _EnvelopeNameFieldState extends State<_EnvelopeNameField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.field.name);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MorkvaTextField(
      controller: _controller,
      label: 'Field name',
      hint: 'Title, Status, Due date…',
      onChanged: (value) =>
          widget.onRebuild(_applyEnvelope(widget.field, name: value)),
    );
  }
}

/// The optional help-text input for the field.
class _EnvelopeDescriptionField extends StatefulWidget {
  const _EnvelopeDescriptionField({
    super.key,
    required this.field,
    required this.onRebuild,
  });

  final FieldDefinition field;
  final ValueChanged<FieldDefinition> onRebuild;

  @override
  State<_EnvelopeDescriptionField> createState() =>
      _EnvelopeDescriptionFieldState();
}

class _EnvelopeDescriptionFieldState extends State<_EnvelopeDescriptionField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.field.description ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MorkvaTextField(
      controller: _controller,
      label: 'Help text',
      hint: 'Optional — guidance shown with this field',
      onChanged: (value) => widget
          .onRebuild(_applyEnvelope(widget.field, description: value)),
    );
  }
}

/// The "type is locked" explanation shown for persisted fields.
class _TypeLockNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(Spacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: Radii.smAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: Spacing.xs),
          Expanded(
            child: Text(
              'Type is locked after the first save. To change it, remove this '
              'field and add a new one.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
