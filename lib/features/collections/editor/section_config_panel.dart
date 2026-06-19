import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import 'collection_editor_cubit.dart';

/// The right-panel properties inspector shown when a layout group/section is
/// selected in the collection editor.
///
/// Mirrors the structure and style of [FieldConfigPanel]. Accepts the
/// [section] and [canDelete] directly so it is testable in isolation; the page
/// wires those values from [CollectionEditorReady].
///
/// Controls:
/// - **Rename** the group title via [CollectionEditorCubit.renameSection].
/// - **"Collapsed by default"** toggle via [CollectionEditorCubit.toggleSectionCollapsed].
/// - **Delete group** (destructive, guarded by [MorkvaConfirmDialog]) via
///   [CollectionEditorCubit.deleteSection]; hidden when [canDelete] is false
///   (i.e. only one section remains in the layout).
class SectionConfigPanel extends StatelessWidget {
  const SectionConfigPanel({
    super.key,
    required this.section,
    required this.canDelete,
  });

  final LayoutSection section;

  /// Whether delete is permitted. False when this is the last remaining section
  /// in the collection (the page passes `draft.layout.sections.length > 1`).
  final bool canDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cubit = context.read<CollectionEditorCubit>();

    return ListView(
      key: ValueKey('section_config_${section.id}'),
      padding: const EdgeInsets.all(Spacing.lg),
      children: [
        // Header
        Row(
          children: [
            Icon(Icons.view_agenda_outlined, size: 20, color: scheme.primary),
            const SizedBox(width: Spacing.xs),
            Expanded(
              child: Text('Group', style: theme.textTheme.titleMedium),
            ),
          ],
        ),
        const SizedBox(height: Spacing.lg),

        // Title rename
        _SectionTitleField(
          key: ValueKey('section_title_${section.id}'),
          section: section,
          onChanged: (value) => cubit.renameSection(
            section.id,
            value.trim().isEmpty ? null : value,
          ),
        ),
        const SizedBox(height: Spacing.md),

        // Collapsed-by-default toggle
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
              Icons.unfold_less_outlined,
              color: scheme.onSurfaceVariant,
            ),
            title: Text(
              'Collapsed by default',
              style: theme.textTheme.titleSmall,
            ),
            subtitle: const Text(
              'The group starts collapsed when a card is opened.',
            ),
            value: section.collapsed,
            onChanged: (_) => cubit.toggleSectionCollapsed(section.id),
          ),
        ),

        // Destructive delete (only when canDelete)
        if (canDelete) ...[
          const Divider(height: Spacing.xl),
          _DeleteGroupButton(section: section),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

/// A stateful text field that manages a controller seeded from the section
/// title. Committed via [onChanged] on every keystroke, consistent with how
/// [FieldConfigPanel]'s envelope name field works.
class _SectionTitleField extends StatefulWidget {
  const _SectionTitleField({
    super.key,
    required this.section,
    required this.onChanged,
  });

  final LayoutSection section;
  final ValueChanged<String> onChanged;

  @override
  State<_SectionTitleField> createState() => _SectionTitleFieldState();
}

class _SectionTitleFieldState extends State<_SectionTitleField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.section.title ?? '',
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
      label: 'Group name',
      hint: 'Leave empty for an ungrouped section',
      onChanged: widget.onChanged,
    );
  }
}

/// The destructive "Delete group" affordance. Opens a [MorkvaConfirmDialog]
/// before calling [CollectionEditorCubit.deleteSection].
class _DeleteGroupButton extends StatelessWidget {
  const _DeleteGroupButton({required this.section});

  final LayoutSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cubit = context.read<CollectionEditorCubit>();

    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: scheme.error,
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm,
        ),
      ),
      icon: const Icon(Icons.delete_outline),
      label: const Text('Delete group'),
      onPressed: () async {
        final confirmed = await MorkvaConfirmDialog.show(
          context,
          title: 'Delete group?',
          message:
              'The group is removed from the layout. Its fields are not deleted '
              'and will be moved to the default section.',
          confirmLabel: 'Delete',
          destructive: true,
        );
        if (confirmed == true && context.mounted) {
          cubit.deleteSection(section.id);
        }
      },
    );
  }
}
