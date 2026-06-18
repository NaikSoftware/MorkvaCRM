import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import '../field_editors/field_editor.dart';
import 'collection_editor_cubit.dart';

/// The configuration surface for the selected field.
///
/// Hosts the **common envelope** (name, description, required) and the per-type
/// config editor from the [FieldEditorRegistry]. Envelope edits route through
/// [CollectionEditorCubit.updateFieldEnvelope] (the cubit owns the rebuild, so
/// the widget stays free of the type registry and any `switch (type)`); per-type
/// edits emit a replacement [FieldDefinition] through
/// [CollectionEditorCubit.updateField] (domain types are immutable).
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
          onChanged: (value) =>
              cubit.updateFieldEnvelope(field.id, name: value),
        ),
        const SizedBox(height: Spacing.md),
        _EnvelopeDescriptionField(
          key: ValueKey('desc_${field.id}'),
          field: field,
          onChanged: (value) =>
              cubit.updateFieldEnvelope(field.id, description: value),
        ),
        const SizedBox(height: Spacing.md),
        // The Required toggle sits in a tinted tile so it reads as a distinct,
        // important choice rather than getting lost in the envelope stack.
        DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: Radii.mdAll,
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: SwitchListTile.adaptive(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: Spacing.xxs,
            ),
            shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
            secondary: Icon(
              Icons.flag_outlined,
              color: scheme.onSurfaceVariant,
            ),
            title: Text('Required', style: theme.textTheme.titleSmall),
            subtitle: const Text(
              'A value must be set before an object is valid.',
            ),
            value: field.isRequired,
            onChanged: (value) =>
                cubit.updateFieldEnvelope(field.id, isRequired: value),
          ),
        ),

        // --- Per-type config ---
        if (resolvedEditor != null) ...[
          const Divider(height: Spacing.xl),
          Text(
            'Options',
            style: theme.textTheme.titleSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
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

/// The field-name input. Owns a controller seeded from the field name and
/// reports each edit through [onChanged] (the cubit rebuilds the envelope).
class _EnvelopeNameField extends StatefulWidget {
  const _EnvelopeNameField({
    super.key,
    required this.field,
    required this.onChanged,
  });

  final FieldDefinition field;
  final ValueChanged<String> onChanged;

  @override
  State<_EnvelopeNameField> createState() => _EnvelopeNameFieldState();
}

class _EnvelopeNameFieldState extends State<_EnvelopeNameField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.field.name,
  );

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
      onChanged: widget.onChanged,
    );
  }
}

/// The optional help-text input for the field.
class _EnvelopeDescriptionField extends StatefulWidget {
  const _EnvelopeDescriptionField({
    super.key,
    required this.field,
    required this.onChanged,
  });

  final FieldDefinition field;
  final ValueChanged<String> onChanged;

  @override
  State<_EnvelopeDescriptionField> createState() =>
      _EnvelopeDescriptionFieldState();
}

class _EnvelopeDescriptionFieldState extends State<_EnvelopeDescriptionField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.field.description ?? '',
  );

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
      onChanged: widget.onChanged,
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
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
