import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../bloc/chat_item.dart';
import '../../../../core/agent/agent_event.dart' show PresentKind;
import '../../../../l10n/l10n.dart';
import 'assistant_scope.dart';
import 'chip_button.dart';
import 'dashed_border.dart';

/// A bar or line chart drawn without a chart dependency: the peak labelled,
/// a partial period (the current month) dashed, then "Show as table" (the
/// accessible fallback) and "Save as a view".
class ResultChartCard extends StatefulWidget {
  const ResultChartCard({super.key, required this.item, this.collectionName});

  final ChartItem item;

  /// The chart's collection name when known ("Save as a view on Orders").
  final String? collectionName;

  @override
  State<ResultChartCard> createState() => _ResultChartCardState();
}

class _ResultChartCardState extends State<ResultChartCard> {
  bool _asTable = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AssistantColors.of(context);
    final scope = AssistantScope.of(context);
    final chart = widget.item.chart;
    final name = widget.collectionName;

    final card = Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
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
                  widget.item.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (chart != null) ...[
                const SizedBox(width: Spacing.xs),
                Text(chart.metricLabel, style: theme.textTheme.bodySmall),
              ],
            ],
          ),
          const SizedBox(height: 10),
          if (chart == null)
            const SkeletonBox(width: double.infinity, height: 170)
          else if (chart.points.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.md),
              child: Text(
                context.l10n.assistantNoChartData,
                style: theme.textTheme.bodySmall,
              ),
            )
          else if (_asTable)
            _PointsTable(chart: chart)
          else if (widget.item.kind == PresentKind.line)
            _LineChart(chart: chart, colors: colors)
          else
            _BarChart(chart: chart, colors: colors),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        card,
        if (chart != null && chart.points.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: Spacing.xs,
              children: [
                ChipButton(
                  label: _asTable
                      ? context.l10n.assistantShowAsChart
                      : context.l10n.assistantShowAsTable,
                  onPressed: () => setState(() => _asTable = !_asTable),
                ),
                if (name != null)
                  ChipButton(
                    label: context.l10n.assistantSaveAsView(name),
                    onPressed: () => scope.actions.suggest(
                      context.l10n.assistantSaveAsViewPrompt(
                        widget.item.title,
                        name,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// "48.2k" for the peak label.
String compactNumber(double value) {
  final abs = value.abs();
  String trim(double v) {
    final s = v.toStringAsFixed(1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  if (abs >= 1e6) return '${trim(value / 1e6)}M';
  if (abs >= 1e3) return '${trim(value / 1e3)}k';
  return trim(value);
}

/// "48 200" (thin-grouped, as the app prints amounts).
String groupedNumber(double value) {
  final rounded = value.roundToDouble() == value
      ? value.toInt().toString()
      : value.toStringAsFixed(2);
  final parts = rounded.split('.');
  final digits = parts[0].replaceFirst('-', '');
  final grouped = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(' ');
    grouped.write(digits[i]);
  }
  final sign = value < 0 ? '-' : '';
  return parts.length > 1 ? '$sign$grouped.${parts[1]}' : '$sign$grouped';
}

/// The largest value, or null when no point has one.
double? _maxValue(List<ChartPoint> points) {
  double? max;
  for (final p in points) {
    final v = p.value;
    if (v != null && (max == null || v > max)) max = v;
  }
  return max;
}

/// The single highest point, or null when there is none or the top is tied
/// (no bar is singled out then).
int? _peakIndex(List<ChartPoint> points) {
  final max = _maxValue(points);
  if (max == null) return null;
  final top = [
    for (var i = 0; i < points.length; i++)
      if (points[i].value == max) i,
  ];
  return top.length == 1 ? top.single : null;
}

String _chartSemantics(
  AppLocalizations l10n,
  ResultChart chart,
  String kind,
) {
  final peak = _peakIndex(chart.points);
  final first = chart.points.first.label;
  final last = chart.points.last.label;
  final peakText = peak == null
      ? ''
      : l10n.assistantChartPeak(
          chart.points[peak].label,
          groupedNumber(chart.points[peak].value!),
        );
  final labels = chart.points.length > 12
      ? ''
      : ': ${chart.points.map((p) => p.label).join(', ')}';
  return l10n.assistantChartSemantics(
    kind,
    chart.metricLabel,
    first,
    last,
    '$peakText$labels',
  );
}

class _BarChart extends StatelessWidget {
  const _BarChart({required this.chart, required this.colors});

  final ResultChart chart;
  final AssistantColors colors;

  static const _plot = 130.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final points = chart.points;
    final peak = _peakIndex(points);
    final max = _maxValue(points) ?? 0.0;
    final valueStyle = theme.textTheme.labelSmall?.copyWith(
      fontSize: 10,
      letterSpacing: 0,
    );

    return Semantics(
      image: true,
      label: _chartSemantics(context.l10n, chart, 'bar'),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 170,
              padding: const EdgeInsets.only(top: 18),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: scheme.outlineVariant),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < points.length; i++) ...[
                    if (i > 0) const SizedBox(width: Spacing.xs),
                    Expanded(
                      child: _Bar(
                        point: points[i],
                        height: max <= 0
                            ? 0
                            : (math.max(0, points[i].value ?? 0) / max) * _plot,
                        peak: i == peak,
                        colors: colors,
                        valueStyle: valueStyle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: Spacing.xs),
            _AxisLabels(points: points),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.point,
    required this.height,
    required this.peak,
    required this.colors,
    required this.valueStyle,
  });

  final ChartPoint point;
  final double height;
  final bool peak;
  final AssistantColors colors;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.vertical(
      top: Radius.circular(6),
      bottom: Radius.circular(2),
    );
    final label = peak
        ? compactNumber(point.value!)
        : point.partial
        ? context.l10n.assistantSoFar
        : null;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: valueStyle?.copyWith(
                color: peak ? colors.objectChipText : null,
              ),
            ),
          ),
        if (point.partial)
          DashedBorder(
            color: colors.objectChipText,
            borderRadius: radius,
            strokeWidth: 2,
            child: SizedBox(width: double.infinity, height: height),
          )
        else
          Container(
            width: double.infinity,
            height: height,
            decoration: BoxDecoration(
              color: peak ? colors.peakBar : colors.bar,
              borderRadius: radius,
            ),
          ),
      ],
    );
  }
}

