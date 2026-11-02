import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../app/navigation/navigation_cubit.dart';
import '../../app/shell/app_shell.dart';
import '../../app/shell/brand_wordmark.dart';
import '../../app/shell/sync_status_indicator.dart';
import '../../core/domain/domain.dart';
import '../../design/design.dart';
import '../auth/conflict_warning_banner.dart';
import 'collection_views_cubit.dart';
import 'collection_views_state.dart';
import 'modes/view_mode.dart';
import 'widgets/fields_editor_sheet.dart';
import 'widgets/new_view_dialog.dart';
import 'widgets/object_detail_sheet.dart';
import 'widgets/quick_add_dialog.dart';
import 'widgets/view_labels.dart';
import 'widgets/view_tabs.dart';
import 'widgets/view_toolbar.dart';
import 'widgets/views_skeleton.dart';

/// A collection's Work surface (`/collections/:id`): header, view tabs,
/// toolbar and the active view drawn by its mode.
///
/// Wide (≥ [AppShell.expandedBreakpoint]): inside the shell with the rail.
/// Phone: a pushed page with back, name, view settings (`tune`) and an
/// overflow holding "Customize collection"; "+ New" is the FAB.
class CollectionViewsPage extends StatelessWidget {
  const CollectionViewsPage({super.key, required this.modes});

  final ViewModeRegistry modes;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CollectionViewsCubit, CollectionViewsState>(
      listenWhen: (prev, next) =>
          next is ViewsReady &&
          next.writeError != null &&
          (prev is! ViewsReady || prev.writeErrorSeq != next.writeErrorSeq),
      listener: (context, state) =>
          _notify(context, (state as ViewsReady).writeError!, error: true),
      builder: (context, state) {
        _maybeNudge(context, state);
        return LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < AppShell.expandedBreakpoint;
            final ready = state is ViewsReady ? state : null;
            final body = switch (state) {
              ViewsLoading() => ViewsSkeleton(compact: compact),
              ViewsNotFound() => const _NotFound(),
              ViewsError() => const _ErrorCard(),
              final ViewsReady s => _WorkBody(
                state: s,
                modes: modes,
                compact: compact,
              ),
            };
            return compact
                ? _PhoneFrame(state: ready, body: body)
                : _WideFrame(state: ready, body: body);
          },
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Page actions. The stubs are swapped for the real sheets by later work.
// -----------------------------------------------------------------------------

/// Collections whose "Add your first `<item>`" nudge was shown this session.
final _nudgedCollections = <String>{};

/// Test hook: forget the session's nudges.
@visibleForTesting
void resetFirstItemNudges() => _nudgedCollections.clear();

/// Once per session per collection, a gentle prompt when it has no objects.
void _maybeNudge(BuildContext context, CollectionViewsState state) {
  if (state is! ViewsReady || state.totalCount != 0) return;
  if (state.collection.fields.isEmpty) return;
  if (!_nudgedCollections.add(state.collection.id)) return;
  final message = 'Add your first ${itemLabelOf(state.collection)}';
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (context.mounted) _notify(context, message);
  });
}

void _notify(
  BuildContext context,
  String message, {
  ViewUndo? undo,
  bool error = false,
}) {
  final messenger = ScaffoldMessenger.of(context);
  final scheme = Theme.of(context).colorScheme;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? scheme.errorContainer : null,
        duration: const Duration(seconds: 5),
        action: undo == null
            ? null
            : SnackBarAction(label: 'Undo', onPressed: () => undo()),
      ),
    );
}

void _comingSoon(BuildContext context, String what) =>
    _notify(context, '$what is coming soon');

/// Columns (Table) / Setup card (other modes), named by the mode.
void _openFieldsEditor(BuildContext context, ViewMode mode) {
  final cubit = context.read<CollectionViewsCubit>();
  if (cubit.state case final ViewsReady state) {
    FieldsEditorSheet.show(
      context,
      title: mode.fieldsLabel,
      collection: state.collection,
      view: state.activeView,
      object: state.objects.firstOrNull,
      referenceLabels: state.referenceLabels,
      onSave: cubit.setFieldIds,
    );
  }
}

void _openFilterEditor(BuildContext context, {int? index}) =>
    _comingSoon(context, 'Filtering');
void _openSortMenu(BuildContext context) => _comingSoon(context, 'Sorting');
void _openViewSettings(BuildContext context) =>
    _comingSoon(context, 'View settings');

void _customize(BuildContext context, String collectionId) =>
    context.go('/collections/$collectionId/edit');

