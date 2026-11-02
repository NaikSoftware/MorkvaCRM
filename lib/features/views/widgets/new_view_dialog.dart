import 'package:flutter/material.dart';

import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import '../modes/view_mode.dart';

/// What the user asked [NewViewDialog] to create.
class NewViewRequest {
  const NewViewRequest({
    required this.name,
    required this.mode,
    this.layoutFieldId,
  });

  final String name;
  final String mode;
  final String? layoutFieldId;
}

/// Picks a name and a mode (one tile per registered [ViewMode], plus a
/// disabled Gallery teaser) and, for modes that need one, the layout field.
/// Resolves to a [NewViewRequest], or null on cancel.
class NewViewDialog extends StatefulWidget {
  const NewViewDialog({
    super.key,
    required this.collection,
    required this.modes,
    required this.onAddField,
  });

  final Collection collection;
  final ViewModeRegistry modes;

  /// Opens the collection editor so the user can add the missing field.
  final VoidCallback onAddField;

  static Future<NewViewRequest?> show(
    BuildContext context, {
    required Collection collection,
    required ViewModeRegistry modes,
    required VoidCallback onAddField,
  }) => showDialog<NewViewRequest>(
    context: context,
    builder: (_) => NewViewDialog(
      collection: collection,
      modes: modes,
      onAddField: onAddField,
    ),
  );

  @override
  State<NewViewDialog> createState() => _NewViewDialogState();
}

class _NewViewDialogState extends State<NewViewDialog> {
  final _name = TextEditingController();
  late ViewMode _mode = widget.modes.modes.firstWhere(
    (m) => m.unavailableReason(widget.collection) == null,
    orElse: () => widget.modes.modes.first,
  );
  String? _layoutFieldId;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
    _layoutFieldId = _soleCandidate(_mode);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  List<FieldDefinition> _candidates(ViewMode mode) => [
    for (final f in widget.collection.fields)
      if (mode.acceptsLayoutField(f)) f,
  ];

  String? _soleCandidate(ViewMode mode) {
    if (!mode.needsLayoutField) return null;
    final c = _candidates(mode);
    return c.length == 1 ? c.single.id : null;
  }

  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      _mode.unavailableReason(widget.collection) == null &&
      (!_mode.needsLayoutField || _layoutFieldId != null);

  void _select(ViewMode mode) => setState(() {
    _mode = mode;
    _layoutFieldId = _soleCandidate(mode);
  });

  void _submit() {
    if (!_valid) return;
    Navigator.of(context).pop(
      NewViewRequest(
        name: _name.text.trim(),
        mode: _mode.id,
        layoutFieldId: _mode.needsLayoutField ? _layoutFieldId : null,
      ),
    );
  }

  void _addField() {
    Navigator.of(context).pop();
    widget.onAddField();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final tiles = <Widget>[
      for (final m in widget.modes.modes)
        _ModeTile(
          icon: m.icon,
          label: m.label,
          description: m.description,
          reason: m.unavailableReason(widget.collection),
          selected: identical(m, _mode),
          onSelect: () => _select(m),
          onAddField: _addField,
        ),
      const _ModeTile(
        icon: Icons.photo_library_outlined,
        label: 'Gallery',
        description: 'Cards with pictures',
        reason: 'Needs image files',
      ),
    ];
    final columns = wide ? 5 : 2;
    final candidates = _candidates(_mode);
    final isDate = candidates.any((f) => f is DateFieldDefinition);

    return AlertDialog(
      title: const Text('New view'),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: wide ? 760 : 420),
        child: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MorkvaTextField(
                  controller: _name,
                  label: 'Name',
                  hint: 'e.g. Pipeline',
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: Spacing.md),
                for (var i = 0; i < tiles.length; i += columns) ...[
                  if (i > 0) const SizedBox(height: Spacing.xs),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var j = 0; j < columns; j++) ...[
                          if (j > 0) const SizedBox(width: Spacing.xs),
                          Expanded(
                            child: i + j < tiles.length
                                ? tiles[i + j]
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                AnimatedSize(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? MotionDurations.none
                      : MotionDurations.slow,
                  curve: MotionCurves.emphasized,
                  alignment: Alignment.topCenter,
                  child: _mode.needsLayoutField && candidates.isNotEmpty
                      ? Padding(
                          padding: const EdgeInsets.only(top: Spacing.md),
                          child: _LayoutFieldPicker(
                            label: isDate ? 'Date field' : 'Group by',
                            fields: candidates,
                            selectedId: _layoutFieldId,
                            onSelect: (id) =>
                                setState(() => _layoutFieldId = id),
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextActionButton(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        PrimaryButton(label: 'Create view', onPressed: _valid ? _submit : null),
      ],
    );
  }
}

class _LayoutFieldPicker extends StatelessWidget {
  const _LayoutFieldPicker({
    required this.label,
    required this.fields,
    required this.selectedId,
    required this.onSelect,
  });

  final String label;
  final List<FieldDefinition> fields;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelMedium),
        const SizedBox(height: Spacing.xs),
        Wrap(
          spacing: Spacing.xs,
          runSpacing: Spacing.xs,
          children: [
            for (final f in fields)
              ChoiceChip(
                label: Text(f.name),
                selected: f.id == selectedId,
                onSelected: (_) => onSelect(f.id),
              ),
          ],
        ),
      ],
    );
  }
}

/// One mode. Unavailable tiles ([reason] set) keep full-contrast text, mute
/// only the illustration, and stay focusable with a tooltip.
class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.icon,
    required this.label,
    required this.description,
    this.reason,
    this.selected = false,
    this.onSelect,
    this.onAddField,
  });

  final IconData icon;
  final String label;
  final String description;
  final String? reason;
  final bool selected;
  final VoidCallback? onSelect;

  /// Shown as a link under the reason; null for tiles with no fix (Gallery).
  final VoidCallback? onAddField;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final linkColor =
        theme.extension<MorkvaSemanticColors>()?.primaryText ?? scheme.primary;
    final unavailable = reason != null;
    final linkLabel = (reason ?? '').toLowerCase().contains('date')
        ? 'Add date field'
        : 'Add field';

    final tile = Material(
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: Radii.mdAll,
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // An unavailable tile still takes focus so its tooltip is reachable.
        onTap: unavailable ? () {} : onSelect,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.all(Spacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Opacity(
                  opacity: unavailable ? 0.4 : 1,
                  child: Icon(
                    icon,
                    size: 28,
                    color: selected
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: Spacing.xs),
                Text(label, style: theme.textTheme.titleSmall),
                const SizedBox(height: Spacing.xxs),
                Text(
                  reason ?? description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (unavailable && onAddField != null)
                  InkWell(
                    onTap: onAddField,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          linkLabel,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: linkColor,
                            decoration: TextDecoration.underline,
                            decorationColor: linkColor,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    return Semantics(
      container: true,
      selected: selected,
      child: reason == null ? tile : Tooltip(message: reason, child: tile),
    );
  }
}
