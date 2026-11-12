import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/automation/apply_policy.dart';
import '../../../core/automation/runner_api.dart';
import '../../../core/domain/automation/automation.dart';
import '../../../core/domain/domain.dart';
import '../../../core/harness/plan/plan_committer.dart';
import '../../../design/design.dart';
import '../bloc/modules_cubit.dart';
import '../bloc/run_log_cubit.dart';
import '../widgets/reason_copy.dart';
import '../widgets/status_chip.dart';
import 'automations_page.dart';
import 'test_run_sheet.dart';

/// `/automations/runs/:id` (UX §7): a run's trigger, inputs, calls, console,
/// plan, links and outcome, with Undo / Run again / Stop. Always its own
/// page. A queued or running run has no doc yet: it shows its live view.
///
/// Reads [RunLogCubit], [ModulesCubit] (automation names for the chain),
/// [CollectionsListCubit] and the [AutomationsHost].
class RunDetailPage extends StatefulWidget {
  const RunDetailPage({
    super.key,
    required this.runId,
    this.now = DateTime.now,
  });

  final String runId;
  final DateTime Function() now;

  @override
  State<RunDetailPage> createState() => _RunDetailPageState();
}

class _RunDetailPageState extends State<RunDetailPage>
    with TickerRefresh<RunDetailPage> {
  late Future<void> _loading = context.read<RunLogCubit>().load(widget.runId);

  @override
  void didUpdateWidget(RunDetailPage old) {
    super.didUpdateWidget(old);
    if (old.runId != widget.runId) {
      _loading = context.read<RunLogCubit>().load(widget.runId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final runLog = context.read<RunLogCubit>();
    final state = context.watch<RunLogCubit>().state;
    final host = context.read<AutomationsHost>();
    final row = state.row(widget.runId);
    final live = state.liveRun(widget.runId);
    final now = widget.now();
    // The undo countdown: re-map once the deadline passes.
    final until = row?.undoUntil;
    tickWhile(
      until != null,
      onTick: () {
        if (!widget.now().isBefore(until!)) runLog.refresh();
      },
    );
    final pad = automationsExpanded(context) ? Spacing.xxl : Spacing.md;
    final Widget body;
    if (row != null) {
      body = _Detail(row: row, live: live, now: now);
    } else if (live != null) {
      body = _LiveDetail(run: live);
    } else {
      body = FutureBuilder<void>(
        future: _loading,
        builder: (context, snap) => state.loadFailed || snap.hasError
            ? AutomationLoadError(
                title: "Couldn't load this run",
                onRetry: () {
                  setState(() {
                    _loading = runLog.load(widget.runId);
                  });
                  if (state.loadFailed) runLog.retry();
                },
              )
            : snap.connectionState != ConnectionState.done || state.loading
            ? const Center(child: LoadingIndicator())
            : const EmptyState(
                icon: Icons.history,
                title: 'This run isn\'t in the log',
                message: 'It may have been removed with older runs.',
              ),
      );
    }
    return BlocListener<RunLogCubit, RunLogState>(
      listenWhen: (a, b) => b.error != null && a.error != b.error,
      listener: (context, s) {
        showAutomationSnack(context, s.error!);
        runLog.clearError();
      },
      child: Material(
        type: MaterialType.transparency,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 1040 + 2 * pad),
            child: Padding(
              padding: EdgeInsets.fromLTRB(pad, Spacing.sm, pad, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextActionButton(
                      label: 'Runs',
                      icon: Icons.arrow_back,
                      onPressed: () =>
                          host.openAutomations(tab: AutomationsTab.runs),
                    ),
                  ),
                  Expanded(child: body),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Succeeded", "Failed", … for the header badge.
String statusLabel(RunStatus status) => switch (status) {
  RunStatus.queued => 'Queued',
  RunStatus.running || RunStatus.sealing => 'Running',
  RunStatus.applying => 'Applying',
  RunStatus.awaitingReview => 'Needs review',
  RunStatus.succeeded => 'Succeeded',
  RunStatus.failed => 'Failed',
  RunStatus.timedOut => 'Timed out',
  RunStatus.skipped => 'Skipped',
  RunStatus.rejected => 'Rejected',
  RunStatus.expired => 'Expired',
};

/// The header badge's glyph (succeeded ✓, failed ⊗, undone ↶).
IconData? statusIcon(RunStatus status, {bool undone = false}) =>
    switch (status) {
      RunStatus.succeeded when undone => Icons.undo_rounded,
      RunStatus.succeeded => Icons.check_rounded,
      RunStatus.failed || RunStatus.timedOut => Icons.cancel_outlined,
      RunStatus.awaitingReview => Icons.visibility_outlined,
      _ => null,
    };

class _LiveDetail extends StatelessWidget {
  const _LiveDetail({required this.run});

  final RunView run;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final copy = runCopy(run.status, run.reason);
    final p = run.progress;
    return ListView(
      children: [
        const SizedBox(height: Spacing.sm),
        Wrap(
          spacing: Spacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            HugChip(label: statusLabel(run.status), tone: copy.tone),
            Text(run.label, style: theme.textTheme.headlineSmall),
          ],
        ),
        const SizedBox(height: Spacing.sm),
        Text(
          [
            copy.row,
            if (run.queuedAhead != null) '${run.queuedAhead} ahead',
            if (p != null)
              '${p.done}/${p.total}${p.label == null ? '' : ' · ${p.label}'}',
          ].join(' · '),
          style: theme.textTheme.bodyMedium,
        ),
        if (p != null && p.total > 0) ...[
          const SizedBox(height: Spacing.sm),
          LinearProgressIndicator(value: p.done / p.total),
        ],
        const SizedBox(height: Spacing.md),
        if (run.status != RunStatus.applying)
          Align(
            alignment: Alignment.centerLeft,
            child: SecondaryButton(
              label: 'Stop',
              icon: Icons.stop_circle_outlined,
              onPressed: () => context.read<RunLogCubit>().stop(run.runId),
            ),
          ),
      ],
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.row, required this.live, required this.now});

  final RunRow row;
  final RunView? live;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final runLog = context.read<RunLogCubit>();
    final host = context.read<AutomationsHost>();
    final collections = automationCollections(context);
    final modules = context.watch<ModulesCubit>().state;
    final automations = modules.automations;
    final offline = automationsOffline(context);
    final run = row.run;
    final collection = collectionOf(collections, run.trigger.collectionId);
    final card = run.trigger.cardLabel;
    // The action's input titles ("Date field"), when the module is known.
    final inputs = modules.modules
        .where((m) => m.module.id == run.moduleId)
        .firstOrNull
        ?.module
        .manifest
        ?.actions
        .where((a) => a.id == run.actionId)
        .firstOrNull
        ?.input
        ?.properties;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final subtitle = [
      '${run.moduleName} v${run.moduleVersion} › ${run.actionLabel}',
      run.apply == ApplyMode.auto ? 'Auto' : 'Ask first',
      'on ${run.device}',
      '${dayMonth(run.startedAt)} ${clock(run.startedAt)}',
      if (run.durationMs != null) durationLabel(run.durationMs),
    ].join(' · ');

    Future<void> again() async {
      final id = await runLog.runAgain(run.id);
      if (id != null) host.openRun(id);
    }

    // Run detail also re-runs a finished button run (UX §7 header); the
    // lists don't, since "Run again" there reads as "it didn't work".
    final canRunAgain =
        row.action == RunRowAction.runAgain ||
        (row.action == RunRowAction.none &&
            run.status == RunStatus.succeeded &&
            run.trigger.kind == TriggerKind.button &&
            (run.receipt?.unconfirmed ?? 0) == 0 &&
            automations.any(
              (a) =>
                  a.automation.id == run.automationId &&
                  a.status != AutomationStatus.needsConsent &&
                  a.status != AutomationStatus.broken,
            ));
    final notHere = row.display == RunDisplay.reviewNotHere;
    final undoLabel = row.undoUntil == null
        ? 'Undo'
        : 'Undo · ${_left(row.undoUntil!.difference(now))}';
    final actions = Wrap(
      spacing: Spacing.xs,
      runSpacing: Spacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (row.undo == UndoState.available)
          SecondaryButton(
            label: 'Undo',
            icon: Icons.undo,
            onPressed: () => runLog.undo(run.id),
          ),
        if (row.action == RunRowAction.review)
          SecondaryButton(
            label: 'Review',
            onPressed: () => host.review(run.id),
          ),
        // Tonal when it leads (a failed run); a link beside Undo.
        if (canRunAgain && row.undo == UndoState.available)
          TextActionButton(
            label: card == null ? 'Run again' : 'Run again on $card',
            icon: Icons.refresh,
            onPressed: offline ? null : again,
          )
        else if (canRunAgain)
          SecondaryButton(
            label: card == null ? 'Run again' : 'Run again on $card',
            icon: Icons.refresh,
            onPressed: offline ? null : again,
          ),
        if (canRunAgain && offline) Text('Needs a connection', style: muted),
        if (live != null && live!.status != RunStatus.applying)
          TextActionButton(
            label: 'Stop',
            icon: Icons.stop_circle_outlined,
            onPressed: () => runLog.stop(run.id),
          ),
        if (run.trigger.cardId case final cardId?
            when run.trigger.kind != TriggerKind.cardDeleted)
          TextActionButton(
            label: 'Open card',
            icon: Icons.open_in_new,
            onPressed: () => host.openCard(run.trigger.collectionId, cardId),
          ),
        if (run.automationId case final id?)
          TextActionButton(
            label: 'Edit automation',
            icon: Icons.edit_outlined,
            onPressed: () => host.editAutomation(id),
          ),
        PopupMenuButton<void>(
          tooltip: 'More',
          icon: const Icon(Icons.more_horiz),
          // 44 px, like every other target here (the default is 40).
          style: IconButton.styleFrom(minimumSize: const Size.square(44)),
          itemBuilder: (_) => [
            PopupMenuItem(
              onTap: () {
                Clipboard.setData(ClipboardData(text: runLogJson(run)));
                showAutomationSnack(context, 'Copied the run log');
              },
              child: const Text('Copy log'),
            ),
          ],
        ),
      ],
    );

    final log = run.log;
    final names = {
      for (final a in automations) a.automation.id: a.automation.name,
    };
    final steps = <Widget>[
      _Step(
        title: 'Trigger',
        summary: whenLine(switch (run.trigger.kind) {
          TriggerKind.button => ButtonTrigger(
            scope: run.trigger.cardId == null
                ? ButtonScope.collection
                : ButtonScope.card,
            collectionId: run.trigger.collectionId,
          ),
          final kind => EventTrigger(
            kind: kind,
            collectionId: run.trigger.collectionId,
          ),
        }, collection),
        children: [
          Text(triggerLine(run, collection), style: theme.textTheme.bodyMedium),
          if (run.chain.length > 1) ...[
            const SizedBox(height: Spacing.xs),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  [
                    for (final id in run.chain.take(run.chain.length - 1))
                      names[id] ?? 'An automation',
                  ].join(' › '),
                  style: muted,
                ),
                Text(' › ', style: muted),
                Text(
                  '${run.automationName ?? run.actionLabel} (this run)',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (run.parentRunId case final parent?)
                  TextActionButton(
                    label: 'Previous run',
                    onPressed: () => host.openRun(parent),
                  ),
              ],
            ),
          ],
          if (log.triggerEval case final eval?) ...[
            const SizedBox(height: Spacing.xs),
            Text(
              eval,
              style: MorkvaTypography.mono(
                theme.textTheme.bodySmall!,
              ).copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
      if (run.params case final params? when params.isNotEmpty)
        _Step(
          title: 'Inputs',
          children: [
            for (final MapEntry(:key, :value) in params.entries)
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${inputs?[key]?.title ?? key}: ',
                      style: muted,
                    ),
                    TextSpan(
                      text: switch (value) {
                        final String id
                            when collection?.fieldById(id) != null =>
                          collection!.fieldById(id)!.name,
                        _ => '$value',
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      _Step(
        title: 'Calls',
        count: log.calls.length,
        children: [
          if (log.calls.isEmpty) Text('No calls', style: muted),
          for (final (i, c) in log.calls.indexed) ...[
            if (i > 0)
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
            _CallRow(call: c, collections: collections, fallback: collection),
          ],
          if (log.dropped.calls > 0)
            Text('+${log.dropped.calls} calls dropped', style: muted),
        ],
      ),
      if (log.console.isNotEmpty)
        _Step(
          title: 'Console',
          count: log.console.length,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Spacing.sm),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: Radii.smAll,
              ),
              child: SelectionArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final c in log.console)
                      ConsoleLineText(
                        line: c,
                        style: MorkvaTypography.mono(
                          theme.textTheme.bodySmall!,
                        ),
                      ),
                    if (log.dropped.console > 0)
                      Text(
                        '+${log.dropped.console} lines dropped',
                        style: muted,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      if (log.plan.isNotEmpty)
        _Step(
          title: 'Plan',
          summary: [
            changeCount(log),
            // A policy line means it asked first; applyStartedAt is the
            // approve.
            if (log.policy != null && run.applyStartedAt != null)
              'approved by you at ${clock(run.applyStartedAt!)}',
          ].join(' · '),
          children: [
            for (final p in log.plan)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.xxs),
                child: PlanLineRow(line: p),
              ),
            // The default "asks first" policy repeats the header's approval.
            if (log.policy case final policy? when policy != kAskFirstPolicy)
              Padding(
                padding: const EdgeInsets.only(top: Spacing.xs),
                child: Text(askedFirstLine(policy), style: muted),
              ),
          ],
        ),
      if (log.ui.isNotEmpty)
        _Step(
          title: 'Links',
          children: [
            Wrap(
              spacing: Spacing.xs,
              children: [
                for (final l in log.ui)
                  TextActionButton(
                    label: 'Open ${l.label}',
                    icon: Icons.open_in_new,
                    onPressed: () => host.openLink(l),
                  ),
              ],
            ),
          ],
        ),
      if (run.status == RunStatus.succeeded)
        _Step(
          title: 'Outcome',
          last: true,
          tone: row.copy.tone,
          summary: _appliedLine(run),
          summaryIcon: Icon(
            Icons.check_circle_outline,
            size: 16,
            color: theme.extension<MorkvaSemanticColors>()!.success,
          ),
          // On a phone the header has no room: Undo goes under it.
          trailing: automationsExpanded(context)
              ? _UndoSlot(row: row, label: undoLabel)
              : null,
          children: [
            if (!automationsExpanded(context) && row.undo != UndoState.none)
              _UndoSlot(row: row, label: undoLabel),
            if ((run.receipt?.failed ?? 0) > 0)
              TextActionButton(
                label: 'Retry failed',
                icon: Icons.refresh,
                onPressed: offline ? null : () => runLog.retryFailed(run.id),
              ),
          ],
        )
      else
        _Step(
          title: 'Outcome',
          last: true,
          tone: row.copy.tone,
          children: [_Outcome(row: row, offline: offline)],
        ),
    ];

    return ListView(
      padding: const EdgeInsets.only(bottom: Spacing.xl),
      children: [
        const SizedBox(height: Spacing.xs),
        Wrap(
          spacing: Spacing.sm,
          runSpacing: Spacing.xxs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Another window's review: muted, like the Runs list's ring.
            HugChip(
              label: run.undoneAt != null
                  ? 'Undone'
                  : notHere
                  ? 'Review elsewhere'
                  : statusLabel(run.status),
              tone: notHere ? CopyTone.muted : row.copy.tone,
              icon: notHere
                  ? Icons.radio_button_unchecked
                  : statusIcon(run.status, undone: run.undoneAt != null),
            ),
            Text(
              run.automationName ?? run.actionLabel,
              style: theme.textTheme.headlineSmall,
            ),
          ],
        ),
        const SizedBox(height: Spacing.xxs),
        Text(subtitle, style: muted),
        const SizedBox(height: Spacing.sm),
        actions,
        const SizedBox(height: Spacing.md),
        ...steps,
      ],
    );
  }
}

/// "9 min left" / "40 s left".
String _left(Duration d) => d.inMinutes >= 1
    ? '${d.inMinutes + (d.inSeconds % 60 > 0 ? 1 : 0)} min left'
    : '${d.inSeconds.clamp(0, 59)} s left';

/// "Button pressed on #1042", "Status changed on #1042", …
String triggerLine(RunRecord run, Collection? collection) {
  final t = run.trigger;
  final card = t.cardLabel ?? 'a card';
  final base = switch (t.kind) {
    TriggerKind.button when t.cardId == null =>
      'Button pressed on ${collection?.name ?? 'a collection'} · '
          '${t.cardCount} ${t.cardCount == 1 ? 'card' : 'cards'}',
    TriggerKind.button => 'Button pressed on $card',
    TriggerKind.cardCreated => 'Created $card',
    TriggerKind.cardDeleted => 'Deleted $card',
    TriggerKind.cardUpdated when t.changedFields.isNotEmpty =>
      '${[for (final f in t.changedFields) collection?.fieldById(f)?.name ?? f].join(', ')} changed on $card',
    TriggerKind.cardUpdated => 'Updated $card',
  };
  final changed = t.changedAt;
  return changed != null && run.startedAt.difference(changed).inMinutes >= 1
      ? '$base · Changed offline ${clock(changed)} · ran ${clock(run.startedAt)}'
      : base;
}

/// The run doc as pretty JSON (Copy log): dates as ISO strings, the log
/// decoded.
String runLogJson(RunRecord run) {
  final doc = run.toJson();
  doc['id'] = run.id;
  doc['log'] = jsonDecode(doc['log']! as String);
  return JsonEncoder.withIndent(
    '  ',
    (o) => o is DateTime ? o.toUtc().toIso8601String() : '$o',
  ).convert(doc);
}

/// "collection: c_orders · target: {ids} · set: {f_ship}" → "Orders ·
/// Shipped on": the collection and field names among the logged keys and
/// string args; the rest (key names, numbers) drops. Fields resolve in the
/// call's own collection, else [fallback] (the trigger's).
String callTargets(
  String args,
  List<Collection> collections,
  Collection? fallback,
) {
  final tokens = [
    for (final part in args.split(' · '))
      if (part.indexOf(': ') case final i when i > 0)
        for (final t in part.substring(i + 2).split(RegExp(r'[{}]|, ')))
          if (t.trim().isNotEmpty) t.trim(),
  ];
  final byId = {for (final c in collections) c.id: c};
  final own = tokens.map((t) => byId[t]).nonNulls.firstOrNull ?? fallback;
  return {
    for (final t in tokens) ?(byId[t]?.name ?? own?.fieldById(t)?.name),
  }.join(' · ');
}

/// "Filtered 10 → 1 Products" → "Filtered 10 → 1 product": the harness
/// summary names the collection (the agent reads it that way); the log
/// counts in item nouns like the plan and banners. Unknown names stay.
String callResultCopy(String result, List<Collection> collections) =>
    result.replaceFirstMapped(
      RegExp(r'^((?:Filtered \d+ → )?)(\d+) (.+?)(?= · |$)'),
      (m) => switch (collections.where((c) => c.name == m[3]).firstOrNull) {
        null => m[0]!,
        final c => '${m[1]}${PlanCommitter.cards(c, int.parse(m[2]!))}',
      },
    );

class _CallRow extends StatelessWidget {
  const _CallRow({
    required this.call,
    this.collections = const [],
    this.fallback,
  });

  final RunCall call;
  final List<Collection> collections;
  final Collection? fallback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = call.ok ? scheme.onSurface : scheme.error;
    // The mock's `.mono` is 400 13px/20px.
    final mono = MorkvaTypography.mono(
      theme.textTheme.bodyMedium!.copyWith(fontSize: 13, height: 20 / 13),
    );
    final targets = callTargets(call.args, collections, fallback);
    final text = [
      if (targets.isNotEmpty) targets,
      if (!(call.ok && call.result == 'Done') || targets.isEmpty)
        callResultCopy(call.result, collections),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(call.op, style: mono.copyWith(color: color)),
          ),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
          Text(
            '${call.ms} ms',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: Spacing.xs),
          Icon(
            call.ok ? Icons.check : Icons.close,
            size: 16,
            color: call.ok
                ? theme.extension<MorkvaSemanticColors>()!.success
                : scheme.error,
          ),
        ],
      ),
    );
  }
}

