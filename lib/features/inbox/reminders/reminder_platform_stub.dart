import 'reminder_scheduler.dart';

/// shortcut: no system notifications off the web and reminders only fire as
/// toasts while the app runs; mobile gets `flutter_local_notifications`
/// scheduling per spec §8.
ReminderPlatform createReminderPlatform() => ReminderPlatform(
  attention: const _AlwaysFocused(),
  store: _MemoryStore(),
  notifier: const _NoNotifier(),
);

final class _AlwaysFocused implements Attention {
  const _AlwaysFocused();

  @override
  bool get focused => true;

  @override
  Stream<void> get changes => const Stream.empty();
}

final class _MemoryStore implements ReminderStore {
  final _values = <String, String>{};

  @override
  String? read(String key) => _values[key];

  @override
  void write(String key, String? value) =>
      value == null ? _values.remove(key) : _values[key] = value;

  @override
  Stream<String> get changes => const Stream.empty();
}

final class _NoNotifier implements SystemNotifier {
  const _NoNotifier();

  @override
  NotificationPermission get permission => NotificationPermission.unsupported;

  @override
  Future<NotificationPermission> requestPermission() async => permission;

  @override
  bool show({
    required String tag,
    required String title,
    required String body,
    required void Function() onClick,
  }) => false;
}
