import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shell/app_shell.dart';
import '../../../core/domain/domain.dart';
import '../../templates/template_picker.dart';
import '../../../design/design.dart';
import '../../../l10n/l10n.dart';
import '../pins/pinned_collections_cubit.dart';
import 'collection_card.dart';
import 'collections_list_cubit.dart';
import 'collections_list_state.dart';
import 'create_collection_dialog.dart';

/// The collections surface — the All collections page.
///
/// Renders the [CollectionsListCubit] over its three states: a calm centered
/// loading state, a friendly error retry surface, and the populated workspace
/// (a responsive grid on wide screens, a single column on narrow ones). The
/// empty workspace reuses the shared [EmptyState] with the primary "New
/// collection" call-to-action.
///
/// All mutations route through the cubit. A card opens the Work page
/// (`/collections/:id`); a new collection opens in its editor (`.../edit`).
class CollectionsListView extends StatelessWidget {
  const CollectionsListView({super.key});

  /// Width at/above which collections lay out as a multi-column grid.
  static const double _gridBreakpoint = 640;

  /// Target max card width; the grid fits as many columns as this allows.
  static const double _maxCardExtent = 320;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CollectionsListCubit, CollectionsListState>(
      builder: (context, state) {
        return switch (state) {
          CollectionsListLoading() => LoadingIndicator(
            message: context.l10n.collectionsLoading,
          ),
          CollectionsListError(:final message) => _ErrorState(message: message),
          CollectionsListReady(:final collections) =>
            collections.isEmpty
                ? _EmptyCollections(
                    onCreate: () => _create(context),
                    onTemplate: () => _fromTemplate(context),
                  )
                : _CollectionsContent(collections: collections),
        };
      },
    );
  }

  static Future<void> _create(BuildContext context) async {
    final cubit = context.read<CollectionsListCubit>();
    final router = GoRouter.of(context);
    final l10n = context.l10n;
    final result = await CollectionFormDialog.create(context);
    if (result == null || !context.mounted) return;
    final id = await cubit.createCollection(
      result.name,
      description: result.description,
      icon: result.icon,
      titleField: l10n.collectionsTitleFieldName,
    );
    router.go('/collections/$id/edit');
  }

  /// Picks a template and adds it; opens its first collection.
  static Future<void> _fromTemplate(BuildContext context) async {
    final cubit = context.read<CollectionsListCubit>();
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.l10n;
    String? first;
    final added = await showTemplatePicker(
      context,
      onAdd: (template) async => first = await cubit.importTemplate(template),
    );
    if (added == null || first == null) return;
    messenger?.showSnackBar(
      SnackBar(content: Text(l10n.collectionsTemplateAdded(added.name))),
    );
    router.go('/collections/$first');
  }
}

/// The populated state: the page header (title, count, create actions), then
/// the pinned collections and everything else as card grids. Finding a
/// collection by name is the shell's Jump to.
class _CollectionsContent extends StatelessWidget {
  const _CollectionsContent({required this.collections});

  final List<Collection> collections;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final pins = context.watch<PinnedCollectionsCubit>().state;
    final all = collections;
    final pinned = pinnedCollections(pins, all);
    final others = [
      for (final c in all)
        if (!pins.contains(c.id)) c,
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide =
            constraints.maxWidth >= CollectionsListView._gridBreakpoint;
        final gutter = isWide ? Spacing.xl : Spacing.md;
        // Below the shell's sidebar breakpoint its header carries the title.
        final ownTitle =
            MediaQuery.sizeOf(context).width >= AppShell.expandedBreakpoint;
        // Labelled buttons beside the title need room; else icon buttons.
        final labelled = constraints.maxWidth >= 760;
        final count = pinned.isEmpty
            ? l10n.collectionsCount(all.length)
            : ownTitle
            ? l10n.collectionsCountWithPinned(all.length, pinned.length)
            : l10n.collectionsCountWithPinnedShort(all.length, pinned.length);
        final countStyle = theme.textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        );

