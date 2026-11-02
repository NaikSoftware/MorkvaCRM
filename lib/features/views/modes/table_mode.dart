import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/shell/app_shell.dart';
import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import '../collection_views_cubit.dart';
import '../widgets/option_pill.dart';
import '../widgets/view_labels.dart';
import 'view_mode.dart';

/// Rows and columns. Header taps cycle the sort; the title column stays
/// pinned while the others scroll sideways.
class TableMode extends ViewMode {
  const TableMode();

  @override
  String get id => ViewModeIds.table;

  @override
  String get label => 'Table';

  @override
  IconData get icon => Icons.table_rows_outlined;

  @override
  String get description => 'Rows and columns, sortable by any field.';

  @override
  String get fieldsLabel => 'Columns';

  @override
  Widget buildBody(BuildContext context, ViewModeData data) =>
      ViewTable(data: data);
}

/// The Table mode body.
class ViewTable extends StatefulWidget {
  const ViewTable({super.key, required this.data});

  final ViewModeData data;

  static const double rowHeight = 52;
  static const double headerHeight = 44;

  @override
  State<ViewTable> createState() => _ViewTableState();
}

class _ViewTableState extends State<ViewTable> {
  final _horizontal = ScrollController();
  final _vertical = ScrollController();

  @override
  void dispose() {
    _horizontal.dispose();
    _vertical.dispose();
    super.dispose();
  }

  static double _widthOf(FieldDefinition f) => switch (f) {
    NumberFieldDefinition() || AutoNumberFieldDefinition() => 128,
    DateFieldDefinition(includeTime: true) => 176,
    DateFieldDefinition() => 136,
    BooleanFieldDefinition() => 96,
    SingleSelectFieldDefinition() => 160,
    _ => 200,
  };

