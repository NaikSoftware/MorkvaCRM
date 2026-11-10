import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:morkva_crm/core/agent/agent_event.dart';

/// One entry of the chat, rendered from structured parts only (no markdown).
/// Every item has a stable [id] (list keys, in-place replacement); the bloc
/// mints it. Persisted through `chat_item_codec.dart`.
sealed class ChatItem extends Equatable {
  const ChatItem(this.id);

  final String id;
}

/// The user's message (soft bubble, right-aligned).
final class UserItem extends ChatItem {
  const UserItem({required String id, required this.text}) : super(id);

  final String text;

  @override
  List<Object?> get props => [id, text];
}

/// The assistant's answer text: plain paragraphs with `**bold**` spans and
/// line breaks only.
///
/// While [streaming], [text] is the text at the last item replacement and
/// [live] (owned by the bloc, updated per delta) carries the growing text, so
/// a delta repaints one paragraph instead of the list. [live] is neither
/// compared nor persisted.
final class AssistantTextItem extends ChatItem {
  const AssistantTextItem({
    required String id,
    required this.text,
    this.streaming = false,
    this.stopped = false,
    this.cutShort = false,
    this.live,
  }) : super(id);

  final String text;

  /// Still receiving text: show the caret.
  final bool streaming;

  /// Stop was pressed (or the page reloaded) mid-answer: "Stopped".
  final bool stopped;

  /// The answer hit the output limit: "cut short".
  final bool cutShort;

  final ValueListenable<String>? live;

  /// The text to show now.
  String get currentText => live?.value ?? text;

  AssistantTextItem copyWith({
    String? text,
    bool? streaming,
    bool? stopped,
    bool? cutShort,
    ValueListenable<String>? live,
    bool clearLive = false,
  }) => AssistantTextItem(
    id: id,
    text: text ?? this.text,
    streaming: streaming ?? this.streaming,
    stopped: stopped ?? this.stopped,
    cutShort: cutShort ?? this.cutShort,
    live: clearLive ? null : live ?? this.live,
  );

  @override
  List<Object?> get props => [id, text, streaming, stopped, cutShort];
}

enum StepStatus { running, done, failed }

/// One tool call of a turn.
final class StepView extends Equatable {
  const StepView({
    required this.callId,
    required this.label,
    this.status = StepStatus.running,
    this.summary,
    this.errorCode,
  });

  final String callId;

  /// The running line ("Filtering 36 fabrics where Metres left < 5…").
  final String label;
  final StepStatus status;

  /// The result's one-line summary, or the failure's short reason.
  final String? summary;

  /// The harness error code of a failed step.
  final String? errorCode;

  /// What the step line shows.
  String get text => summary ?? label;

  StepView finish({required bool ok, required String summary, String? code}) =>
      StepView(
        callId: callId,
        label: label,
        status: ok ? StepStatus.done : StepStatus.failed,
        summary: summary,
        errorCode: code,
      );

  @override
  List<Object?> get props => [callId, label, status, summary, errorCode];
}

/// The tool-steps chip: collapsed to one line, expandable to a line per step.
final class StepsItem extends ChatItem {
  const StepsItem({required String id, required this.steps}) : super(id);

  final List<StepView> steps;

  bool get running => steps.any((s) => s.status == StepStatus.running);

  /// The collapsed line ("Looked at Orders · filtered 148 → 5 · summed Total").
  /// Failed steps the model recovered from are counted, not repeated, so the
  /// line reads "… · 2 steps didn't go through" instead of listing each one.
  String get headline {
    final ok = steps.where((s) => s.status != StepStatus.failed).toList();
    final failed = steps.length - ok.length;
    if (failed == 0 || ok.isEmpty) return steps.map((s) => s.text).join(' · ');
    final note = failed == 1
        ? "1 step didn't go through"
        : "$failed steps didn't go through";
    return [...ok.map((s) => s.text), note].join(' · ');
  }

  @override
  List<Object?> get props => [id, steps];
}

// ---------------------------------------------------------------------------
// Results rendered from handles.

/// A table column.
final class ResultColumn extends Equatable {
  const ResultColumn(this.label, {this.numeric = false});

  final String label;

  /// Right-aligned, tabular figures.
  final bool numeric;

  @override
  List<Object?> get props => [label, numeric];
}

