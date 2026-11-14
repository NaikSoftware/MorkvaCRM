import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../api/data/data_repository.dart';
import '../../../api/sync/sync_status.dart';
import '../../../api/sync/sync_status_cubit.dart';
import '../../../design/design.dart';
import '../../../l10n/l10n.dart';
import '../../assistant/view/widgets/dashed_border.dart';
import '../../automation/view/automations_page.dart';
import '../../automation/view/consent_sheet.dart';
import '../../automation/widgets/reason_copy.dart';
import '../../automation/widgets/status_chip.dart';
import 'trello_import_cubit.dart';

/// A picked board export.
typedef TrelloExportFile = ({String name, String text});

/// The system picker for Trello board exports (several `.json` at once).
Future<List<TrelloExportFile>> pickTrelloExports() async {
  final files = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['json'],
  );
  return [
    for (final f in files)
      // Malformed text still reaches the parser, which says what is wrong.
      (
        name: f.name,
        text: utf8.decode(await f.readAsBytes(), allowMalformed: true),
      ),
  ];
}

/// Opens the Trello import sheet. Completes with the location to go to
/// (a created collection, or Automations), or null.
Future<String?> showTrelloImportSheet(
  BuildContext context, {
  Future<List<TrelloExportFile>> Function() pickFiles = pickTrelloExports,
}) {
  final repo = context.read<DataRepository>();
  final sync = context.read<SyncStatusCubit?>();
  final sheet = _Sheet(pickFiles);
  final names = context.l10n.trelloNames;
  return showAutomationSheet<String>(
    context,
    // A write in flight must not lose its cubit to a scrim tap.
    dismissible: false,
    builder: (_) => BlocProvider(
      // Seeded: a listener only hears later changes.
      create: (_) =>
          TrelloImportCubit(repo, names: names)
            ..setOffline(sync?.state is SyncOffline),
      child: sync == null
          ? sheet
          : BlocListener<SyncStatusCubit, SyncStatus>(
              bloc: sync,
              listener: (context, s) => context
                  .read<TrelloImportCubit>()
                  .setOffline(s is SyncOffline),
              child: sheet,
            ),
    ),
  );
}

class _Sheet extends StatelessWidget {
  const _Sheet(this.pickFiles);

  final Future<List<TrelloExportFile>> Function() pickFiles;

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<TrelloImportCubit, TrelloImportState>(
        builder: (context, state) => PopScope(
          canPop: !state.isWriting,
          child: switch (state.step) {
            TrelloImportStep.add => _AddStep(state, pickFiles: pickFiles),
            TrelloImportStep.choose => _ChooseStep(state),
            TrelloImportStep.importing => _ImportingStep(state),
            TrelloImportStep.done => _DoneStep(state),
          },
        ),
      );
}

const _boardIcon = MorkvaIcons.viewBoard;

/// "1,200".
String _n(int n) =>
    '$n'.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

TextStyle? _strong(ThemeData theme) =>
    theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);

TextStyle? _sub(ThemeData theme) => theme.textTheme.bodySmall?.copyWith(
  color: theme.colorScheme.onSurfaceVariant,
);

TextStyle? _figures(TextStyle? style) =>
    style == null ? null : MorkvaTypography.tabular(style);

// --- Step 1: add boards.

enum _Source { files, paste }

class _AddStep extends StatefulWidget {
  const _AddStep(this.state, {required this.pickFiles});

  final TrelloImportState state;
  final Future<List<TrelloExportFile>> Function() pickFiles;

  @override
  State<_AddStep> createState() => _AddStepState();
}

class _AddStepState extends State<_AddStep> {
  _Source _source = _Source.files;
  final _paste = TextEditingController();

  @override
  void dispose() {
    _paste.dispose();
    super.dispose();
  }

