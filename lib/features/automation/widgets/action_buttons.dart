import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/automation/runner_api.dart';
import '../../../core/domain/automation/automation.dart';
import '../../../design/design.dart';
import '../bloc/automation_runs_cubit.dart';
import '../bloc/modules_cubit.dart';
import '../view/review_sheet.dart';
import 'reason_copy.dart';

// -----------------------------------------------------------------------------
// Shared helpers (the editor, the collection page and the indicator use them)
// -----------------------------------------------------------------------------

/// [T] from the context, or null where none is provided (the app provides the
/// automation cubits and the runner once signed in; tests and pages without
/// them show no automation UI).
T? maybeRead<T>(BuildContext context) {
  try {
    return context.read<T>();
  } on ProviderNotFoundException {
    return null;
  }
}

/// Captures the app's automation providers from [context], for a route that
/// may sit outside them (the card editor dialog): wrap its child with the
/// returned function.
Widget Function(Widget child) automationCarrier(BuildContext context) {
  final runner = maybeRead<AutomationRunnerApi>(context);
  final stores = maybeRead<AutomationStores>(context);
  final runs = maybeRead<AutomationRunsCubit>(context);
  final modules = maybeRead<ModulesCubit>(context);
  return (child) {
    var out = child;
    if (modules != null) out = BlocProvider.value(value: modules, child: out);
    if (runs != null) out = BlocProvider.value(value: runs, child: out);
    if (stores != null) {
      out = RepositoryProvider.value(value: stores, child: out);
    }
    if (runner != null) {
      out = RepositoryProvider.value(value: runner, child: out);
    }
    return out;
  };
}

/// The automation routes (T16 registers them).
abstract final class AutomationPaths {
  static String run(String runId) => '/automations/runs/$runId';

  static String module(String moduleId) => '/automations/modules/$moduleId';

  /// The Runs tab, optionally filtered (`review`, `failed`).
  static String runs({String? filter}) => Uri(
    path: '/automations',
    queryParameters: {'tab': 'runs', 'filter': ?filter},
  ).toString();

  static String automationsOf(String collectionId) => Uri(
    path: '/automations',
    queryParameters: {'tab': 'automations', 'collection': collectionId},
  ).toString();
}

/// The enabled button automations of [collectionId] with [scope], in button
/// order.
List<AutomationEntry> buttonsOf(
  List<AutomationEntry> all,
  String collectionId, {
  ButtonScope scope = ButtonScope.card,
}) =>
    [
      for (final a in all)
        if (a.automation.trigger case ButtonTrigger(
          scope: final s,
          collectionId: final c,
        ) when a.automation.enabled && s == scope && c == collectionId)
          a,
    ]..sort((a, b) {
      final order = (a.automation.button?.order ?? 0).compareTo(
        b.automation.button?.order ?? 0,
      );
      return order != 0
          ? order
          : a.automation.name.compareTo(b.automation.name);
    });

/// A button's tint pair: its stored tint id, else the collection's own.
CollectionTint buttonTintOf(String? tint, String seed, Brightness brightness) {
  final palette = brightness == Brightness.light
      ? CollectionTints.light
      : CollectionTints.dark;
  final i = kButtonTintIds.indexOf(tint ?? '');
  return i < 0 ? CollectionTints.of(seed, brightness) : palette[i];
}

/// The button's icon: its own, else the action's, else a bolt.
IconData buttonIconOf(AutomationEntry entry) {
  final key = entry.automation.button?.icon ?? entry.action?.icon;
  return key == null ? Icons.bolt_rounded : CollectionIcons.byKey(key);
}

/// The button label: the stored one, else the action's.
String buttonLabelOfEntry(AutomationEntry entry) =>
    entry.automation.button?.label ??
    entry.action?.label ??
    entry.automation.name;

/// Header labels ellipsize at 16 characters (UX §4).
String shortButtonLabel(String label) =>
    label.length <= 16 ? label : '${label.substring(0, 15)}…';

