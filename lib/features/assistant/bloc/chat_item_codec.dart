/// The persisted form of [ChatItem]s: the `ui` list of a turn doc
/// (`{schema: 1, type, …}` records of plain JSON).
///
/// What is kept is deliberately compact: tables and charts keep their title,
/// summary and query spec but **no row values** and no handle (handles are not
/// persisted; the spec re-runs), and plans keep only their first 5 items,
/// without the before/after values of their diffs (a restored card never
/// shows them; deleting a card leaves no copy of its values) and without a
/// module's code.
///
/// Decoding restores, it does not resurrect: a turn doc is member-writable,
/// so a malformed record, an unknown `type` or a newer `schema` is skipped
/// (null) rather than failing the thread, and in-flight states map to their
/// settled form (streaming text → stopped, a pending plan → expired, a
/// committing one → interrupted, a running step → failed, an undo in
/// progress → available).
library;

import 'package:morkva_crm/core/agent/agent_event.dart';

import 'chat_item.dart';

/// The record schema this codec writes and reads.
const int kChatItemSchema = 1;

/// Plan items kept per persisted plan.
const int kPersistedPlanItems = 5;

Map<String, Object?> encodeChatItem(ChatItem item) => {
  'schema': kChatItemSchema,
  'id': item.id,
  ...switch (item) {
    UserItem(:final text) => {'type': 'user', 'text': text},
    AssistantTextItem() => {
      'type': 'text',
      'text': item.currentText,
      if (item.streaming) 'streaming': true,
      if (item.stopped) 'stopped': true,
      if (item.cutShort) 'cutShort': true,
    },
    StepsItem(:final steps) => {
      'type': 'steps',
      'steps': [
        for (final s in steps)
          {
            'callId': s.callId,
            'label': s.label,
            'status': s.status.name,
            'summary': ?s.summary,
            'errorCode': ?s.errorCode,
          },
      ],
    },
    TableItem() => {
      'type': 'table',
      'title': item.title,
      'spec': ?item.spec,
      'summary': ?item.summary,
    },
    ChartItem() => {
      'type': 'chart',
      'title': item.title,
      'kind': item.kind.name,
      'spec': ?item.spec,
      'summary': ?item.summary,
    },
    ObjectChipItem() => {
      'type': 'chip',
      'collectionId': item.collectionId,
      'cardId': ?item.cardId,
      'viewId': ?item.viewId,
      'label': item.label,
    },
    PlanItem() => {
      'type': 'plan',
      'planId': item.plan.planId,
      'plan': _persistedPlan(item.plan),
      'selected': [...item.selected],
      'status': item.status.name,
      'message': ?item.message,
    },
    AppliedItem() => {
      'type': 'applied',
      'planId': item.plan.planId,
      'plan': _persistedPlan(item.plan),
      'receipt': item.receipt.toJson(),
      if (item.undoUntil != null)
        'undoUntil': item.undoUntil!.toUtc().toIso8601String(),
      'undoState': item.undoState.name,
      'undoNote': ?item.undoNote,
      if (item.undoSessionOnly) 'undoSessionOnly': true,
      if (item.startedRuns > 0) 'startedRuns': item.startedRuns,
    },
    // The log stays out: a test run's calls and console are session-only.
    TestRunItem(:final result) => {
      'type': 'testRun',
      'title': item.title,
      'result': {...result.toJson()}..remove('log'),
    },
    ErrorItem() => {
      'type': 'error',
      'kind': item.kind.name,
      'message': item.message,
      'nothingChanged': item.nothingChanged,
      'retryable': item.retryable,
    },
  },
};

/// [plan]'s first items with each diff cut to its field and no module
/// `code`: titles, labels and details stay.
Map<String, Object?> _persistedPlan(PlanView plan) {
  final json = plan.compact(maxItems: kPersistedPlanItems).toJson();
  Map<String, Object?> field(Object? change) {
    final c = change! as Map<String, Object?>;
    return {'fieldId': ?c['fieldId'], 'field': c['field']};
  }

  return {
    ...json,
    'items': [
      for (final row in json['items']! as List)
        {
          for (final e in (row as Map<String, Object?>).entries)
            if (e.key != 'code') e.key: e.value,
          'changes': [for (final c in row['changes']! as List) field(c)],
        },
    ],
    if (json['sharedChange'] case final shared?) 'sharedChange': field(shared),
  };
}

List<Map<String, Object?>> encodeChatItems(Iterable<ChatItem> items) => [
  for (final item in items) encodeChatItem(item),
];

/// The item [record] holds, in its settled form, or null when the record is
/// malformed, of an unknown type or from a newer schema.
ChatItem? decodeChatItem(Object? record) {
  if (record is! Map) return null;
  final json = record.cast<String, Object?>();
  if (json['schema'] != kChatItemSchema) return null;
  try {
    return _decode(json);
  } on FormatException {
    return null;
  } on TypeError {
    // A wrong-typed value in a member-writable doc: skip the record.
    return null;
  }
}

