import 'package:flutter/material.dart';

import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import '../modes/table_mode.dart';
import 'object_card.dart';
import 'view_labels.dart';

/// Chooses which fields a view shows and in what order: "Columns" for Table,
/// "Setup card" for the other modes. The first field is the title; it is
/// changed with the "Card title" picker, not by dragging. Edits are a draft
/// with a live preview and only reach [onSave] on Save.
class FieldsEditorSheet extends StatefulWidget {
  const FieldsEditorSheet({
    super.key,
    required this.title,
    required this.collection,
    required this.view,
    required this.onSave,
    this.object,
    this.referenceLabels = const {},
  });

  /// "Columns" or "Setup card".
  final String title;
  final Collection collection;
  final ViewDefinition view;

  /// The object the preview shows (the view's first), or null for names only.
  final MorkvaObject? object;
  final Map<String, String> referenceLabels;
  final ValueChanged<List<String>> onSave;

  /// Full-screen on phones, a dialog on wide screens.
  static Future<void> show(
    BuildContext context, {
    required String title,
    required Collection collection,
    required ViewDefinition view,
    required ValueChanged<List<String>> onSave,
    MorkvaObject? object,
    Map<String, String> referenceLabels = const {},
  }) {
    if (collection.fields.isEmpty) return Future.value();
    final sheet = FieldsEditorSheet(
      title: title,
      collection: collection,
      view: view,
      object: object,
      referenceLabels: referenceLabels,
      onSave: onSave,
    );
    final compact = MediaQuery.sizeOf(context).width < 600;
    return showDialog<void>(
      context: context,
      builder: (_) => compact
          ? Dialog.fullscreen(child: sheet)
          : Dialog(
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 560,
                  maxHeight: 720,
                ),
                child: sheet,
              ),
            ),
    );
  }

  @override
  State<FieldsEditorSheet> createState() => _FieldsEditorSheetState();
}

class _FieldsEditorSheetState extends State<FieldsEditorSheet> {
  late String _titleId;
  late List<String> _order; // every listed field except the title
  late Set<String> _shown;

  bool get _columns => widget.view.mode == ViewModeIds.table;

  /// Summary draws tiles, not cards: no card preview, and empty values show.
  bool get _tiles => widget.view.mode == ViewModeIds.summary;
  String? get _layoutId => widget.view.layoutFieldId;
  List<String> get _original => [
    for (final id in widget.view.fieldIds)
      if (widget.collection.fieldById(id) != null) id,
  ];

  FieldDefinition get _titleField =>
      widget.collection.fieldById(_titleId) ?? widget.collection.fields.first;

  @override
  void initState() {
    super.initState();
    final c = widget.collection;
    final ids = _original;
    _titleId = ids.firstOrNull ?? c.fields.first.id;
    final shown = [
      for (final id in ids.skip(1))
        if (id != _layoutId) id,
    ];
    _shown = shown.toSet();
    _order = [
      ...shown,
      for (final f in c.fields)
        if (f.id != _titleId && f.id != _layoutId && !_shown.contains(f.id))
          f.id,
    ];
  }

  List<String> get _draftIds {
    final ids = [_titleId, ..._order.where(_shown.contains)];
    final at = _original.indexOf(_layoutId ?? '');
    // The layout field is not listed; keep it where the view had it.
    if (at > 0 && _layoutId != _titleId) {
      ids.insert(at.clamp(0, ids.length), _layoutId!);
    }
    return ids;
  }

  bool get _dirty {
    final draft = _draftIds;
    final original = _original;
    return draft.length != original.length ||
        Iterable<int>.generate(
          draft.length,
        ).any((i) => draft[i] != original[i]);
  }

  void _toggle(String id) =>
      setState(() => _shown.contains(id) ? _shown.remove(id) : _shown.add(id));

  void _move(int from, int to) => setState(() {
    if (to < 0 || to >= _order.length) return;
    _order.insert(to, _order.removeAt(from));
  });

