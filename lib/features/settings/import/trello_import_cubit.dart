import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' show min;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../api/data/data_repository.dart';
import '../../../core/domain/domain.dart';
import '../../../core/domain/ids.dart';
import '../../../core/import/trello/trello_board.dart';
import '../../../core/import/trello/trello_mapper.dart';

export '../../../core/import/trello/trello_mapper.dart'
    show ImportedKind, TrelloBoardSummary;

/// The import sheet's steps.
enum TrelloImportStep { add, choose, importing, done }

/// A collection's write progress.
enum ImportRowStatus { pending, running, done, paused }

/// A parsed board and the file it came from.
final class LoadedBoard extends Equatable {
  const LoadedBoard({required this.fileName, required this.board});

  final String fileName;
  final TrelloBoard board;

  @override
  List<Object?> get props => [fileName, board];
}

/// An inline row on the add step: a file that is not a board, or a board
/// added twice.
final class ImportProblem extends Equatable {
  const ImportProblem({required this.name, required this.message});

  final String name;
  final String message;

  @override
  List<Object?> get props => [name, message];
}

/// What to import from one board. The children count only while [board] is
/// ticked.
final class BoardChoice extends Equatable {
  const BoardChoice({
    this.board = true,
    this.checklists = true,
    this.comments = true,
  });

  final bool board;
  final bool checklists;
  final bool comments;

  BoardChoice copyWith({bool? board, bool? checklists, bool? comments}) =>
      BoardChoice(
        board: board ?? this.board,
        checklists: checklists ?? this.checklists,
        comments: comments ?? this.comments,
      );

  @override
  List<Object?> get props => [board, checklists, comments];
}

/// One collection being imported; on the done step, one created collection.
final class ImportProgressRow extends Equatable {
  const ImportProgressRow({
    required this.collectionId,
    required this.name,
    required this.kind,
    required this.total,
    this.written = 0,
    this.status = ImportRowStatus.pending,
  });

  final String collectionId;
  final String name;
  final ImportedKind kind;

  /// Objects to write.
  final int total;

  /// Objects the server acknowledged (or already had).
  final int written;
  final ImportRowStatus status;

  ImportProgressRow copyWith({int? written, ImportRowStatus? status}) =>
      ImportProgressRow(
        collectionId: collectionId,
        name: name,
        kind: kind,
        total: total,
        written: written ?? this.written,
        status: status ?? this.status,
      );

  @override
  List<Object?> get props => [collectionId, name, kind, total, written, status];
}

final class TrelloImportState extends Equatable {
  const TrelloImportState({
    this.step = TrelloImportStep.add,
    this.boards = const [],
    this.problems = const [],
    this.choices = const {},
    this.summaries = const {},
    this.includeArchived = false,
    this.offline = false,
    this.rows = const [],
    this.running = false,
    this.failure,
    this.stalled = false,
  });

  final TrelloImportStep step;
  final List<LoadedBoard> boards;
  final List<ImportProblem> problems;

  /// By Trello board id.
  final Map<String, BoardChoice> choices;

  /// By Trello board id, following [includeArchived].
  final Map<String, TrelloBoardSummary> summaries;
  final bool includeArchived;
  final bool offline;

  /// One per imported collection, in write order.
  final List<ImportProgressRow> rows;

  /// A write run is in flight.
  final bool running;

  /// Why the import is paused (shown with Retry); null while it is not.
  final String? failure;

  /// The pause is a slice that never acked, not a refused write.
  final bool stalled;

  bool get canContinue => boards.isNotEmpty;

  /// Collections the current choices create; a child counts only when its
  /// board is ticked and it has objects (the mapper skips empty ones).
  int get selectedCollectionCount => boards.fold(0, (n, b) {
    final choice = choices[b.board.id];
    final summary = summaries[b.board.id];
    if (choice == null || !choice.board || summary == null) return n;
    return n +
        1 +
        (choice.checklists && summary.checklistItems > 0 ? 1 : 0) +
        (choice.comments && summary.comments > 0 ? 1 : 0);
  });

  String? get importBlockedReason => selectedCollectionCount == 0
      ? 'Choose at least one collection'
      : offline
      ? "You're offline — connect to import"
      : null;

  bool get canImport => importBlockedReason == null;

  bool get isWriting => step == TrelloImportStep.importing && running;

  int get totalObjects => rows.fold(0, (n, r) => n + r.total);
  int get writtenObjects => rows.fold(0, (n, r) => n + r.written);

  /// The first board collection, to open after the import.
  String? get firstCollectionId =>
      rows.where((r) => r.kind == ImportedKind.board).firstOrNull?.collectionId;

  TrelloImportState copyWith({
    TrelloImportStep? step,
    List<LoadedBoard>? boards,
    List<ImportProblem>? problems,
    Map<String, BoardChoice>? choices,
    Map<String, TrelloBoardSummary>? summaries,
    bool? includeArchived,
    bool? offline,
    List<ImportProgressRow>? rows,
    bool? running,
    String? Function()? failure,
    bool? stalled,
  }) => TrelloImportState(
    step: step ?? this.step,
    boards: boards ?? this.boards,
    problems: problems ?? this.problems,
    choices: choices ?? this.choices,
    summaries: summaries ?? this.summaries,
    includeArchived: includeArchived ?? this.includeArchived,
    offline: offline ?? this.offline,
    rows: rows ?? this.rows,
    running: running ?? this.running,
    failure: failure == null ? this.failure : failure(),
    stalled: stalled ?? this.stalled,
  );