/// "Applied 1 change · 12:05", "Updated 190, 10 failed · 12:05": a
/// succeeded run's Outcome header.
String _appliedLine(RunRecord run) {
  final applied = run.receipt?.applied ?? 0;
  final failed = run.receipt?.failed ?? 0;
  final head = failed > 0
      ? 'Updated $applied, $failed failed'
      : applied == 0
      ? (run.summary ?? 'No changes')
      : 'Applied $applied ${applied == 1 ? 'change' : 'changes'}';
  return [head, if (run.endedAt != null) clock(run.endedAt!)].join(' · ');
}

/// A succeeded run's Undo, or why there is none.
class _UndoSlot extends StatelessWidget {
  const _UndoSlot({required this.row, required this.label});

  final RunRow row;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final run = row.run;
    return switch (row.undo) {
      UndoState.available => SecondaryButton(
        label: label,
        icon: Icons.undo,
        onPressed: () => context.read<RunLogCubit>().undo(run.id),
      ),
      UndoState.expired => Text('Undo expired', style: muted),
      UndoState.afterReload => Text(
        "Undo isn't available after a reload",
        style: muted,
      ),
      UndoState.undone => Text(
        'Reverted · ${clock(run.undoneAt!)}',
        style: muted,
      ),
      UndoState.none => const SizedBox.shrink(),
    };
  }
}

