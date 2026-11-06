import 'package:flutter/material.dart';

import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import '../widgets/view_labels.dart';
import 'view_mode.dart';

/// Each object as a panel of big stat tiles — a dashboard. A one-object
/// collection of totals reads as the workspace's summary; a collection of,
/// say, colors as a summary per color.
class SummaryMode extends ViewMode {
  const SummaryMode();

  @override
  String get id => ViewModeIds.summary;

  @override
  String get label => 'Summary';

  @override
  IconData get icon => Icons.space_dashboard_outlined;

  @override
  String get description => 'Big numbers per item, like a dashboard.';

  @override
  String get fieldsLabel => 'Setup tiles';

  @override
  Widget buildBody(BuildContext context, ViewModeData data) =>
      SummaryPanels(data: data);
}

/// The panels, one per object in view order.
class SummaryPanels extends StatelessWidget {
  const SummaryPanels({super.key, required this.data});

  final ViewModeData data;

  @override
  Widget build(BuildContext context) {
    final state = data.state;
    final view = state.activeView;
    final collection = state.collection;
    final tiles = [
      for (final id in view.fieldIds.skip(1)) ?collection.fieldById(id),
    ];
    final single = state.objects.length == 1;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        Spacing.md,
        Spacing.xs,
        Spacing.md,
        Spacing.xxl,
      ),
      itemCount: state.objects.length,
      separatorBuilder: (_, _) => const SizedBox(height: Spacing.md),
      itemBuilder: (context, i) {
        final object = state.objects[i];
        return _Panel(
          title: titleOf(view, collection, object),
          large: single,
          onEdit: () => data.openObject(object),
          tiles: [
            for (final (n, f) in tiles.indexed)
              _Tile(
                label: f.name,
                value: formatFieldValue(
                  f,
                  object[f.id] ?? f.emptyValue(),
                  referenceLabels: state.referenceLabels,
                ),
                numeric: isNumericField(f),
                hero: n == tiles.indexWhere(isNumericField),
                caption: switch (f) {
                  CalculatedFieldDefinition() => state.calculationNotes[f.id],
                  NumberFieldDefinition() => 'Entered by hand',
                  _ => null,
                },
              ),
          ],
        );
      },
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.tiles,
    required this.large,
    required this.onEdit,
  });

  final String title;
  final List<_Tile> tiles;
  final bool large;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(Radii.lg + 8)),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(large ? Spacing.lg : Spacing.md + 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: large
                        ? theme.textTheme.headlineSmall
                        : theme.textTheme.titleLarge,
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit values'),
                ),
              ],
            ),
            const SizedBox(height: Spacing.md),
            if (tiles.isEmpty)
              Text(
                'Pick fields to show with “Setup tiles”.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  const gap = Spacing.sm;
                  final columns = (constraints.maxWidth / (large ? 220 : 180))
                      .floor()
                      .clamp(1, 4);
                  final width =
                      (constraints.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final t in tiles)
                        SizedBox(
                          width: width,
                          child: t.copyWith(large: large),
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.value,
    required this.numeric,
    required this.hero,
    this.caption,
    this.large = true,
  });

  final String label;
  final String value;
  final bool numeric;

  /// The first number: drawn on the accent container.
  final bool hero;
  final String? caption;
  final bool large;

  _Tile copyWith({bool? large}) => _Tile(
    label: label,
    value: value,
    numeric: numeric,
    hero: hero,
    caption: caption,
    large: large ?? this.large,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ink = hero ? scheme.onPrimaryContainer : scheme.onSurface;
    final muted = hero ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;
    final empty = value.trim().isEmpty;
    final valueStyle = numeric
        ? MorkvaTypography.tabular(
            ((large
                        ? theme.textTheme.headlineLarge
                        : theme.textTheme.headlineSmall) ??
                    const TextStyle())
                .copyWith(color: ink, fontWeight: FontWeight.w700),
          )
        : theme.textTheme.titleMedium?.copyWith(color: ink);
    return Semantics(
      container: true,
      label: '$label: ${empty ? 'empty' : value}',
      excludeSemantics: true,
      child: Container(
        constraints: BoxConstraints(minHeight: large ? 116 : 92),
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm + 2,
        ),
        decoration: BoxDecoration(
          color: hero ? scheme.primaryContainer : scheme.surface,
          borderRadius: Radii.lgAll,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(color: muted),
            ),
            const SizedBox(height: Spacing.xxs),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(empty ? '—' : value, maxLines: 1, style: valueStyle),
            ),
            if (caption != null && large) ...[
              const SizedBox(height: Spacing.xxs),
              Text(
                caption!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