/// "Running… 2/3", "Applying…", "Queued · 3 ahead".
String liveRunLabel(RunView run) {
  if (run.status == RunStatus.queued) {
    final ahead = run.queuedAhead;
    return ahead == null || ahead == 0 ? 'Queued' : 'Queued · $ahead ahead';
  }
  final p = run.progress;
  final base = run.status == RunStatus.applying ? 'Applying…' : 'Running…';
  return p == null || p.total <= 0 ? base : '$base ${p.done}/${p.total}';
}

// -----------------------------------------------------------------------------
// Finish notices (in-editor banner; the finish snackbar reuses the words)
// -----------------------------------------------------------------------------

/// What a finish notice offers.
enum NoticeAction { undo, viewRun, review, runAgain }

/// The words and actions of a finished run (UX §4 banner, §5 snackbar).
typedef NoticeCopy = ({String text, List<NoticeAction> actions, bool error});

/// [card] names the card when the notice is about another card than the
/// one on screen ("Spin forever on Order #1042 timed out after 20 s").
/// [runnable]: the automation may run again (neither needs consent nor is
/// broken), as the run log's Run again rule.
NoticeCopy runNoticeCopy(RunView run, {String? card, bool runnable = false}) {
  final label = card == null ? run.label : '${run.label} on $card';
  switch (run.status) {
    case RunStatus.awaitingReview:
      return (
        text: '$label needs your review',
        actions: const [NoticeAction.review],
        error: false,
      );
    case RunStatus.succeeded:
      final changed = run.planId != null;
      // The host's count first ("1 order updated"): the module's own words
      // may carry raw values (an ISO date).
      return (
        text:
            '$label · ${run.outcome ?? run.summary ?? (changed ? 'Done' : 'No changes')}',
        actions: [if (changed) NoticeAction.undo, NoticeAction.viewRun],
        error: false,
      );
    case RunStatus.timedOut:
      return (
        text: '$label timed out after 20 s',
        // View run first: the snackbar offers only the first.
        actions: [
          NoticeAction.viewRun,
          if (runnable &&
              run.automationId != null &&
              run.trigger.kind != TriggerKind.cardDeleted)
            NoticeAction.runAgain,
        ],
        error: true,
      );
    case RunStatus.failed when run.reason == RunReason.cancelled:
      return (
        text: '$label was stopped. Nothing was changed.',
        actions: const [],
        error: false,
      );
    case RunStatus.failed when run.reason == RunReason.offline:
      return (
        text: card == null
            ? "Couldn't apply — you're offline"
            : "Couldn't apply $label — you're offline",
        actions: const [NoticeAction.runAgain],
        error: true,
      );
    case RunStatus.failed:
      final message = run.error?.message;
      return (
        text: message == null ? '$label failed' : '$label failed — $message',
        actions: const [NoticeAction.viewRun],
        error: true,
      );
    case RunStatus.skipped when run.reason == RunReason.engineUnavailable:
      return (
        text: "Automations can't run on this device",
        actions: const [NoticeAction.viewRun],
        error: true,
      );
    case _:
      return (
        text: '$label · ${runCopy(run.status, run.reason).row}',
        actions: const [NoticeAction.viewRun],
        error: false,
      );
  }
}

// -----------------------------------------------------------------------------
// One button's state
// -----------------------------------------------------------------------------

/// Where a card button stands (UX §4 "States").
enum ButtonPhase { idle, needsConsent, queued, running, review, failed }

/// A card / collection button as drawn: its automation, phase and live run.
final class ButtonView {
  const ButtonView({
    required this.entry,
    required this.phase,
    this.run,
    this.failedRunId,
    this.dirty = false,
  });

  final AutomationEntry entry;
  final ButtonPhase phase;

  /// The live run (queued, running, review).
  final RunView? run;

  /// The last run on this card failed: the error dot opens it.
  final String? failedRunId;

  /// The form has unsaved changes (or the card is new): a press offers
  /// "Save and run".
  final bool dirty;

  String get label => buttonLabelOfEntry(entry);

  bool get busy => phase == ButtonPhase.queued || phase == ButtonPhase.running;
}

