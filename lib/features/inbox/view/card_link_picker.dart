import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../api/data/data_repository.dart';
import '../../../app/shell/app_shell.dart';
import '../../../core/domain/domain.dart';
import '../../../core/domain/inbox/inbox.dart';
import '../../../design/design.dart';
import '../../../l10n/l10n.dart';
import '../../objects/value_editors/field_value_editor.dart'
    show ReferenceChoices;
import 'inbox_link_chip.dart' show CollectionsWatcher;

/// Picks a card to link in two steps: a collection (searchable), then one
/// of its cards (searchable). Resolves to the link with the card's label,
/// or null when dismissed. A dialog on wide screens, a root bottom sheet on
/// phones.
Future<InboxLink?> showCardLinkPicker(BuildContext context) {
  const picker = CardLinkPicker();
  if (MediaQuery.sizeOf(context).width >= AppShell.expandedBreakpoint) {
    return showDialog<InboxLink>(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => Dialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(borderRadius: Radii.fullAll),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
          child: picker,
        ),
      ),
    );
  }
  return showModalBottomSheet<InboxLink>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: picker,
      ),
    ),
  );
}

/// The picker's body (see [showCardLinkPicker]).
class CardLinkPicker extends StatefulWidget {
  const CardLinkPicker({super.key});

  @override
  State<CardLinkPicker> createState() => _CardLinkPickerState();
}

class _CardLinkPickerState extends State<CardLinkPicker> {
  Collection? _collection;
  Future<ReferenceChoices>? _cards;
  String _query = '';

  void _choose(Collection collection) => setState(() {
    _collection = collection;
    _query = '';
    _cards = context
        .read<DataRepository>()
        .getObjects(collection.id, schema: collection)
        .then(
          (objects) => ReferenceChoices.fromObjects(
            targets: [collection],
            objects: {collection.id: objects},
          ),
        );
  });

  void _back() => setState(() {
    _collection = null;
    _cards = null;
    _query = '';
  });

  @override
  Widget build(BuildContext context) {
    final collection = _collection;
    // Hugs its content (the dialog grows up to its max height); the
    // stretch keeps both steps the dialog's full width.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(collection: collection, onBack: _back),
        Flexible(
          child: collection == null
              ? CollectionsWatcher(
                  builder: (context, byId) => _collections(byId?.values),
                  errorBuilder: (context, retry) => _Notice(
                    context.l10n.inboxCollectionsLoadFailed,
                    onRetry: retry,
                  ),
                )
              : FutureBuilder(
                  future: _cards,
                  builder: (context, snap) => switch (snap) {
                    AsyncSnapshot(:final data?) => _cardList(collection, data),
                    AsyncSnapshot(hasError: true) => _Notice(
                      context.l10n.inboxCardsLoadFailed,
                    ),
                    _ => const _Loading(),
                  },
                ),
        ),
      ],
    );
  }

  Widget _search({required String hint, String? suffix}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    OutlineInputBorder stadium(BorderSide side) =>
        OutlineInputBorder(borderRadius: Radii.fullAll, borderSide: side);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.sm),
      // A stadium field, as the mockup (no shared stadium search exists).
      child: Theme(
        data: theme.copyWith(
          inputDecorationTheme: theme.inputDecorationTheme.copyWith(
            border: stadium(BorderSide(color: scheme.outline)),
            enabledBorder: stadium(BorderSide(color: scheme.outline)),
            focusedBorder: stadium(BorderSide(color: scheme.primary, width: 2)),
          ),
        ),
        child: MorkvaTextField(
          // A new field per step, so the query resets.
          key: ValueKey(_collection?.id),
          autofocus: true,
          hint: hint,
          prefixIcon: const Icon(Icons.search),
          suffixText: suffix,
          textInputAction: TextInputAction.search,
          onChanged: (text) => setState(() => _query = text),
        ),
      ),
    );
  }

  Widget _collections(Iterable<Collection>? all) {
    if (all == null) return const _Loading();
    final l10n = context.l10n;
    final q = _query.trim().toLowerCase();
    final rows = [
      for (final c in all)
        if (q.isEmpty || c.name.toLowerCase().contains(q)) c,
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _search(hint: l10n.inboxSearchCollections),
        Flexible(
          child: rows.isEmpty
              ? _Notice(
                  all.isEmpty
                      ? l10n.inboxNoCollections
                      : l10n.inboxNoCollectionsMatch(_query.trim()),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(
                    Spacing.sm,
                    0,
                    Spacing.sm,
                    Spacing.md,
                  ),
                  itemCount: rows.length,
                  itemBuilder: (context, i) {
                    final c = rows[i];
                    return _Row(
                      leading: CollectionGlyph(
                        iconKey: c.icon,
                        tintSeed: c.id,
                        size: 36,
                        iconSize: 20,
                      ),
                      title: c.name,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _choose(c),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _cardList(Collection collection, ReferenceChoices choices) {
    final l10n = context.l10n;
    final labels = choices.labels[collection.id] ?? const {};
    final q = _query.trim().toLowerCase();
    final rows = [
      for (final e in labels.entries)
        if (q.isEmpty || e.value.toLowerCase().contains(q)) e,
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _search(
          hint: l10n.inboxSearchIn(collection.name.toLowerCase()),
          suffix: q.isEmpty
              ? null
              : l10n.inboxShownOf(rows.length, labels.length),
        ),
        Flexible(
          child: rows.isEmpty
              ? _Notice(
                  labels.isEmpty
                      ? l10n.inboxCollectionNoCards(collection.name)
                      : l10n.inboxNoCardsMatch(_query.trim()),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(
                    Spacing.sm,
                    0,
                    Spacing.sm,
                    Spacing.md,
                  ),
                  itemCount: rows.length,
                  itemBuilder: (context, i) {
                    final MapEntry(key: id, value: label) = rows[i];
                    return _Row(
                      title: label,
                      subtitle: choices.secondaryOf(id),
                      onTap: () => Navigator.of(context).pop(
                        InboxLink.toCard(
                          collectionId: collection.id,
                          cardId: id,
                          label: label,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.collection, required this.onBack});

  final Collection? collection;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final c = collection;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.sm,
        Spacing.md,
        Spacing.sm,
        Spacing.sm,
      ),
      child: Row(
        children: [
          if (c == null)
            const SizedBox(width: Spacing.sm)
          else ...[
            IconButton(
              tooltip: l10n.inboxBackToCollections,
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
            ),
            CollectionGlyph(iconKey: c.icon, tintSeed: c.id, size: 36),
            const SizedBox(width: Spacing.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c?.name ?? l10n.inboxLinkCard,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall,
                ),
                Text(
                  c == null
                      ? l10n.inboxLinkStepCollection
                      : l10n.inboxLinkStepCard,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.commonClose,
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
  });

  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: Radii.mdAll,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
          child: Row(
            children: [
              if (leading case final l?) ...[
                l,
                const SizedBox(width: Spacing.sm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle case final s?)
                      Text(
                        s,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing case final t?)
                IconTheme.merge(
                  data: IconThemeData(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  child: t,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A spinner that keeps the hugging dialog short while loading.
class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(Spacing.xl),
    child: Center(heightFactor: 1, child: LoadingIndicator()),
  );
}

class _Notice extends StatelessWidget {
  const _Notice(this.text, {this.onRetry});

  final String text;

  /// Adds a Retry button under the text.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(Spacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (onRetry case final retry?) ...[
            const SizedBox(height: Spacing.sm),
            TextActionButton(label: context.l10n.commonRetry, onPressed: retry),
          ],
        ],
      ),
    );
  }
}