  @override
  List<Object?> get props => [
    step,
    boards,
    problems,
    choices,
    summaries,
    includeArchived,
    offline,
    rows,
    running,
    failure,
    stalled,
  ];
}

/// Drives the Trello import sheet: add board exports, choose collections,
/// then write them (collections first, then cards in slices) with a watchdog
/// per write and a resumable Retry.
class TrelloImportCubit extends Cubit<TrelloImportState> {
  TrelloImportCubit(
    this._repo, {
    IdGenerator? ids,
    this.sliceTimeout = const Duration(seconds: 30),
    this.sliceSize = 450,
  }) : _ids = ids ?? IdGenerator(),
       super(const TrelloImportState());

  final DataRepository _repo;
  final IdGenerator _ids;

  /// How long one write may go unacknowledged before the import stalls.
  final Duration sliceTimeout;

  /// Objects per saveObjectsBatch call.
  final int sliceSize;

  final _summaryCache = <(String, bool), TrelloBoardSummary>{};

  // The run's plan, kept across retries.
  List<ImportedCollection> _collections = const [];
  final _saved = <String>{};
  final _pending = <String, List<MorkvaObject>>{};

  /// Collections whose last slice may have landed unacknowledged; their
  /// pending ids are checked against the server before the next send.
  final _unsure = <String>{};

  static const _origin = WriteOrigin(kind: WriteKind.template);

  static const _paused =
      " Check your connection, then retry — cards already written won't be "
      "added twice. Closing keeps what's already imported.";

  /// [TrelloImportState.failure] when a write never acked (the paused
  /// banner's body, after "Import paused.").
  static const stalledMessage =
      "Morkva couldn't reach the server for 30 seconds.$_paused";

  /// [TrelloImportState.failure] when a write was refused.
  static const refusedMessage = "Morkva couldn't save some cards.$_paused";

  /// Past the choose step the plan is fixed: edits are no-ops.
  bool get _locked => state.step.index >= TrelloImportStep.importing.index;

  void setOffline(bool offline) => _emit(state.copyWith(offline: offline));

  // --- Step 1.

  void addFiles(List<({String name, String text})> files) {
    if (_locked) return;
    for (final f in files) {
      _add(f.name, f.text);
    }
  }

  /// Adds a pasted export; true when a board was added (the field clears).
  bool addPasted(String text) => !_locked && _add(pastedName, text);

  /// The [ImportProblem.name] of a pasted export's problem.
  static const pastedName = 'Pasted text';

  /// Shows [message] as a problem row for [name] (e.g. a file the browser
  /// couldn't read).
  void addProblem(String name, String message) => _problem(name, message);

  bool _add(String name, String text) {
    final TrelloBoard board;
    try {
      board = TrelloBoard.parse(text);
    } on TrelloFormatException catch (e) {
      _problem(name, e.message);
      return false;
    }
    if (state.boards.any((b) => b.board.id == board.id)) {
      _problem(name, 'Already added');
      return false;
    }
    _emit(
      _summarized(
        state.copyWith(
          boards: [
            ...state.boards,
            LoadedBoard(fileName: name, board: board),
          ],
          choices: {...state.choices, board.id: const BoardChoice()},
        ),
      ),
    );
    return true;
  }

  void _problem(String name, String message) => _emit(
    state.copyWith(
      problems: [
        ...state.problems,
        ImportProblem(name: name, message: message),
      ],
    ),
  );

  void removeBoard(String boardId) {
    if (_locked) return;
    // A newer export of the same board may be added next.
    _summaryCache.removeWhere((key, _) => key.$1 == boardId);
    _emit(
      _summarized(
        state.copyWith(
          boards: [
            for (final b in state.boards)
              if (b.board.id != boardId) b,
          ],
          choices: {...state.choices}..remove(boardId),
        ),
      ),
    );
  }

  void dismissProblem(int index) {
    if (index < 0 || index >= state.problems.length) return;
    _emit(state.copyWith(problems: [...state.problems]..removeAt(index)));
  }

  void next() {
    if (state.step == TrelloImportStep.add && state.canContinue) {
      _emit(state.copyWith(step: TrelloImportStep.choose));
    }
  }

  void back() {
    if (state.step == TrelloImportStep.choose) {
      _emit(state.copyWith(step: TrelloImportStep.add));
    }
  }

  // --- Step 2.

  void select(String boardId, {bool? board, bool? checklists, bool? comments}) {
    final choice = state.choices[boardId];
    if (choice == null || _locked) return;
    _emit(
      state.copyWith(
        choices: {
          ...state.choices,
          boardId: choice.copyWith(
            board: board,
            checklists: checklists,
            comments: comments,
          ),
        },
      ),
    );
  }