  void _setTitle(String id) => setState(() {
    if (id == _titleId) return;
    _order.remove(id);
    _order.insert(0, _titleId);
    _shown.add(_titleId);
    _shown.remove(id);
    _titleId = id;
  });

  void _save() {
    widget.onSave(_draftIds);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final c = widget.collection;
    final layout = _layoutId == null ? null : c.fieldById(_layoutId!);
    final candidates = [
      for (final f in c.fields)
        if (f.id != _layoutId || f.id == _titleId) f,
    ];
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Material(
      color: scheme.surface,
      child: SafeArea(
        child: Column(
          mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.lg,
                Spacing.sm,
                Spacing.xs,
                Spacing.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconActionButton(
                    icon: Icons.close,
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            if (!_columns)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.lg,
                  0,
                  Spacing.lg,
                  Spacing.sm,
                ),
                child: Text(
                  'Choose which fields show '
                  '${_tiles ? 'as tiles' : 'on each card'} in '
                  '“${widget.view.name}” and drag to set their order.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (!_tiles)
              Container(
                color: scheme.surfaceContainerLow,
                padding: const EdgeInsets.all(Spacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PREVIEW',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: Spacing.xs),
                    Semantics(
                      label: 'Preview',
                      child: _columns
                          ? _ColumnsPreview(this)
                          : _CardPreview(this),
                    ),
                    if (layout != null) ...[
                      const SizedBox(height: Spacing.xs),
                      Text(
                        _layoutNote(layout),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (!_columns) ...[
                      const SizedBox(height: Spacing.xs),
                      Text(
                        'Empty fields are skipped on the card.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            _TitleRow(
              columns: _columns,
              current: _titleField,
              candidates: candidates,
              onChanged: _setTitle,
            ),
            Padding(
              padding: const EdgeInsets.only(right: Spacing.xxs),
              child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: 48,
                  child: Text(
                    'Show',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
            Flexible(
              fit: compact ? FlexFit.tight : FlexFit.loose,
              child: ReorderableListView(
                shrinkWrap: true,
                buildDefaultDragHandles: false,
                onReorderItem: _move,
                // The proxy sits in the overlay, above the sheet's Material:
                // it needs its own for the row's InkWell.
                proxyDecorator: (child, _, _) => Material(
                  color: scheme.surfaceContainerLowest,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      boxShadow: MorkvaElevation.level2,
                    ),
                    child: Transform.scale(scale: 1.02, child: child),
                  ),
                ),
                children: [
                  for (var i = 0; i < _order.length; i++)
                    _FieldRow(
                      key: ValueKey(_order[i]),
                      field: c.fieldById(_order[i])!,
                      index: i,
                      count: _order.length,
                      shown: _shown.contains(_order[i]),
                      onToggle: () => _toggle(_order[i]),
                      onMove: (to) => _move(i, to),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Spacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextActionButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: Spacing.xs),
                  PrimaryButton(
                    label: 'Save',
                    onPressed: _dirty ? _save : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _layoutNote(FieldDefinition layout) => switch (widget.view.mode) {
    ViewModeIds.board => '${layout.name} is shown as the columns',
    ViewModeIds.calendar => '${layout.name} places each card on its day',
    _ => '${layout.name} is shown separately',
  };
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({
    required this.columns,
    required this.current,
    required this.candidates,
    required this.onChanged,
  });

  final bool columns;
  final FieldDefinition current;
  final List<FieldDefinition> candidates;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = columns ? 'Title column' : 'Card title';
    return PopupMenuButton<String>(
      tooltip: 'Change ${label.toLowerCase()}',
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final f in candidates)
          CheckedPopupMenuItem(
            value: f.id,
            checked: f.id == current.id,
            child: Text(f.name),
          ),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
          child: Row(
            children: [
              const SizedBox(
                width: 44,
                child: Icon(Icons.push_pin_outlined, size: 20),
              ),
              Expanded(
                child: Text(
                  current.name,
                  style: theme.textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Icon(Icons.arrow_drop_down, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    super.key,
    required this.field,
    required this.index,
    required this.count,
    required this.shown,
    required this.onToggle,
    required this.onMove,
  });

  final FieldDefinition field;
  final int index;
  final int count;
  final bool shown;
  final VoidCallback onToggle;
  final ValueChanged<int> onMove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SizedBox(
      height: 52,
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.only(left: Spacing.md),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: Semantics(
                  label: 'Reorder ${field.name}',
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      Icons.drag_indicator,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              Icon(
                fieldTypeIcon(field),
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: Spacing.xs),
              Expanded(
                child: Text(
                  field.name,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: shown ? scheme.onSurface : scheme.onSurfaceVariant,
                  ),
                ),
              ),
              PopupMenuButton<int>(
                tooltip: 'Move ${field.name}',
                icon: Icon(Icons.more_vert, color: scheme.onSurfaceVariant),
                onSelected: onMove,
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: index - 1,
                    enabled: index > 0,
                    child: const Text('Move up'),
                  ),
                  PopupMenuItem(
                    value: index + 1,
                    enabled: index < count - 1,
                    child: const Text('Move down'),
                  ),
                ],
              ),
              Semantics(
                label: field.name,
                child: Checkbox(value: shown, onChanged: (_) => onToggle()),
              ),
              const SizedBox(width: Spacing.xxs),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardPreview extends StatelessWidget {
  const _CardPreview(this.s);

  final _FieldsEditorSheetState s;

  @override
  Widget build(BuildContext context) {
    final c = s.widget.collection;
    final view = s.widget.view.copyWith(fieldIds: s._draftIds);
    final object = s.widget.object;
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: object != null
            ? ObjectCard(
                object: object,
                collection: c,
                view: view,
                referenceLabels: s.widget.referenceLabels,
              )
            : _NamesOnly(
                title: s._titleField,
                fields: [
                  for (final id in view.fieldIds.skip(1))
                    if (id != view.layoutFieldId) c.fieldById(id)!,
                ],
              ),
      ),
    );
  }
}

/// Stands in for a card when the view has no objects yet: field names only.
class _NamesOnly extends StatelessWidget {
  const _NamesOnly({required this.title, required this.fields});

  final FieldDefinition title;
  final List<FieldDefinition> fields;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: Spacing.sm,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: Radii.mdAll,
        boxShadow: MorkvaElevation.level1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.name,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (fields.isNotEmpty) ...[
            const SizedBox(height: Spacing.xs),
            Wrap(
              spacing: Spacing.xs,
              runSpacing: Spacing.xxs,
              children: [
                for (final f in fields)
                  Text(
                    f.name,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ColumnsPreview extends StatelessWidget {
  const _ColumnsPreview(this.s);

  final _FieldsEditorSheetState s;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final c = s.widget.collection;
    final object = s.widget.object;
    final fields = [for (final id in s._draftIds) c.fieldById(id)!];
    Widget cell(String text, TextStyle? style) => SizedBox(
      width: 120,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      ),
    );
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: Radii.mdAll,
        boxShadow: MorkvaElevation.level1,
      ),
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (final f in fields)
                  cell(
                    f.name,
                    theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Spacing.xxs),
            // The value row is drawn by the Table's own cells.
            SizedBox(
              height: ViewTable.rowHeight,
              child: Row(
                children: [
                  for (final (i, f) in fields.indexed)
                    if (object == null || i == 0)
                      cell(
                        object == null
                            ? '—'
                            : formatFieldValue(
                                f,
                                object[f.id] ?? f.emptyValue(),
                                referenceLabels: s.widget.referenceLabels,
                              ),
                        i == 0
                            ? theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              )
                            : theme.textTheme.bodyMedium,
                      )
                    else
                      SizedBox(
                        width: 120,
                        child: ViewTableCell(
                          field: f,
                          value: object[f.id] ?? f.emptyValue(),
                          referenceLabels: s.widget.referenceLabels,
                        ),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