Future<void> _quickAdd(
  BuildContext context,
  ViewsReady state, {
  String? groupKey,
  DateTime? day,
}) async {
  final cubit = context.read<CollectionViewsCubit>();
  final collection = state.collection;
  final titleField = cubit.quickAddTitleField();
  final layout = state.layoutField;
  final prefill = switch (layout) {
    _ when groupKey != null && layout != null =>
      '${layout.name} · ${state.groups?.where((g) => g.key == groupKey).firstOrNull?.label ?? ''}',
    final DateFieldDefinition f when day != null =>
      '${f.name} · ${formatFieldValue(f, withDay(f, const DateFieldValue(null), day))}',
    _ => null,
  };
  final itemLabel = itemLabelOf(collection);
  final title = await QuickAddDialog.show(
    context,
    itemLabel: itemLabel,
    titleLabel: titleField?.name ?? 'Title',
    prefill: prefill,
  );
  if (title == null || !context.mounted) return;
  final id = cubit.quickAdd(title, groupKey: groupKey, day: day);
  final now = cubit.state;
  if (id != null && now is ViewsReady && now.objectById(id) == null) {
    _notify(context, 'Added — hidden by the filters');
  }
}

Future<void> _openObject(
  BuildContext context,
  ViewsReady state,
  MorkvaObject object,
) async {
  final cubit = context.read<CollectionViewsCubit>();
  final title = titleOf(state.activeView, state.collection, object);
  final delete = await ObjectDetailSheet.show(
    context,
    object: object,
    collection: state.collection,
    title: title,
    referenceLabels: state.referenceLabels,
  );
  if (delete != true || !context.mounted) return;
  final undo = cubit.deleteObject(object.id);
  if (undo != null) _notify(context, 'Deleted "$title"', undo: undo);
}

Future<void> _openNewView(
  BuildContext context,
  Collection collection,
  ViewModeRegistry modes,
) async {
  final cubit = context.read<CollectionViewsCubit>();
  final request = await NewViewDialog.show(
    context,
    collection: collection,
    modes: modes,
    onAddField: () => _customize(context, collection.id),
  );
  if (request == null) return;
  await cubit.createView(
    request.name,
    mode: request.mode,
    layoutFieldId: request.layoutFieldId,
  );
}

Future<void> _deleteView(BuildContext context, ViewDefinition view) async {
  final cubit = context.read<CollectionViewsCubit>();
  final confirmed = await MorkvaConfirmDialog.show(
    context,
    title: 'Delete view?',
    message:
        'This deletes the view "${view.name}" and its filters and sort. '
        'Your data stays as it is.',
    confirmLabel: 'Delete',
    destructive: true,
  );
  if (confirmed == true) await cubit.deleteView(view.id);
}

// -----------------------------------------------------------------------------
// Frames
// -----------------------------------------------------------------------------

class _WideFrame extends StatelessWidget {
  const _WideFrame({required this.state, required this.body});

  final ViewsReady? state;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final collection = state?.collection;
    return AppShell(
      selectedIndex: kAppSections.indexOf(AppSection.home),
      destinations: kAppSections,
      onDestinationSelected: (i) {
        context.read<NavigationCubit>().select(kAppSections[i]);
        context.go('/');
      },
      railHeaderBuilder: (context, extended) =>
          BrandWordmark(extended: extended),
      title: collection?.name ?? '',
      header: collection == null
          ? const SizedBox.shrink()
          : _WideHeader(collection: collection, state: state!),
      banner: const ConflictWarningBanner(),
      child: body,
    );
  }
}

class _WideHeader extends StatelessWidget {
  const _WideHeader({required this.collection, required this.state});

  final Collection collection;
  final ViewsReady state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.lg,
        Spacing.lg,
        Spacing.lg,
        Spacing.xs,
      ),
      child: Row(
        children: [
          CollectionGlyph(iconKey: collection.icon, size: 44, iconSize: 24),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(
              collection.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineMedium,
            ),
          ),
          const SyncStatusIndicator(),
          const SizedBox(width: Spacing.sm),
          OutlinedButton.icon(
            onPressed: () => _customize(context, collection.id),
            icon: const Icon(Icons.tune, size: 18),
            label: const Text('Customize'),
          ),
          if (collection.fields.isNotEmpty) ...[
            const SizedBox(width: Spacing.sm),
            PrimaryButton(
              label: 'New ${itemLabelOf(collection)}',
              icon: Icons.add,
              onPressed: () => _quickAdd(context, state),
            ),
          ],
        ],
      ),
    );
  }
}

class _PhoneFrame extends StatelessWidget {
  const _PhoneFrame({required this.state, required this.body});

