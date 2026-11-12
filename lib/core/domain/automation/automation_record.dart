import 'package:equatable/equatable.dart';

import 'codec.dart';
import 'module_record.dart';

/// What starts a run: a button press or a card event.
enum TriggerKind {
  button('button'),
  cardCreated('card.created'),
  cardUpdated('card.updated'),
  cardDeleted('card.deleted');

  const TriggerKind(this.wire);

  final String wire;

  bool get isEvent => this != button;

  static TriggerKind? fromWire(Object? wire) {
    for (final k in values) {
      if (k.wire == wire) return k;
    }
    return null;
  }
}

/// Where a button shows: a card's header or a collection's Actions menu.
enum ButtonScope { card, collection }

/// `card.updated`: fire once when the card starts matching (default) or on
/// every matching update.
enum TriggerMode { enters, matches }

/// The trigger of an automation: [ButtonTrigger] or [EventTrigger].
sealed class TriggerSpec extends Equatable {
  const TriggerSpec(this.collectionId);

  /// Throws [FormatException].
  factory TriggerSpec.fromJson(Map<String, Object?> json) {
    final kind = TriggerKind.fromWire(json['kind']);
    final collectionId = readString(json, 'collectionId');
    return switch (kind) {
      null => throw FormatException('Unknown trigger "${json['kind']}"'),
      TriggerKind.button => ButtonTrigger(
        scope: readEnum(json, 'scope', ButtonScope.values, (s) => s.name),
        collectionId: collectionId,
      ),
      _ => EventTrigger(
        kind: kind,
        collectionId: collectionId,
        where: switch (json['where'] ?? const []) {
          final List<Object?> l when l.every((w) => w is Map) => [
            for (final w in l) (w as Map).cast<String, Object?>(),
          ],
          _ => throw const FormatException('"where" must be a list'),
        },
        mode:
            readEnumOrNull(json, 'mode', TriggerMode.values, (m) => m.name) ??
            TriggerMode.enters,
        fields: readStringsOrNull(json, 'fields'),
      ),
    };
  }

  final String collectionId;

  TriggerKind get kind;

  Map<String, Object?> toJson();
}

final class ButtonTrigger extends TriggerSpec {
  const ButtonTrigger({required this.scope, required String collectionId})
    : super(collectionId);

  final ButtonScope scope;

  @override
  TriggerKind get kind => TriggerKind.button;

  @override
  Map<String, Object?> toJson() => {
    'kind': kind.wire,
    'scope': scope.name,
    'collectionId': collectionId,
  };

  @override
  List<Object?> get props => [scope, collectionId];
}

final class EventTrigger extends TriggerSpec {
  const EventTrigger({
    required this.kind,
    required String collectionId,
    this.where = const [],
    this.mode = TriggerMode.enters,
    this.fields,
  }) : assert(kind != TriggerKind.button),
       super(collectionId);

  @override
  final TriggerKind kind;

  /// Friendly filter JSON, id-normalized at save (`{field, op, value}` or
  /// `{field, op, relative}`), AND-ed.
  final List<Map<String, Object?>> where;

  /// `card.updated` only.
  final TriggerMode mode;

  /// `card.updated` only: fire only when one of these field ids changed.
  final List<String>? fields;

  @override
  Map<String, Object?> toJson() => {
    'kind': kind.wire,
    'collectionId': collectionId,
    'where': where,
    'mode': mode.name,
    'fields': ?fields,
  };

  @override
  List<Object?> get props => [kind, collectionId, where, mode, fields];
}

/// A button's look: label (≤ 24), a collection icon id, a collection tint id
/// and its order among the collection's buttons.
final class ButtonSpec extends Equatable {
  const ButtonSpec({required this.label, this.icon, this.tint, this.order = 0});

  static const int kMaxLabel = 24;

  factory ButtonSpec.fromJson(Map<String, Object?> json) => ButtonSpec(
    label: readString(json, 'label'),
    icon: readStringOrNull(json, 'icon'),
    tint: readStringOrNull(json, 'tint'),
    order: readIntOrNull(json, 'order') ?? 0,
  );

  final String label;
  final String? icon;
  final String? tint;
  final int order;

  Map<String, Object?> toJson() => {
    'label': label,
    'icon': ?icon,
    'tint': ?tint,
    'order': order,
  };

  @override
  List<Object?> get props => [label, icon, tint, order];
}

enum ApplyMode { ask, auto }

/// Why the runner paused an automation (stored).
enum PausedReason {
  broken('broken'),
  loopSuspected('loop_suspected'),
  crashed('crashed');

  const PausedReason(this.wire);

  final String wire;
}

/// `workspaces/{wid}/automations/{id}`: one module action bound to a
/// button or a card event.
///
/// Dates are [DateTime] in [toJson]/[fromJson]; the store converts
/// Timestamps.
final class AutomationRecord extends Equatable {
  const AutomationRecord({
    required this.id,
    required this.name,
    required this.enabled,
    required this.moduleId,
    required this.actionId,
    required this.trigger,
    required this.apply,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.params = const {},
    this.button,
    this.collections,
    this.autoBy,
    this.pausedReason,
    this.brokenDetail,
  }) : assert(apply == ApplyMode.ask || autoBy != null);