/// One table row, display text per column. The first cell is the card's
/// title, rendered as an object chip linking to [cardId].
final class ResultRow extends Equatable {
  const ResultRow({this.cardId, required this.cells});

  final String? cardId;
  final List<String> cells;

  @override
  List<Object?> get props => [cardId, cells];
}

/// The renderable read-model of a table result, materialized by the bloc from
/// the harness result handle (never authored by the model).
final class ResultTable extends Equatable {
  const ResultTable({
    required this.columns,
    required this.rows,
    this.totals,
    int? totalCount,
    this.collectionId,
  }) : _totalCount = totalCount;

  /// At most 6; wider tables scroll inside the card.
  final List<ResultColumn> columns;

  /// The rows shown (the first page).
  final List<ResultRow> rows;

  /// The footer row, aligned with [columns] ('' for an empty cell).
  final List<String>? totals;

  final int? _totalCount;

  /// Rows matching the query ("Show all N"); defaults to [rows]' length.
  int get totalCount => _totalCount ?? rows.length;

  /// The collection the rows belong to (object chips, "Open as filtered
  /// view").
  final String? collectionId;

  @override
  List<Object?> get props => [columns, rows, totals, totalCount, collectionId];
}

/// One bar or point.
final class ChartPoint extends Equatable {
  const ChartPoint(this.label, this.value, {this.partial = false});

  /// The axis label ("O", "Oct", "2026-10").
  final String label;
  final double? value;

  /// The period is not over yet: drawn dashed.
  final bool partial;

  @override
  List<Object?> get props => [label, value, partial];
}

/// The renderable read-model of an aggregate shown as a chart.
final class ResultChart extends Equatable {
  const ResultChart({
    required this.points,
    required this.metricLabel,
    this.collectionId,
  });

  final List<ChartPoint> points;

  /// The value axis caption ("Sum of Total, ₴").
  final String metricLabel;
  final String? collectionId;

  @override
  List<Object?> get props => [points, metricLabel, collectionId];
}

/// A result table card. [table] is null until the bloc has read the handle
/// (and after a reload, until it re-runs [spec]).
final class TableItem extends ChatItem {
  const TableItem({
    required String id,
    required this.title,
    this.handle,
    this.spec,
    this.summary,
    this.table,
  }) : super(id);

  final String title;

  /// The live result handle; not persisted.
  final String? handle;

  /// The query spec behind the result, persisted so it can re-run.
  final Map<String, Object?>? spec;
  final String? summary;
  final ResultTable? table;

  @override
  List<Object?> get props => [id, title, handle, spec, summary, table];
}

/// A bar or line chart card ([kind] is never `table`).
final class ChartItem extends ChatItem {
  const ChartItem({
    required String id,
    required this.title,
    this.kind = PresentKind.bar,
    this.handle,
    this.spec,
    this.summary,
    this.chart,
  }) : super(id);

  final String title;
  final PresentKind kind;
  final String? handle;
  final Map<String, Object?>? spec;
  final String? summary;
  final ResultChart? chart;

  @override
  List<Object?> get props => [id, title, kind, handle, spec, summary, chart];
}

/// An object or view chip from `ui.open`; navigates only on tap.
final class ObjectChipItem extends ChatItem {
  const ObjectChipItem({
    required String id,
    required this.collectionId,
    this.cardId,
    this.viewId,
    required this.label,
  }) : super(id);

  final String collectionId;
  final String? cardId;
  final String? viewId;
  final String label;

  @override
  List<Object?> get props => [id, collectionId, cardId, viewId, label];
}

// ---------------------------------------------------------------------------
// Plans.

enum PlanRisk { low, medium, high }

/// One field's before → after, harness-written display text.
final class PlanChange extends Equatable {
  const PlanChange({
    this.fieldId,
    required this.field,
    this.beforeText,
    this.afterText,
  });

  final String? fieldId;

  /// The field name.
  final String field;

  /// Null when the value was empty (creates) or goes away (deletes).
  final String? beforeText;
  final String? afterText;

  @override
  List<Object?> get props => [fieldId, field, beforeText, afterText];
}

/// One reviewable item of a plan (a card, field, view or collection change).
final class PlanRow extends Equatable {
  const PlanRow({
    required this.itemId,
    required this.kind,
    required this.label,
    this.collectionId,
    this.targetId,
    this.risk = PlanRisk.low,
    this.changes = const [],
    this.detail,
  });