  Future<void> _choose() async {
    final cubit = context.read<TrelloImportCubit>();
    final filesLabel = context.l10n.trelloImportFiles;
    final List<TrelloExportFile> files;
    try {
      files = await widget.pickFiles();
    } on Object catch (e, st) {
      // The browser refused to read a picked file (moved, or no access).
      developer.log(
        'Trello export pick failed',
        name: 'import',
        error: e,
        stackTrace: st,
      );
      cubit.addProblem(filesLabel, ImportProblemKind.unreadable);
      return;
    }
    cubit.addFiles(files);
  }

  /// Pasted problems show under the field until it changes.
  void _dismissPasted() {
    final cubit = context.read<TrelloImportCubit>();
    final problems = cubit.state.problems;
    for (var i = problems.length - 1; i >= 0; i--) {
      if (problems[i].name == TrelloImportCubit.pastedName) {
        cubit.dismissProblem(i);
      }
    }
  }

  void _addPasted() {
    _dismissPasted();
    if (context.read<TrelloImportCubit>().addPasted(_paste.text)) {
      _paste.clear();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = widget.state;
    final cubit = context.read<TrelloImportCubit>();
    final l10n = context.l10n;
    final pasted = [
      for (final p in state.problems)
        if (p.name == TrelloImportCubit.pastedName) p,
    ];
    final fileProblems = [
      for (final (i, p) in state.problems.indexed)
        if (p.name != TrelloImportCubit.pastedName) (i, p),
    ];

    final input = switch (_source) {
      _Source.files => DashedBorder(
        color: scheme.outline,
        borderRadius: Radii.mdAll,
        strokeWidth: 1.5,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: 20,
          ),
          child: Column(
            children: [
              Icon(
                MorkvaIcons.uploadFile,
                size: 28,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(height: Spacing.xs),
              Text(
                l10n.trelloImportDropHint,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Spacing.xs),
              SecondaryButton(
                label: l10n.trelloImportChooseFiles,
                icon: MorkvaIcons.folder,
                onPressed: _choose,
              ),
            ],
          ),
        ),
      ),
      _Source.paste => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // MorkvaTextField types in bodyLarge: make that mono for the JSON.
          Theme(
            data: theme.copyWith(
              textTheme: theme.textTheme.copyWith(
                bodyLarge: MorkvaTypography.mono(theme.textTheme.bodyMedium!),
              ),
            ),
            child: MorkvaTextField(
              controller: _paste,
              label: l10n.trelloImportBoardJson,
              hint: l10n.trelloImportPasteHint,
              minLines: 8,
              maxLines: 8,
              keyboardType: TextInputType.multiline,
              onChanged: (_) {
                if (pasted.isNotEmpty) _dismissPasted();
                setState(() {});
              },
            ),
          ),
          if (pasted.isNotEmpty) ...[
            const SizedBox(height: Spacing.xs),
            for (final p in pasted) _InlineProblem(_problemText(l10n, p.kind)),
          ],
          const SizedBox(height: Spacing.xs),
          Row(
            children: [
              Expanded(
                child: Text(l10n.trelloImportPasteHelp, style: _sub(theme)),
              ),
              const SizedBox(width: Spacing.sm),
              SecondaryButton(
                label: l10n.trelloImportAddBoard,
                icon: MorkvaIcons.add,
                onPressed: _paste.text.trim().isEmpty ? null : _addPasted,
              ),
            ],
          ),
        ],
      ),
    };

    return AutomationSheetFrame(
      header: SheetHeader(
        icon: _boardIcon,
        title: l10n.trelloImportTitle,
        subtitle: l10n.trelloImportStep1,
        onClose: () => Navigator.of(context).pop(),
      ),
      body: [
        const _ExportHowTo(),
        const SizedBox(height: Spacing.md),
        SegmentedButton<_Source>(
          segments: [
            ButtonSegment(
              value: _Source.files,
              label: Text(l10n.trelloImportFiles),
            ),
            ButtonSegment(
              value: _Source.paste,
              label: Text(l10n.trelloImportPaste),
            ),
          ],
          selected: {_source},
          showSelectedIcon: false,
          style: sheetSegmentedStyle,
          onSelectionChanged: (s) => setState(() => _source = s.single),
        ),
        const SizedBox(height: Spacing.md),
        input,
        const SizedBox(height: Spacing.md),
        if (state.boards.isEmpty && fileProblems.isEmpty)
          const _NoBoards()
        else ...[
          if (state.boards.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.xs),
              child: Text.rich(
                TextSpan(
                  text: l10n.trelloImportBoardsToImport,
                  children: [
                    TextSpan(
                      text: ' · ${state.boards.length}',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                style: _figures(_strong(theme)),
              ),
            ),
          _Group(
            children: [
              for (final b in state.boards)
                _BoardRow(
                  name: b.board.name,
                  summary: state.summaries[b.board.id],
                  onRemove: () => cubit.removeBoard(b.board.id),
                ),
              for (final (i, p) in fileProblems)
                _ProblemRow(
                  problem: p,
                  onDismiss: () => cubit.dismissProblem(i),
                ),
            ],
          ),
        ],
      ],
      footer: SheetFooter(
        hint: state.canContinue ? null : l10n.trelloImportAddAtLeastOne,
        buttons: [
          PrimaryButton(
            label: l10n.commonContinue,
            onPressed: state.canContinue ? cubit.next : null,
          ),
        ],
      ),
    );
  }
}

