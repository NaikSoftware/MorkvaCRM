import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../app/shell/app_shell.dart';
import '../../app/shell/app_shell_scaffold.dart' show AskMorkvaAction;
import '../../app/shell/sync_status_indicator.dart';
import '../../core/domain/domain.dart';
import '../../design/design.dart';
import '../assistant/bloc/assistant_focus.dart';
import '../automation/widgets/collection_actions_menu.dart';
import '../automation/widgets/run_indicator.dart';
import '../auth/conflict_warning_banner.dart';
import '../../l10n/l10n.dart';
import '../objects/object_editor.dart';
import 'collection_views_cubit.dart';
import 'collection_views_state.dart';
import 'modes/view_mode.dart';
import 'screen_focus.dart';
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
/// Wide (≥ [AppShell.expandedBreakpoint]): in the persistent shell's main
/// panel, beside the rail.
/// Phone: a pushed page with back, name, sync status, Ask Morkva and an
/// overflow holding view settings and "Customize collection"; "+ New" is
/// the FAB.
///
/// Deep links (`collectionLink`): the page applies the `view`, `filter` and
/// `card` query parameters whenever they change, also while it stays on the
/// same collection. It keeps the app's [AssistantFocusNotifier], when one is
/// provided, up to date with what it shows (see `screenFocusOf`).
class CollectionViewsPage extends StatefulWidget {
  const CollectionViewsPage({super.key, required this.modes});

  final ViewModeRegistry modes;

  @override
  State<CollectionViewsPage> createState() => _CollectionViewsPageState();
}

/// Wide-frame content narrower than this (a side panel beside the page)
/// drops the Customize label.
const _narrowContent = 720.0;

/// How long the screen must settle before the assistant's focus is updated,
/// so a burst of changes publishes once.
const _focusDebounce = Duration(milliseconds: 150);

class _CollectionViewsPageState extends State<CollectionViewsPage> {
  /// The last applied deep link `(view, filter, card)`.
  (String?, String?, String?)? _link;

  /// A linked card to open once the objects have loaded.
  String? _pendingCard;

  /// The card open in the editor, for the assistant's focus.
  ({String id, String title})? _openCard;

  AssistantFocusNotifier? _focus;
  AssistantFocus? _published;
  Timer? _publishTimer;

  @override
  void initState() {
    super.initState();
    _schedulePublish();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _readLink();
  }

  @override
  void didUpdateWidget(CollectionViewsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // go_router reuses this page for the same collection: a new location
    // rebuilds it with new query parameters.
    _readLink();
  }

