import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import '../../../core/domain/inbox/inbox_item.dart';

/// Whether the user is looking at this tab (`document.hasFocus()`), and a
/// ping whenever that may have changed (focus, blur, visibility).
abstract interface class Attention {
  bool get focused;
  Stream<void> get changes;
}

/// A string store shared by all tabs (`localStorage`). [changes] carries the
/// keys other tabs wrote (`storage` events), never this tab's own writes.
abstract interface class ReminderStore {
  String? read(String key);

  /// A null [value] removes the key.
  void write(String key, String? value);
  Stream<String> get changes;
}

enum NotificationPermission { granted, denied, defaultState, unsupported }

/// The OS-level notification (`Notification` on web).
abstract interface class SystemNotifier {
  NotificationPermission get permission;
  Future<NotificationPermission> requestPermission();

  /// False when nothing was shown (e.g. the constructor threw).
  bool show({
    required String tag,
    required String title,
    required String body,
    required void Function() onClick,
  });
}

/// The platform's ports, from `createReminderPlatform()`.
final class ReminderPlatform {
  const ReminderPlatform({
    required this.attention,
    required this.store,
    required this.notifier,
  });

  final Attention attention;
  final ReminderStore store;
  final SystemNotifier notifier;
}

/// A fired reminder waiting for the user to see it as a toast. [catchUp]
/// entries belong to the one "while you were away" group.
final class PendingReminder extends Equatable {
  const PendingReminder({
    required this.key,
    required this.itemId,
    required this.fireAt,
    this.catchUp = false,
  });

  /// `itemId@fireMillis`, also the system notification tag.
  final String key;
  final String itemId;
  final DateTime fireAt;
  final bool catchUp;

  Map<String, Object?> toJson() => {
    'key': key,
    'itemId': itemId,
    'fireAt': fireAt.millisecondsSinceEpoch,
    'catchUp': catchUp,
  };

  static PendingReminder? tryParse(Object? json) => switch (json) {
    {
      'key': final String key,
      'itemId': final String itemId,
      'fireAt': final int fireAt,
    } =>
      PendingReminder(
        key: key,
        itemId: itemId,
        fireAt: DateTime.fromMillisecondsSinceEpoch(fireAt),
        catchUp: json['catchUp'] == true,
      ),
    _ => null,
  };

  @override
  List<Object?> get props => [key, itemId, fireAt, catchUp];
}

/// Fires Inbox reminders while the app runs (spec §4 "Reminders: delivery on
/// web"). Every tick fires the reminders in `(lastTickAt, now]` from a
/// high-water mark all tabs share, so a reminder fires once however many tabs
/// are open and however late a throttled timer runs.
///
/// shortcut: no Web Lock around read-window-write, so two tabs ticking at
/// once may both fire; the notification tag and the pending key dedupe that
/// invisibly. Add `navigator.locks` if duplicates ever show up.
class ReminderScheduler {
  ReminderScheduler({
    required DateTime Function() now,
    required Attention attention,
    required ReminderStore store,
    required SystemNotifier notifier,
    required String Function(InboxItem) bodyOf,
    required void Function(String itemId) onOpen,
    Duration tick = const Duration(seconds: 20),
  }) : _now = now,
       _attention = attention,
       _store = store,
       _notifier = notifier,
       _bodyOf = bodyOf,
       _onOpen = onOpen,
       _tick = tick;

  static const lastTickKey = 'morkva.reminders.lastTickAt';
  static const pendingKey = 'morkva.reminders.pending';
  static const maxWindow = Duration(hours: 24);
  static const catchUpAfter = Duration(minutes: 2);
  static const pendingTtl = Duration(days: 7);

  final DateTime Function() _now;
  final Attention _attention;
  final ReminderStore _store;
  final SystemNotifier _notifier;
  final String Function(InboxItem) _bodyOf;
  final void Function(String itemId) _onOpen;
  final Duration _tick;

  /// Null until the first [updateItems]: "not loaded" is not "no items", so
  /// nothing ticks (the mark would skip the catch-up) or prunes until then.
  Map<String, InboxItem>? _items;
  List<PendingReminder> _pending = const [];
  final _pendingChanges = StreamController<List<PendingReminder>>.broadcast();
  final _subs = <StreamSubscription<Object?>>[];
  Timer? _timer;

