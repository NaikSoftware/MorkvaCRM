import 'dart:async';
import 'dart:developer' as developer;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../api/assistant/thread_repository.dart';

/// The conversation list: the newest [kThreadListLimit] thread-meta records
/// (`{id, title, updatedAt, lastSnippet, …}`), as
/// `ThreadRepository.watchThreads` emits them. The view maps each record to
/// its own summary type.
final class ThreadListState extends Equatable {
  const ThreadListState({
    this.threads = const [],
    this.loading = true,
    this.failed = false,
  });

  final List<AssistantRecord> threads;

  /// Before the first emission.
  final bool loading;

  /// The list could not be read; it stays as last shown.
  final bool failed;

  @override
  List<Object?> get props => [threads, loading, failed];
}

/// Watches the member's last threads while the history list is on screen;
/// created by the panel or page that shows it and closed with it. Selecting
/// or deleting a thread goes through the assistant bloc (`ThreadSelected`,
/// `ThreadDeleted`), which knows whether that thread is the open one.
class ThreadListCubit extends Cubit<ThreadListState> {
  ThreadListCubit(ThreadRepository threads) : super(const ThreadListState()) {
    _sub = threads.watchThreads().listen(
      (records) => emit(ThreadListState(threads: records, loading: false)),
      onError: (Object error) {
        developer.log(
          'Reading the conversation list failed',
          name: 'assistant',
          error: error,
        );
        emit(
          ThreadListState(threads: state.threads, loading: false, failed: true),
        );
      },
    );
  }

  late final StreamSubscription<List<AssistantRecord>> _sub;

  @override
  Future<void> close() async {
    await _sub.cancel();
    return super.close();
  }
}