  /// Throws [FormatException].
  factory AutomationRecord.fromJson(String id, Map<String, Object?> json) {
    final apply = readEnum(json, 'apply', ApplyMode.values, (a) => a.name);
    final autoBy = readStringOrNull(json, 'autoBy');
    if (apply == ApplyMode.auto && autoBy == null) {
      throw const FormatException('An auto automation needs "autoBy"');
    }
    return AutomationRecord(
      id: id,
      name: readString(json, 'name'),
      enabled: readBool(json, 'enabled'),
      moduleId: readString(json, 'moduleId'),
      actionId: readString(json, 'actionId'),
      params: readMapOrNull(json, 'params') ?? const {},
      trigger: TriggerSpec.fromJson(readMap(json, 'trigger')),
      button: switch (readMapOrNull(json, 'button')) {
        final b? => ButtonSpec.fromJson(b),
        null => null,
      },
      collections: readStringsOrNull(json, 'collections'),
      apply: apply,
      autoBy: autoBy,
      pausedReason: readEnumOrNull(
        json,
        'pausedReason',
        PausedReason.values,
        (r) => r.wire,
      ),
      brokenDetail: readStringOrNull(json, 'brokenDetail'),
      createdBy: readString(json, 'createdBy'),
      createdAt: readDate(json, 'createdAt'),
      updatedAt: readDate(json, 'updatedAt'),
    );
  }

  final String id;
  final String name;
  final bool enabled;
  final String moduleId;
  final String actionId;

  /// Validated against the action's input schema at save and at run start.
  final Map<String, Object?> params;
  final TriggerSpec trigger;

  /// Button kinds only.
  final ButtonSpec? button;

  /// The optional narrowing scope; null = the consent's collections.
  final List<String>? collections;
  final ApplyMode apply;

  /// The uid whose consent auto-applies ([apply] auto only).
  final String? autoBy;
  final PausedReason? pausedReason;

  /// Why it is broken, in words ("The condition uses "Status", which was
  /// deleted").
  final String? brokenDetail;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  AutomationRecord copyWith({
    String? name,
    bool? enabled,
    Map<String, Object?>? params,
    DateTime? updatedAt,
  }) => AutomationRecord(
    id: id,
    name: name ?? this.name,
    enabled: enabled ?? this.enabled,
    moduleId: moduleId,
    actionId: actionId,
    params: params ?? this.params,
    trigger: trigger,
    button: button,
    collections: collections,
    apply: apply,
    autoBy: autoBy,
    pausedReason: pausedReason,
    brokenDetail: brokenDetail,
    createdBy: createdBy,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Paused for [reason] (null resumes it and clears the detail).
  AutomationRecord withPause(
    PausedReason? reason, {
    String? detail,
    required DateTime now,
  }) => AutomationRecord(
    id: id,
    name: name,
    enabled: enabled,
    moduleId: moduleId,
    actionId: actionId,
    params: params,
    trigger: trigger,
    button: button,
    collections: collections,
    apply: apply,
    autoBy: autoBy,
    pausedReason: reason,
    brokenDetail: reason == null ? null : detail,
    createdBy: createdBy,
    createdAt: createdAt,
    updatedAt: now,
  );

  Map<String, Object?> toJson() => {
    'schema': 1,
    'name': name,
    'enabled': enabled,
    'moduleId': moduleId,
    'actionId': actionId,
    'params': params,
    'trigger': trigger.toJson(),
    'button': ?button?.toJson(),
    'collections': ?collections,
    'apply': apply.name,
    'autoBy': ?autoBy,
    'pausedReason': ?pausedReason?.wire,
    'brokenDetail': ?brokenDetail,
    'createdBy': createdBy,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  @override
  List<Object?> get props => [
    id,
    name,
    enabled,
    moduleId,
    actionId,
    params,
    trigger,
    button,
    collections,
    apply,
    autoBy,
    pausedReason,
    brokenDetail,
    createdBy,
    createdAt,
    updatedAt,
  ];
}

/// An automation's status chip (computed).
enum AutomationStatus {
  needsConsent('needs_consent'),
  broken('broken'),
  crashed('crashed'),
  loopSuspected('loop_suspected'),
  paused('paused'),
  active('active');

  const AutomationStatus(this.wire);

  final String wire;
}

/// First match wins: its module needs consent, broken (stored, or the module
/// is broken or gone: [module] null), crashed, loop suspected, paused
/// (disabled), active.
AutomationStatus automationStatusOf(
  AutomationRecord automation,
  ModuleStatus? module,
) {
  if (module == ModuleStatus.needsConsent) return AutomationStatus.needsConsent;
  if (module == null ||
      module == ModuleStatus.broken ||
      automation.pausedReason == PausedReason.broken) {
    return AutomationStatus.broken;
  }
  return switch (automation.pausedReason) {
    PausedReason.crashed => AutomationStatus.crashed,
    PausedReason.loopSuspected => AutomationStatus.loopSuspected,
    _ when !automation.enabled => AutomationStatus.paused,
    _ => AutomationStatus.active,
  };
}
