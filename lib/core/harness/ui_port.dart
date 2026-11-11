import 'dart:async';

/// Where the app navigates when the user taps a chip the assistant posted
/// with `ui.open`. The host implements it (over go_router); the harness
/// never calls it, because `ui.open` only describes the chip: the model
/// never yanks the screen, navigation happens on the user's tap.
///
/// The arguments are the `ui.open` result's keys, so a chip opens with
/// `port.open(collectionId: r['collectionId'], viewId: r['viewId'], …)`.
abstract interface class UiPort {
  /// Shows [collectionId], in [viewId] when given, with [where] (friendly
  /// filters, the shape of a tool's `where`, already validated by
  /// `ui.open`) as transient filters, and the editor of [cardId] open.
  FutureOr<void> open({
    required String collectionId,
    String? viewId,
    String? cardId,
    List<Object?>? where,
  });
}