  @override
  void dispose() {
    _publishTimer?.cancel();
    final focus = _focus;
    final published = _published;
    if (focus != null && published != null) {
      // After the frame: listeners may rebuild, and the tree is locked now.
      // The next page may already have published its own focus.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (identical(focus.value, published)) focus.value = null;
      });
    }
    super.dispose();
  }

  void _readLink() {
    final params = GoRouter.maybeOf(context) == null
        ? const <String, String>{}
        : GoRouterState.of(context).uri.queryParameters;
    final link = (params['view'], params['filter'], params['card']);
    if (link == _link) return;
    _link = link;
    final (view, filter, card) = link;
    context.read<CollectionViewsCubit>().openLink(viewId: view, filter: filter);
    _pendingCard = card;
    if (card != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openPendingCard());
    }
  }

  /// Opens the linked card's editor once the objects are in.
  void _openPendingCard() {
    final id = _pendingCard;
    if (id == null || !mounted) return;
    final cubit = context.read<CollectionViewsCubit>();
    final state = cubit.state;
    if (state is ViewsLoading) return;
    _pendingCard = null;
    if (state is! ViewsReady) return;
    final object = state.objectById(id) ?? cubit.findObject(id);
    if (object == null) {
      _notify(
        context,
        context.l10n.viewsLinkCardGone(itemLabelOf(state.collection)),
      );
      _dropParams({'card': id});
      return;
    }
    _openObject(
      context,
      state,
      object,
    ).whenComplete(() => _dropParams({'card': id}));
  }

  /// Once the user leaves the linked view or clears the linked filter, takes
  /// them out of the location, so the same chip tapped again applies them.
  void _dropLeftLink() {
    final (view, filter, _) = _link ?? (null, null, null);
    final cubit = context.read<CollectionViewsCubit>();
    // The current state, not the delivered one: that may predate the link.
    final state = cubit.state;
    if (state is! ViewsReady || cubit.linkPending) return;
    final left =
        (view != null && state.activeViewId != view) ||
        (filter != null && state.transientFilters.isEmpty);
    if (left) _dropParams({'view': ?view, 'filter': ?filter});
  }

  /// Takes [handled] link parameters out of the location (in place, no
  /// history entry), so the same chip tapped again is a new link.
  void _dropParams(Map<String, String> handled) {
    if (!mounted) return;
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    final uri = router.routerDelegate.currentConfiguration.uri;
    final params = {...uri.queryParameters};
    // Only while this page's linked location is still the current one.
    if (uri.path != GoRouterState.of(context).uri.path ||
        handled.entries.any((e) => params[e.key] != e.value)) {
      return;
    }
    params.removeWhere((key, _) => handled.containsKey(key));
    // What stays in the location stays applied: don't re-apply it.
    _link = (params['view'], params['filter'], params['card']);
    final location = Uri(
      path: uri.path,
      queryParameters: params.isEmpty ? null : params,
    );
    Router.neglect(context, () => router.go(location.toString()));
  }

  void _setOpenCard(({String id, String title})? card) {
    _openCard = card;
    _schedulePublish();
  }

  void _schedulePublish() {
    _publishTimer?.cancel();
    _publishTimer = Timer(_focusDebounce, _publish);
  }

  void _publish() {
    if (!mounted) return;
    final focus = _focus ??= _focusNotifierOf(context);
    if (focus == null) return;
    final state = context.read<CollectionViewsCubit>().state;
    final next = state is ViewsReady
        ? screenFocusOf(
            state,
            openCardId: _openCard?.id,
            openCardTitle: _openCard?.title,
          )
        : null;
    if (next == null) {
      // Loading keeps the last focus; a missing or failed collection drops it.
      if (state is! ViewsLoading && identical(focus.value, _published)) {
        focus.value = _published = null;
      }
      return;
    }
    if (next == _published && identical(focus.value, _published)) return;
    focus.value = _published = next;
  }

  @override
  Widget build(BuildContext context) {
    final modes = widget.modes;
    return BlocListener<CollectionViewsCubit, CollectionViewsState>(
      listener: (_, _) {
        _schedulePublish();
        _openPendingCard();
        _dropLeftLink();
      },
      child: _consumer(modes),
    );
  }

  Widget _consumer(ViewModeRegistry modes) {
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
            // The frame follows the window, as the shell and the modes do:
            // a side panel pushing the page keeps it a desktop page.
            final compact =
                MediaQuery.sizeOf(context).width < AppShell.expandedBreakpoint;
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
                : _WideFrame(
                    state: ready,
                    body: body,
                    narrow: constraints.maxWidth < _narrowContent,
                  );
          },
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Page actions. The stubs are swapped for the real sheets by later work.
// -----------------------------------------------------------------------------

/// The app's [AssistantFocusNotifier], or null where none is provided.
AssistantFocusNotifier? _focusNotifierOf(BuildContext context) {
  try {
    return context.read<AssistantFocusNotifier>();
  } on ProviderNotFoundException {
    return null;
  }
}

/// The page around [context] (or the page's own context).
_CollectionViewsPageState? _pageOf(BuildContext context) => switch (context) {
  StatefulElement(state: final _CollectionViewsPageState page) => page,
  _ => context.findAncestorStateOfType<_CollectionViewsPageState>(),
};

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
      context.l10n.viewsAddFirstItem(item),
      action: SnackBarAction(
        label: context.l10n.viewsNewItem(item),
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
            : SnackBarAction(
                label: context.l10n.commonUndo,
                onPressed: () => undo(),
              ),
      ),
    );
}

/// What the collection's buttons run on: the active view's shown cards.
CollectionScope _actionScope(ViewsReady state) => CollectionScope(
  collection: state.collection,
  shownCardIds: [for (final o in state.objects) o.id],
  filtered: state.effectiveFilters.isNotEmpty,
  viewId: state.activeViewId,
);

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
    label: initial == null
        ? context.l10n.viewsAddFilter
        : context.l10n.viewsEditFilter,
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
    label: context.l10n.viewsSort,
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
    titleLabel: titleField?.name ?? context.l10n.viewsTitleFallback,
    prefill: prefill,
  );
  if (result == null || !context.mounted) return;
  if (!result.details) {
    final id = cubit.quickAdd(result.title, groupKey: groupKey, day: day);
    final now = cubit.state;
    if (id != null && now is ViewsReady && now.objectById(id) == null) {
      _notify(context, context.l10n.viewsAddedHidden);
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
            ? context.l10n.viewsFilledFromColumn(groupLabel)
            : context.l10n.viewsFilledFromGroup(groupLabel),
      final DateFieldDefinition f when dayValue != null =>
        context.l10n.viewsFilledFromDay(formatFieldValue(f, dayValue)),
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
    derive: cubit.deriveFor,
    notes: cubit.calculationNotes(),
  );
  if (result is ObjectEditorSaved && context.mounted) {
    _notifyIfHidden(context, result.object);
  }
}