/// The buttons of [entries] on [cardId] (null: a new card) as they stand in
/// [runs]. A collection button passes [cardId] null and [collection] true.
List<ButtonView> buttonViewsOf(
  List<AutomationEntry> entries,
  AutomationRunsState runs, {
  required String? cardId,
  bool dirty = false,
  bool collection = false,
}) => [
  for (final e in entries)
    _viewOf(e, runs, cardId: cardId, dirty: dirty, collection: collection),
];

ButtonView _viewOf(
  AutomationEntry entry,
  AutomationRunsState runs, {
  required String? cardId,
  required bool dirty,
  required bool collection,
}) {
  final id = entry.automation.id;
  // runOf(cardId: null) matches any card: a new card has no runs yet.
  final live = cardId == null && !collection
      ? null
      : runs.activity.runOf(id, cardId: cardId);
  if (live != null) {
    return ButtonView(
      entry: entry,
      run: live,
      dirty: dirty,
      phase: switch (live.status) {
        RunStatus.queued => ButtonPhase.queued,
        RunStatus.awaitingReview => ButtonPhase.review,
        _ => ButtonPhase.running,
      },
    );
  }
  if (entry.status == AutomationStatus.needsConsent) {
    return ButtonView(
      entry: entry,
      phase: ButtonPhase.needsConsent,
      dirty: dirty,
    );
  }
  final last = cardId == null
      ? null
      : runs.recent
            .where((r) => r.automationId == id && r.trigger.cardId == cardId)
            .firstOrNull;
  if (last != null && runFailed(last)) {
    return ButtonView(
      entry: entry,
      phase: ButtonPhase.failed,
      failedRunId: last.id,
      dirty: dirty,
    );
  }
  return ButtonView(entry: entry, phase: ButtonPhase.idle, dirty: dirty);
}

/// What the hosting surface does for a card button.
final class CardActionHooks {
  const CardActionHooks({
    required this.onSaveAndRun,
    required this.onNavigate,
    required this.onMessage,
  });

  /// "Save and run": save without closing, then run on the saved card.
  final Future<void> Function(AutomationEntry entry) onSaveAndRun;

  /// Leaves the editor for [path] (run detail, module details).
  final void Function(String path) onNavigate;

  /// A refused press, shown in the editor.
  final void Function(String message) onMessage;
}

/// A press on [view]: focus a live run, open what a dot means, or start a
/// run on [cardId] (an idle button on a saved, clean form).
Future<void> pressCardButton(
  BuildContext context,
  ButtonView view, {
  required AutomationRunsCubit runs,
  required String? cardId,
  required CardActionHooks hooks,
}) async {
  switch (view.phase) {
    case ButtonPhase.review:
      await showReviewSheet(context, runId: view.run!.runId, overEditor: true);
    case ButtonPhase.failed:
      hooks.onNavigate(AutomationPaths.run(view.failedRunId!));
    case ButtonPhase.needsConsent:
      hooks.onNavigate(AutomationPaths.module(view.entry.automation.moduleId));
    case ButtonPhase.queued || ButtonPhase.running:
      break;
    case ButtonPhase.idle when view.dirty || cardId == null:
      await hooks.onSaveAndRun(view.entry);
    case ButtonPhase.idle:
      final id = await runs.pressCard(
        view.entry.automation.id,
        cardId: cardId!,
      );
      if (id == null) {
        final error = runs.state.error;
        if (error != null) hooks.onMessage(error);
      }
  }
}

// -----------------------------------------------------------------------------
// Card editor: header buttons (wide) and ⚡ (phone)
// -----------------------------------------------------------------------------

/// The card buttons of [collectionId] for the card editor: on the header's
/// title row (wide) or as ⚡ in the app bar (phone, [compact]). Nothing
/// without the app's automation cubits or without card buttons.
class CardActions extends StatelessWidget {
  const CardActions({
    super.key,
    required this.collectionId,
    required this.cardId,
    required this.dirty,
    required this.hooks,
    this.compact = false,
    this.headerWidth = double.infinity,
  });

  final String collectionId;

  /// Null for a card not saved yet.
  final String? cardId;
  final bool dirty;
  final CardActionHooks hooks;
  final bool compact;

  /// The editor header's width (the 45 % budget, icon-only below 560).
  final double headerWidth;

