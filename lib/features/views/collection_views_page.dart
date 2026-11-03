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
import '../objects/object_editor.dart';
import 'collection_views_cubit.dart';
import 'collection_views_state.dart';
import 'modes/view_mode.dart';
import 'widgets/filter_builder.dart';
import 'widgets/fields_editor_sheet.dart';
import 'widgets/new_view_dialog.dart';
import 'widgets/quick_add_dialog.dart';
import 'widgets/sort_menu.dart';
import 'widgets/view_labels.dart';
import 'widgets/view_popover.dart';
import 'widgets/view_settings_sheet.dart';
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
                ? _PhoneFrame(state: ready, modes: modes, body: body)
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
  final item = itemLabelOf(state.collection);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    _notify(
      context,
      'Add your first $item',
      action: SnackBarAction(
        label: 'New $item',
        onPressed: () => _quickAdd(context, state),
      ),
    );
  });
}

void _notify(
  BuildContext context,
  String message, {
  ViewUndo? undo,
  SnackBarAction? action,
  bool error = false,
}) {
  final messenger = ScaffoldMessenger.of(context);
  final scheme = Theme.of(context).colorScheme;
  final wide = MediaQuery.sizeOf(context).width >= AppShell.expandedBreakpoint;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? scheme.errorContainer : null,
        duration: const Duration(seconds: 5),
        // A SnackBar with an action persists by default; Undo still expires.
        persist: false,
        // Floating and 480 wide on desktop, so it never spans the rail.
        behavior: SnackBarBehavior.floating,
        width: wide ? 480 : null,
        action: undo == null
            ? action
            : SnackBarAction(label: 'Undo', onPressed: () => undo()),
      ),
    );
}

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

/// Adds a filter, or edits the one at [index]. A popover hanging from
/// [anchor] (the toolbar) when given, else a bottom sheet.
Future<void> _openFilterEditor(
  BuildContext context, {
  int? index,
  Rect? anchor,
  double inset = 0,
}) async {
  final cubit = context.read<CollectionViewsCubit>();
  final opened = cubit.state;
  if (opened is! ViewsReady) return;
  final initial = index == null
      ? null
      : opened.activeView.filters.elementAtOrNull(index);
  final result = await showViewPopover<ViewFilter>(
    context,
    compact: anchor == null,
    anchor: anchor ?? Rect.zero,
    horizontalInset: inset,
    label: initial == null ? 'Add filter' : 'Edit filter',
    // Rebuilds as reference choices arrive.
    builder: (sheetContext) =>
        BlocBuilder<CollectionViewsCubit, CollectionViewsState>(
          bloc: cubit,
          builder: (_, state) => FilterBuilder(
            collection: state is ViewsReady
                ? state.collection
                : opened.collection,
            initial: initial,
            referenceChoices: (id) =>
                state is ViewsReady ? state.referenceChoices[id] : null,
            onLoadChoices: cubit.loadReferenceChoices,
            onApply: (f) => Navigator.of(sheetContext).pop(f),
          ),
        ),
  );
  if (result == null) return;
  final current = cubit.state;
  if (current is! ViewsReady) return;
  final filters = [...current.activeView.filters];
  if (index != null && index < filters.length) {
    filters[index] = result;
  } else {
    filters.add(result);
  }
  await cubit.setFilters(filters);
}

/// The sort menu: a popover hanging from [anchor]'s right edge when given,
/// else a bottom sheet. Manual order is offered on Board and List.
Future<void> _openSortMenu(
  BuildContext context,
  ViewModeRegistry modes, {
  Rect? anchor,
  double inset = 0,
}) async {
  final cubit = context.read<CollectionViewsCubit>();
  final state = cubit.state;
  if (state is! ViewsReady) return;
  final view = state.activeView;
  await showViewPopover<void>(
    context,
    compact: anchor == null,
    anchor: anchor ?? Rect.zero,
    alignEnd: true,
    horizontalInset: inset,
    label: 'Sort',
    builder: (sheetContext) => SortMenu(
      collection: state.collection,
      current: view.sort,
      allowManual: modes.resolve(view.mode).supportsManualOrder,
      onChanged: cubit.setSort,
      onPicked: () => Navigator.of(sheetContext).pop(),
    ),
  );
}

/// The phone's view settings sheet. Sort and the fields editor replace it
/// rather than stacking on it.
Future<void> _openViewSettings(BuildContext context, ViewModeRegistry modes) {
  final cubit = context.read<CollectionViewsCubit>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
    ),
    // The sheet lives above the route that provides the cubit.
    builder: (sheet) => BlocProvider.value(
      value: cubit,
      child: ViewSettingsSheet(
        modes: modes,
        onSort: () {
          Navigator.of(sheet).pop();
          _openSortMenu(context, modes);
        },
        onEditFields: (mode) {
          Navigator.of(sheet).pop();
          _openFieldsEditor(context, mode);
        },
      ),
    ),
  );
}

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
  final groupLabel = groupKey == null
      ? null
      : state.groups?.where((g) => g.key == groupKey).firstOrNull?.label ?? '';
  final dayValue = day != null && layout is DateFieldDefinition
      ? withDay(layout, const DateFieldValue(null), day)
      : null;
  final prefill = switch (layout) {
    _ when groupLabel != null && layout != null =>
      '${layout.name} · $groupLabel',
    final DateFieldDefinition f when dayValue != null =>
      '${f.name} · ${formatFieldValue(f, dayValue)}',
    _ => null,
  };
  final itemLabel = itemLabelOf(collection);
  final result = await QuickAddDialog.show(
    context,
    itemLabel: itemLabel,
    titleLabel: titleField?.name ?? 'Title',
    prefill: prefill,
  );
  if (result == null || !context.mounted) return;
  if (!result.details) {
    final id = cubit.quickAdd(result.title, groupKey: groupKey, day: day);
    final now = cubit.state;
    if (id != null && now is ViewsReady && now.objectById(id) == null) {
      _notify(context, 'Added — hidden by the filters');
    }
    return;
  }
  // "Add details": the full form, pre-filled like quick add would.
  final title = result.title;
  await _createObject(
    context,
    state,
    prefill: {
      if (titleField != null && title.isNotEmpty)
        titleField.id: TextFieldValue(title),
      if (groupKey != null && isGroupable(layout))
        layout!.id: groupValueFor(layout, groupKey),
      if (layout != null && dayValue != null) layout.id: dayValue,
    },
    prefillNote: switch (layout) {
      _ when groupLabel != null && groupLabel.isNotEmpty =>
        state.activeView.mode == ViewModeIds.board
            ? 'Filled from the $groupLabel column'
            : 'Filled from the $groupLabel group',
      final DateFieldDefinition f when dayValue != null =>
        'Filled from ${formatFieldValue(f, dayValue)}',
      _ => null,
    },
  );
}

