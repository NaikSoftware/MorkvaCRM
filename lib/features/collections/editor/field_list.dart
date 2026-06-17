import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import '../field_editors/field_editor.dart';
import 'add_field_sheet.dart';
import 'collection_editor_cubit.dart';
import 'collection_editor_state.dart';
import 'field_row.dart';

/// The reorderable list of fields in the schema editor.
///
/// Wraps a [ReorderableListView] of [FieldRow]s and an "Add field" affordance
/// that opens the [AddFieldSheet]. Reorder and remove pass straight through to
/// [CollectionEditorCubit]; tapping a row selects it (driving the config panel).
///
/// When the schema is empty it shows an inline invitation instead of a bare
/// list, so a fresh collection still reads as intentional.
class FieldList extends StatelessWidget {
  const FieldList({
    super.key,
    required this.state,
    required this.registry,
    this.scrollable = true,
  });

  final CollectionEditorReady state;
  final FieldEditorRegistry registry;

  /// Whether the list manages its own scrolling. False when embedded in an
  /// already-scrolling parent (the narrow single-column layout).
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fields = state.draft.fields;

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.xxs,
        0,
        Spacing.xxs,
        Spacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Fields',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TextActionButton(
            label: 'Add field',
            icon: Icons.add,
            onPressed: () => _addField(context),
          ),
        ],
      ),
    );

    if (fields.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          _EmptyFields(onAdd: () => _addField(context)),
        ],
      );
    }

    final list = ReorderableListView.builder(
      shrinkWrap: !scrollable,
      physics: scrollable ? null : const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      buildDefaultDragHandles: false,
      itemCount: fields.length,
      onReorder: (oldIndex, newIndex) => context
          .read<CollectionEditorCubit>()
          .reorderFields(oldIndex, newIndex),
      proxyDecorator: (child, index, animation) => Material(
        color: Colors.transparent,
        elevation: 0,
        child: child,
      ),
      itemBuilder: (context, index) {
        final field = fields[index];
        return FieldRow(
          key: ValueKey(field.id),
          field: field,
          editor: registry.forType(field.type),
          index: index,
          selected: state.selectedFieldId == field.id,
          typeLocked: state.isFieldTypeLocked(field.id),
          onTap: () =>
              context.read<CollectionEditorCubit>().selectField(field.id),
          onRemove: () => _confirmRemove(context, field),
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: scrollable ? MainAxisSize.max : MainAxisSize.min,
      children: [
        header,
        scrollable ? Expanded(child: list) : list,
      ],
    );
  }

  Future<void> _addField(BuildContext context) async {
    final cubit = context.read<CollectionEditorCubit>();
    final typeId = await AddFieldSheet.show(context, editors: registry.all);
    if (typeId == null) return;
    cubit.addField(typeId);
  }

  Future<void> _confirmRemove(
    BuildContext context,
    FieldDefinition field,
  ) async {
    final cubit = context.read<CollectionEditorCubit>();
    final theme = Theme.of(context);
    final name = field.name.trim().isEmpty ? 'this field' : '"${field.name}"';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: Radii.lgAll),
        title: const Text('Remove field?'),
        content: Text(
          'Remove $name from the schema. Existing objects keep their other '
          'values; this one stops being shown. You can re-add it later.',
        ),
        actions: [
          TextActionButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(context).pop(false),
          ),
          const SizedBox(width: Spacing.xxs),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style:
                TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) cubit.removeField(field.id);
  }
}

/// The inline "no fields yet" invitation shown for a fresh schema.
class _EmptyFields extends StatelessWidget {
  const _EmptyFields({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return PressableScale(
      onPressed: onAdd,
      semanticLabel: 'Add your first field',
      borderRadius: Radii.lgAll,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: Spacing.xl,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: Radii.lgAll,
          border: Border.all(
            color: scheme.outlineVariant,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          children: [
            Icon(Icons.add_circle_outline, size: 32, color: scheme.primary),
            const SizedBox(height: Spacing.sm),
            Text(
              'Add your first field',
              style: theme.textTheme.titleSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Spacing.xxs),
            Text(
              'Fields are the columns of your collection — '
              'a title, a status, a date, a price.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