  @override
  Widget build(BuildContext context) {
    final runs = maybeRead<AutomationRunsCubit>(context);
    final modules = maybeRead<ModulesCubit>(context);
    if (runs == null || modules == null) return const SizedBox.shrink();
    return BlocBuilder<ModulesCubit, ModulesState>(
      bloc: modules,
      builder: (context, m) {
        final entries = buttonsOf(m.automations, collectionId);
        if (entries.isEmpty) return const SizedBox.shrink();
        return BlocBuilder<AutomationRunsCubit, AutomationRunsState>(
          bloc: runs,
          builder: (context, r) {
            final views = buttonViewsOf(
              entries,
              r,
              cardId: cardId,
              dirty: dirty || cardId == null,
            );
            void tap(ButtonView view) => pressCardButton(
              context,
              view,
              runs: runs,
              cardId: cardId,
              hooks: hooks,
            );

            if (compact) {
              return PhoneActionsButton(
                views: views,
                onOpen: () => showActionsSheet(
                  context,
                  runs: runs,
                  modules: modules,
                  build: (r, m) => buttonViewsOf(
                    buttonsOf(m.automations, collectionId),
                    r,
                    cardId: cardId,
                    dirty: dirty || cardId == null,
                  ),
                  onSelect: tap,
                ),
              );
            }
            return HeaderActionButtons(
              views: views,
              headerWidth: headerWidth,
              tintSeed: collectionId,
              onPressed: tap,
              onStop: runs.stop,
            );
          },
        );
      },
    );
  }
}

/// The wide card editor's title-row buttons: at most 45 % of the header,
/// labels cut at 16 characters, the rest under **More ▾**, icon-only below a
/// 560 px header (UX §4).
class HeaderActionButtons extends StatelessWidget {
  const HeaderActionButtons({
    super.key,
    required this.views,
    required this.headerWidth,
    required this.tintSeed,
    required this.onPressed,
    required this.onStop,
  });

  final List<ButtonView> views;
  final double headerWidth;
  final String tintSeed;
  final ValueChanged<ButtonView> onPressed;
  final ValueChanged<String> onStop;

  static const double _gap = Spacing.xs;

  @override
  Widget build(BuildContext context) {
    final iconOnly = headerWidth < 560;
    final style = Theme.of(context).textTheme.labelLarge;
    final scaler = MediaQuery.textScalerOf(context);
    double textWidth(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      return painter.width;
    }

    double widthOf(ButtonView v) => iconOnly
        ? 44
        : _ActionButton.chrome + textWidth(_ActionButton.textOf(v));
    final budget = headerWidth * 0.45;
    final widths = [for (final v in views) widthOf(v)];
    final all = widths.fold<double>(0, (s, w) => s + w + _gap);
    // More grows with the state of what it hides ("Running… 2/3").
    double moreWidth(Iterable<ButtonView> hidden) {
      final loud = _loudest(hidden);
      final icon = loud == null ? 0.0 : 18.0 + Spacing.xs;
      return iconOnly
          ? 44 + icon
          : _MoreButton.chrome + icon + textWidth(_MoreButton.textOf(loud));
    }

    var shown = views.length;
    if (all > budget) {
      var used = 0.0;
      shown = 0;
      while (shown < views.length && used + widths[shown] + _gap <= budget) {
        used += widths[shown] + _gap;
        shown++;
      }
      while (shown > 0 && used + moreWidth(views.skip(shown)) > budget) {
        shown--;
        used -= widths[shown] + _gap;
      }
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final v in views.take(shown)) ...[
          _ActionButton(
            view: v,
            iconOnly: iconOnly,
            tintSeed: tintSeed,
            onPressed: () => onPressed(v),
            onStop: v.run == null ? null : () => onStop(v.run!.runId),
          ),
          const SizedBox(width: _gap),
        ],
        if (shown < views.length)
          _MoreButton(
            views: views.skip(shown).toList(),
            iconOnly: iconOnly,
            onPressed: onPressed,
            onStop: onStop,
          ),
      ],
    );
  }
}

