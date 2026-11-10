import 'package:go_router/go_router.dart';

import '../../../core/harness/harness.dart';
import '../../../core/harness/query/query_engine.dart';
import '../../../core/harness/ui_port.dart';
import '../../views/view_link.dart';

/// The assistant's [UiPort] over go_router: a chip (or "Open as filtered
/// view") opens `/collections/:id?view=…&card=…&filter=…`, the deep-link
/// contract of `view_link.dart`.
///
/// On phone the chat is the full-screen `/assistant` route on the root
/// navigator: it is popped first, so the collection opens in the shell
/// underneath and the conversation (kept by the bloc) is one tap away.
final class RouterUiPort implements UiPort {
  RouterUiPort(this._router, {this.chatPath = '/assistant'});

  /// Read lazily: the app builds its router after the assistant session.
  final GoRouter Function() _router;

  /// The phone chat route (and its `/history` child).
  final String chatPath;

  @override
  void open({
    required String collectionId,
    String? viewId,
    String? cardId,
    List<Object?>? where,
  }) {
    final router = _router();
    // `go` then replaces whatever chat page (e.g. `/assistant/history`) is
    // left on the stack.
    if (_inChat(router) && router.canPop()) router.pop();
    router.go(
      collectionLink(collectionId, view: viewId, card: cardId, where: where),
    );
  }

  /// The card query [spec] stands for when a filtered view can show exactly
  /// its cards, else null: a search, or a filter on a card's created/updated
  /// time, has no link filter, and dropping it would show more cards than
  /// the table did. Hide "Open as filtered view" when this is null.
  static QuerySpec? viewQuery(Map<String, Object?>? spec) {
    if (spec == null) return null;
    final QuerySpec query;
    try {
      query = QuerySpec.fromJson(spec);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
    final timestamps = {kCreatedAtRef, kUpdatedAtRef};
    if (query.search != null ||
        query.filters.any((f) => timestamps.contains(f.fieldId))) {
      return null;
    }
    return query;
  }

  /// Opens the cards a table card shows: its stored query spec (ids, every
  /// filter already validated) as transient filters over its collection.
  /// Returns false when [spec] has no [viewQuery].
  bool openQuery(Map<String, Object?> spec) {
    final query = viewQuery(spec);
    if (query == null) return false;
    open(
      collectionId: query.collectionId,
      viewId: query.orderViewId,
      where: query.filters.isEmpty
          ? null
          : [
              for (final f in query.filters)
                {
                  'field': f.fieldId,
                  'op': f.op.name,
                  if (f.operand != null) 'value': f.operand,
                },
            ],
    );
    return true;
  }

  bool _inChat(GoRouter router) {
    final path = router.routerDelegate.currentConfiguration.uri.path;
    return path == chatPath || path.startsWith('$chatPath/');
  }
}