class _ExportHowTo extends StatelessWidget {
  const _ExportHowTo();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    const bold = TextStyle(fontWeight: FontWeight.w600);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: Radii.mdAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(MorkvaIcons.info, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.trelloImportHowToTitle, style: _strong(theme)),
                const SizedBox(height: Spacing.xxs),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: l10n.trelloImportHowToOpen),
                      TextSpan(text: l10n.trelloImportHowToMenu, style: bold),
                      const TextSpan(text: ' → '),
                      TextSpan(text: l10n.trelloImportHowToShare, style: bold),
                      const TextSpan(text: ' → '),
                      TextSpan(text: l10n.trelloImportHowToExport, style: bold),
                      TextSpan(text: l10n.trelloImportHowToRest),
                    ],
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoBoards extends StatelessWidget {
  const _NoBoards();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: Radii.mdAll,
      ),
      child: Column(
        children: [
          Text(context.l10n.trelloImportNoBoards, style: _strong(theme)),
          const SizedBox(height: Spacing.xxs),
          Text(
            context.l10n.trelloImportNoBoardsBody,
            style: _sub(theme),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Rows in a rounded, outlined box, split by hairlines.
class _Group extends StatelessWidget {
  const _Group({required this.children, this.strong = false});

  final List<Widget> children;

  /// The choose step's board groups take the stronger outline.
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: Radii.mdAll,
        border: Border.all(
          color: strong ? scheme.outlineVariant : scheme.surfaceContainer,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, c) in children.indexed) ...[
            if (i > 0) Divider(height: 1, color: scheme.surfaceContainer),
            c,
          ],
        ],
      ),
    );
  }
}

/// A 32 px tile at the start of a row.
class _RowTile extends StatelessWidget {
  const _RowTile({
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    width: 32,
    height: 32,
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Icon(icon, size: 16, color: foreground),
  );
}

class _BoardRow extends StatelessWidget {
  const _BoardRow({
    required this.name,
    required this.summary,
    required this.onRemove,
  });