        Widget caption(String text, {IconData? icon}) => SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              gutter,
              Spacing.lg,
              gutter,
              Spacing.sm,
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: scheme.primary),
                  const SizedBox(width: Spacing.xs),
                ],
                Text(
                  text,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.9,
                  ),
                ),
              ],
            ),
          ),
        );

        Widget grid(List<Collection> items) => SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          sliver: SliverGrid(
            gridDelegate: isWide
                ? const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: CollectionsListView._maxCardExtent,
                    mainAxisSpacing: Spacing.md,
                    crossAxisSpacing: Spacing.md,
                    mainAxisExtent: CollectionCard.height,
                  )
                : const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: Spacing.sm,
                    crossAxisSpacing: Spacing.sm,
                    mainAxisExtent: CollectionCard.height,
                  ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _card(
                context,
                items[index],
                pinned: pins.contains(items[index].id),
              ),
              childCount: items.length,
            ),
          ),
        );

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                gutter,
                ownTitle ? Spacing.xl : Spacing.xxs,
                gutter,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: Row(
                  crossAxisAlignment: ownTitle
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: ownTitle
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.shellAllCollections,
                                  style: theme.textTheme.headlineMedium,
                                ),
                                const SizedBox(height: Spacing.xxs),
                                Text(count, style: countStyle),
                              ],
                            )
                          : Text(count, style: countStyle),
                    ),
                    const SizedBox(width: Spacing.xs),
                    if (labelled) ...[
                      SecondaryButton(
                        label: l10n.collectionsFromTemplate,
                        icon: MorkvaIcons.mosaic,
                        onPressed: () =>
                            CollectionsListView._fromTemplate(context),
                      ),
                      const SizedBox(width: Spacing.xs),
                      PrimaryButton(
                        label: l10n.collectionsNewCollection,
                        icon: MorkvaIcons.add,
                        onPressed: () => CollectionsListView._create(context),
                      ),
                    ] else ...[
                      IconButton.outlined(
                        tooltip: l10n.collectionsFromTemplate,
                        icon: const Icon(MorkvaIcons.mosaic),
                        onPressed: () =>
                            CollectionsListView._fromTemplate(context),
                      ),
                      const SizedBox(width: Spacing.sm),
                      IconButton.filled(
                        tooltip: l10n.collectionsNewCollection,
                        icon: const Icon(MorkvaIcons.add),
                        onPressed: () => CollectionsListView._create(context),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (pinned.isNotEmpty) ...[
              caption(l10n.shellPinnedHeader, icon: MorkvaIcons.pinFilled),
              grid(pinned),
            ],
            if (others.isNotEmpty) ...[
              caption(
                pinned.isEmpty
                    ? l10n.collectionsHeaderAll
                    : l10n.collectionsHeaderOthers,
              ),
              grid(others),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: Spacing.xxl)),
          ],
        );
      },
    );
  }

  Widget _card(
    BuildContext context,
    Collection collection, {
    required bool pinned,
  }) {
    return CollectionCard(
      collection: collection,
      pinned: pinned,
      onTogglePin: () =>
          context.read<PinnedCollectionsCubit>().toggle(collection.id),
      onOpen: () => context.go('/collections/${collection.id}'),
      onAction: (action) => _handleAction(context, collection, action),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    Collection collection,
    CollectionCardAction action,
  ) async {
    final cubit = context.read<CollectionsListCubit>();
    switch (action) {
      case CollectionCardAction.customize:
        context.go('/collections/${collection.id}/edit');
      case CollectionCardAction.rename:
        final result = await CollectionFormDialog.rename(
          context,
          name: collection.name,
          description: collection.description,
          icon: collection.icon,
        );
        if (result == null || !context.mounted) return;
        await cubit.renameCollection(
          collection.id,
          result.name,
          description: result.description,
          icon: result.icon,
        );
      case CollectionCardAction.delete:
        final confirmed = await _confirmDelete(context, collection.name);
        if (confirmed != true || !context.mounted) return;
        await cubit.deleteCollection(collection.id);
    }
  }

  Future<bool?> _confirmDelete(BuildContext context, String name) {
    return MorkvaConfirmDialog.show(
      context,
      title: context.l10n.collectionsDeleteTitle,
      message: context.l10n.collectionsDeleteMessage(name),
      confirmLabel: context.l10n.commonDelete,
      destructive: true,
    );
  }
}

/// The empty workspace: teaches what a collection is and invites the first one.
class _EmptyCollections extends StatelessWidget {
  const _EmptyCollections({required this.onCreate, required this.onTemplate});

  final VoidCallback onCreate;
  final VoidCallback onTemplate;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: MorkvaIcons.dashboard,
      title: context.l10n.collectionsEmptyTitle,
      message: context.l10n.collectionsEmptyMessage,
      action: Wrap(
        alignment: WrapAlignment.center,
        spacing: Spacing.xs,
        runSpacing: Spacing.xs,
        children: [
          SecondaryButton(
            label: context.l10n.collectionsStartFromTemplate,
            icon: MorkvaIcons.mosaic,
            onPressed: onTemplate,
          ),
          PrimaryButton(
            label: context.l10n.collectionsNewCollection,
            icon: MorkvaIcons.add,
            onPressed: onCreate,
          ),
        ],
      ),
    );
  }
}

/// A friendly, recoverable error surface for a failed collections stream.
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: MorkvaIcons.cloudOff,
      title: context.l10n.collectionsLoadErrorTitle,
      message: context.l10n.collectionsLoadFailed(message),
      action: SecondaryButton(
        label: context.l10n.commonRetry,
        icon: MorkvaIcons.refresh,
        onPressed: () => context.read<CollectionsListCubit>().initialize(),
      ),
    );
  }
}
