import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/domain.dart';
import '../../../design/design.dart';
import 'collection_card.dart';
import 'collections_list_cubit.dart';
import 'collections_list_state.dart';
import 'create_collection_dialog.dart';

/// The collections surface — the Home body.
///
/// Renders the [CollectionsListCubit] over its three states: a calm centered
/// loading state, a friendly error retry surface, and the populated workspace
/// (a responsive grid on wide screens, a single column on narrow ones). The
/// empty workspace reuses the shared [EmptyState] with the primary "New
/// collection" call-to-action.
///
/// All mutations route through the cubit; navigation to an editor uses
/// go_router (`/collections/:id`). The widget is otherwise dumb.
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
          CollectionsListLoading() => const LoadingIndicator(
            message: 'Loading your collections…',
          ),
          CollectionsListError(:final message) => _ErrorState(message: message),
          CollectionsListReady(:final collections) =>
            collections.isEmpty
                ? _EmptyCollections(onCreate: () => _create(context))
                : _CollectionsContent(collections: collections),
        };
      },
    );
  }

  static Future<void> _create(BuildContext context) async {
    final cubit = context.read<CollectionsListCubit>();
    final router = GoRouter.of(context);
    final result = await CollectionFormDialog.create(context);
    if (result == null || !context.mounted) return;
    final id = await cubit.createCollection(
      result.name,
      description: result.description,
    );
    router.go('/collections/$id');
  }
}

/// The populated state: a header row with the create CTA, then the responsive
/// collection grid/list.
class _CollectionsContent extends StatelessWidget {
  const _CollectionsContent({required this.collections});

  final List<Collection> collections;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide =
            constraints.maxWidth >= CollectionsListView._gridBreakpoint;
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.lg,
                Spacing.lg,
                Spacing.lg,
                Spacing.sm,
              ),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${collections.length} '
                        '${collections.length == 1 ? 'collection' : 'collections'}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    PrimaryButton(
                      label: 'New collection',
                      icon: Icons.add,
                      onPressed: () => CollectionsListView._create(context),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.lg,
                Spacing.xs,
                Spacing.lg,
                Spacing.xxl,
              ),
              sliver: isWide
                  ? SliverGrid(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: CollectionsListView._maxCardExtent,
                        mainAxisSpacing: Spacing.md,
                        crossAxisSpacing: Spacing.md,
                        // A relaxed aspect so descriptions and the field-count
                        // footer breathe without clipping.
                        mainAxisExtent: 164,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _card(context, collections[index]),
                        childCount: collections.length,
                      ),
                    )
                  : SliverList.separated(
                      itemCount: collections.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: Spacing.sm),
                      itemBuilder: (context, index) =>
                          _card(context, collections[index]),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _card(BuildContext context, Collection collection) {
    return CollectionCard(
      collection: collection,
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
      case CollectionCardAction.rename:
        final result = await CollectionFormDialog.rename(
          context,
          name: collection.name,
          description: collection.description,
        );
        if (result == null || !context.mounted) return;
        await cubit.renameCollection(
          collection.id,
          result.name,
          description: result.description,
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
      title: 'Delete collection?',
      message:
          'This permanently deletes "$name" and its schema. '
          'Objects in it are no longer reachable. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
  }
}

/// The empty workspace: teaches what a collection is and invites the first one.
class _EmptyCollections extends StatelessWidget {
  const _EmptyCollections({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.dashboard_customize_outlined,
      title: 'No collections yet',
      message:
          'Collections hold your cards — orders, clients, inventory, anything. '
          'Create your first one to start organizing your work.',
      actionLabel: 'New collection',
      onAction: onCreate,
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
      icon: Icons.cloud_off_outlined,
      title: "Couldn't load collections",
      message: message,
      action: SecondaryButton(
        label: 'Retry',
        icon: Icons.refresh,
        onPressed: () => context.read<CollectionsListCubit>().initialize(),
      ),
    );
  }
}
