import 'package:flutter/material.dart';

import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import '../../views/widgets/view_labels.dart';
import '../value_editors/field_value_editor.dart';

/// Picks the objects a reference field links to: a dialog on wide screens
/// (≥ 840 px), a bottom sheet below. Search filters by label as you type.
///
/// Single link: tapping a row links it and closes; the current link has a
/// check and "Unlink" clears it. Multiple: checkboxes, then Done.
class ReferencePicker extends StatefulWidget {
  const ReferencePicker({
    super.key,
    required this.field,
    required this.choices,
    required this.selected,
  });

  final ReferenceFieldDefinition field;
  final ReferenceChoices choices;
  final List<String> selected;

  /// Resolves to the new linked ids (`[]` = unlinked), or null when
  /// cancelled/dismissed.
  static Future<List<String>?> show(
    BuildContext context, {
    required ReferenceFieldDefinition field,
    required ReferenceChoices choices,
    required List<String> selected,
  }) {
    final picker = ReferencePicker(
      field: field,
      choices: choices,
      selected: selected,
    );
    if (MediaQuery.sizeOf(context).width >= 840) {
      return showDialog<List<String>>(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
            child: picker,
          ),
        ),
      );
    }
    return showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: picker,
        ),
      ),
    );
  }

  @override
  State<ReferencePicker> createState() => _ReferencePickerState();
}

class _ReferencePickerState extends State<ReferencePicker> {
  late final _checked = {...widget.selected};
  String _query = '';

  bool get _multiple => widget.field.multiple;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final target = widget.choices.targetOf(widget.field);
    final targetName = target?.name ?? 'This collection';
    final items = target?.name.trim().toLowerCase() ?? 'items';
    final item = target == null ? 'item' : itemLabelOf(target);
    final labels = widget.choices.labelsFor(widget.field) ?? const {};
    final q = _query.trim().toLowerCase();
    final rows = [
      for (final e in labels.entries)
        if (q.isEmpty || e.value.toLowerCase().contains(q)) e,
    ];
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.lg,
            Spacing.lg,
            Spacing.lg,
            Spacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      _multiple ? 'Link $items' : 'Link $item',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  if (_multiple && target != null)
                    Text('from $targetName', style: muted),
                ],
              ),
              const SizedBox(height: Spacing.sm),
              MorkvaTextField(
                autofocus: true,
                hint: 'Search $items',
                prefixIcon: const Icon(Icons.search),
                suffixText: q.isEmpty
                    ? null
                    : '${rows.length} of ${labels.length}',
                textInputAction: TextInputAction.search,
                onChanged: (text) => setState(() => _query = text),
              ),
            ],
          ),
        ),
        Expanded(
          child: labels.isEmpty || rows.isEmpty
              ? _Notice(
                  title: labels.isEmpty
                      ? '$targetName has no items yet'
                      : 'No $items match “${_query.trim()}”',
                  subtitle: labels.isEmpty ? null : 'Try another name',
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
                  itemCount: rows.length,
                  itemBuilder: (context, i) {
                    final MapEntry(key: id, value: label) = rows[i];
                    return _Row(
                      label: label,
                      secondary: widget.choices.secondaryOf(id),
                      multiple: _multiple,
                      checked: _checked.contains(id),
                      onTap: () => _multiple
                          ? setState(() {
                              if (!_checked.remove(id)) _checked.add(id);
                            })
                          : Navigator.of(context).pop([id]),
                    );
                  },
                ),
        ),
        Divider(height: 1, color: scheme.outlineVariant),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.md,
            Spacing.sm,
            Spacing.md,
            Spacing.md,
          ),
          child: Row(
            children: [
              if (_multiple)
                Expanded(child: Text('${_checked.length} linked', style: muted))
              else ...[
                if (widget.selected.isNotEmpty)
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: scheme.error,
                      minimumSize: const Size(44, 44),
                    ),
                    onPressed: () => Navigator.of(context).pop(<String>[]),
                    child: const Text('Unlink'),
                  ),
                const Spacer(),
              ],
              TextActionButton(
                label: 'Cancel',
                onPressed: () => Navigator.of(context).pop(),
              ),
              if (_multiple) ...[
                const SizedBox(width: Spacing.xs),
                PrimaryButton(
                  label: 'Done',
                  // Keep the target's order, then any ids it no longer has.
                  onPressed: () => Navigator.of(context).pop([
                    for (final id in labels.keys)
                      if (_checked.contains(id)) id,
                    for (final id in widget.selected)
                      if (_checked.contains(id) && !labels.containsKey(id)) id,
                  ]),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.secondary,
    required this.multiple,
    required this.checked,
    required this.onTap,
  });

  final String label;
  final String? secondary;
  final bool multiple;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (secondary case final s?)
          Text(
            s,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
      ],
    );
    return MergeSemantics(
      child: Material(
        color: checked ? scheme.surfaceContainer : Colors.transparent,
        borderRadius: Radii.mdAll,
        child: InkWell(
          borderRadius: Radii.mdAll,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
              child: Row(
                children: [
                  if (multiple) ...[
                    Checkbox(value: checked, onChanged: (_) => onTap()),
                    const SizedBox(width: Spacing.xs),
                  ],
                  Expanded(child: text),
                  if (!multiple && checked)
                    Icon(
                      Icons.check,
                      color: scheme.primary,
                      semanticLabel: 'Linked',
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: Spacing.xs,
        ),
        padding: const EdgeInsets.all(Spacing.lg),
        width: double.infinity,
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: Radii.mdAll,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (subtitle case final s?) ...[
              const SizedBox(height: Spacing.xxs),
              Text(
                s,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
