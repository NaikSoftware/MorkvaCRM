import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import '../../views/widgets/view_labels.dart';
import '../field_editors/field_editor.dart';
import 'add_field_sheet.dart';
import 'collection_editor_cubit.dart';
import 'collection_editor_state.dart';

/// Whether [saved] is still just a starting collection: no fields, or only the
/// pre-made "Name" text field.
bool isStarterSchema(Collection saved) =>
    saved.fields.isEmpty ||
    (saved.fields.length == 1 && saved.fields.first.type == kTextFieldType);

/// The Build › Fields guided empty state: "What do you track for each
/// `<item>`?" with one-tap typed suggestions and a "Custom field" fallback.
/// Chips add through [CollectionEditorCubit]; nothing is saved until Save.
class FirstRunFields extends StatelessWidget {
  const FirstRunFields({
    super.key,
    required this.collection,
    required this.registry,
  });

  /// The draft being edited.
  final Collection collection;
  final FieldEditorRegistry registry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cubit = context.read<CollectionEditorCubit>();
    final used = {for (final f in collection.fields) f.name.toLowerCase()};

    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.md),
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: Radii.mdAll,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What do you track for each ${itemLabelOf(collection)}?',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: Spacing.xxs),
          Text(
            'Tap to add — you can rename or tweak any field afterwards.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Wrap(
            spacing: Spacing.xs,
            runSpacing: Spacing.xs,
            children: [
              for (final s in _suggestions)
                if (!used.contains(s.name.toLowerCase()))
                  ActionChip(
                    key: Key('suggest_${s.name}'),
                    avatar: Icon(s.icon, size: 18),
                    label: Text('${s.name} · ${s.hint}'),
                    onPressed: () => _add(cubit, s),
                  ),
              ActionChip(
                key: const Key('suggest_custom'),
                avatar: const Icon(Icons.add, size: 18),
                label: const Text('Custom field'),
                onPressed: () async {
                  final typeId = await AddFieldSheet.show(
                    context,
                    editors: registry.all,
                  );
                  if (typeId != null) cubit.addField(typeId);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _add(CollectionEditorCubit cubit, _Suggestion s) {
    cubit.addField(s.typeId);
    final ready = cubit.state;
    if (ready is! CollectionEditorReady) return;
    final id = ready.selectedFieldId;
    if (id == null) return;
    cubit.updateFieldEnvelope(id, name: s.name);

    final options = s.options;
    if (options != null) {
      cubit.updateField(
        SingleSelectFieldDefinition(
          id: id,
          name: s.name,
          options: [
            for (final (i, label) in options.indexed)
              SelectOption(id: 'opt_${i + 1}', label: label),
          ],
        ),
      );
    }

    if (s.typeId == kReferenceFieldType) {
      // Never guess a target: pick an obvious one, otherwise leave the field
      // selected so the regular config panel asks for it.
      final target = ready.availableCollections
          .where((c) => c.id != collection.id && _targetName.hasMatch(c.name))
          .firstOrNull;
      if (target != null) {
        cubit.updateField(
          ReferenceFieldDefinition(
            id: id,
            name: s.name,
            targetCollectionId: target.id,
          ),
        );
      }
    }
  }
}

final _targetName = RegExp(
  'customer|client|compan|contact',
  caseSensitive: false,
);

class _Suggestion {
  const _Suggestion(
    this.name,
    this.hint,
    this.typeId,
    this.icon, [
    this.options,
  ]);
  final String name;
  final String hint;
  final String typeId;
  final IconData icon;
  final List<String>? options;
}

const _suggestions = [
  _Suggestion('Status', 'choice', kSingleSelectFieldType, Icons.flag_outlined, [
    'To do',
    'In progress',
    'Done',
  ]),
  _Suggestion('Due date', 'date', kDateFieldType, Icons.event_outlined),
  _Suggestion('Amount', 'number', kNumberFieldType, Icons.pin_outlined),
  _Suggestion('Customer', 'reference', kReferenceFieldType, Icons.link),
  _Suggestion('Notes', 'text', kTextFieldType, Icons.notes),
];