  /// The toasts to show, starting with the current list on listen.
  Stream<List<PendingReminder>> get pending => Stream.multi((c) {
    c.add(_pending);
    final sub = _pendingChanges.stream.listen(c.add, onDone: c.close);
    c.onCancel = sub.cancel;
  });

  List<PendingReminder> get currentPending => _pending;

  void start() {
    _subs
      ..add(_attention.changes.listen((_) => tickNow()))
      ..add(
        _store.changes.listen((key) {
          if (key == pendingKey) _refresh();
        }),
      );
    _timer = Timer.periodic(_tick, (_) => tickNow());
    _refresh();
    tickNow();
  }

  void dispose() {
    _timer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _pendingChanges.close();
  }

  void updateItems(List<InboxItem> items) {
    _items = {for (final i in items) i.id: i};
    _refresh();
    tickNow();
  }

  void dismiss(String key) => _edit((e) => e.key != key);

  void dismissItem(String itemId) => _edit((e) => e.itemId != itemId);

  @visibleForTesting
  void tickNow() {
    final items = _items;
    if (items == null) return;
    final now = _now().millisecondsSinceEpoch;
    final last = int.tryParse(_store.read(lastTickKey) ?? '');
    // Clock moved back: wait for it to pass the mark rather than refire,
    // unless the mark is absurdly ahead (corrupt) - then restart from now.
    if (last != null && now <= last && last - now <= maxWindow.inMilliseconds) {
      return;
    }
    _store.write(lastTickKey, '$now');
    if (last == null || now <= last) return; // first run in this browser
    final from = max(last, now - maxWindow.inMilliseconds);
    final catchUp = now - last > catchUpAfter.inMilliseconds;
    final toasts = <PendingReminder>[];
    for (final item in items.values) {
      for (final fire in item.fireTimes) {
        final at = fire.millisecondsSinceEpoch;
        if (at <= from || at > now) continue;
        final key = '${item.id}@$at';
        if (!catchUp && _notify(item, key)) continue;
        toasts.add(
          PendingReminder(
            key: key,
            itemId: item.id,
            fireAt: fire,
            catchUp: catchUp,
          ),
        );
      }
    }
    if (toasts.isEmpty) return;
    final stored = _stored();
    final known = {for (final e in stored) e.key};
    _write([...stored, ...toasts.where((t) => known.add(t.key))]);
  }

  /// A system notification when the user is away from this tab and allowed
  /// them; false means "show a toast instead".
  bool _notify(InboxItem item, String key) =>
      !_attention.focused &&
      _notifier.permission == NotificationPermission.granted &&
      _notifier.show(
        tag: key,
        title: item.title,
        body: _bodyOf(item),
        onClick: () => _onOpen(item.id),
      );

  void _edit(bool Function(PendingReminder) keep) =>
      _write(_stored().where(keep).toList());

  /// Stored entries younger than [pendingTtl]; a bad shape reads as empty.
  List<PendingReminder> _stored() {
    final cutoff = _now().subtract(pendingTtl);
    try {
      final json = jsonDecode(_store.read(pendingKey) ?? '{}');
      final entries = json is Map ? json['entries'] : null;
      return [
        for (final e in entries is List ? entries : const [])
          ?PendingReminder.tryParse(e),
      ].where((e) => e.fireAt.isAfter(cutoff)).toList();
    } on FormatException {
      return const [];
    }
  }

  void _write(List<PendingReminder> entries) {
    final raw = entries.isEmpty
        ? null
        : jsonEncode({
            'entries': [for (final e in entries) e.toJson()],
          });
    if (raw != _store.read(pendingKey)) _store.write(pendingKey, raw);
    _refresh();
  }

  /// Shows only entries whose item is still open with that fire time (so a
  /// toast vanishes when its item is done, deleted or rescheduled). Filtered,
  /// not deleted: another tab's items may lag behind this one's; leftovers
  /// expire after [pendingTtl].
  void _refresh() {
    final items = _items;
    if (items == null) return; // can't tell live entries from dead ones yet
    final visible = [
      for (final e in _stored())
        if (_live(items[e.itemId], e)) e,
    ];
    if (listEquals(visible, _pending)) return;
    _pending = List.unmodifiable(visible);
    if (!_pendingChanges.isClosed) _pendingChanges.add(_pending);
  }

  static bool _live(InboxItem? item, PendingReminder e) =>
      item != null &&
      item.fireTimes.any(
        (f) => f.millisecondsSinceEpoch == e.fireAt.millisecondsSinceEpoch,
      );
}