/// The Outcome of a run that didn't succeed: the reason, the error and its
/// stack, and the fix.
class _Outcome extends StatelessWidget {
  const _Outcome({required this.row, required this.offline});

  final RunRow row;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final runLog = context.read<RunLogCubit>();
    final host = context.read<AutomationsHost>();
    final run = row.run;
    final copy = row.copy;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    final error = run.error;
    final advice = copy.advice;
    final fix = advice?.fix;
    final VoidCallback? onFix = switch (fix) {
      null => null,
      RunFix.reviewPermissions ||
      RunFix.changeAccess => () => host.openModule(run.moduleId),
      RunFix.editAutomation =>
        run.automationId == null
            ? null
            : () => host.editAutomation(run.automationId!),
      RunFix.resume =>
        run.automationId == null
            ? null
            : () => runLog.resume(run.automationId!),
      RunFix.runAgain =>
        row.action == RunRowAction.runAgain && !offline
            ? () => runLog.runAgain(run.id)
            : null,
      RunFix.askMorkva => switch (host.askMorkva) {
        final ask? => () => ask(
          'Fix the module "${run.moduleName}": '
          '${error?.message ?? copy.row}',
        ),
        null => null,
      },
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: Spacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (copy.tone == CopyTone.error)
              Icon(Icons.cancel_outlined, size: 18, color: scheme.error),
            Text(
              copy.row,
              style: theme.textTheme.titleSmall?.copyWith(
                color: copy.tone == CopyTone.error ? scheme.error : null,
              ),
            ),
            // The error code beside the words ("Module failed module_error").
            if (error != null && copy.tone == CopyTone.error)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.xs,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: Radii.smAll,
                ),
                child: Text(
                  error.code,
                  style: MorkvaTypography.mono(
                    theme.textTheme.bodySmall!,
                  ).copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
          ],
        ),
        if (error != null && copy.tone == CopyTone.error) ...[
          const SizedBox(height: Spacing.xs),
          Text(error.message, style: theme.textTheme.bodyMedium),
          if (error.stack case final stack?) ...[
            const SizedBox(height: Spacing.xs),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Spacing.sm),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: Radii.smAll,
              ),
              child: SelectableText(
                stack,
                style: MorkvaTypography.mono(theme.textTheme.bodySmall!),
              ),
            ),
          ],
        ] else
          Text(copy.detail, style: muted),
        Wrap(
          spacing: Spacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (fix != null && onFix != null)
              TextActionButton(
                label: fix.label,
                icon: fix == RunFix.askMorkva
                    ? Icons.auto_awesome_outlined
                    : null,
                onPressed: onFix,
              )
            else if (advice != null && fix == null)
              Text(advice.text, style: muted),
            if (error != null)
              TextActionButton(
                label: 'Copy',
                icon: Icons.copy_outlined,
                onPressed: () => Clipboard.setData(
                  ClipboardData(
                    text: [
                      '${error.code}: ${error.message}',
                      ?error.stack,
                    ].join('\n'),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// The failed Outcome step's error outline (the error card of UX §7).
class _ErrorOutline extends StatelessWidget {
  const _ErrorOutline({required this.on, required this.child});

  final bool on;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!on) return child;
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: const ValueKey('step-error'),
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: Radii.lgAll,
        border: Border.all(color: scheme.error),
      ),
      child: child,
    );
  }
}