  final String name;
  final TrelloBoardSummary? summary;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sky = (theme.brightness == Brightness.light
        ? CollectionTints.light
        : CollectionTints.dark)[2];
    final s = summary;
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.sm, 6, Spacing.xxs, 6),
      child: Row(
        children: [
          _RowTile(
            icon: _boardIcon,
            background: sky.background,
            foreground: sky.foreground,
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: _strong(theme),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (s != null)
                  Text(
                    [
                      l10n.trelloImportListCount(s.lists, _n(s.lists)),
                      l10n.trelloImportCardCount(s.cards, _n(s.cards)),
                      if (s.checklistItems > 0)
                        l10n.trelloImportChecklistItemCount(
                          s.checklistItems,
                          _n(s.checklistItems),
                        ),
                      if (s.comments > 0)
                        l10n.trelloImportCommentCount(
                          s.comments,
                          _n(s.comments),
                        ),
                    ].join(' · '),
                    style: _figures(_sub(theme)),
                  ),
              ],
            ),
          ),
          IconActionButton(
            icon: MorkvaIcons.close,
            tooltip: l10n.trelloImportRemoveNamed(name),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

/// A file that is not a board, or a board added twice.
class _ProblemRow extends StatelessWidget {
  const _ProblemRow({required this.problem, required this.onDismiss});

  final ImportProblem problem;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = StatusChip.colorsOf(theme, CopyTone.error);
    return Semantics(
      liveRegion: true,
      container: true,
      child: ColoredBox(
        color: tone.background.withValues(alpha: 0.45),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.sm, 6, Spacing.xxs, 6),
          child: Row(
            children: [
              _RowTile(
                icon: MorkvaIcons.error,
                background: tone.background,
                foreground: tone.foreground,
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      problem.name,
                      style: _strong(theme),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _problemText(context.l10n, problem.kind),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: tone.foreground,
                      ),
                    ),
                  ],
                ),
              ),
              IconActionButton(
                icon: MorkvaIcons.close,
                tooltip: context.l10n.trelloImportDismissNamed(problem.name),
                onPressed: onDismiss,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _problemText(AppLocalizations l10n, ImportProblemKind kind) =>
    switch (kind) {
      ImportProblemKind.notABoard => l10n.trelloImportProblemNotABoard,
      ImportProblemKind.alreadyAdded => l10n.trelloImportProblemAlreadyAdded,
      ImportProblemKind.unreadable => l10n.trelloImportProblemUnreadable,
    };

/// A pasted export's problem, under the field.
class _InlineProblem extends StatelessWidget {
  const _InlineProblem(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.error;
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(MorkvaIcons.error, size: 16, color: color),
          const SizedBox(width: Spacing.xs),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Step 2: choose what to import.

class _ChooseStep extends StatelessWidget {
  const _ChooseStep(this.state);

  final TrelloImportState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.read<TrelloImportCubit>();
    final archived = state.summaries.values.fold(
      0,
      (n, s) => n + s.archivedCards,
    );
    final count = state.selectedCollectionCount;
    final l10n = context.l10n;
    return AutomationSheetFrame(
      header: SheetHeader(
        icon: _boardIcon,
        title: l10n.trelloImportTitle,
        subtitle: l10n.trelloImportStep2,
        onClose: () => Navigator.of(context).pop(),
      ),
      body: [
        AutomationBanner(
          tone: CopyTone.neutral,
          icon: MorkvaIcons.bolt,
          title: l10n.trelloImportNoAutomationsTitle,
          body: l10n.trelloImportNoAutomationsBody,
        ),
        const SizedBox(height: Spacing.sm),
        MergeSemantics(
          child: InkWell(
            onTap: () => cubit.setIncludeArchived(!state.includeArchived),
            borderRadius: Radii.smAll,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.only(left: Spacing.xxs),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.trelloImportIncludeArchived,
                            style: _strong(theme),
                          ),
                          Text(
                            archived == 0
                                ? l10n.trelloImportNoArchived
                                : l10n.trelloImportArchivedCards(
                                    archived,
                                    _n(archived),
                                  ),
                            style: _figures(_sub(theme)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: Spacing.sm),
                    Switch(
                      value: state.includeArchived,
                      onChanged: cubit.setIncludeArchived,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: Spacing.sm),
        Semantics(
          header: true,
          child: Text(l10n.commonCollections, style: _strong(theme)),
        ),
        const SizedBox(height: 2),
        Text(l10n.trelloImportCollectionsHelp, style: _sub(theme)),
        for (final b in state.boards)
          if ((state.choices[b.board.id], state.summaries[b.board.id]) case (
            final choice?,
            final summary?,
          )) ...[
            const SizedBox(height: Spacing.xs),
            _BoardGroup(
              name: b.board.name,
              choice: choice,
              summary: summary,
              capped: b.board.actionsCapped,
              onSelect: ({board, checklists, comments}) => cubit.select(
                b.board.id,
                board: board,
                checklists: checklists,
                comments: comments,
              ),
            ),
          ],
      ],
      footer: SheetFooter(
        hint: switch (state.importBlockedReason) {
          null => null,
          ImportBlockedReason.nothingChosen => l10n.trelloImportNothingChosen,
          ImportBlockedReason.offline => l10n.trelloImportOffline,
        },
        hintIcon: count > 0 && state.offline ? MorkvaIcons.wifiOff : null,
        buttons: [
          TextActionButton(label: l10n.commonBack, onPressed: cubit.back),
          PrimaryButton(
            label: l10n.trelloImportCollectionsButton(count, _n(count)),
            onPressed: state.canImport
                ? () => unawaited(cubit.startImport())
                : null,
          ),
        ],
      ),
    );
  }
}

class _BoardGroup extends StatelessWidget {
  const _BoardGroup({
    required this.name,
    required this.choice,
    required this.summary,
    required this.capped,
    required this.onSelect,
  });

  final String name;
  final BoardChoice choice;
  final TrelloBoardSummary summary;
  final bool capped;
  final void Function({bool? board, bool? checklists, bool? comments}) onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<MorkvaSemanticColors>()!;
    final on = choice.board;
    final l10n = context.l10n;
    final needs = on ? '' : ' · ${l10n.trelloImportNeedsBoard}';
    return Semantics(
      container: true,
      label: name,
      explicitChildNodes: true,
      child: _Group(
        strong: true,
        children: [
          _CheckRow(
            value: on,
            onChanged: (v) => onSelect(board: v),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: _strong(theme),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${l10n.trelloImportCardCount(summary.cards, _n(summary.cards))}'
                  ' · '
                  '${l10n.trelloImportListCount(summary.lists, _n(summary.lists))}',
                  style: _figures(_sub(theme)),
                ),
                const SizedBox(height: 6),
                _FieldChips(summary.fieldNames),
              ],
            ),
          ),
          if (summary.checklistItems > 0)
            _CheckRow(
              indent: true,
              value: on && choice.checklists,
              enabled: on,
              onChanged: (v) => onSelect(checklists: v),
              child: _ChildText(
                title: l10n.trelloImportChecklistItems,
                sub:
                    '${l10n.trelloImportItemCount(summary.checklistItems, _n(summary.checklistItems))}'
                    '$needs',
                enabled: on,
              ),
            ),
          if (summary.comments > 0)
            _CheckRow(
              indent: true,
              value: on && choice.comments,
              enabled: on,
              onChanged: (v) => onSelect(comments: v),
              child: _ChildText(
                title: l10n.trelloImportComments,
                sub:
                    '${l10n.trelloImportCommentCount(summary.comments, _n(summary.comments))}'
                    '$needs',
                enabled: on,
                note: on && capped
                    ? Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              MorkvaIcons.info,
                              size: 14,
                              color: semantic.onWarningContainer,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                l10n.trelloImportCapped,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: semantic.onWarningContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

/// A checkbox row whose whole width is the target (one semantics node).
class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.value,
    required this.onChanged,
    required this.child,
    this.enabled = true,
    this.indent = false,
  });

  /// The checkbox's width plus the gaps around it: where a child row starts.
  static const double _indent = Spacing.sm + 24 + Spacing.sm;

  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget child;
  final bool enabled;
  final bool indent;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: InkWell(
      onTap: enabled ? () => onChanged(!value) : null,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          indent ? _indent : Spacing.sm,
          Spacing.sm,
          Spacing.sm,
          Spacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: value,
              onChanged: enabled ? (v) => onChanged(v ?? false) : null,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: const VisualDensity(
                horizontal: VisualDensity.minimumDensity,
                vertical: VisualDensity.minimumDensity,
              ),
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(child: child),
          ],
        ),
      ),
    ),
  );
}

class _ChildText extends StatelessWidget {
  const _ChildText({
    required this.title,
    required this.sub,
    required this.enabled,
    this.note,
  });

  final String title;
  final String sub;
  final bool enabled;
  final Widget? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Disabled reads in the muted ink, not faded: it must stay legible.
    final title = _strong(
      theme,
    )?.copyWith(color: enabled ? null : theme.colorScheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(this.title, style: title),
        Text(sub, style: _figures(_sub(theme))),
        ?note,
      ],
    );
  }
}