  final String itemId;

  /// `updateCard`, `createCard`, `deleteCard`, `addField`, `createCollection`,
  /// … (the harness's item kind).
  final String kind;

  /// Sanitized, single-line ("#1042 · Iryna Melnyk", "Phone").
  final String label;
  final String? collectionId;

  /// The card, field or view the item touches.
  final String? targetId;
  final PlanRisk risk;
  final List<PlanChange> changes;

  /// A harness-written secondary line: a field's type and options
  /// ("Select · Kyiv, Lviv, Odesa"), a deleted card's context.
  final String? detail;

  @override
  List<Object?> get props => [
    itemId,
    kind,
    label,
    collectionId,
    targetId,
    risk,
    changes,
    detail,
  ];
}

/// The rows of one item kind; a mixed plan renders one group per kind.
final class PlanGroup extends Equatable {
  const PlanGroup(this.kind, this.rows);

  final String kind;
  final List<PlanRow> rows;

  /// The highest risk of the group's rows.
  PlanRisk get risk => rows.fold(
    PlanRisk.low,
    (max, r) => r.risk.index > max.index ? r.risk : max,
  );

  @override
  List<Object?> get props => [kind, rows];
}

final class PlanWarning extends Equatable {
  const PlanWarning(this.code, this.message);

  final String code;
  final String message;

  @override
  List<Object?> get props => [code, message];
}

/// The UI read-model of a plan, parsed from the harness plan JSON: the full
/// plan from `plans.get`, or the compact one (first 5 items) from
/// `plans.seal`. Every string in it is harness-written.
final class PlanView extends Equatable {
  const PlanView({
    required this.planId,
    required this.title,
    this.risk = PlanRisk.low,
    this.rows = const [],
    int? itemCount,
    this.sharedChange,
    this.warnings = const [],
    this.notes = const [],
    this.undo = 'full',
    this.expiresAt,
  }) : _itemCount = itemCount;

  /// Parses the plan JSON. Throws [FormatException] on a wrong shape.
  factory PlanView.fromJson(Map<String, Object?> json) {
    final risk = _risk(json['risk']) ?? PlanRisk.low;
    final rows = [
      for (final raw in _list(json, 'items'))
        _row(_map(raw, 'items[]'), fallbackRisk: risk),
    ];
    final shared = json['sharedChange'];
    final expires = json['expiresAt'];
    return PlanView(
      planId: _str(json, 'planId'),
      title: json['title'] as String? ?? '',
      risk: risk,
      rows: rows,
      itemCount: (json['itemCount'] as num?)?.toInt(),
      sharedChange: shared == null
          ? null
          : _change(_map(shared, 'sharedChange')),
      warnings: [
        for (final raw in _list(json, 'warnings'))
          _warning(_map(raw, 'warnings[]')),
      ],
      notes: [for (final n in _list(json, 'notes')) '$n'],
      undo: json['undo'] as String? ?? 'full',
      expiresAt: expires is String ? DateTime.tryParse(expires) : null,
    );
  }

  final String planId;

  /// "Set Status to Shipped · 3 orders".
  final String title;

  /// The max over the items.
  final PlanRisk risk;

  /// The items known so far (all of them once the full plan is loaded).
  final List<PlanRow> rows;

  final int? _itemCount;

  /// Items in the whole plan (may exceed [rows] for a compact plan); defaults
  /// to [rows]' length.
  int get itemCount => _itemCount ?? rows.length;

  /// The diff shown once in the header when every item gets the same
  /// old → new value; rows then list only the items.
  final PlanChange? sharedChange;
  final List<PlanWarning> warnings;
  final List<String> notes;

  /// `full`, `partial` or `none`.
  final String undo;
  final DateTime? expiresAt;

  /// Whether [rows] holds every item.
  bool get isComplete => rows.length >= itemCount;

  /// A destructive plan (error border, typed confirm for collections).
  bool get destructive => risk == PlanRisk.high;

