import 'package:flutter/material.dart';

import '../../../design/design.dart';

/// The result of the create / rename collection form: a trimmed [name], an
/// optional [description] (null when blank), and an optional [icon] key (null
/// for the default glyph).
typedef CollectionFormResult = ({String name, String? description, String? icon});

/// A polished dialog for naming a collection — used both to **create** a new
/// collection and to **rename** an existing one (the only difference is the
/// title, the confirm label, and the initial values).
///
/// Inline-validates an empty name (the one blocking rule) and returns a
/// [CollectionFormResult] on confirm, or null on cancel. It does not touch any
/// cubit itself — the caller decides what to do with the result — so the same
/// form serves both flows.
class CollectionFormDialog extends StatefulWidget {
  const CollectionFormDialog({
    super.key,
    required this.title,
    required this.confirmLabel,
    this.initialName = '',
    this.initialDescription,
    this.initialIcon,
  });

  /// Dialog headline (e.g. "New collection" / "Rename collection").
  final String title;

  /// Label for the primary confirm button (e.g. "Create" / "Save").
  final String confirmLabel;

  /// Pre-filled name (empty for create, the current name for rename).
  final String initialName;

  /// Pre-filled description, if any.
  final String? initialDescription;

  /// Pre-filled icon key, if any.
  final String? initialIcon;

  /// Opens the dialog for **creating** a collection.
  static Future<CollectionFormResult?> create(BuildContext context) {
    return showDialog<CollectionFormResult>(
      context: context,
      builder: (_) => const CollectionFormDialog(
        title: 'New collection',
        confirmLabel: 'Create',
      ),
    );
  }

  /// Opens the dialog for **renaming** a collection, pre-filled with [name],
  /// [description] and [icon].
  static Future<CollectionFormResult?> rename(
    BuildContext context, {
    required String name,
    String? description,
    String? icon,
  }) {
    return showDialog<CollectionFormResult>(
      context: context,
      builder: (_) => CollectionFormDialog(
        title: 'Rename collection',
        confirmLabel: 'Save',
        initialName: name,
        initialDescription: description,
        initialIcon: icon,
      ),
    );
  }

  @override
  State<CollectionFormDialog> createState() => _CollectionFormDialogState();
}

class _CollectionFormDialogState extends State<CollectionFormDialog> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.initialName,
  );
  late final TextEditingController _descriptionController =
      TextEditingController(text: widget.initialDescription ?? '');
  late String? _icon = widget.initialIcon;
  String? _nameError;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickIcon() async {
    final selection = await CollectionIconPicker.show(context, current: _icon);
    if (selection == null || !mounted) return;
    setState(() => _icon = selection.key);
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Give your collection a name');
      return;
    }
    final description = _descriptionController.text.trim();
    Navigator.of(context).pop<CollectionFormResult>((
      name: name,
      description: description.isEmpty ? null : description,
      icon: _icon,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      shape: const RoundedRectangleBorder(borderRadius: Radii.lgAll),
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title, style: theme.textTheme.titleLarge),
              const SizedBox(height: Spacing.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CollectionGlyph(
                    iconKey: _icon,
                    onTap: _pickIcon,
                    tooltip: 'Choose icon',
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: MorkvaTextField(
                      controller: _nameController,
                      label: 'Name',
                      hint: 'Orders, Clients, Inventory…',
                      autofocus: true,
                      errorText: _nameError,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) {
                        if (_nameError != null) {
                          setState(() => _nameError = null);
                        }
                      },
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.md),
              MorkvaTextField(
                controller: _descriptionController,
                label: 'Description',
                hint: 'Optional — what this collection holds',
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: Spacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextActionButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: Spacing.xs),
                  PrimaryButton(
                    label: widget.confirmLabel,
                    onPressed: _submit,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