class _AxisLabels extends StatelessWidget {
  const _AxisLabels({required this.points});

  final List<ChartPoint> points;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11);
    return Row(
      children: [
        for (var i = 0; i < points.length; i++) ...[
          if (i > 0) const SizedBox(width: Spacing.xs),
          Expanded(
            // A multi-word label wraps once at a space, then ellipsizes; a
            // single word ellipsizes on one line rather than breaking
            // mid-word ("Ordere / d"). Hover shows it whole.
            child: Tooltip(
              message: points[i].label,
              child: Text(
                points[i].label,
                textAlign: TextAlign.center,
                maxLines: points[i].label.trim().contains(' ') ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _LineChart extends StatelessWidget {
  const _LineChart({required this.chart, required this.colors});

  final ResultChart chart;
  final AssistantColors colors;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      image: true,
      label: _chartSemantics(context.l10n, chart, 'line'),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 170,
              padding: const EdgeInsets.only(top: 18),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: scheme.outlineVariant),
                ),
              ),
              child: CustomPaint(
                painter: _LinePainter(
                  chart.points,
                  line: colors.peakBar,
                  partial: colors.objectChipText,
                  labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    letterSpacing: 0,
                    color: colors.objectChipText,
                  ),
                ),
              ),
            ),
            const SizedBox(height: Spacing.xs),
            _AxisLabels(points: chart.points),
          ],
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter(
    this.points, {
    required this.line,
    required this.partial,
    required this.labelStyle,
  });

  final List<ChartPoint> points;
  final Color line;
  final Color partial;
  final TextStyle? labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final max = _maxValue(points);
    if (max == null) return;
    final peak = _peakIndex(points);
    // Points sit at the centres of the axis label slots (gap 8 between).
    const gap = Spacing.xs;
    final slot = (size.width - gap * (points.length - 1)) / points.length;
    Offset at(int i) => Offset(
      i * (slot + gap) + slot / 2,
      size.height -
          (max <= 0
              ? 0
              : (math.max(0, points[i].value!) / max) * (size.height - 4)),
    );

    final solid = Paint()
      ..color = line
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final dashed = Paint()
      ..color = partial
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    int? prev;
    for (var i = 0; i < points.length; i++) {
      if (points[i].value == null) {
        prev = null;
        continue;
      }
      if (prev != null) {
        final a = at(prev);
        final b = at(i);
        if (points[i].partial) {
          _dash(canvas, a, b, dashed);
        } else {
          canvas.drawLine(a, b, solid);
        }
      }
      canvas.drawCircle(
        at(i),
        3,
        Paint()..color = points[i].partial ? partial : line,
      );
      prev = i;
    }

    if (peak == null) return;
    final tp = TextPainter(
      text: TextSpan(text: compactNumber(max), style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final p = at(peak);
    tp.paint(canvas, Offset(p.dx - tp.width / 2, p.dy - tp.height - 6));
  }

  void _dash(Canvas canvas, Offset a, Offset b, Paint paint) {
    final total = (b - a).distance;
    final dir = (b - a) / total;
    for (var d = 0.0; d < total; d += 7) {
      canvas.drawLine(a + dir * d, a + dir * math.min(d + 4, total), paint);
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.points != points || old.line != line || old.partial != partial;
}

class _PointsTable extends StatelessWidget {
  const _PointsTable({required this.chart});

  final ResultChart chart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AssistantColors.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(fontSize: 13);
    return Table(
      columnWidths: const {0: FlexColumnWidth(), 1: IntrinsicColumnWidth()},
      children: [
        for (final p in chart.points)
          TableRow(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.divider)),
            ),
            children: [
              SizedBox(
                height: 36,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    p.partial ? context.l10n.assistantPointSoFar(p.label) : p.label,
                    style: style,
                  ),
                ),
              ),
              SizedBox(
                height: 36,
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(
                    p.value == null ? '—' : groupedNumber(p.value!),
                    style: style == null
                        ? null
                        : MorkvaTypography.tabular(style),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