  /// Rows grouped by kind, in first-appearance order. A plan that only
  /// creates one collection and its fields is one group: the collection
  /// row, then its field rows.
  List<PlanGroup> get groups {
    final byKind = <String, List<PlanRow>>{};
    for (final r in rows) {
      (byKind[r.kind] ??= []).add(r);
    }
    if ((byKind['createCollection'], byKind['addField'])
        case ([final collection], final fields?)
        when byKind.length == 2 &&
            fields.every((f) => f.collectionId == collection.collectionId)) {
      return [
        PlanGroup('createCollection', [collection, ...fields]),
      ];
    }
    return [for (final e in byKind.entries) PlanGroup(e.key, e.value)];
  }

  /// The selection a fresh card starts with: every item, except that in a
  /// plan mixing several kinds, medium- and high-risk groups start unticked
  /// (so a delete cannot ride along under "Approve N").
  Set<String> get defaultSelection {
    final groups = this.groups;
    final mixed = groups.length > 1;
    return {
      for (final g in groups)
        if (!mixed || g.risk == PlanRisk.low)
          for (final r in g.rows) r.itemId,
    };
  }

  /// The same plan cut to its first [maxItems] rows (what is persisted).
  PlanView compact({int maxItems = 5}) => rows.length <= maxItems
      ? this
      : PlanView(
          planId: planId,
          title: title,
          risk: risk,
          rows: rows.take(maxItems).toList(),
          itemCount: itemCount,
          sharedChange: sharedChange,
          warnings: warnings,
          notes: notes,
          undo: undo,
          expiresAt: expiresAt,
        );

  /// The plan JSON shape [PlanView.fromJson] reads.
  Map<String, Object?> toJson() => {
    'planId': planId,
    'title': title,
    'risk': risk.name,
    'items': [for (final r in rows) _rowJson(r)],
    'itemCount': itemCount,
    if (sharedChange != null) 'sharedChange': _changeJson(sharedChange!),
    'warnings': [
      for (final w in warnings) {'code': w.code, 'message': w.message},
    ],
    'notes': notes,
    'undo': undo,
    if (expiresAt != null) 'expiresAt': expiresAt!.toUtc().toIso8601String(),
  };

  @override
  List<Object?> get props => [
    planId,
    title,
    risk,
    rows,
    itemCount,
    sharedChange,
    warnings,
    notes,
    undo,
    expiresAt,
  ];
}

/// Where a plan card stands.
enum PlanStatus {
  /// Awaiting approval.
  pending,

  /// Approved, being written ("Updating 120 of 200…").
  committing,
  applied,

  /// "Rejected — nothing changed".
  rejected,

  /// A new message was sent instead: "Skipped — nothing changed".
  skipped,

  /// Every selected item changed since the preview.
  stale,

  /// The plan outlived its 15 minutes (or the page reloaded): "Rebuild".
  expired,

  /// The page reloaded while it was committing: some chunks may have been
  /// written ("May have been partly applied"), so it is never rebuilt.
  interrupted,

  /// The commit failed (e.g. "Needs a connection").
  failed,
}

/// A plan card. Once applied, the bloc adds an [AppliedItem] after it.
final class PlanItem extends ChatItem {
  const PlanItem({
    required String id,
    required this.plan,
    required this.selected,
    this.status = PlanStatus.pending,
    this.message,
  }) : super(id);

  /// A fresh pending card with the plan's default selection.
  factory PlanItem.proposed({required String id, required PlanView plan}) =>
      PlanItem(id: id, plan: plan, selected: plan.defaultSelection);

  final PlanView plan;

  /// The ticked item ids.
  final Set<String> selected;
  final PlanStatus status;

  /// A harness-written reason for [PlanStatus.failed] / [PlanStatus.stale].
  final String? message;

  PlanItem copyWith({
    PlanView? plan,
    Set<String>? selected,
    PlanStatus? status,
    String? message,
    bool clearMessage = false,
  }) => PlanItem(
    id: id,
    plan: plan ?? this.plan,
    selected: selected ?? this.selected,
    status: status ?? this.status,
    message: clearMessage ? null : message ?? this.message,
  );

  @override
  List<Object?> get props => [id, plan, selected, status, message];
}

enum UndoState {
  /// The Undo button shows until [AppliedItem.undoUntil].
  available,

  /// Undo is being written.
  undoing,

  /// "Reverted 12 orders".
  undone,

  /// "Undo expired".
  expired,

