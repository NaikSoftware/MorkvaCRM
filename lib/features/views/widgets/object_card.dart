import 'package:flutter/material.dart';

import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import 'option_pill.dart';
import 'view_labels.dart';

/// How dense an [ObjectCard] is drawn.
enum ObjectCardDensity {
  /// A board card: title, a top-right metric, quiet chips.
  board,

  /// A list row (56 px, 64 with a subtitle).
  list,

  /// A 24 px calendar pill.
  pill,
}

/// One object as a card, the same widget for every mode. Shows the view's
/// title field, then its other shown fields (empty ones skipped). The view's
/// layout field is not repeated (the board columns / list dots carry it).
class ObjectCard extends StatelessWidget {
  const ObjectCard({
    super.key,
    required this.object,
    required this.collection,
    required this.view,
    this.density = ObjectCardDensity.board,
    this.referenceLabels = const {},
    this.onTap,
  });

  final MorkvaObject object;
  final Collection collection;
  final ViewDefinition view;
  final ObjectCardDensity density;
  final Map<String, String> referenceLabels;
  final VoidCallback? onTap;

  static const _tabular = [FontFeature.tabularFigures()];

  @override
  Widget build(BuildContext context) {
    final title = titleOf(view, collection, object);
    final fields = [
      for (final id in view.fieldIds.skip(1))
        if (id != view.layoutFieldId)
          if (collection.fieldById(id) case final field?)
            if ((object[id] ?? field.emptyValue()).isNotEmpty) field,
    ];
    final metric = fields.where(isMetricField).firstOrNull;
    final rest = [
      for (final f in fields)
        if (f != metric) f,
    ];
    return switch (density) {
      ObjectCardDensity.board => _BoardCard(
        title: title,
        metric: metric == null ? null : _text(metric),
        chips: [for (final f in rest) _chip(context, f)],
        onTap: onTap,
      ),
      ObjectCardDensity.list => _ListRow(
        title: title,
        hasDot: _dotField() != null,
        dot: _selectColor(_dotField()),
        subtitle: rest.take(2).map(_text).join(' · '),
        trailing: metric == null ? null : _text(metric),
        onTap: onTap,
      ),
      ObjectCardDensity.pill => _Pill(
        title: title,
        accent: _layoutColor() ?? _firstSelectColor(),
        onTap: onTap,
      ),
    };
  }

  FieldValue _value(FieldDefinition f) => object[f.id] ?? f.emptyValue();

  String _text(FieldDefinition f) =>
      formatFieldValue(f, _value(f), referenceLabels: referenceLabels);

  Color? _selectColor(FieldDefinition? f) =>
      switch ((f, f == null ? null : _value(f))) {
        (
          final SingleSelectFieldDefinition f,
          SingleSelectFieldValue(:final optionId),
        ) =>
          optionColor(f, optionId),
        _ => null,
      };

  Color? _layoutColor() => _selectColor(
    view.layoutFieldId == null
        ? null
        : collection.fieldById(view.layoutFieldId!),
  );

  /// The select field a list row's dot shows: the layout field when it is
  /// one, else — on a date layout (the calendar agenda) — the first shown
  /// select field, like the calendar pills.
  SingleSelectFieldDefinition? _dotField() {
    final layout = view.layoutFieldId == null
        ? null
        : collection.fieldById(view.layoutFieldId!);
    return switch (layout) {
      final SingleSelectFieldDefinition f => f,
      DateFieldDefinition() =>
        view.fieldIds
            .map(collection.fieldById)
            .whereType<SingleSelectFieldDefinition>()
            .firstOrNull,
      _ => null,
    };
  }

  Color? _firstSelectColor() => _selectColor(
    view.fieldIds
        .map(collection.fieldById)
        .whereType<SingleSelectFieldDefinition>()
        .firstOrNull,
  );

  Widget _chip(BuildContext context, FieldDefinition f) {
    final value = _value(f);
    if (f is SingleSelectFieldDefinition && value is SingleSelectFieldValue) {
      return OptionPill(label: _text(f), color: optionColor(f, value.optionId));
    }
    final theme = Theme.of(context);
    final label = f is BooleanFieldDefinition ? f.name : _text(f);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.xs,
        vertical: Spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: Radii.smAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (f is BooleanFieldDefinition) ...[
            Icon(
              (value as BooleanFieldValue).value == true
                  ? Icons.check_circle_outline
                  : Icons.radio_button_unchecked,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: Spacing.xxs),
          ],
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  // A bare number says nothing on its own: lead with the field name.
                  if (isNumericField(f))
                    TextSpan(
                      text: '${f.name} ',
                      style: TextStyle(color: theme.colorScheme.outline),
                    ),
                  TextSpan(text: label),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontFeatures: ObjectCard._tabular,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BoardCard extends StatefulWidget {
  const _BoardCard({
    required this.title,
    required this.metric,
    required this.chips,
    required this.onTap,
  });

  final String title;
  final String? metric;
  final List<Widget> chips;
  final VoidCallback? onTap;

  @override
  State<_BoardCard> createState() => _BoardCardState();
}

class _BoardCardState extends State<_BoardCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: PressableScale(
        onPressed: widget.onTap,
        semanticLabel: widget.title,
        borderRadius: Radii.mdAll,
        child: AnimatedContainer(
          duration: reduceMotion ? MotionDurations.none : MotionDurations.fast,
          curve: MotionCurves.standard,
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: Spacing.sm,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            borderRadius: Radii.mdAll,
            boxShadow: _hovered
                ? MorkvaElevation.level2
                : MorkvaElevation.level1,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (widget.metric case final metric?) ...[
                    const SizedBox(width: Spacing.xs),
                    Text(
                      metric,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontFeatures: ObjectCard._tabular,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
              if (widget.chips.isNotEmpty) ...[
                const SizedBox(height: Spacing.xs),
                Wrap(
                  spacing: Spacing.xxs,
                  runSpacing: Spacing.xxs,
                  children: widget.chips,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.title,
    required this.hasDot,
    required this.dot,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  final String title;

  /// Whether rows of this view carry a dot; an empty value keeps the slot
  /// with a hollow ring so titles stay aligned.
  final bool hasDot;
  final Color? dot;
  final String subtitle;
  final String? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        hoverColor: scheme.surfaceContainerLow,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: subtitle.isEmpty ? 56 : 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
            child: Row(
              children: [
                if (hasDot) ...[
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: dot,
                      shape: BoxShape.circle,
                      border: dot == null
                          ? Border.all(color: scheme.outlineVariant, width: 1.5)
                          : null,
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                ],
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing case final text?) ...[
                  const SizedBox(width: Spacing.sm),
                  Text(
                    text,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontFeatures: ObjectCard._tabular,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.title, required this.accent, required this.onTap});

  final String title;
  final Color? accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return PressableScale(
      onPressed: onTap,
      semanticLabel: title,
      borderRadius: Radii.smAll,
      child: Container(
        height: 24,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: Radii.smAll,
        ),
        child: Row(
          children: [
            Container(width: 3, color: accent ?? scheme.primary),
            const SizedBox(width: Spacing.xxs),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
