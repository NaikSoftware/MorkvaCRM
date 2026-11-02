import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import '../collection_views_cubit.dart';
import '../collection_views_state.dart';
import '../modes/view_mode.dart';
import 'view_labels.dart';

/// The phone's per-view settings: mode, the mode's layout field, sort and
/// the shown fields. Reads and writes the active view through
/// [CollectionViewsCubit], so it stays live while open.
class ViewSettingsSheet extends StatelessWidget {
  const ViewSettingsSheet({
    super.key,
    required this.modes,
    required this.onSort,
    required this.onEditFields,
  });

  final ViewModeRegistry modes;

  /// Opens the sort menu.
  final VoidCallback onSort;

  /// Opens Columns / Setup card for [mode].
  final ValueChanged<ViewMode> onEditFields;

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<CollectionViewsCubit, CollectionViewsState>(
        builder: (context, state) {
          if (state is! ViewsReady) return const SizedBox.shrink();
          return _Body(
            state: state,
            modes: modes,
            onSort: onSort,
            onEditFields: onEditFields,
          );
        },
      );
}

class _Body extends StatelessWidget {
  const _Body({
    required this.state,
    required this.modes,
    required this.onSort,
    required this.onEditFields,
  });

  final ViewsReady state;
  final ViewModeRegistry modes;
  final VoidCallback onSort;
  final ValueChanged<ViewMode> onEditFields;

  /// Switches mode in one write. The layout field stays when the new mode
  /// accepts it or uses none at all (Board → Table → Board keeps Stage); a
  /// mode that needs one and can't take it gets the first fitting field.
  Future<void> _switchTo(BuildContext context, ViewMode mode) {
    final current = state.layoutField;
    final usesLayout =
        mode.needsLayoutField ||
        state.collection.fields.any(mode.acceptsLayoutField);
    final keep =
        current != null && (mode.acceptsLayoutField(current) || !usesLayout);
    final first = mode.needsLayoutField
        ? state.collection.fields.where(mode.acceptsLayoutField).firstOrNull
        : null;
    return context.read<CollectionViewsCubit>().setMode(
      mode.id,
      layoutFieldId: keep ? current.id : first?.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final collection = state.collection;
    final view = state.activeView;
    final mode = modes.resolve(view.mode);
    final cubit = context.read<CollectionViewsCubit>();
    final unavailable = [
      for (final m in modes.modes)
        if (m.unavailableReason(collection) case final reason?)
          '${m.label}: ${reason[0].toLowerCase()}${reason.substring(1)}',
    ];
    final layoutFields = collection.fields
        .where(mode.acceptsLayoutField)
        .toList();
    final renders = mode.unavailableReason(collection) == null;
    final caption = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final allowManual = modes.resolve(view.mode).supportsManualOrder;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
            child: Text.rich(
              TextSpan(
                text: 'View settings',
                style: theme.textTheme.titleMedium,
                children: [
                  TextSpan(
                    text: '  ${view.name}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const _SectionLabel('Mode'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                for (final m in modes.modes)
                  ButtonSegment(
                    value: m.id,
                    icon: Icon(m.icon, semanticLabel: m.label),
                    tooltip: m.unavailableReason(collection) ?? m.label,
                    enabled: m.unavailableReason(collection) == null,
                  ),
              ],
              selected: {mode.id},
              onSelectionChanged: (picked) {
                final next = modes.byId(picked.first);
                if (next != null) _switchTo(context, next);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.lg,
              Spacing.xs,
              Spacing.lg,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${mode.label} · ${mode.description}',
                  style: theme.textTheme.bodyMedium,
                ),
                for (final line in unavailable)
                  Padding(
                    padding: const EdgeInsets.only(top: Spacing.xxs),
                    child: Text(line, style: caption),
                  ),
              ],
            ),
          ),
          if (layoutFields.isNotEmpty) ...[
            _SectionLabel(mode.layoutFieldLabel),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
              child: Wrap(
                spacing: Spacing.xs,
                runSpacing: Spacing.xs,
                children: [
                  if (!mode.needsLayoutField)
                    ChoiceChip(
                      label: const Text('None'),
                      selected: state.layoutField == null,
                      onSelected: (_) => cubit.setLayoutField(null),
                    ),
                  for (final f in layoutFields)
                    ChoiceChip(
                      // The selected fill marks the pick; a checkmark would
                      // replace the type icon.
                      showCheckmark: false,
                      avatar: Icon(
                        fieldTypeIcon(f),
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                      label: Text(f.name),
                      selected: state.layoutField?.id == f.id,
                      onSelected: (_) => cubit.setLayoutField(f.id),
                    ),
                ],
              ),
            ),
          ],
          if (renders) ...[
            const SizedBox(height: Spacing.sm),
            const Divider(height: 1),
            const SizedBox(height: Spacing.xs),
            _SettingRow(
              icon: switch (view.sort) {
                null => Icons.swap_vert,
                ViewSort(ascending: true) => Icons.arrow_upward,
                _ => Icons.arrow_downward,
              },
              title: 'Sort',
              value:
                  sortLabel(view.sort, collection) ??
                  (allowManual ? 'Manual order' : 'None'),
              onTap: onSort,
            ),
            _SettingRow(
              icon: Icons.view_column_outlined,
              title: mode.id == ViewModeIds.table ? 'Columns' : 'Card fields',
              value: '${view.fieldIds.length} shown',
              onTap: () => onEditFields(mode),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.lg,
        Spacing.md,
        Spacing.lg,
        Spacing.xs,
      ),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// A 56 px row: icon, title, current value and a chevron.
class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListTile(
      minTileHeight: 56,
      contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      leading: Icon(icon, color: scheme.onSurfaceVariant),
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: Spacing.xxs),
          Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        ],
      ),
      onTap: onTap,
    );
  }
}
