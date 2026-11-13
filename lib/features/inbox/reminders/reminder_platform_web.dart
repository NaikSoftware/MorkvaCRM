import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'reminder_scheduler.dart';

ReminderPlatform createReminderPlatform() => ReminderPlatform(
  attention: const _WebAttention(),
  store: _WebStore(),
  notifier: const _WebNotifier(),
);

final class _WebAttention implements Attention {
  const _WebAttention();

  @override
  bool get focused => web.document.hasFocus();

  @override
  Stream<void> get changes => Stream.multi((c) {
    final subs = [
      const web.EventStreamProvider<web.Event>(
        'visibilitychange',
      ).forTarget(web.document),
      web.EventStreamProviders.focusEvent.forTarget(web.window),
      web.EventStreamProviders.blurEvent.forTarget(web.window),
    ].map((events) => events.listen((_) => c.add(null))).toList();
    c.onCancel = () => Future.wait([for (final s in subs) s.cancel()]);
  });
}

/// `localStorage`, or memory when it throws (blocked site data).
final class _WebStore implements ReminderStore {
  final _memory = <String, String>{};

  @override
  String? read(String key) {
    try {
      return web.window.localStorage.getItem(key);
    } catch (_) {
      return _memory[key];
    }
  }

  @override
  void write(String key, String? value) {
    try {
      final storage = web.window.localStorage;
      value == null ? storage.removeItem(key) : storage.setItem(key, value);
    } catch (_) {
      value == null ? _memory.remove(key) : _memory[key] = value;
    }
  }

  @override
  Stream<String> get changes => web.EventStreamProviders.storageEvent
      .forTarget(web.window)
      .expand((e) => [?e.key]);
}

final class _WebNotifier implements SystemNotifier {
  const _WebNotifier();

  static bool get _supported {
    try {
      return globalContext.has('Notification');
    } catch (_) {
      return false;
    }
  }

  @override
  NotificationPermission get permission {
    if (!_supported) return NotificationPermission.unsupported;
    try {
      return _parse(web.Notification.permission);
    } catch (_) {
      return NotificationPermission.unsupported;
    }
  }

  @override
  Future<NotificationPermission> requestPermission() async {
    if (!_supported) return NotificationPermission.unsupported;
    try {
      return _parse((await web.Notification.requestPermission().toDart).toDart);
    } catch (_) {
      // Old Safari takes a callback and returns no promise.
      return permission;
    }
  }

  @override
  bool show({
    required String tag,
    required String title,
    required String body,
    required void Function() onClick,
  }) {
    if (!_supported) return false;
    try {
      final n = web.Notification(
        title,
        web.NotificationOptions(body: body, tag: tag),
      );
      n.onclick = (web.Event _) {
        web.window.focus();
        onClick();
        n.close();
      }.toJS;
      return true;
    } catch (_) {
      // Chrome Android throws from the constructor (service worker only).
      return false;
    }
  }

  static NotificationPermission _parse(String wire) => switch (wire) {
    'granted' => NotificationPermission.granted,
    'denied' => NotificationPermission.denied,
    _ => NotificationPermission.defaultState,
  };
}