/// A dot on a button's icon: unsaved form, consent / review, last failed.
Color? _dotColor(BuildContext context, ButtonView view) {
  final theme = Theme.of(context);
  final semantic = theme.extension<MorkvaSemanticColors>();
  final warning = semantic?.warning ?? theme.colorScheme.tertiary;
  return switch (view.phase) {
    ButtonPhase.needsConsent || ButtonPhase.review => warning,
    ButtonPhase.failed => theme.colorScheme.error,
    _ when view.dirty => theme.colorScheme.primary,
    _ => null,
  };
}

/// The words a screen reader hears for a button's state.
String _stateWord(ButtonView v) => switch (v.phase) {
  ButtonPhase.idle => v.dirty ? 'saves first' : '',
  ButtonPhase.needsConsent => 'needs consent',
  // The phase only: progress ticks are never announced.
  ButtonPhase.queued => 'queued',
  ButtonPhase.running => 'running',
  ButtonPhase.review => 'waiting for review',
  ButtonPhase.failed => 'last run failed',
};

/// The icon slot: a 14 px spinner while running, a clock while queued, else
/// the button's icon with its dot.
class _ButtonIcon extends StatelessWidget {
  const _ButtonIcon({required this.view, required this.color});

  final ButtonView view;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final dot = _dotColor(context, view);
    return SizedBox(
      width: 18,
      height: 18,
      child: switch (view.phase) {
        ButtonPhase.running => Center(
          child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: color),
          ),
        ),
        ButtonPhase.queued => Icon(
          Icons.schedule_rounded,
          size: 18,
          color: color,
        ),
        _ => Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(buttonIconOf(view.entry), size: 18, color: color),
            if (dot != null)
              Positioned(
                right: -3,
                top: -3,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dot,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.surface,
                    ),
                  ),
                ),
              ),
          ],
        ),
      },
    );
  }
}

/// One header button: 36 px tint pill in a 44 px hit area; a dirty form
/// opens "Save and run", a long press on a live run offers Stop.
class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.view,
    required this.iconOnly,
    required this.tintSeed,
    required this.onPressed,
    required this.onStop,
  });

  final ButtonView view;
  final bool iconOnly;
  final String tintSeed;
  final VoidCallback onPressed;
  final VoidCallback? onStop;

  /// Horizontal padding, icon and gap around the label.
  static const double chrome = Spacing.sm * 2 + 18 + Spacing.xs;

  static String textOf(ButtonView v) =>
      v.busy ? liveRunLabel(v.run!) : shortButtonLabel(v.label);

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  final _menu = MenuController();

  ButtonView get view => widget.view;

  void _tap() {
    if (view.dirty && view.phase == ButtonPhase.idle) {
      _menu.open();
    } else {
      widget.onPressed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = buttonTintOf(
      view.entry.automation.button?.tint,
      widget.tintSeed,
      theme.brightness,
    );
    final description = view.entry.action?.description;
    final tooltip = [
      if (widget.iconOnly || view.label.length > 16) view.label,
      ?description,
    ].join(' — ');
    final state = _stateWord(view);
    final pill = Container(
      height: 36,
      padding: EdgeInsets.symmetric(
        horizontal: widget.iconOnly ? Spacing.sm - 2 : Spacing.sm,
      ),
      decoration: BoxDecoration(
        color: tint.background,
        borderRadius: Radii.mdAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ButtonIcon(view: view, color: tint.foreground),
          if (!widget.iconOnly) ...[
            const SizedBox(width: Spacing.xs),
            Text(
              _ActionButton.textOf(view),
              maxLines: 1,
              style: theme.textTheme.labelLarge?.copyWith(
                color: tint.foreground,
              ),
            ),
          ],
        ],
      ),
    );
    final button = Semantics(
      button: true,
      liveRegion: view.phase != ButtonPhase.idle,
      label: [view.label, if (state.isNotEmpty) state].join(', '),
      excludeSemantics: true,
      onTap: _tap,
      onLongPress: view.busy && widget.onStop != null ? _menu.open : null,
      child: GestureDetector(
        onLongPress: view.busy && widget.onStop != null ? _menu.open : null,
        child: PressableScale(
          onPressed: _tap,
          borderRadius: Radii.mdAll,
          child: SizedBox(height: 44, child: Center(child: pill)),
        ),
      ),
    );
    return MenuAnchor(
      controller: _menu,
      menuChildren: view.busy
          ? [
              MenuItemButton(
                leadingIcon: const Icon(Icons.stop_circle_outlined),
                onPressed: widget.onStop,
                child: const Text('Stop'),
              ),
            ]
          : [
              _SaveAndRunMenu(
                onSaveAndRun: () {
                  _menu.close();
                  widget.onPressed();
                },
                onCancel: _menu.close,
              ),
            ],
      child: tooltip.isEmpty
          ? button
          : Tooltip(message: tooltip, child: button),
    );
  }
}

