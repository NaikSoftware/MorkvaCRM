import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../api/inbox/inbox_repository.dart';
import '../../../core/domain/inbox/inbox.dart';

sealed class InboxState extends Equatable {
  const InboxState();

  @override
  List<Object?> get props => [];
}

final class InboxLoading extends InboxState {
  const InboxLoading();
}

final class InboxReady extends InboxState {
  const InboxReady(this.items, {this.fromCache = false});

  final List<InboxItem> items;

  /// The local cache's items, not yet confirmed by the server (they may
  /// miss or hold stale items).
  final bool fromCache;

  @override
  List<Object?> get props => [items, fromCache];
}

/// The listener died (denied, offline first load failed): "Retry".
final class InboxFailed extends InboxState {
  const InboxFailed(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

/// The signed-in member's Inbox, app-wide (sidebar badge, page, card
/// button). One per sign-in; listens from construction.
///
/// Writes fire without awaiting the server ack (offline must just work);
/// a rejected write is reported once on [errors] (the error's text) for a
/// "Couldn't save — …" snackbar.
class InboxCubit extends Cubit<InboxState> {
  InboxCubit(this._repository, {DateTime Function() now = DateTime.now})
    : _now = now,
      super(const InboxLoading()) {
    _listen();
  }

  final InboxRepository _repository;
  final DateTime Function() _now;
  final _errors = StreamController<String>.broadcast();
  StreamSubscription<({List<InboxItem> items, bool fromCache})>? _sub;

  /// Failed writes, as the error's text.
  Stream<String> get errors => _errors.stream;

  List<InboxItem> get items => switch (state) {
    InboxReady(:final items) => items,
    _ => const [],
  };

  /// Open tasks overdue or due today, as of now.
  int get badgeCount => inboxBadgeCount(items, _now());

  void _listen() {
    _sub = _repository.watch().listen(
      (s) => emit(InboxReady(s.items, fromCache: s.fromCache)),
      onError: (Object e) => emit(InboxFailed('$e')),
    );
  }

  /// A failed Firestore listener is dead: subscribe again.
  Future<void> retry() async {
    await _sub?.cancel();
    if (isClosed) return;
    emit(const InboxLoading());
    _listen();
  }

  String newId() => _repository.newId();

  void add(InboxItem item) => _fire(_repository.create(item));

  void update(String id, Map<String, Object?> fields) =>
      _fire(_repository.update(id, fields));

  /// Checks or unchecks a task; `doneAt` is set to now or cleared.
  void setDone(String id, bool done) =>
      update(id, {'done': done, 'doneAt': done ? _now().toUtc() : null});

  /// Deletes item [id]; returns it for Undo ([restore]), or null if unknown.
  InboxItem? delete(String id) {
    final item = items.where((i) => i.id == id).firstOrNull;
    if (item != null) _fire(_repository.delete(id));
    return item;
  }

  /// Undo of [delete]: writes [item] back whole.
  void restore(InboxItem item) => add(item);

  /// Moves every overdue task to today, keeping a timed task's local time
  /// of day. Returns the previous `dueAt`s by id for [restoreDueAts].
  Map<String, DateTime> moveAllOverdueToToday() {
    final now = _now();
    final today = localDay(now);
    final previous = <String, DateTime>{};
    for (final (:item, daysLate: _) in InboxSections.of(
      items,
      day: today,
      now: now,
    ).overdue) {
      final due = item.dueAt!;
      final l = due.toLocal();
      previous[item.id] = due;
      update(item.id, {
        'dueAt': item.allDay
            ? allDayDue(today)
            : DateTime(
                today.year,
                today.month,
                today.day,
                l.hour,
                l.minute,
              ).toUtc(),
      });
    }
    return previous;
  }

  /// Undo of [moveAllOverdueToToday].
  void restoreDueAts(Map<String, DateTime> previous) {
    for (final MapEntry(key: id, value: dueAt) in previous.entries) {
      update(id, {'dueAt': dueAt});
    }
  }

  void _fire(Future<void> write) => unawaited(
    write.catchError((Object e) {
      if (!_errors.isClosed) _errors.add('$e');
    }),
  );

  @override
  Future<void> close() async {
    await _sub?.cancel();
    await _errors.close();
    return super.close();
  }
}