/// "Saved — hidden by the filters" when [object] fails the active view.
void _notifyIfHidden(BuildContext context, MorkvaObject object) {
  final now = context.read<CollectionViewsCubit>().state;
  if (now is ViewsReady &&
      applyView(
        now.collection,
        now.activeView.copyWith(filters: now.effectiveFilters),
        [object],
      ).isEmpty) {
    _notify(context, context.l10n.viewsSavedHidden);
  }
}

Future<void> _openObject(
  BuildContext context,
  ViewsReady state,
  MorkvaObject object,
) async {
  final cubit = context.read<CollectionViewsCubit>();
  final page = _pageOf(context);
  page?._setOpenCard((
    id: object.id,
    title: titleOf(state.activeView, state.collection, object),
  ));
  final result = await showObjectEditor(
    context,
    collection: state.collection,
    object: object,
    titleFieldId: cubit.quickAddTitleField()?.id,
    derive: cubit.deriveFor,
    notes: cubit.calculationNotes(),
  );
  if (page != null && page.mounted && page._openCard?.id == object.id) {
    page._setOpenCard(null);
  }
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
      if (undo != null) {
        _notify(context, context.l10n.viewsDeletedTitle(title), undo: undo);
      }
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
    title: context.l10n.viewsDeleteViewTitle,
    message: context.l10n.viewsDeleteViewMessage(view.name),
    confirmLabel: context.l10n.commonDelete,
    destructive: true,
  );
  if (confirmed == true) await cubit.deleteView(view.id);
}

// -----------------------------------------------------------------------------
// Frames
// -----------------------------------------------------------------------------

/// Wide: the page's own header and banner over the body, in the persistent
/// shell's main panel (the shell draws the rail).
class _WideFrame extends StatelessWidget {
  const _WideFrame({
    required this.state,
    required this.body,
    required this.narrow,
  });

  final ViewsReady? state;
  final Widget body;

