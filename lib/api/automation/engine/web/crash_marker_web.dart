// The web CrashMarker: a localStorage breadcrumb that survives a tab crash
// (an out-of-memory worker can take the tab down with it).
import 'dart:convert';

import 'package:web/web.dart' as web;

import '../../../../core/automation/engine/script_engine.dart';

final class WebCrashMarker implements CrashMarker {
  static const key = 'morkva.automation.crash';

  // localStorage access throws when storage is blocked: a breadcrumb is
  // best effort and must never fail a run.
  @override
  void set(String runId, String automationId) {
    try {
      web.window.localStorage.setItem(
        key,
        jsonEncode({'runId': runId, 'automationId': automationId}),
      );
    } catch (_) {}
  }

  @override
  void clear() {
    try {
      web.window.localStorage.removeItem(key);
    } catch (_) {}
  }

  @override
  ({String runId, String automationId})? leftover() {
    try {
      final raw = web.window.localStorage.getItem(key);
      if (raw == null) return null;
      final m = jsonDecode(raw);
      if (m case {
        'runId': final String runId,
        'automationId': final String automationId,
      }) {
        return (runId: runId, automationId: automationId);
      }
    } catch (_) {}
    return null;
  }
}