/// Every decodable item of [records], in order.
List<ChatItem> decodeChatItems(Iterable<Object?> records) => [
  for (final r in records) ?decodeChatItem(r),
];

ChatItem? _decode(Map<String, Object?> json) {
  final id = _str(json, 'id');
  switch (json['type']) {
    case 'user':
      return UserItem(id: id, text: _str(json, 'text'));
    case 'text':
      final streaming = json['streaming'] == true;
      return AssistantTextItem(
        id: id,
        text: _str(json, 'text'),
        stopped: streaming || json['stopped'] == true,
        cutShort: json['cutShort'] == true,
      );
    case 'steps':
      return StepsItem(
        id: id,
        steps: [
          for (final raw in _list(json, 'steps'))
            if (raw is Map) _step(raw.cast<String, Object?>()),
        ],
      );
    case 'table':
      return TableItem(
        id: id,
        title: _str(json, 'title'),
        spec: _mapOrNull(json['spec']),
        summary: json['summary'] as String?,
      );
    case 'chart':
      final kind = _enum(PresentKind.values, json['kind'], PresentKind.bar)!;
      return ChartItem(
        id: id,
        title: _str(json, 'title'),
        kind: kind == PresentKind.table ? PresentKind.bar : kind,
        spec: _mapOrNull(json['spec']),
        summary: json['summary'] as String?,
      );
    case 'chip':
      return ObjectChipItem(
        id: id,
        collectionId: _str(json, 'collectionId'),
        cardId: json['cardId'] as String?,
        viewId: json['viewId'] as String?,
        label: _str(json, 'label'),
      );
    case 'plan':
      final plan = _plan(json);
      final status = _enum(PlanStatus.values, json['status'], null);
      if (status == null) return null;
      return PlanItem(
        id: id,
        plan: plan,
        selected: {
          for (final s in _list(json, 'selected'))
            if (s is String) s,
        },
        status: switch (status) {
          PlanStatus.pending => PlanStatus.expired,
          PlanStatus.committing => PlanStatus.interrupted,
          _ => status,
        },
        message: json['message'] as String?,
      );
    case 'applied':
      final undoState = _enum(UndoState.values, json['undoState'], null);
      final undoUntil = json['undoUntil'];
      if (undoState == null) return null;
      return AppliedItem(
        id: id,
        plan: _plan(json),
        receipt: Receipt.fromJson(_map(json['receipt'], 'receipt')),
        undoUntil: undoUntil is String ? DateTime.parse(undoUntil) : null,
        undoState: undoState == UndoState.undoing
            ? UndoState.available
            : undoState,
        undoNote: json['undoNote'] as String?,
        undoSessionOnly: json['undoSessionOnly'] == true,
        startedRuns: (json['startedRuns'] as num?)?.toInt() ?? 0,
      );
    case 'testRun':
      return TestRunItem(
        id: id,
        title: _str(json, 'title'),
        result: testRunResultFromJson(_map(json['result'], 'result')),
      );
    case 'error':
      return ErrorItem(
        id: id,
        kind: _enum(ChatErrorKind.values, json['kind'], ChatErrorKind.unknown)!,
        message: _str(json, 'message'),
        nothingChanged: json['nothingChanged'] != false,
        retryable: json['retryable'] != false,
      );
    default:
      return null;
  }
}

StepView _step(Map<String, Object?> json) {
  final status = _enum(StepStatus.values, json['status'], StepStatus.done)!;
  return StepView(
    callId: _str(json, 'callId'),
    label: _str(json, 'label'),
    // A step that never finished before the reload did not complete.
    status: status == StepStatus.running ? StepStatus.failed : status,
    summary: json['summary'] as String?,
    errorCode: json['errorCode'] as String?,
  );
}

PlanView _plan(Map<String, Object?> json) {
  final plan = PlanView.fromJson(_map(json['plan'], 'plan'));
  if (plan.planId != json['planId']) {
    throw const FormatException('"planId" does not match the plan');
  }
  return plan;
}

T? _enum<T extends Enum>(List<T> values, Object? wire, T? fallback) =>
    values.asNameMap()[wire] ?? fallback;

String _str(Map<String, Object?> json, String key) => switch (json[key]) {
  final String s => s,
  _ => throw FormatException('"$key" must be a string'),
};

List<Object?> _list(Map<String, Object?> json, String key) =>
    switch (json[key]) {
      null => const [],
      final List l => l,
      _ => throw FormatException('"$key" must be a list'),
    };

Map<String, Object?> _map(Object? value, String key) => switch (value) {
  final Map m => m.cast<String, Object?>(),
  _ => throw FormatException('"$key" must be an object'),
};

Map<String, Object?>? _mapOrNull(Object? value) =>
    value is Map ? value.cast<String, Object?>() : null;