  /// The page is squeezed (a side panel beside it): Customize goes
  /// icon-only.
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    final ready = state;
    // Ink for the page's own controls, over the shell's doodles.
    return Material(
      type: MaterialType.transparency,
      child: Column(
        children: [
          if (ready != null)
            _WideHeader(
              collection: ready.collection,
              state: ready,
              narrow: narrow,
            ),
          const ConflictWarningBanner(),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _WideHeader extends StatelessWidget {
  const _WideHeader({
    required this.collection,
    required this.state,
    required this.narrow,
  });

  final Collection collection;
  final ViewsReady state;
  final bool narrow;

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
          CollectionGlyph(
            iconKey: collection.icon,
            tintSeed: collection.id,
            size: 44,
            iconSize: 24,
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(
              collection.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineMedium,
            ),
          ),
          // Sync status lives in the sidebar's profile row (rail: avatar dot).
          CollectionRunPill(collectionId: collection.id),
          CollectionActionsMenu(scope: _actionScope(state), narrow: narrow),
          if (narrow)
            IconButton.outlined(
              tooltip: context.l10n.viewsCustomize,
              onPressed: () => _customize(context, collection.id),
              icon: const Icon(Icons.tune, size: 18),
            )
          else
            OutlinedButton.icon(
              onPressed: () => _customize(context, collection.id),
              icon: const Icon(Icons.tune, size: 18),
              label: Text(context.l10n.viewsCustomize),
            ),
          if (collection.fields.isNotEmpty) ...[
            const SizedBox(width: Spacing.sm),
            PrimaryButton(
              label: context.l10n.viewsNewItem(itemLabelOf(collection)),
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
    final onAsk = ShellTab.askOf(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        titleSpacing: ShellTab.of(context) ? Spacing.md : 0,
        automaticallyImplyLeading: false,
        leading: ShellTab.of(context)
            ? null
            : IconButton(
                tooltip: context.l10n.commonBack,
                icon: const Icon(Icons.arrow_back),
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/'),
              ),
        title: collection == null
            ? null
            : Row(
                children: [
                  CollectionGlyph(
                    iconKey: collection.icon,
                    tintSeed: collection.id,
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
            // Takes the sync pill's slot while automations need a look.
            const RunIndicatorButton(idle: SyncStatusIndicator()),
            if (onAsk != null) const SizedBox(width: Spacing.xs),
          ],
          if (onAsk != null) AskMorkvaAction(onTap: onAsk),
          if (collection != null)
            PopupMenuButton<void>(
              tooltip: context.l10n.commonMore,
              icon: const Icon(Icons.more_vert),
              itemBuilder: (_) => [
                // Without fields the body's Customize carries the only
                // view settings entry.
                if (collection.fields.isNotEmpty)
                  PopupMenuItem(
                    onTap: () => _openViewSettings(context, modes),
                    child: Row(
                      children: [
                        const Icon(Icons.view_quilt_outlined, size: 20),
                        const SizedBox(width: Spacing.sm),
                        Flexible(child: Text(context.l10n.viewsViewSettings)),
                      ],
                    ),
                  ),
                if (ready != null)
                  ...collectionPhoneMenuItems(context, _actionScope(ready)),
                PopupMenuItem(
                  onTap: () => _customize(context, collection.id),
                  child: Row(
                    children: [
                      const Icon(Icons.tune, size: 20),
                      const SizedBox(width: Spacing.sm),
                      Flexible(
                        child: Text(context.l10n.viewsCustomizeCollection),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      floatingActionButton: ready == null || ready.collection.fields.isEmpty
          ? null
          // Floats over the body (no reserved strip), so a round "+" that
          // covers as little as possible.
          : FloatingActionButton(
              onPressed: () => _createObject(context, ready),
              tooltip: context.l10n.viewsNewItem(
                itemLabelOf(ready.collection),
              ),
              child: const Icon(Icons.add),
            ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const ConflictWarningBanner(),
            Expanded(child: DoodleBackground(child: body)),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Body
// -----------------------------------------------------------------------------

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
        title: context.l10n.viewsNoFieldsTitle,
        message: context.l10n.viewsNoFieldsMessage(itemLabelOf(collection)),
        action: PrimaryButton(
          label: context.l10n.viewsCustomize,
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
              leading: [
                if (state.transientFilters.isNotEmpty) ...[
                  _AssistantFiltersChip(
                    state: state,
                    onClear: cubit.clearTransientFilters,
                  ),
                  TextActionButton(
                    label: context.l10n.viewsSaveAsView,
                    icon: Icons.bookmark_add_outlined,
                    onPressed: cubit.saveTransientAsView,
                  ),
                ],
              ],
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
            padding: EdgeInsets.fromLTRB(gutter, Spacing.xxs, gutter, gutter),
            child: noMatches
                ? EmptyState(
                    icon: Icons.filter_alt_off_outlined,
                    title: context.l10n.viewsNoMatchesTitle,
                    message: context.l10n.viewsNoMatchesMessage(
                      state.totalCount,
                      collection.name.toLowerCase(),
                    ),
                    action: SecondaryButton(
                      label: context.l10n.viewsClearFilters,
                      icon: Icons.filter_alt_off_outlined,
                      onPressed: cubit.clearFilters,
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

/// The deep link's transient filters: "From assistant · Stage is Won";
/// removing it shows the view as saved.
class _AssistantFiltersChip extends StatelessWidget {
  const _AssistantFiltersChip({required this.state, required this.onClear});

  final ViewsReady state;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final filters = [
      for (final f in state.transientFilters)
        filterLabel(
          f,
          state.collection,
          referenceLabels: state.referenceLabels,
        ),
    ].join(' · ');
    return Tooltip(
      message: context.l10n.viewsAssistantFiltersTooltip(filters),
      child: InputChip(
        avatar: Icon(
          Icons.auto_awesome,
          size: 16,
          color: scheme.onSecondaryContainer,
        ),
        label: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Text(
            context.l10n.viewsFromAssistant(filters),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        onDeleted: onClear,
        deleteIcon: const Icon(Icons.close, size: 16),
        deleteButtonTooltipMessage: context.l10n.viewsClearAssistantFilters,
        backgroundColor: scheme.secondaryContainer,
        side: BorderSide.none,
        shape: const RoundedRectangleBorder(borderRadius: Radii.smAll),
        labelStyle: theme.textTheme.labelLarge?.copyWith(
          color: scheme.onSecondaryContainer,
        ),
        deleteIconColor: scheme.onSecondaryContainer,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        materialTapTargetSize: MaterialTapTargetSize.padded,
      ),
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
                context.l10n.viewsUnknownMode(
                  modeId,
                  fallback.label.toLowerCase(),
                ),
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
    title: context.l10n.viewsNotFoundTitle,
    message: context.l10n.viewsNotFoundMessage,
    action: PrimaryButton(
      label: context.l10n.viewsBackToCollections,
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
                context.l10n.viewsLoadError,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Spacing.xs),
              Text(
                context.l10n.viewsLoadErrorMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Spacing.md),
              SecondaryButton(
                label: context.l10n.commonRetry,
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