/// The menu a press on a dirty form opens: **Save and run** · Cancel.
class _SaveAndRunMenu extends StatelessWidget {
  const _SaveAndRunMenu({required this.onSaveAndRun, required this.onCancel});

  final VoidCallback onSaveAndRun;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 232,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.xs,
              Spacing.xs,
              Spacing.xs,
              0,
            ),
            child: PrimaryButton(
              label: 'Save and run',
              icon: Icons.bolt_rounded,
              expand: true,
              onPressed: onSaveAndRun,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.sm,
              Spacing.xs,
              Spacing.sm,
              Spacing.xs,
            ),
            child: Text(
              'The action works on the saved card.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const Divider(height: 1),
          MenuItemButton(onPressed: onCancel, child: const Text('Cancel')),
        ],
      ),
    );
  }
}

/// The view whose state **More** shows: running, then queued, waiting for
/// review, last failed.
ButtonView? _loudest(Iterable<ButtonView> views) {
  for (final phase in const [
    ButtonPhase.running,
    ButtonPhase.queued,
    ButtonPhase.review,
    ButtonPhase.failed,
  ]) {
    final v = views.where((v) => v.phase == phase).firstOrNull;
    if (v != null) return v;
  }
  return null;
}

/// **More ▾**: the buttons that didn't fit (Stop under a live one), with the
/// state of the busiest one on its face.
class _MoreButton extends StatefulWidget {
  const _MoreButton({
    required this.views,
    required this.iconOnly,
    required this.onPressed,
    required this.onStop,
  });

  final List<ButtonView> views;
  final bool iconOnly;
  final ValueChanged<ButtonView> onPressed;
  final ValueChanged<String> onStop;

  static const double chrome = Spacing.sm * 2 + Spacing.xxs + 18;

  static String textOf(ButtonView? loud) =>
      loud != null && loud.busy ? liveRunLabel(loud.run!) : 'More';

  @override
  State<_MoreButton> createState() => _MoreButtonState();
}

class _MoreButtonState extends State<_MoreButton> {
  /// The rows as the menu opened. A run ending while it is open drops its
  /// Stop row; the rows below moved up and a stale tap started another
  /// action (web e2e 2026-11-12), so the rows stay put until it closes.
  List<ButtonView>? _opened;