/// The object form in create mode; says so when the new object is hidden
/// by the active filters.
Future<void> _createObject(
  BuildContext context,
  ViewsReady state, {
  Map<String, FieldValue> prefill = const {},
  String? prefillNote,
}) async {
  final cubit = context.read<CollectionViewsCubit>();
  final result = await showObjectEditor(
    context,
    collection: state.collection,
    prefill: prefill,
    prefillNote: prefillNote,
    titleFieldId: cubit.quickAddTitleField()?.id,
  );
  if (result is ObjectEditorSaved && context.mounted) {
    _notifyIfHidden(context, result.object);
  }
}

/// "Saved — hidden by the filters" when [object] fails the active view.
void _notifyIfHidden(BuildContext context, MorkvaObject object) {
  final now = context.read<CollectionViewsCubit>().state;
  if (now is ViewsReady &&
      applyView(now.collection, now.activeView, [object]).isEmpty) {
    _notify(context, 'Saved — hidden by the filters');
  }
}

Future<void> _openObject(
  BuildContext context,
  ViewsReady state,
  MorkvaObject object,
) async {
  final cubit = context.read<CollectionViewsCubit>();
  final result = await showObjectEditor(
    context,
    collection: state.collection,
    object: object,
    titleFieldId: cubit.quickAddTitleField()?.id,
  );
  if (!context.mounted) return;
  switch (result) {
    case ObjectEditorSaved(:final object):
      _notifyIfHidden(context, object);
    case ObjectEditorDeleted():
      final now = cubit.state;
      final latest = now is ViewsReady ? now : state;
      final title = titleOf(
        latest.activeView,
        latest.collection,
        latest.objectById(object.id) ?? object,
      );
      final undo = cubit.deleteObject(object.id);
      if (undo != null) _notify(context, 'Deleted "$title"', undo: undo);
    case null:
      break;
  }
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
              onPressed: () => _createObject(context, state),
            ),
          ],
        ],
      ),
    );
  }
}

class _PhoneFrame extends StatelessWidget {
  const _PhoneFrame({
    required this.state,
    required this.modes,
    required this.body,
  });

  final ViewsReady? state;
  final ViewModeRegistry modes;
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
            // Without fields the body's Customize carries the only `tune`.
            if (collection.fields.isNotEmpty)
              IconButton(
                tooltip: 'View settings',
                icon: const Icon(Icons.tune),
                onPressed: () => _openViewSettings(context, modes),
              ),
            PopupMenuButton<void>(
              tooltip: 'More',
              icon: const Icon(Icons.more_vert),
              itemBuilder: (_) => [
                PopupMenuItem(
                  onTap: () => _customize(context, collection.id),
                  child: const Row(
                    children: [
                      Icon(Icons.tune, size: 20),
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
          : FloatingActionButton.extended(
              onPressed: () => _createObject(context, ready),
              icon: const Icon(Icons.add),
              label: Text('New ${itemLabelOf(ready.collection)}'),
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

/// Bottom space under the phone body: the extended FAB (56) plus margins.
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
    final renders = mode.unavailableReason(collection) == null;

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
        Builder(
          builder: (toolbar) {
            Rect? anchor() => compact ? null : globalRectOf(toolbar);
            return ViewToolbar(
              collection: collection,
              view: view,
              compact: compact,
              fieldsLabel: mode.fieldsLabel,
              horizontalPadding: gutter,
              referenceLabels: state.referenceLabels,
              settingsChip: mode.buildSettingsChip(context, data),
              onAddFilter: () =>
                  _openFilterEditor(context, anchor: anchor(), inset: gutter),
              onEditFilter: (i) => _openFilterEditor(
                context,
                index: i,
                anchor: anchor(),
                inset: gutter,
              ),
              onRemoveFilter: (i) =>
                  cubit.setFilters([...view.filters]..removeAt(i)),
              // Nothing to sort or set up while the mode can't draw yet.
              onSort: renders
                  ? () => _openSortMenu(
                      context,
                      modes,
                      anchor: anchor(),
                      inset: gutter,
                    )
                  : null,
              onEditFields: renders ? data.editFields : null,
            );
          },
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
                : KeyedSubtree(
                    key: ValueKey(view.id),
                    child: mode.buildBody(context, data),
                  ),
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
