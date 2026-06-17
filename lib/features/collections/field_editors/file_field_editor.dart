import 'package:flutter/material.dart';

import '../../../core/domain/domain.dart';
import 'field_editor.dart';
import 'widgets/config_controls.dart';

/// [FieldEditor] for the file/attachment field type.
class FileFieldEditor extends FieldEditor {
  const FileFieldEditor();

  @override
  String get typeId => kFileFieldType;

  @override
  String get displayLabel => 'File';

  @override
  String get description => 'One or more file attachments.';

  @override
  IconData get icon => Icons.attach_file;

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConfigSwitch(
          label: 'Allow multiple',
          subtitle: 'Attach more than one file.',
          value: field.multiple,
          onChanged: (value) => onChanged(update(multiple: value)),
        ),
        ConfigTextField(
          label: 'Allowed extensions',
          hint: 'e.g. png, jpg, pdf — comma separated, blank for any',
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
  String summarize(FieldDefinition definition) {
    final field = definition as FileFieldDefinition;
    final parts = <String>[
      if (field.multiple) 'multiple',
      if (field.allowedExtensions != null) field.allowedExtensions!.join('/'),
    ];
    return parts.join(' · ');
  }
}