  @override
  Widget build(BuildContext context) {
    final views = widget.views;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final loud = _loudest(views);
    final dot = loud == null ? null : _dotColor(context, loud);
    final state = switch (loud?.phase) {
      // `info`, as every other running spinner.
      ButtonPhase.running => Center(
        child: SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: theme.extension<MorkvaSemanticColors>()!.info,
          ),
        ),
      ),
      ButtonPhase.queued => Icon(
        Icons.schedule_rounded,
        size: 18,
        color: scheme.onSurface,
      ),
      _ when dot != null => Center(
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
      ),
      _ => null,
    };
    final said = loud == null
        ? 'More actions'
        : 'More actions, ${loud.label} ${_stateWord(loud)}';
    // A row shows its automation as it stands now (it may have moved to the
    // header); a Stop row whose run ended stays, disabled.
    ButtonView now(ButtonView was) =>
        views
            .where((v) => v.entry.automation.id == was.entry.automation.id)
            .firstOrNull ??
        was;
    return MenuAnchor(
      onOpen: () => _opened = views,
      onClose: () => _opened = null,
      menuChildren: [
        for (final (was, v) in [
          for (final was in _opened ?? views) (was, now(was)),
        ]) ...[
          MenuItemButton(
            leadingIcon: _ButtonIcon(view: v, color: scheme.onSurface),
            onPressed: () => widget.onPressed(v),
            child: Text(
              v.busy ? '${v.label} · ${liveRunLabel(v.run!)}' : v.label,
            ),
          ),
          if (was.busy)
            MenuItemButton(
              leadingIcon: const Icon(Icons.stop_circle_outlined),
              onPressed: v.busy ? () => widget.onStop(v.run!.runId) : null,
              child: Text('Stop ${v.label}'),
            ),
        ],
      ],
      builder: (context, controller, _) => Tooltip(
        message: loud == null
            ? 'More actions'
            : '${loud.label} · ${loud.busy ? liveRunLabel(loud.run!) : _stateWord(loud)}',
        child: PressableScale(
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
          semanticLabel: said,
          borderRadius: Radii.mdAll,
          child: SizedBox(
            height: 44,
            child: Center(
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: Radii.mdAll,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (state != null) ...[
                      SizedBox(width: 18, height: 18, child: state),
                      const SizedBox(width: Spacing.xs),
                    ],
                    if (!widget.iconOnly) ...[
                      Text(
                        _MoreButton.textOf(loud),
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(width: Spacing.xxs),
                    ],
                    Icon(
                      Icons.expand_more_rounded,
                      size: 18,
                      color: scheme.onSurface,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The phone card editor's ⚡: a spinner ring with `n/N` while a run of this
/// card is live (UX §4 phone, artboard 13).
class PhoneActionsButton extends StatelessWidget {
  const PhoneActionsButton({
    super.key,
    required this.views,
    required this.onOpen,
  });

  final List<ButtonView> views;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final live = views.where((v) => v.busy).map((v) => v.run!).firstOrNull;
    if (live == null) {
      return IconActionButton(
        icon: Icons.bolt_rounded,
        tooltip: 'Actions',
        onPressed: onOpen,
      );
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // `info`, as every other running spinner (sidebar pill, rail, run rows).
    final info = theme.extension<MorkvaSemanticColors>()!.info;
    final p = live.progress;
    final value = p == null || p.total <= 0 ? null : p.done / p.total;
    return Tooltip(
      message: '${live.label} · ${liveRunLabel(live)}',
      child: PressableScale(
        onPressed: onOpen,
        semanticLabel: 'Actions, ${live.label} ${liveRunLabel(live)}',
        borderRadius: Radii.fullAll,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: Spacing.xxs),
          decoration: BoxDecoration(
            color: info.withValues(alpha: 0.12),
            borderRadius: Radii.fullAll,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        key: const ValueKey('run-ring'),
                        value: value,
                        strokeWidth: 2.5,
                        color: info,
                        backgroundColor: scheme.outlineVariant,
                      ),
                    ),
                    Icon(Icons.bolt_rounded, size: 18, color: scheme.onSurface),
                  ],
                ),
              ),
              if (p != null && p.total > 0)
                Padding(
                  padding: const EdgeInsets.only(
                    left: Spacing.xxs,
                    right: Spacing.xs,
                  ),
                  child: Text(
                    '${p.done}/${p.total}',
                    style: theme.textTheme.labelLarge,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The 2 px line under the phone editor's app bar while a run of this card
/// is live.
class CardRunProgress extends StatelessWidget implements PreferredSizeWidget {
  const CardRunProgress({
    super.key,
    required this.collectionId,
    required this.cardId,
  });

  final String collectionId;
  final String? cardId;

  @override
  Size get preferredSize => const Size.fromHeight(2);

  @override
  Widget build(BuildContext context) {
    final runs = maybeRead<AutomationRunsCubit>(context);
    final card = cardId;
    if (runs == null || card == null) return const SizedBox(height: 2);
    return BlocBuilder<AutomationRunsCubit, AutomationRunsState>(
      bloc: runs,
      builder: (context, r) {
        final live = r.activity.runs
            .where(
              (x) =>
                  x.trigger.cardId == card &&
                  x.trigger.collectionId == collectionId &&
                  x.status != RunStatus.awaitingReview,
            )
            .firstOrNull;
        if (live == null) return const SizedBox(height: 2);
        final p = live.progress;
        return SizedBox(
          height: 2,
          child: LinearProgressIndicator(
            value: p == null || p.total <= 0 ? null : p.done / p.total,
            minHeight: 2,
            color: Theme.of(context).extension<MorkvaSemanticColors>()!.info,
          ),
        );
      },
    );
  }
}

/// The **Actions** bottom sheet (phone card ⚡, the collection's "Run
/// action…"): one row per button, live; a row closes the sheet and runs.
Future<void> showActionsSheet(
  BuildContext context, {
  required AutomationRunsCubit runs,
  required ModulesCubit modules,
  required List<ButtonView> Function(AutomationRunsState, ModulesState) build,
  required ValueChanged<ButtonView> onSelect,
  String subtitle = 'The action works on the saved card.',
  String tintSeed = '',
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  useSafeArea: true,
  isScrollControlled: true,
  backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
  ),
  builder: (sheet) => BlocBuilder<ModulesCubit, ModulesState>(
    bloc: modules,
    builder: (_, m) => BlocBuilder<AutomationRunsCubit, AutomationRunsState>(
      bloc: runs,
      builder: (_, r) => _ActionsSheet(
        views: build(r, m),
        subtitle: subtitle,
        tintSeed: tintSeed,
        onSelect: (v) {
          Navigator.of(sheet).pop();
          onSelect(v);
        },
        onStop: runs.stop,
      ),
    ),
  ),
);

class _ActionsSheet extends StatelessWidget {
  const _ActionsSheet({
    required this.views,
    required this.subtitle,
    required this.tintSeed,
    required this.onSelect,
    required this.onStop,
  });

  final List<ButtonView> views;
  final String subtitle;
  final String tintSeed;
  final ValueChanged<ButtonView> onSelect;
  final ValueChanged<String> onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.lg,
          0,
          Spacing.lg,
          Spacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Actions', style: theme.textTheme.headlineSmall),
            const SizedBox(height: Spacing.xxs),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Spacing.sm),
            if (views.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.md),
                child: Text(
                  'No buttons yet.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            for (final v in views)
              _SheetRow(
                view: v,
                tintSeed: tintSeed,
                onTap: () => onSelect(v),
                onStop: v.run == null ? null : () => onStop(v.run!.runId),
              ),
          ],
        ),
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.view,
    required this.tintSeed,
    required this.onTap,
    required this.onStop,
  });

  final ButtonView view;
  final String tintSeed;
  final VoidCallback onTap;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tint = buttonTintOf(
      view.entry.automation.button?.tint,
      tintSeed.isEmpty ? view.entry.automation.trigger.collectionId : tintSeed,
      theme.brightness,
    );
    final module = view.entry.module?.module.name ?? view.entry.automation.name;
    final lead = switch (view.phase) {
      ButtonPhase.needsConsent => 'Needs consent',
      ButtonPhase.review => 'Needs review',
      ButtonPhase.failed => 'Last run failed',
      ButtonPhase.queued || ButtonPhase.running => liveRunLabel(view.run!),
      ButtonPhase.idle => view.dirty ? 'Save and run' : null,
    };
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return InkWell(
      onTap: view.busy ? null : onTap,
      borderRadius: Radii.mdAll,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tint.background,
                  borderRadius: Radii.mdAll,
                ),
                child: _ButtonIcon(
                  view: ButtonView(
                    entry: view.entry,
                    phase: view.phase,
                    run: view.run,
                  ),
                  color: tint.foreground,
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(view.label, style: theme.textTheme.titleSmall),
                    Text.rich(
                      TextSpan(
                        children: [
                          if (lead != null) ...[
                            TextSpan(
                              text: lead,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface,
                              ),
                            ),
                            const TextSpan(text: ' · '),
                          ],
                          TextSpan(text: module),
                        ],
                      ),
                      style: muted,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (view.busy && onStop != null)
                TextActionButton(label: 'Stop', onPressed: onStop),
            ],
          ),
        ),
      ),
    );
  }
}