  /// Undo could not run (or skipped items): see [AppliedItem.undoNote].
  failed,
}

/// The collapsed result of an approved plan, with Undo for the window.
final class AppliedItem extends ChatItem {
  const AppliedItem({
    required String id,
    required this.plan,
    required this.receipt,
    this.undoUntil,
    this.undoState = UndoState.available,
    this.undoNote,
    this.undoSessionOnly = false,
  }) : super(id);

  /// The plan as previewed (title, rows for schema changes).
  final PlanView plan;
  final Receipt receipt;

  /// When Undo expires (the receipt's `undoUntil`, or null: no undo).
  final DateTime? undoUntil;
  final UndoState undoState;

  /// The undo result line ("Reverted 12 orders", "3 cards changed since;
  /// left as they are").
  final String? undoNote;

  /// The journal mirror did not fit the message doc: "Undo available until
  /// you close Morkva".
  final bool undoSessionOnly;

  AppliedItem copyWith({
    Receipt? receipt,
    UndoState? undoState,
    String? undoNote,
    bool clearUndoNote = false,
    bool? undoSessionOnly,
  }) => AppliedItem(
    id: id,
    plan: plan,
    receipt: receipt ?? this.receipt,
    undoUntil: undoUntil,
    undoState: undoState ?? this.undoState,
    undoNote: clearUndoNote ? null : undoNote ?? this.undoNote,
    undoSessionOnly: undoSessionOnly ?? this.undoSessionOnly,
  );

  @override
  List<Object?> get props => [
    id,
    plan,
    receipt,
    undoUntil,
    undoState,
    undoNote,
    undoSessionOnly,
  ];
}

/// What went wrong, for the error row's icon and the retry decision.
enum ChatErrorKind {
  /// Dropped connection, 5xx, malformed response.
  connection,
  rateLimited,
  dailyQuota,

  /// "I can't help with that request."
  blocked,
  notSetUp,
  unavailable,

  /// The conversation could not be saved.
  saveFailed,
  unknown,
}

/// The dashed error row: [message] is the full text shown ("The connection
/// dropped before I finished. Nothing was changed."); "Try again" re-runs the
/// last turn when [retryable].
final class ErrorItem extends ChatItem {
  const ErrorItem({
    required String id,
    required this.kind,
    required this.message,
    this.nothingChanged = true,
    this.retryable = true,
  }) : super(id);

  final ChatErrorKind kind;
  final String message;

  /// No plan of the failed turn was committed.
  final bool nothingChanged;
  final bool retryable;

  @override
  List<Object?> get props => [id, kind, message, nothingChanged, retryable];
}

// ---------------------------------------------------------------------------
// Plan JSON helpers.

PlanRow _row(Map<String, Object?> json, {required PlanRisk fallbackRisk}) =>
    PlanRow(
      itemId: _str(json, 'itemId'),
      kind: _str(json, 'kind'),
      label: json['label'] as String? ?? '',
      collectionId: json['collectionId'] as String?,
      targetId: json['targetId'] as String?,
      risk: _risk(json['risk']) ?? fallbackRisk,
      changes: [
        for (final c in _list(json, 'changes')) _change(_map(c, 'changes[]')),
      ],
      detail: json['detail'] as String?,
    );

Map<String, Object?> _rowJson(PlanRow r) => {
  'itemId': r.itemId,
  'kind': r.kind,
  'label': r.label,
  'collectionId': ?r.collectionId,
  'targetId': ?r.targetId,
  'risk': r.risk.name,
  'changes': [for (final c in r.changes) _changeJson(c)],
  'detail': ?r.detail,
};

PlanChange _change(Map<String, Object?> json) => PlanChange(
  fieldId: json['fieldId'] as String?,
  field: json['field'] as String? ?? '',
  beforeText: json['beforeText'] as String?,
  afterText: json['afterText'] as String?,
);

Map<String, Object?> _changeJson(PlanChange c) => {
  'fieldId': ?c.fieldId,
  'field': c.field,
  'beforeText': ?c.beforeText,
  'afterText': ?c.afterText,
};

PlanWarning _warning(Map<String, Object?> json) =>
    PlanWarning(json['code'] as String? ?? '', _str(json, 'message'));

PlanRisk? _risk(Object? wire) => PlanRisk.values.asNameMap()[wire];

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
