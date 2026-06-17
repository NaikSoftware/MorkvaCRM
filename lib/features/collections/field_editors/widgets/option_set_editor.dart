import 'package:flutter/material.dart';

import '../../../../core/domain/domain.dart';
import '../../../../design/design.dart';
import '../../util/id_generator.dart';
import 'color_swatch_picker.dart';

/// Edits the fixed option set shared by single- and multi-select fields.
///
/// Supports add / rename / reorder / recolor. Option ids are generated once and
/// stay stable across edits (object values key off the id, never the label or
/// position), so renaming or reordering never corrupts stored data. The widget
/// never mutates its input: every change emits a fresh `List<SelectOption>`
/// through [onChanged].
class OptionSetEditor extends StatefulWidget {
  const OptionSetEditor({
    super.key,
    required this.options,
    required this.onChanged,
    this.idGenerator,
  });

  /// The current option set.
  final List<SelectOption> options;

  /// Called with the replacement option set on every edit.
  final ValueChanged<List<SelectOption>> onChanged;

  /// Injectable id generator (tests supply a deterministic one).
  final IdGenerator? idGenerator;

  @override
  State<OptionSetEditor> createState() => _OptionSetEditorState();
}

class _OptionSetEditorState extends State<OptionSetEditor> {
  late final IdGenerator _ids = widget.idGenerator ?? IdGenerator();

  // Controllers are keyed by stable option id so a reorder/rename does not
  // recreate or mis-associate text fields.
  final Map<String, TextEditingController> _controllers = {};

  TextEditingController _controllerFor(SelectOption option) {
    final existing = _controllers[option.id];
    if (existing != null) {
      if (existing.text != option.label) existing.text = option.label;
      return existing;
    }
    final controller = TextEditingController(text: option.label);
    _controllers[option.id] = controller;
    return controller;
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    final option = SelectOption(
      id: _ids.optionId(),
      label: 'Option ${widget.options.length + 1}',
    );
    widget.onChanged([...widget.options, option]);
  }

  void _renameOption(String id, String label) {
    widget.onChanged([
      for (final o in widget.options)
        if (o.id == id)
          SelectOption(id: o.id, label: label, color: o.color)
        else
          o,
    ]);
  }

  void _recolorOption(String id, String? color) {
    widget.onChanged([
      for (final o in widget.options)
        if (o.id == id)
          SelectOption(id: o.id, label: o.label, color: color)
        else
          o,
    ]);
  }

  void _removeOption(String id) {
    _controllers.remove(id)?.dispose();
    widget.onChanged(widget.options.where((o) => o.id != id).toList());
  }

  void _reorder(int oldIndex, int newIndex) {
    final next = [...widget.options];
    var target = newIndex;
    if (target > oldIndex) target -= 1;
    final moved = next.removeAt(oldIndex);
    next.insert(target, moved);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Options', style: theme.textTheme.titleSmall),
        const SizedBox(height: Spacing.xs),
        if (widget.options.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
            child: Text(
              'No options yet — add the first choice.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorder: _reorder,
            children: [
              for (var i = 0; i < widget.options.length; i++)
                _OptionRow(
                  key: ValueKey(widget.options[i].id),
                  index: i,
                  option: widget.options[i],
                  controller: _controllerFor(widget.options[i]),
                  onLabelChanged: (label) =>
                      _renameOption(widget.options[i].id, label),
                  onColorChanged: (color) =>
                      _recolorOption(widget.options[i].id, color),
                  onRemove: () => _removeOption(widget.options[i].id),
                ),
            ],
          ),
        const SizedBox(height: Spacing.xs),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addOption,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add option'),
          ),
        ),
      ],
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    super.key,
    required this.index,
    required this.option,
    required this.controller,
    required this.onLabelChanged,
    required this.onColorChanged,
    required this.onRemove,
  });

  final int index;
  final SelectOption option;
  final TextEditingController controller;
  final ValueChanged<String> onLabelChanged;
  final ValueChanged<String?> onColorChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xxs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: Icon(
                  Icons.drag_indicator,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: Spacing.xs),
              if (option.color != null)
                Padding(
                  padding: const EdgeInsets.only(right: Spacing.xs),
                  child: CircleAvatar(
                    radius: 7,
                    backgroundColor: colorFromHex(option.color!),
                  ),
                ),
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onLabelChanged,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    hintText: 'Option label',
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Remove option',
                icon: const Icon(Icons.close),
                onPressed: onRemove,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(
              left: Spacing.xl,
              top: Spacing.xxs,
              bottom: Spacing.xs,
            ),
            child: ColorSwatchPicker(
              selected: option.color,
              onChanged: onColorChanged,
            ),
          ),
        ],
      ),
    );
  }
}
