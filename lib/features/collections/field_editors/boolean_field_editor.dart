import 'package:flutter/material.dart';

import '../../../core/domain/domain.dart';
import '../../../l10n/l10n.dart';
import 'field_editor.dart';
import 'widgets/preview_affordances.dart';

/// [FieldEditor] for the boolean (true/false) field type.
///
/// The boolean type carries no per-type config, so the config editor shows a
/// short explanatory note. Name / description / required are edited by the host
/// panel's common envelope.
class BooleanFieldEditor extends FieldEditor {
  const BooleanFieldEditor();

  @override
  String get typeId => kBooleanFieldType;

  @override
  String label(AppLocalizations l10n) => l10n.collectionsTypeBoolean;

  @override
  String description(AppLocalizations l10n) =>
      l10n.collectionsTypeBooleanDescription;

  @override
  IconData get icon => Icons.toggle_on_outlined;

  @override
  FieldDefinition createDefault({required String id, required String name}) =>
      BooleanFieldDefinition(id: id, name: name);

  @override
  Widget buildConfigEditor(
    BuildContext context,
    FieldDefinition definition,
    ValueChanged<FieldDefinition> onChanged, {
    required List<Collection> collections,
    required String editingCollectionId,
  }) {
    return Text(
      context.l10n.collectionsBooleanNoSettings,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  @override
  String summarize(
    AppLocalizations l10n,
    FieldDefinition definition, {
    List<Collection> collections = const [],
  }) => '';

  @override
  Widget buildPreviewAffordance(
    BuildContext context,
    FieldDefinition definition,
  ) => const PreviewStubSwitch();
}