  final ViewsReady? state;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ready = state;
    final collection = ready?.collection;
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: collection == null
            ? null
            : Row(
                children: [
                  CollectionGlyph(
                    iconKey: collection.icon,
                    size: 32,
                    iconSize: 18,
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Text(
                      collection.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
        actions: [
          if (collection != null) ...[
            const SyncStatusIndicator(),
            IconButton(
              tooltip: 'View settings',
              icon: const Icon(Icons.tune),
              onPressed: () => _openViewSettings(context),
            ),
            PopupMenuButton<void>(
              tooltip: 'More',
              icon: const Icon(Icons.more_vert),
              itemBuilder: (_) => [
                PopupMenuItem(
                  onTap: () => _customize(context, collection.id),
                  child: const Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 20),
                      SizedBox(width: Spacing.sm),
                      Flexible(child: Text('Customize collection')),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      floatingActionButton: ready == null || ready.collection.fields.isEmpty
          ? null
          : FloatingActionButton(
              tooltip: 'New ${itemLabelOf(ready.collection)}',
              onPressed: () => _quickAdd(context, ready),
              child: const Icon(Icons.add),
            ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const ConflictWarningBanner(),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Body
// -----------------------------------------------------------------------------

/// Bottom space under the phone body: the FAB (56) plus its margins.
const double _fabClearance = 88;

class _WorkBody extends StatelessWidget {
  const _WorkBody({
    required this.state,
    required this.modes,
    required this.compact,
  });

  final ViewsReady state;
  final ViewModeRegistry modes;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CollectionViewsCubit>();
    final collection = state.collection;
    final view = state.activeView;
    final gutter = compact ? Spacing.md : Spacing.lg;

    if (collection.fields.isEmpty) {
      return EmptyState(
        icon: Icons.view_column_outlined,
        title: 'This collection has no fields yet',
        message:
            'Add the fields you track for each ${itemLabelOf(collection)}, '
            'then come back to work with them here.',
        action: PrimaryButton(
          label: 'Customize',
          icon: Icons.tune,
          onPressed: () => _customize(context, collection.id),
        ),
      );
    }

    final mode = modes.resolve(view.mode);
    final known = modes.byId(view.mode) != null;
    final data = ViewModeData(
      state: state,
      itemLabel: itemLabelOf(collection),
      openObject: (o) => _openObject(context, state, o),
      quickAdd: ({groupKey, day}) =>
          _quickAdd(context, state, groupKey: groupKey, day: day),
      editFields: () => _openFieldsEditor(context, mode),
      notify: (message, {undo}) => _notify(context, message, undo: undo),
    );
    final noMatches =
        state.objects.isEmpty && state.isFiltered && !mode.drawsNoMatches;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ViewTabs(
          views: collection.views,
          activeViewId: state.activeViewId,
          modes: modes,
          horizontalPadding: gutter,
          onSelect: cubit.selectView,
          onNewView: () => _openNewView(context, collection, modes),
          onRename: cubit.renameView,
          onDuplicate: cubit.duplicateView,
          onDelete: (id) => _deleteView(
            context,
            collection.views.firstWhere((v) => v.id == id),
          ),
        ),
        ViewToolbar(
          collection: collection,
          view: view,
          compact: compact,
          fieldsLabel: mode.fieldsLabel,
          horizontalPadding: gutter,
          settingsChip: mode.buildSettingsChip(context, data),
          onAddFilter: () => _openFilterEditor(context),
          onEditFilter: (i) => _openFilterEditor(context, index: i),
          onRemoveFilter: (i) =>
              cubit.setFilters([...view.filters]..removeAt(i)),
          onSort: () => _openSortMenu(context),
          onEditFields: data.editFields,
        ),
        if (!known)
          _UnknownModeNotice(modeId: view.mode, fallback: mode, gutter: gutter),
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              gutter,
              Spacing.xxs,
              gutter,
              // Room for the FAB so it never covers the table footer.
              compact ? _fabClearance : gutter,
            ),
            child: noMatches
                ? EmptyState(
                    icon: Icons.filter_alt_off_outlined,
                    title: 'Nothing matches these filters',
                    message:
                        'None of your ${state.totalCount} '
                        '${collection.name.toLowerCase()} pass the filters '
                        'above.',
                    action: SecondaryButton(
                      label: 'Clear filters',
                      icon: Icons.filter_alt_off_outlined,
                      onPressed: () => cubit.setFilters(const []),
                    ),
                  )
                : mode.buildBody(context, data),
          ),
        ),
      ],
    );
  }
}

class _UnknownModeNotice extends StatelessWidget {
  const _UnknownModeNotice({
    required this.modeId,
    required this.fallback,
    required this.gutter,
  });

  final String modeId;
  final ViewMode fallback;
  final double gutter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, 0, gutter, Spacing.xs),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm,
          vertical: Spacing.xs,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: Radii.mdAll,
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: Spacing.xs),
            Expanded(
              child: Text(
                'This view uses the "$modeId" mode, which this version '
                "doesn't have yet. Showing it as a ${fallback.label.toLowerCase()}.",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.search_off_outlined,
    title: 'Collection not found',
    message:
        'This collection may have been deleted, or the link is wrong. '
        'Head back home to pick another.',
    action: PrimaryButton(
      label: 'Back to collections',
      icon: Icons.arrow_back,
      onPressed: () => context.go('/'),
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: Radii.lgAll,
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined, size: 32, color: scheme.error),
              const SizedBox(height: Spacing.sm),
              Text(
                "Couldn't load this view",
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Spacing.xs),
              Text(
                'Check your connection and try again.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Spacing.md),
              SecondaryButton(
                label: 'Retry',
                icon: Icons.refresh,
                onPressed: () => context.read<CollectionViewsCubit>().retry(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