/// The board collection's fields; a phone shows the first six.
class _FieldChips extends StatelessWidget {
  const _FieldChips(this.names);

  final List<String> names;

  static const _compactMax = 6;

  @override
  Widget build(BuildContext context) {
    final compact = !automationsExpanded(context);
    final more = compact && names.length > _compactMax
        ? names.length - _compactMax
        : 0;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final n in names.take(names.length - more))
          HugChip(label: n, tone: CopyTone.muted),
        if (more > 0)
          Text(
            context.l10n.trelloImportMoreFields(more, _n(more)),
            style: _sub(Theme.of(context)),
          ),
      ],
    );
  }
}

// --- Importing (and paused).

class _ImportingStep extends StatelessWidget {
  const _ImportingStep(this.state);

  final TrelloImportState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final semantic = theme.extension<MorkvaSemanticColors>()!;
    final cubit = context.read<TrelloImportCubit>();
    final l10n = context.l10n;
    final failure = state.failure;
    final paused = failure != null && !state.running;
    final written = state.writtenObjects;
    final total = state.totalObjects;
    // The total spans checklist items and comments too, so say so.
    final what = state.rows.any((r) => r.kind != ImportedKind.board)
        ? l10n.trelloImportWritingCardsAndItems
        : l10n.trelloImportWritingCards;
    final progress = l10n.trelloImportWrittenOf(_n(written), _n(total));
    return AutomationSheetFrame(
      header: SheetHeader(
        icon: _boardIcon,
        title: l10n.trelloImportImporting,
        subtitle: l10n.trelloImportKeepOpen,
      ),
      body: [
        if (paused) ...[
          AutomationBanner(
            tone: CopyTone.warning,
            icon: MorkvaIcons.warning,
            title: l10n.trelloImportPaused,
            body: switch (failure) {
              ImportFailure.stalled => l10n.trelloImportStalled,
              ImportFailure.refused => l10n.trelloImportRefused,
            },
          ),
          const SizedBox(height: Spacing.md),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(child: Text(what, style: _strong(theme))),
            Text(
              progress,
              style: _figures(
                theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.xs),
        LinearProgressIndicator(
          value: total == 0 ? 0 : written / total,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
          backgroundColor: scheme.surfaceContainer,
          color: paused ? semantic.warning : scheme.primary,
          // The value must stay numeric (a percentage); the count goes in
          // the label.
          semanticsLabel: '$what, $progress',
        ),
        const SizedBox(height: Spacing.xs),
        Text(l10n.trelloImportNoAutomationsStart, style: _sub(theme)),
        const SizedBox(height: Spacing.md),
        _Group(children: [for (final r in state.rows) _ProgressRow(r)]),
      ],
      footer: paused
          ? SheetFooter(
              buttons: [
                TextActionButton(
                  label: l10n.commonClose,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                PrimaryButton(
                  label: l10n.commonRetry,
                  icon: MorkvaIcons.refresh,
                  onPressed: () => unawaited(cubit.retry()),
                ),
              ],
            )
          : SheetFooter(
              hint: l10n.trelloImportWritingKeepOpen,
              buttons: [PrimaryButton(label: l10n.commonDone, onPressed: null)],
            ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow(this.row);

  final ImportProgressRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final semantic = theme.extension<MorkvaSemanticColors>()!;
    final success = StatusChip.colorsOf(theme, CopyTone.success);
    final l10n = context.l10n;
    Widget dot(IconData icon, Color bg, Color fg, String label) => Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, size: 16, color: fg, semanticLabel: label),
    );
    final marker = switch (row.status) {
      ImportRowStatus.done => dot(
        MorkvaIcons.check,
        success.background,
        success.foreground,
        l10n.commonDone,
      ),
      ImportRowStatus.paused => dot(
        MorkvaIcons.pause,
        semantic.warningContainer,
        semantic.onWarningContainer,
        l10n.trelloImportRowPaused,
      ),
      ImportRowStatus.running => SizedBox.square(
        dimension: 28,
        child: Center(
          child: SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              backgroundColor: scheme.surfaceContainer,
              semanticsLabel: l10n.trelloImportRowWriting,
            ),
          ),
        ),
      ),
      ImportRowStatus.pending => SizedBox.square(
        dimension: 28,
        child: Icon(
          MorkvaIcons.schedule,
          size: 18,
          color: scheme.onSurfaceVariant,
          semanticLabel: l10n.trelloImportRowWaiting,
        ),
      ),
    };
    final waiting = row.status == ImportRowStatus.pending;
    return MergeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.sm,
            vertical: Spacing.xxs,
          ),
          child: Row(
            children: [
              marker,
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(
                  row.name,
                  style: waiting
                      ? theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        )
                      : _strong(theme),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Text(
                l10n.trelloImportWrittenOf(_n(row.written), _n(row.total)),
                style: _figures(_sub(theme)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Done.

class _DoneStep extends StatelessWidget {
  const _DoneStep(this.state);

  final TrelloImportState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final navigator = Navigator.of(context);
    final l10n = context.l10n;
    final cards = state.rows
        .where((r) => r.kind == ImportedKind.board)
        .fold(0, (n, r) => n + r.total);
    return AutomationSheetFrame(
      header: SheetHeader(
        icon: MorkvaIcons.check,
        title: l10n.trelloImportDoneTitle,
        subtitle:
            '${l10n.trelloImportCollectionCount(state.rows.length, _n(state.rows.length))}'
            ' · ${l10n.trelloImportCardCount(cards, _n(cards))}',
      ),
      body: [
        _Group(
          children: [
            for (final r in state.rows)
              MergeSemantics(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Spacing.sm,
                      Spacing.xxs,
                      Spacing.xxs,
                      Spacing.xxs,
                    ),
                    child: Row(
                      children: [
                        CollectionGlyph(
                          iconKey: switch (r.kind) {
                            ImportedKind.board => 'cards',
                            ImportedKind.checklistItems => 'task',
                            ImportedKind.comments => 'note',
                          },
                          tintSeed: r.collectionId,
                          size: 32,
                          iconSize: 16,
                        ),
                        const SizedBox(width: Spacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.name, style: _strong(theme)),
                              Text(switch (r.kind) {
                                ImportedKind.board =>
                                  l10n.trelloImportBoardViewByList(
                                    r.total,
                                    _n(r.total),
                                  ),
                                ImportedKind.checklistItems =>
                                  l10n.trelloImportItemCount(
                                    r.total,
                                    _n(r.total),
                                  ),
                                ImportedKind.comments =>
                                  l10n.trelloImportCommentCount(
                                    r.total,
                                    _n(r.total),
                                  ),
                              }, style: _figures(_sub(theme))),
                            ],
                          ),
                        ),
                        TextActionButton(
                          label: l10n.commonOpen,
                          onPressed: () =>
                              navigator.pop('/collections/${r.collectionId}'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: Spacing.md),
        Container(
          padding: const EdgeInsets.fromLTRB(
            Spacing.sm,
            Spacing.xs,
            Spacing.xxs,
            Spacing.xs,
          ),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: Radii.mdAll,
          ),
          child: Row(
            children: [
              Icon(
                MorkvaIcons.bolt,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(
                  l10n.trelloImportButlerHint,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              TextActionButton(
                label: l10n.commonAutomations,
                onPressed: () => navigator.pop('/automations'),
              ),
            ],
          ),
        ),
      ],
      footer: SheetFooter(
        buttons: [
          PrimaryButton(
            label: l10n.commonDone,
            onPressed: () => navigator.pop(),
          ),
        ],
      ),
    );
  }
}