/// The failed Outcome's errorContainer wash, under the step's content.
class _ErrorFill extends StatelessWidget {
  const _ErrorFill({required this.on, required this.child});

  final bool on;
  final Widget child;

  @override
  Widget build(BuildContext context) => !on
      ? child
      : DecoratedBox(
          key: const ValueKey('step-error-fill'),
          decoration: BoxDecoration(
            // A wash, not the container: dark's errorContainer is a
            // saturated red.
            color: Theme.of(context).colorScheme.errorContainer.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? 0.2
                  : 0.3,
            ),
            borderRadius: Radii.lgAll,
          ),
          child: child,
        );
}

/// A collapsible timeline step: a dot on the rule, then a section card.
class _Step extends StatefulWidget {
  const _Step({
    required this.title,
    required this.children,
    this.summary,
    this.summaryIcon,
    this.trailing,
    this.count,
    this.last = false,
    this.tone,
  });

  final String title;
  final String? summary;

  /// A status glyph before [summary] (Outcome's ✓).
  final Widget? summaryIcon;

  /// At the header's end (Outcome's Undo).
  final Widget? trailing;
  final int? count;
  final List<Widget> children;
  final bool last;
  final CopyTone? tone;

  @override
  State<_Step> createState() => _StepState();
}

class _StepState extends State<_Step> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final error = widget.tone == CopyTone.error;
    // The error chip's ink is a pale pink in dark; the dot stays red.
    final dot = widget.tone == null
        ? scheme.outline
        : error
        ? scheme.error
        : StatusChip.colorsOf(theme, widget.tone!).foreground;
    // The card sizes the step; the rail is positioned beside it (an
    // IntrinsicHeight row came out 1 px short of the text on web).
    return Stack(
      children: [
        if (!widget.last)
          Positioned(
            left: 11,
            top: 30,
            bottom: 0,
            child: Container(width: 2, color: scheme.outlineVariant),
          ),
        Positioned(
          left: 6,
          top: 18,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(
            left: 24 + Spacing.sm,
            bottom: Spacing.xs,
          ),
          child: _ErrorOutline(
            on: error,
            child: SurfaceCard(
              padding: EdgeInsets.zero,
              child: _ErrorFill(
                on: error,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InkWell(
                      onTap: () => setState(() => _open = !_open),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Spacing.sm,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _open ? Icons.expand_more : Icons.chevron_right,
                                size: 20,
                              ),
                              const SizedBox(width: Spacing.xs),
                              Text(
                                widget.title,
                                style: theme.textTheme.titleMedium,
                              ),
                              if (widget.count != null) ...[
                                const SizedBox(width: Spacing.xs),
                                CountBadge(count: widget.count!),
                              ],
                              if (widget.summaryIcon != null) ...[
                                const SizedBox(width: Spacing.sm),
                                widget.summaryIcon!,
                              ],
                              if (widget.summary != null) ...[
                                SizedBox(
                                  width: widget.summaryIcon == null
                                      ? Spacing.sm
                                      : Spacing.xxs,
                                ),
                                Expanded(
                                  child: Text(
                                    widget.summary!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: widget.summaryIcon == null
                                        ? theme.textTheme.bodyMedium?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          )
                                        : theme.textTheme.bodyMedium,
                                  ),
                                ),
                              ] else if (widget.trailing != null)
                                const Spacer(),
                              if (widget.trailing != null) ...[
                                const SizedBox(width: Spacing.sm),
                                widget.trailing!,
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_open && widget.children.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Spacing.xl + Spacing.xs,
                          0,
                          Spacing.md,
                          Spacing.md,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: widget.children,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
