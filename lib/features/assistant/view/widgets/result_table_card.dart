import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../design/design.dart';
import '../../bloc/chat_item.dart';
import 'assistant_scope.dart';
import 'chip_button.dart';
import 'object_chip.dart';

/// A result table: the first column is an object chip linking to the card,
/// at most 6 columns (more than 4 scroll sideways inside the card), long
/// text ellipsized, an optional totals footer, then "Open as filtered view"
/// and "Copy table".
class ResultTableCard extends StatelessWidget {
  const ResultTableCard({super.key, required this.item});

  final TableItem item;

  static const _rowHeight = 44.0;

  @override
  Widget build(BuildContext context) {
    final scope = AssistantScope.of(context);
    final colors = AssistantColors.of(context);
    final theme = Theme.of(context);
    final table = item.table;

    final card = ClipRRect(
      borderRadius: BorderRadius.circular(14),
      // The border paints over the rows, so the totals fill never covers it.
      child: Container(
        decoration: BoxDecoration(
          color: colors.panel,
          borderRadius: BorderRadius.circular(14),
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: table == null
            ? const _TableSkeleton()
            : Semantics(
                container: true,
                label: item.title,
                child: _ResultTable(table: table, colors: colors),
              ),
      ),
    );

    final more = table != null && table.totalCount > table.rows.length
        ? 'Showing ${table.rows.length} of ${table.totalCount}'
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        card,
        if (more != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(more, style: theme.textTheme.bodySmall),
          ),
        if (table != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: Spacing.xs,
              children: [
                if (table.collectionId != null)
                  ChipButton(
                    label: 'Open as filtered view',
                    onPressed: () => scope.actions.openTable(item),
                  ),
                ChipButton(
                  label: 'Copy table',
                  onPressed: () => _copy(context, table),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _copy(BuildContext context, ResultTable table) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    await Clipboard.setData(ClipboardData(text: tableAsText(table)));
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Table copied')));
  }
}

/// [table] as tab-separated lines (header, rows, totals), built only when
/// "Copy table" is tapped.
String tableAsText(ResultTable table) {
  String line(Iterable<String> cells) =>
      cells.map((c) => c.replaceAll(RegExp(r'[\t\n\r]'), ' ')).join('\t');
  return [
    line(table.columns.map((c) => c.label)),
    for (final row in table.rows) line(row.cells),
    if (table.totals != null) line(table.totals!),
  ].join('\n');
}

class _ResultTable extends StatelessWidget {
  const _ResultTable({required this.table, required this.colors});

  final ResultTable table;
  final AssistantColors colors;

  @override
  Widget build(BuildContext context) {
    final columns = table.columns;
    final scroll = columns.length > 4;
    final widths = <int, TableColumnWidth>{
      for (var i = 0; i < columns.length; i++)
        i: !scroll && i == (columns.length == 1 ? 0 : 1)
            ? const FlexColumnWidth()
            : const IntrinsicColumnWidth(),
    };
    final totals = table.totals;
    final grid = Table(
      columnWidths: widths,
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        for (final row in table.rows)
          TableRow(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.divider)),
            ),
            children: [
              for (var i = 0; i < columns.length; i++)
                _cell(context, i, row, scroll: scroll),
            ],
          ),
        if (totals != null)
          TableRow(
            decoration: BoxDecoration(color: colors.canvas),
            children: [
              for (var i = 0; i < columns.length; i++)
                _pad(
                  i,
                  _text(
                    context,
                    i < totals.length ? totals[i] : '',
                    column: columns[i],
                    weight: FontWeight.w600,
                    muted: false,
                    scroll: scroll,
                  ),
                ),
            ],
          ),
      ],
    );
    if (!scroll) return grid;
    return SingleChildScrollView(scrollDirection: Axis.horizontal, child: grid);
  }

  Widget _cell(
    BuildContext context,
    int i,
    ResultRow row, {
    required bool scroll,
  }) {
    final value = i < row.cells.length ? row.cells[i] : '';
    final column = table.columns[i];
    if (i == 0 && row.cardId != null && table.collectionId != null) {
      final label = value.startsWith('#') ? value.substring(1) : value;
      return _pad(
        i,
        Align(
          alignment: AlignmentDirectional.centerStart,
          widthFactor: 1,
          child: ObjectChip(
            label: label,
            leading: const HashGlyph(),
            semanticLabel: 'Open ${column.label} $label',
            onTap: () => AssistantScope.of(context).actions.openObject(
              collectionId: table.collectionId!,
              cardId: row.cardId,
            ),
          ),
        ),
      );
    }
    return _pad(
      i,
      _text(
        context,
        value,
        column: column,
        weight: i == 1 ? FontWeight.w600 : FontWeight.w400,
        muted: i > 1 && !column.numeric,
        scroll: scroll,
      ),
    );
  }

  Widget _pad(int i, Widget child) => Padding(
    padding: EdgeInsetsDirectional.only(
      start: i == 0 ? 12 : 5,
      end: i == table.columns.length - 1 ? 12 : 5,
    ),
    child: SizedBox(
      height: ResultTableCard._rowHeight,
      child: Align(
        alignment: table.columns[i].numeric
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        widthFactor: 1,
        child: child,
      ),
    ),
  );

  Widget _text(
    BuildContext context,
    String value, {
    required ResultColumn column,
    required FontWeight weight,
    required bool muted,
    required bool scroll,
  }) {
    final scheme = Theme.of(context).colorScheme;
    var style = Theme.of(context).textTheme.bodyMedium!.copyWith(
      fontSize: 13,
      fontWeight: weight,
      color: muted ? scheme.onSurfaceVariant : scheme.onSurface,
    );
    if (column.numeric) style = MorkvaTypography.tabular(style);
    final text = Semantics(
      label: value.isEmpty ? null : '${column.label}: $value',
      excludeSemantics: true,
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        textAlign: column.numeric ? TextAlign.end : TextAlign.start,
        style: style,
      ),
    );
    // Intrinsic columns would grow to the longest text; cap them.
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: scroll ? 180 : 160),
      child: text,
    );
  }
}

class _TableSkeleton extends StatelessWidget {
  const _TableSkeleton();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == 2 ? 0 : 12),
            child: const SkeletonBox(width: double.infinity, height: 20),
          ),
      ],
    ),
  );
}
