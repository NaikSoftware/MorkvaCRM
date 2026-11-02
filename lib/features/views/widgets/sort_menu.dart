import 'package:flutter/material.dart';

import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import 'view_labels.dart';

/// Picks the view's one sort: a field (plus "Created" / "Updated") and a
/// direction, or "Manual" when [allowManual] (Board, List: drag to order).
///
/// Every change is reported through [onChanged] at once (null = manual);
/// the direction toggle keeps the menu open, picking a field closes it via
/// [onPicked].
class SortMenu extends StatefulWidget {
  const SortMenu({
    super.key,
    required this.collection,
    required this.current,
    required this.allowManual,
    required this.onChanged,
    this.onPicked,
  });

  final Collection collection;
  final ViewSort? current;
  final bool allowManual;
  final ValueChanged<ViewSort?> onChanged;
  final VoidCallback? onPicked;

  @override
  State<SortMenu> createState() => _SortMenuState();
}

class _SortMenuState extends State<SortMenu> {
  late ViewSort? _sort = widget.current;
  late bool _ascending = widget.current?.ascending ?? true;

  void _pick(String? fieldId) {
    final sort = fieldId == null
        ? null
        : ViewSort(fieldId: fieldId, ascending: _ascending);
    setState(() => _sort = sort);
    widget.onChanged(sort);
    widget.onPicked?.call();
  }

  void _direction(bool ascending) {
    setState(() => _ascending = ascending);
    final sort = _sort;
    if (sort == null) return;
    final next = ViewSort(fieldId: sort.fieldId, ascending: ascending);
    setState(() => _sort = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = _sort?.fieldId;
    final rows = <(String?, String, IconData)>[
      if (widget.allowManual) (null, 'Manual', Icons.drag_indicator),
      for (final f in widget.collection.fields)
        // Files have no meaningful order (only their count would sort).
        if (f is! FileFieldDefinition) (f.id, f.name, fieldTypeIcon(f)),
      (ViewSort.createdAt, 'Created', Icons.schedule),
      (ViewSort.updatedAt, 'Updated', Icons.update),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.md,
            Spacing.sm,
            Spacing.md,
            Spacing.xs,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text('Sort by', style: theme.textTheme.titleSmall),
              ),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: const [
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.arrow_upward, size: 18),
                    label: Text('Asc'),
                    tooltip: 'Ascending',
                  ),
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.arrow_downward, size: 18),
                    label: Text('Desc'),
                    tooltip: 'Descending',
                  ),
                ],
                selected: {_ascending},
                onSelectionChanged: _sort == null
                    ? null
                    : (s) => _direction(s.first),
              ),
            ],
          ),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: Spacing.xs),
            children: [
              for (final (id, label, icon) in rows)
                _SortRow(
                  label: label,
                  icon: icon,
                  selected: id == selected,
                  onTap: () => _pick(id),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SortRow extends StatelessWidget {
  const _SortRow({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.xxs),
        child: Material(
          color: selected ? scheme.secondaryContainer : Colors.transparent,
          shape: const RoundedRectangleBorder(borderRadius: Radii.smAll),
          child: InkWell(
            onTap: onTap,
            borderRadius: Radii.smAll,
            child: SizedBox(
              height: 44,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: scheme.onSurfaceVariant),
                    const SizedBox(width: Spacing.sm),
                    Expanded(
                      child: Text(
                        label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: selected
                              ? scheme.onSecondaryContainer
                              : scheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (selected)
                      Icon(
                        Icons.check,
                        size: 20,
                        color: scheme.onSecondaryContainer,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
