import 'package:flutter/material.dart';

import '../../../core/domain/domain.dart';
import '../../../l10n/l10n.dart';
import 'field_editor.dart';
import 'widgets/config_controls.dart';
import 'widgets/preview_affordances.dart';
import 'package:morkva_crm/design/morkva_icons.dart';

/// [FieldEditor] for the file/attachment field type.
class FileFieldEditor extends FieldEditor {
  const FileFieldEditor();

  @override
  String get typeId => kFileFieldType;

  @override
  String label(AppLocalizations l10n) => l10n.collectionsTypeFile;

  @override
  String description(AppLocalizations l10n) =>
      l10n.collectionsTypeFileDescription;

  @override
  IconData get icon => MorkvaIcons.attach;

  @override
  FieldDefinition createDefault({required String id, required String name}) =>
      FileFieldDefinition(id: id, name: name);

  @override
  Widget buildConfigEditor(
    BuildContext context,
    FieldDefinition definition,
    ValueChanged<FieldDefinition> onChanged, {
    required List<Collection> collections,
    required String editingCollectionId,
  }) {
    final field = definition as FileFieldDefinition;

    FileFieldDefinition update({
      bool? multiple,
      List<String>? Function()? allowedExtensions,
    }) => FileFieldDefinition(
      id: field.id,
      name: field.name,
      description: field.description,
      isRequired: field.isRequired,
      multiple: multiple ?? field.multiple,
      allowedExtensions: allowedExtensions == null
          ? field.allowedExtensions
          : allowedExtensions(),
    );

    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConfigSwitch(
          label: l10n.collectionsAllowMultiple,
          subtitle: l10n.collectionsFileMultipleHint,
          value: field.multiple,
          onChanged: (value) => onChanged(update(multiple: value)),
        ),
        ConfigTextField(
          label: l10n.collectionsAllowedExtensions,
          hint: l10n.collectionsAllowedExtensionsHint,
          value: (field.allowedExtensions ?? const []).join(', '),
          onChanged: (text) => onChanged(
            update(allowedExtensions: () => _parseExtensions(text)),
          ),
        ),
      ],
    );
  }

  /// Parses a comma/space separated list of extensions into a lowercase,
  /// dot-stripped list; an empty result becomes null (any extension allowed).
  static List<String>? _parseExtensions(String text) {
    final parts = text
        .split(RegExp(r'[,\s]+'))
        .map((e) => e.trim().replaceAll('.', '').toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();
    return parts.isEmpty ? null : parts;
  }

  @override
  String summarize(
    AppLocalizations l10n,
    FieldDefinition definition, {
    List<Collection> collections = const [],
  }) {
    final field = definition as FileFieldDefinition;
    final parts = <String>[
      if (field.multiple) l10n.collectionsSummaryMultiple,
      if (field.allowedExtensions != null) field.allowedExtensions!.join('/'),
    ];
    return parts.join(' · ');
  }

  @override
  Widget buildPreviewAffordance(
    BuildContext context,
    FieldDefinition definition,
  ) => PreviewStubInput(
    icon: MorkvaIcons.attach,
    height: 36,
    hint: context.l10n.collectionsNoFile,
  );
}
