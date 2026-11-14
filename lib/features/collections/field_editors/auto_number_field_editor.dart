import 'package:flutter/material.dart';

import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import '../../../l10n/l10n.dart';
import 'field_editor.dart';
import 'widgets/config_controls.dart';
import 'widgets/preview_affordances.dart';

/// [FieldEditor] for the auto-number field type.
///
/// Numbers are handed out when an item is first saved; this configures where
/// they start and how they read.
class AutoNumberFieldEditor extends FieldEditor {
  const AutoNumberFieldEditor();

  @override
  String get typeId => kAutoNumberFieldType;

  @override
  String label(AppLocalizations l10n) => l10n.collectionsTypeAutoNumber;

  @override
  String description(AppLocalizations l10n) =>
      l10n.collectionsTypeAutoNumberDescription;

  @override
  IconData get icon => MorkvaIcons.hashtag;

  @override
  bool get isComputed => true;

  @override
  FieldDefinition createDefault({required String id, required String name}) =>
      AutoNumberFieldDefinition(id: id, name: name);

  @override
  Widget buildConfigEditor(
    BuildContext context,
    FieldDefinition definition,
    ValueChanged<FieldDefinition> onChanged, {
    required List<Collection> collections,
    required String editingCollectionId,
  }) {
    final field = definition as AutoNumberFieldDefinition;

    AutoNumberFieldDefinition update({
      String? Function()? prefix,
      int? Function()? padding,
      int? start,
    }) => AutoNumberFieldDefinition(
      id: field.id,
      name: field.name,
      description: field.description,
      isRequired: field.isRequired,
      prefix: prefix == null ? field.prefix : prefix(),
      padding: padding == null ? field.padding : padding(),
      start: start ?? field.start,
    );

    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final next = formatFieldValue(field, AutoNumberFieldValue(field.start));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConfigTextField(
          label: l10n.collectionsStartAt,
          hint: '1',
          value: field.start == 1 ? '' : '${field.start}',
          keyboardType: TextInputType.number,
          onChanged: (text) {
            final n = parseOptionalInt(text);
            onChanged(update(start: n == null || n < 0 ? 1 : n));
          },
        ),
        ConfigTextField(
          label: l10n.collectionsPrefix,
          hint: l10n.collectionsPrefixHint,
          value: field.prefix ?? '',
          onChanged: (text) =>
              onChanged(update(prefix: () => text.isEmpty ? null : text)),
        ),
        ConfigTextField(
          label: l10n.collectionsDigits,
          hint: l10n.collectionsDigitsHint,
          value: field.padding?.toString() ?? '',
          keyboardType: TextInputType.number,
          onChanged: (text) =>
              onChanged(update(padding: () => parseOptionalInt(text))),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(Spacing.md),
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: Radii.mdAll,
          ),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '${l10n.collectionsFirstNumber}  '),
                TextSpan(
                  text: next,
                  style: MorkvaTypography.tabular(
                    (theme.textTheme.titleMedium ?? const TextStyle()).copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: Spacing.xs),
        Text(
          l10n.collectionsAutoNumberNote,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  @override
  String summarize(
    AppLocalizations l10n,
    FieldDefinition definition, {
    List<Collection> collections = const [],
  }) {
    final field = definition as AutoNumberFieldDefinition;
    final parts = <String>[
      if (field.prefix != null) field.prefix!,
      if (field.padding case final digits?)
        l10n.collectionsSummaryDigits(digits),
      if (field.start != 1) l10n.collectionsSummaryFrom(field.start),
    ];
    return parts.isEmpty
        ? l10n.collectionsSummaryAuto
        : parts.join(' · ');
  }

  @override
  Widget buildPreviewAffordance(
    BuildContext context,
    FieldDefinition definition,
  ) => const PreviewStubInput(icon: MorkvaIcons.hashtag, height: 36);
}