  void _cycleSort(FieldDefinition field) {
    final sort = widget.data.state.activeView.sort;
    final next = switch (sort) {
      ViewSort(:final fieldId, ascending: true) when fieldId == field.id =>
        ViewSort(fieldId: field.id, ascending: false),
      ViewSort(:final fieldId, ascending: false) when fieldId == field.id =>
        null,
      _ => ViewSort(fieldId: field.id),
    };
    context.read<CollectionViewsCubit>().setSort(next);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final state = data.state;
    final collection = state.collection;
    final view = state.activeView;
    final scheme = Theme.of(context).colorScheme;
    final ids = view.fieldIds.isEmpty
        ? ViewDefinition.defaultFor(collection.fields).fieldIds
        : view.fieldIds;
    final fields = [for (final id in ids) ?collection.fieldById(id)];
    if (fields.isEmpty) return const SizedBox.shrink();
    final titleField = fields.first;
    final columns = fields.skip(1).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            MediaQuery.sizeOf(context).width < AppShell.expandedBreakpoint;
        final titleWidth = compact ? 168.0 : 264.0;
        final columnsWidth = columns.fold(0.0, (sum, f) => sum + _widthOf(f));
        final tableWidth = (titleWidth + columnsWidth).clamp(
          constraints.maxWidth,
          double.infinity,
        );
        final layout = _TableLayout(
          titleField: titleField,
          titleWidth: titleWidth,
          columns: columns,
          widths: [for (final f in columns) _widthOf(f)],
          width: tableWidth,
          horizontal: _horizontal,
        );
        // The ghost "+ New" row only stands in for an empty table.
        final empty = state.objects.isEmpty;
        final rowCount = empty ? 1 : state.objects.length;
        // The card hugs its rows instead of filling the body (+2: border).
        final contentHeight =
            ViewTable.headerHeight +
            rowCount * ViewTable.rowHeight +
            _Footer.height +
            2;

        // The border paints over the rows so opaque cells never hide it.
        final card = DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: Radii.lgAll,
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: ClipRRect(
            borderRadius: Radii.lgAll,
            child: ColoredBox(
              color: scheme.surfaceContainerLowest,
              child: Column(
                children: [
                  Expanded(
                    child: Scrollbar(
                      controller: _vertical,
                      notificationPredicate: (n) =>
                          n.metrics.axis == Axis.vertical,
                      child: Scrollbar(
                        controller: _horizontal,
                        notificationPredicate: (n) =>
                            n.metrics.axis == Axis.horizontal,
                        child: SingleChildScrollView(
                          controller: _horizontal,
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: tableWidth,
                            child: Column(
                              children: [
                                _HeaderRow(
                                  layout: layout,
                                  sort: view.sort,
                                  onSort: _cycleSort,
                                ),
                                Expanded(
                                  child: ListView.builder(
                                    controller: _vertical,
                                    itemExtent: ViewTable.rowHeight,
                                    itemCount: rowCount,
                                    itemBuilder: (context, i) {
                                      if (empty) {
                                        return _GhostRow(
                                          layout: layout,
                                          label: 'New ${data.itemLabel}',
                                          onAdd: () => data.quickAdd(),
                                          onChangeFields: data.editFields,
                                        );
                                      }
                                      final object = state.objects[i];
                                      return _ObjectRow(
                                        key: ValueKey(object.id),
                                        layout: layout,
                                        object: object,
                                        view: view,
                                        collection: collection,
                                        referenceLabels: state.referenceLabels,
                                        onOpen: () => data.openObject(object),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  _Footer(
                    text: state.isFiltered
                        ? '${state.objects.length} of ${state.totalCount}'
                        : '${state.totalCount} '
                              '${state.totalCount == 1 ? data.itemLabel : collection.name.toLowerCase()}',
                  ),
                ],
              ),
            ),
          ),
        );
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: contentHeight.clamp(0, constraints.maxHeight).toDouble(),
            child: card,
          ),
        );
      },
    );
  }
}

/// Column geometry shared by the header and every row.
class _TableLayout {
  const _TableLayout({
    required this.titleField,
    required this.titleWidth,
    required this.columns,
    required this.widths,
    required this.width,
    required this.horizontal,
  });

  final FieldDefinition titleField;
  final double titleWidth;
  final List<FieldDefinition> columns;
  final List<double> widths;
  final double width;
  final ScrollController horizontal;
}

const _cellPadding = EdgeInsets.symmetric(horizontal: Spacing.sm);
const _tabular = [FontFeature.tabularFigures()];

/// A row: the scrolling cells, with the title cell pinned on top of them at
/// the current horizontal offset.
class _PinnedRow extends StatelessWidget {
  const _PinnedRow({
    required this.layout,
    required this.height,
    required this.background,
    required this.title,
    required this.cells,
    this.focused = false,
  });

  final _TableLayout layout;
  final double height;
  final Color background;
  final Widget title;
  final List<Widget> cells;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      width: layout.width,
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: background,
              child: Row(
                children: [
                  SizedBox(width: layout.titleWidth),
                  for (var i = 0; i < cells.length; i++)
                    SizedBox(width: layout.widths[i], child: cells[i]),
                ],
              ),
            ),
          ),
          ListenableBuilder(
            listenable: layout.horizontal,
            builder: (context, child) {
              final offset = layout.horizontal.hasClients
                  ? layout.horizontal.offset.clamp(0.0, double.infinity)
                  : 0.0;
              return Positioned(
                left: offset,
                top: 0,
                bottom: 0,
                width: layout.titleWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: background,
                    border: offset > 0
                        ? Border(
                            right: BorderSide(color: scheme.outlineVariant),
                          )
                        : null,
                  ),
                  child: child,
                ),
              );
            },
            child: Stack(
              children: [
                Positioned.fill(child: title),
                if (focused)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 2,
                    child: ColoredBox(color: scheme.primary),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.layout,
    required this.sort,
    required this.onSort,
  });

  final _TableLayout layout;
  final ViewSort? sort;
  final ValueChanged<FieldDefinition> onSort;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: _PinnedRow(
        layout: layout,
        height: ViewTable.headerHeight,
        background: scheme.surfaceContainerLow,
        title: _HeaderCell(
          field: layout.titleField,
          sort: sort,
          onSort: onSort,
          leading: true,
        ),
        cells: [
          for (final f in layout.columns)
            _HeaderCell(field: f, sort: sort, onSort: onSort),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.field,
    required this.sort,
    required this.onSort,
    this.leading = false,
  });

  final FieldDefinition field;
  final ViewSort? sort;
  final ValueChanged<FieldDefinition> onSort;
  final bool leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sorted = sort?.fieldId == field.id;
    final color = sorted ? scheme.onSurface : scheme.onSurfaceVariant;
    final numeric = isNumericField(field);
    final label = Flexible(
      child: Text(
        field.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelLarge?.copyWith(
          color: color,
          fontWeight: sorted ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
    );
    final arrow = sorted
        ? Icon(
            sort!.ascending ? Icons.arrow_upward : Icons.arrow_downward,
            size: 16,
            color: scheme.onSurface,
          )
        : null;
    final direction = sorted
        ? (sort!.ascending ? 'ascending' : 'descending')
        : null;
    return Semantics(
      button: true,
      label: 'Sort by ${field.name}',
      value: direction,
      excludeSemantics: true,
      child: InkWell(
        onTap: () => onSort(field),
        hoverColor: scheme.surfaceContainer,
        child: Padding(
          padding: leading
              ? const EdgeInsets.only(left: Spacing.md, right: Spacing.sm)
              : _cellPadding,
          child: Row(
            mainAxisAlignment: numeric
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              if (!numeric) ...[
                Icon(fieldTypeIcon(field), size: 16, color: scheme.outline),
                const SizedBox(width: Spacing.xxs),
              ],
              label,
              if (arrow != null) ...[const SizedBox(width: Spacing.xxs), arrow],
            ],
          ),
        ),
      ),
    );
  }
}

class _ObjectRow extends StatefulWidget {
  const _ObjectRow({
    super.key,
    required this.layout,
    required this.object,
    required this.view,
    required this.collection,
    required this.referenceLabels,
    required this.onOpen,
  });

  final _TableLayout layout;
  final MorkvaObject object;
  final ViewDefinition view;
  final Collection collection;
  final Map<String, String> referenceLabels;
  final VoidCallback onOpen;

  @override
  State<_ObjectRow> createState() => _ObjectRowState();
}

class _ObjectRowState extends State<_ObjectRow> {
  bool _hovered = false;
  bool _focused = false;

  FieldValue _value(FieldDefinition f) => widget.object[f.id] ?? f.emptyValue();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final layout = widget.layout;
    final titleValue = _value(layout.titleField);
    final titleText = formatFieldValue(
      layout.titleField,
      titleValue,
      referenceLabels: widget.referenceLabels,
    );
    final untitled = titleText.trim().isEmpty;
    final background = _hovered || _focused
        ? scheme.surfaceContainerLow
        : scheme.surfaceContainerLowest;

    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      onShowHoverHighlight: (v) => setState(() => _hovered = v),
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onOpen();
            return null;
          },
        ),
      },
      child: Semantics(
        button: true,
        label: untitled ? 'Untitled' : titleText,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onOpen,
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
            ),
            child: _PinnedRow(
              layout: layout,
              height: ViewTable.rowHeight,
              background: background,
              focused: _focused,
              title: Padding(
                padding: const EdgeInsets.only(
                  left: Spacing.md,
                  right: Spacing.sm,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    untitled ? 'Untitled' : titleText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: untitled ? scheme.outline : scheme.onSurface,
                    ),
                  ),
                ),
              ),
              cells: [for (final f in layout.columns) _cell(context, f)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cell(BuildContext context, FieldDefinition field) {
    final theme = Theme.of(context);
    final value = _value(field);
    final Widget? content = switch ((field, value)) {
      _ when value.isEmpty => null,
      (
        SingleSelectFieldDefinition(),
        SingleSelectFieldValue(:final optionId),
      ) =>
        OptionPill(
          label: formatFieldValue(field, value),
          color: optionColor(field, optionId),
        ),
      (MultiSelectFieldDefinition(), MultiSelectFieldValue(:final optionIds)) =>
        Row(
          children: [
            Flexible(
              child: OptionPill(
                label: formatFieldValue(
                  field,
                  MultiSelectFieldValue([optionIds.first]),
                ),
                color: optionColor(field, optionIds.first),
              ),
            ),
            if (optionIds.length > 1) ...[
              const SizedBox(width: Spacing.xxs),
              Text(
                '+${optionIds.length - 1}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      (BooleanFieldDefinition(), BooleanFieldValue(value: true)) => Icon(
        Icons.check_rounded,
        size: 20,
        color: theme.colorScheme.primary,
        semanticLabel: 'Yes',
      ),
      (BooleanFieldDefinition(), _) => null,
      _ => Text(
        formatFieldValue(field, value, referenceLabels: widget.referenceLabels),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: isNumericField(field) ? TextAlign.end : TextAlign.start,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontFeatures: isMetricField(field) ? _tabular : null,
        ),
      ),
    };
    return Padding(
      padding: _cellPadding,
      child: Align(
        alignment: isNumericField(field)
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: content,
      ),
    );
  }
}

/// The trailing `+ New <item>` row; with no objects it also offers
/// "Change fields".
class _GhostRow extends StatelessWidget {
  const _GhostRow({
    required this.layout,
    required this.label,
    required this.onAdd,
    this.onChangeFields,
  });

  final _TableLayout layout;
  final String label;
  final VoidCallback onAdd;
  final VoidCallback? onChangeFields;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final link =
        theme.extension<MorkvaSemanticColors>()?.primaryText ?? scheme.primary;
    return Material(
      type: MaterialType.transparency,
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onAdd,
              hoverColor: scheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                child: ListenableBuilder(
                  listenable: layout.horizontal,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(
                      layout.horizontal.hasClients
                          ? layout.horizontal.offset.clamp(0.0, double.infinity)
                          : 0,
                      0,
                    ),
                    child: child,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.add, size: 20, color: link),
                      const SizedBox(width: Spacing.xs),
                      Text(
                        label,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: link,
                        ),
                      ),
                      if (onChangeFields case final onTap?) ...[
                        const SizedBox(width: Spacing.md),
                        TextButton.icon(
                          onPressed: onTap,
                          icon: const Icon(
                            Icons.view_column_outlined,
                            size: 18,
                          ),
                          label: const Text('Change fields'),
                          style: TextButton.styleFrom(
                            foregroundColor: scheme.onSurfaceVariant,
                            minimumSize: const Size(44, 44),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.text});

  static const double height = 40;

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          fontFeatures: _tabular,
        ),
      ),
    );
  }
}
