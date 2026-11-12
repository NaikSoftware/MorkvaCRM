// Collects one run's log while it runs. Entries are plain-text summaries,
// never card values in full (PII); `encodeRunLog` fits the result into the
// run doc's 64 KB budget.
import 'dart:convert';

import '../domain/automation/automation.dart';
import '../domain/automation/codec.dart' show cutText;
import '../harness/api/envelope.dart';
import '../harness/plan/plan.dart';
import '../harness/query/result_shaper.dart';
import 'engine/protocol.dart';

/// The result text of a `no_change` call: information, not a failure.
const String kNoChangeText = 'Already up to date';

const ResultShaper _clean = ResultShaper(textMax: kMaxLogLineChars);

/// Builds a [RunLog]: call rows, console lines (≤ [kMaxLogLinesPerRun],
/// the rest counted as dropped), `ui.open` links, the plan's rows and the
/// action's return value (→ [summary]). `t` is milliseconds since the
/// builder was made, read from [now].
final class RunLogBuilder {
  RunLogBuilder({required DateTime Function() now})
    : _now = now,
      _start = now();

  final DateTime Function() _now;
  final DateTime _start;

  /// Why it fired: the trigger evaluation line.
  String? triggerEval;

  /// Why the plan was not auto-applied.
  String? policy;

  /// The run summary the action returned (≤ 200 chars), or null.
  String? summary;

  final _calls = <RunCall>[];
  final _console = <ConsoleLine>[];
  final _plan = <PlanLine>[];
  final _links = <UiLink>[];
  Map<String, Object?>? _returned;
  var _droppedConsole = 0;

  int get _t => _now().difference(_start).inMilliseconds;

  /// One answered call. [error] (a `HarnessError` JSON) marks it failed,
  /// except `no_change`, which reads as [kNoChangeText].
  void call({
    required String op,
    required String kind,
    Map<String, Object?>? args,
    Map<String, Object?>? result,
    HarnessErrorJson? error,
    int ms = 0,
  }) {
    final noChange = error?['code'] == ErrorCode.noChange.wire;
    _calls.add(
      RunCall(
        t: _t,
        op: _clean.name(op),
        kind: kind,
        args: summarizeArgs(args),
        ok: error == null || noChange,
        result: switch (error) {
          null => _clean.text('${result?['summary'] ?? 'Done'}'),
          _ when noChange => kNoChangeText,
          _ => _clean.text('${error['code']} — ${error['message']}'),
        },
        ms: ms,
      ),
    );
    if (op == 'ui.open' && error == null && result != null) _link(result);
  }

  /// A `console.*` / `morkva.log` line; `log` reads as `info`.
  void console(String level, List<String> args) {
    if (_console.length >= kMaxLogLinesPerRun) {
      _droppedConsole++;
      return;
    }
    _console.add(
      ConsoleLine(
        t: _t,
        level: level == 'log' ? 'info' : level,
        text: _clean.text(args.join(' ')),
      ),
    );
  }

  /// The sealed plan's items as rows ("Shipped on: — → 2026-11-12").
  void plan(Plan plan) {
    _plan
      ..clear()
      ..addAll([
        for (final item in plan.items)
          PlanLine(
            kind: item.kind.name,
            label: item.label,
            change: item.changes.isEmpty
                ? item.detail ?? item.kind.name
                : [
                    for (final c in item.changes)
                      '${c.field}: ${c.beforeText ?? '—'} → '
                          '${c.afterText ?? '—'}',
                  ].join('; '),
            changes: [
              for (final c in item.changes)
                (field: c.field, before: c.beforeText, after: c.afterText),
            ],
          ),
      ]);
  }

  /// The action's return value: a string, or `{message}`, becomes
  /// [summary]; an object's other keys are kept (≤ 4 KB). Anything over
  /// [kMaxReturnValueBytes] keeps only the summary.
  void returned(Object? value) {
    final message = switch (value) {
      final String s => s,
      {'message': final String s} => s,
      _ => null,
    };
    if (message != null) summary = cutText(_clean.text(message), 200);
    if (value is! Map<String, Object?>) return;
    final rest = {...value}..remove('message');
    if (rest.isEmpty) return;
    final bytes = utf8.encode(jsonEncode(value)).length;
    if (bytes > kMaxReturnValueBytes) {
      console('warn', [
        'The action returned more than 16 KB; only the summary was kept',
      ]);
    } else if (utf8.encode(jsonEncode(rest)).length >
        RunLog.kMaxReturnedBytes) {
      console('warn', [
        'The action returned more than 4 KB besides "message"; it was not kept',
      ]);
    } else {
      _returned = rest;
    }
  }

  /// The `ui.open` chips so far.
  List<UiLink> get links => List.unmodifiable(_links);

  RunLog build() => RunLog(
    triggerEval: triggerEval,
    calls: List.unmodifiable(_calls),
    console: List.unmodifiable(_console),
    plan: List.unmodifiable(_plan),
    ui: links,
    policy: policy,
    returned: _returned,
    dropped: RunLogDropped(console: _droppedConsole),
  );

  // Links: `card` → `<collectionId>/<cardId>`, `view` →
  // `<collectionId>/<viewId>`, `collection` → `<collectionId>`.
  void _link(Map<String, Object?> result) {
    if (_links.length >= RunLog.kMaxUiLinks) return;
    final collectionId = result['collectionId'];
    if (collectionId is! String) return;
    final (kind, ref) = switch ((result['cardId'], result['viewId'])) {
      (final String card, _) => ('card', '$collectionId/$card'),
      (_, final String view) => ('view', '$collectionId/$view'),
      _ => ('collection', collectionId),
    };
    _links.add(
      UiLink(
        kind: kind,
        ref: ref,
        label: _clean.label('${result['label'] ?? ''}'),
      ),
    );
  }
}

/// A call's args in one line, values never in full: strings cut to 80
/// chars, lists as their length, objects as their keys
/// (`collection: Orders · ids: [2] · values: {Status, Shipped on}`).
String summarizeArgs(Map<String, Object?>? args) {
  if (args == null || args.isEmpty) return '';
  final parts = [
    for (final MapEntry(:key, :value) in args.entries)
      '${_clean.name(key)}: ${switch (value) {
        final String s => _clean.label(s),
        num() || bool() || null => '$value',
        final List l => '[${l.length}]',
        final Map m => '{${m.keys.map((k) => _clean.name('$k')).join(', ')}}',
        _ => '?',
      }}',
  ];
  return cutText(parts.join(' · '), 300);
}
