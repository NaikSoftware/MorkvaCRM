import 'reminder_platform_stub.dart'
    if (dart.library.js_interop) 'reminder_platform_web.dart'
    as impl;
import 'reminder_scheduler.dart';

/// The reminder ports for this platform: browser APIs on web, inert stubs
/// elsewhere.
ReminderPlatform createReminderPlatform() => impl.createReminderPlatform();
