import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import '../../../l10n/l10n.dart';
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

/// The "Fields" block above the object form while the collection is still a
/// starter (see [isStarterSchema]): a heading and [FirstRunFields]. Empty
/// otherwise.
class FirstRunSection extends StatelessWidget {
  const FirstRunSection({
    super.key,
    required this.collection,
    required this.registry,
  });

  final Collection collection;
  final FieldEditorRegistry registry;

  @override
  Widget build(BuildContext context) {
    final starter = context.select<CollectionEditorCubit, bool>((c) {
      final s = c.state;
      return s is CollectionEditorReady && isStarterSchema(s.saved);
    });
    if (!starter) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.collectionsFields,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: Spacing.sm),
        FirstRunFields(collection: collection, registry: registry),
        const SizedBox(height: Spacing.sm),
      ],
    );
  }
}

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
    final l10n = context.l10n;
    final used = {for (final f in collection.fields) f.name.toLowerCase()};
    // itemLabelOf singularizes English names; other languages quote the name.
    final item = l10n.localeName == 'en'
        ? itemLabelOf(collection)
        : collection.name;

    return Container(
      key: const Key('first_run_card'),
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
            l10n.collectionsFirstRunQuestion(item),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: Spacing.xxs),
          Text(
            l10n.collectionsFirstRunHint,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              // Narrow (phone): one full-width row per chip instead of a
              // ragged wrap.
              final narrow = constraints.maxWidth < 420;
              // A chip centres its content in a forced width, so the label
              // itself is sized to make the chip span the row (52 = avatar,
              // paddings and border).
              Widget label(String text) => narrow
                  ? SizedBox(
                      width: constraints.maxWidth - 52,
                      child: Text(text, overflow: TextOverflow.ellipsis),
                    )
                  : Text(text);
              return Wrap(
                spacing: Spacing.xs,
                runSpacing: Spacing.xs,
                children: [
                  for (final s in _suggestions(l10n))
                    if (!used.contains(s.name.toLowerCase()))
                      ActionChip(
                        key: Key('suggest_${s.id}'),
                        avatar: Icon(s.icon, size: 18),
                        label: label('${s.name} · ${s.hint}'),
                        onPressed: () => _add(cubit, s),
                      ),
                  ActionChip(
                    key: const Key('suggest_custom'),
                    avatar: const Icon(Icons.add, size: 18),
                    label: label(l10n.collectionsCustomField),
                    onPressed: () async {
                      final typeId = await AddFieldSheet.show(
                        context,
                        editors: registry.all,
                      );
                      if (typeId != null) {
                        cubit.addField(
                          typeId,
                          label: registry.forType(typeId)?.label(l10n),
                        );
                      }
                    },
                  ),
                ],
              );
            },
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
    // Customer: no target is guessed; the new field stays selected so the
    // config panel asks for one.
  }
}

class _Suggestion {
  const _Suggestion(
    this.id,
    this.name,
    this.hint,
    this.typeId,
    this.icon, [
    this.options,
  ]);

  /// A stable English id for the chip's key.
  final String id;
  final String name;
  final String hint;
  final String typeId;
  final IconData icon;
  final List<String>? options;
}

List<_Suggestion> _suggestions(AppLocalizations l10n) => [
  _Suggestion(
    'Status',
    l10n.collectionsSuggestStatus,
    l10n.collectionsSuggestStatusHint,
    kSingleSelectFieldType,
    Icons.flag_outlined,
    [
      l10n.collectionsSuggestToDo,
      l10n.collectionsSuggestInProgress,
      l10n.collectionsSuggestDone,
    ],
  ),
  _Suggestion(
    'Due date',
    l10n.collectionsSuggestDueDate,
    l10n.collectionsSuggestDueDateHint,
    kDateFieldType,
    Icons.event_outlined,
  ),
  _Suggestion(
    'Amount',
    l10n.collectionsSuggestAmount,
    l10n.collectionsSuggestAmountHint,
    kNumberFieldType,
    Icons.pin_outlined,
  ),
  _Suggestion(
    'Customer',
    l10n.collectionsSuggestCustomer,
    l10n.collectionsSuggestCustomerHint,
    kReferenceFieldType,
    Icons.link,
  ),
  _Suggestion(
    'Notes',
    l10n.collectionsSuggestNotes,
    l10n.collectionsSuggestNotesHint,
    kTextFieldType,
    Icons.notes,
  ),
];