  void setIncludeArchived(bool value) {
    if (_locked) return;
    _emit(_summarized(state.copyWith(includeArchived: value)));
  }

  TrelloImportState _summarized(TrelloImportState s) => s.copyWith(
    summaries: {
      for (final b in s.boards)
        b.board.id: _summaryCache.putIfAbsent(
          (b.board.id, s.includeArchived),
          () =>
              summarizeTrelloBoard(b.board, includeArchived: s.includeArchived),
        ),
    },
  );

  // --- Writing.

  /// Maps the chosen collections and writes them; completes when the run
  /// ends (done or paused).
  Future<void> startImport() async {
    if (state.step != TrelloImportStep.choose || !state.canImport) return;
    _collections = [
      for (final b in state.boards)
        if (state.choices[b.board.id] case final c? when c.board)
          ...mapTrelloBoard(
            b.board,
            includeArchived: state.includeArchived,
            checklists: c.checklists,
            comments: c.comments,
            ids: _ids,
          ),
    ];
    _saved.clear();
    _unsure.clear();
    _pending
      ..clear()
      ..addAll({
        for (final c in _collections) c.collection.id: [...c.objects],
      });
    _emit(
      state.copyWith(
        step: TrelloImportStep.importing,
        rows: [
          for (final c in _collections)
            ImportProgressRow(
              collectionId: c.collection.id,
              name: c.collection.name,
              kind: c.kind,
              total: c.objects.length,
            ),
        ],
      ),
    );
    await _run();
  }

  /// Resumes a paused import from what is not yet written.
  Future<void> retry() async {
    if (state.step != TrelloImportStep.importing ||
        state.running ||
        state.failure == null) {
      return;
    }
    await _run();
  }

  Future<void> _run() async {
    _emit(
      state.copyWith(
        running: true,
        failure: () => null,
        stalled: false,
        rows: [
          for (final r in state.rows)
            r.status == ImportRowStatus.paused
                ? r.copyWith(status: ImportRowStatus.pending)
                : r,
        ],
      ),
    );
    for (final c in _collections) {
      final collection = c.collection;
      if (_saved.contains(collection.id)) continue;
      final ok = await _guard(
        collection.id,
        () => _repo.saveCollection(collection),
      );
      if (!ok) return;
      _saved.add(collection.id);
    }
    for (final c in _collections) {
      final id = c.collection.id;
      final pending = _pending[id]!;
      if (pending.isEmpty) {
        _setRow(id, ImportRowStatus.done);
        continue;
      }
      _setRow(id, ImportRowStatus.running);
      if (_unsure.contains(id)) {
        // A timed-out create that landed late would turn a re-send into an
        // update, which the monotonic-rev rule rejects for the whole batch.
        final ok = await _guard(id, () async {
          final server = await _repo.getServerObjects(id, schema: c.collection);
          final there = {for (final o in server) o.id};
          pending.removeWhere((o) => there.contains(o.id));
        });
        if (!ok) return;
        _unsure.remove(id);
        _setRow(id, ImportRowStatus.running);
      }
      while (pending.isNotEmpty) {
        final slice = pending.sublist(0, min(sliceSize, pending.length));
        late BatchResult result;
        _unsure.add(id);
        final ok = await _guard(
          id,
          () async => result = await _repo.saveObjectsBatch(
            [for (final o in slice) ObjectCreate(o)],
            schemas: {id: c.collection},
            origin: _origin,
          ),
        );
        if (!ok) return;
        final written = result.written.toSet();
        pending.removeWhere((o) => written.contains(o.id));
        if (result.failed.isNotEmpty) {
          developer.log(
            'Trello import: ${result.failed.length} cards refused',
            name: 'import',
          );
          _pause(id, refusedMessage);
          return;
        }
        _unsure.remove(id);
        _setRow(id, ImportRowStatus.running);
      }
      _setRow(id, ImportRowStatus.done);
    }
    _emit(state.copyWith(step: TrelloImportStep.done, running: false));
  }

  /// Runs [write] under the watchdog; on a timeout or error pauses [id]'s
  /// row and returns false. Also false once the cubit closed.
  Future<bool> _guard(String id, Future<void> Function() write) async {
    try {
      await write().timeout(sliceTimeout);
    } on TimeoutException {
      _pause(id, stalledMessage, stalled: true);
      return false;
    } catch (e, st) {
      developer.log(
        'Trello import write failed',
        name: 'import',
        error: e,
        stackTrace: st,
      );
      _pause(id, refusedMessage);
      return false;
    }
    return !isClosed;
  }

  void _pause(String id, String message, {bool stalled = false}) {
    _setRow(id, ImportRowStatus.paused);
    _emit(
      state.copyWith(running: false, failure: () => message, stalled: stalled),
    );
  }

  void _setRow(String id, ImportRowStatus status) => _emit(
    state.copyWith(
      rows: [
        for (final r in state.rows)
          r.collectionId == id
              ? r.copyWith(
                  status: status,
                  written: r.total - (_pending[id]?.length ?? 0),
                )
              : r,
      ],
    ),
  );

  void _emit(TrelloImportState s) {
    if (!isClosed) emit(s);
  }
}
