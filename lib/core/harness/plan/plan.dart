/// The plan model: what a plan op proposes and the user approves. A plan is a
/// typed diff with before-images and no side effects; `plans.commit` (T7)
/// applies the items the user ticked.
///
/// Two JSON forms:
/// - [Plan.toJson]: the full plan for the UI (`plans.get`), every item with
///   its display text *and* the domain JSON the committer and the journal
///   need (before/after values, field, view and collection images);
/// - [Plan.toCompactJson]: what the model sees (`plans.seal`): title, counts,
///   warnings, notes and the first 5 items, display text only.
///
/// Both carry the keys `PlanView.fromJson` (features layer) reads: `planId,
/// title, risk, items[{itemId, kind, label, collectionId?, targetId?, risk,
/// changes[{fieldId?, field, beforeText?, afterText?}], detail?}], itemCount,
/// sharedChange?, warnings[{code, message}], notes, undo, expiresAt`.
///
/// Every string in a plan is written by the harness, user text sanitized.
library;

import '../../domain/automation/automation.dart';
import '../../domain/domain.dart';
import '../api/capability.dart';

/// How careful the user should be with an item; a plan's risk is the max
/// over its items.
enum Risk {
  low,
  medium,
  high;

  Risk max(Risk other) => other.index > index ? other : this;
}

/// How much of a plan `journal.undo` can revert.
enum UndoSupport { full, partial, none }

/// One key's before → after: a card field (stored JSON) or a schema
/// attribute (a collection's name, a field's options).
final class FieldChange {
  const FieldChange({
    this.fieldId,
    required this.field,
    this.before,
    this.after,
    this.beforeText,
    this.afterText,
  });

  /// The card field the change writes; null for schema attributes.
  final String? fieldId;

  /// The display name (`Status`, `Name`, `Options`).
  final String field;

  /// Stored domain JSON (`valueToJson`), null when empty.
  final Object? before;
  final Object? after;

  /// Display text; null when the value is empty.
  final String? beforeText;
  final String? afterText;

  /// Whether [other] writes the same key from the same value to the same
  /// value (the plan header's shared diff).
  bool sameAs(FieldChange other) =>
      fieldId == other.fieldId &&
      field == other.field &&
      beforeText == other.beforeText &&
      afterText == other.afterText &&
      jsonEquals(before, other.before) &&
      jsonEquals(after, other.after);

  Map<String, Object?> toDisplayJson() => {
    'fieldId': ?fieldId,
    'field': field,
    'beforeText': ?beforeText,
    'afterText': ?afterText,
  };

  Map<String, Object?> toJson() => {
    ...toDisplayJson(),
    'before': before,
    'after': after,
  };
}

/// One view's image before and after a schema item: null `before` means the
/// item adds the view, null `after` that it removes it.
final class ViewEntry {
  const ViewEntry({
    required this.viewId,
    required this.index,
    this.before,
    this.after,
  });

  final String viewId;

  /// The view's position in the collection's view list (before the item).
  final int index;
  final ViewDefinition? before;
  final ViewDefinition? after;

  Map<String, Object?> toJson() => {
    'viewId': viewId,
    'index': index,
    'before': before?.toJson(),
    'after': after?.toJson(),
  };
}

/// The views of [before] that [after] changes, adds or drops, by id.
List<ViewEntry> viewEntries(
  List<ViewDefinition> before,
  List<ViewDefinition> after,
) {
  final afterById = {for (final v in after) v.id: v};
  final beforeIds = {for (final v in before) v.id};
  return [
    for (final (i, v) in before.indexed)
      if (afterById[v.id] != v)
        ViewEntry(viewId: v.id, index: i, before: v, after: afterById[v.id]),
    for (final (i, v) in after.indexed)
      if (!beforeIds.contains(v.id))
        ViewEntry(viewId: v.id, index: i, after: v),
  ];
}

/// The item kinds, by wire name (what the UI groups by).
enum PlanItemKind {
  createCard(Capability.dataWrite),
  updateCard(Capability.dataWrite),
  deleteCard(Capability.dataDelete),
  createCollection(Capability.schemaWrite),
  updateCollection(Capability.schemaWrite),
  deleteCollection(Capability.schemaDelete),
  addField(Capability.schemaWrite),
  updateField(Capability.schemaWrite),
  deleteField(Capability.schemaDelete),
  createView(Capability.viewsWrite),
  updateView(Capability.viewsWrite),
  deleteView(Capability.viewsWrite),
  saveModule(Capability.modulesWrite, scoped: false),
  saveAutomation(Capability.automationsWrite, scoped: false),
  deleteAutomation(Capability.automationsWrite, scoped: false);

  const PlanItemKind(this.capability, {this.scoped = true});

  /// What the creator needed to plan it (re-checked at commit).
  final Capability capability;

  /// Whether the item writes into its collection, so the creator's
  /// collection grants apply. Module and automation items are workspace
  /// docs: the commit checks only their capability.
  final bool scoped;
}

/// One reviewable, separately selectable change. Items commit in plan
/// order; an item whose [dependsOn] item is deselected is skipped.
sealed class PlanItem {
  const PlanItem({
    required this.itemId,
    required this.callId,
    required this.collectionId,
    required this.label,
    required this.risk,
    this.targetId,
    this.detail,
    this.changes = const [],
    this.dependsOn = const [],
  });

  /// `i1`, `i2`, … in plan order.
  final String itemId;

  /// The plan call that proposed it (`r2.1`).
  final String callId;
  final String collectionId;

  /// The card, field or view the item touches (the collection for
  /// collection items).
  final String? targetId;

  /// Sanitized, single line: `#1042 · Iryna Melnyk`, `Phone`, `Unpaid`.
  final String label;

  /// A secondary line: a field's type tag (`Select · Kyiv, Lviv`), a view's
  /// mode, a deleted card's day.
  final String? detail;
  final Risk risk;

  /// The keys the item writes, before → after.
  final List<FieldChange> changes;

  /// Items this one needs (a new field for its fill, a new collection for
  /// its fields and cards).
  final List<String> dependsOn;

  PlanItemKind get kind;

  Capability get capability => kind.capability;

  /// The domain JSON the committer and the journal need.
  Map<String, Object?> dataJson();

  /// What the UI and the model read.
  Map<String, Object?> toDisplayJson() => {
    'itemId': itemId,
    'callId': callId,
    'kind': kind.name,
    'label': label,
    'collectionId': collectionId,
    'targetId': ?targetId,
    'risk': risk.name,
    'changes': [for (final c in changes) c.toDisplayJson()],
    'detail': ?detail,
  };

  Map<String, Object?> toJson() => {
    ...toDisplayJson(),
    'changes': [for (final c in changes) c.toJson()],
    if (dependsOn.isNotEmpty) 'dependsOn': dependsOn,
    ...dataJson(),
  };
}

/// A new card. Auto-numbers are assigned on save. It depends on its
/// collection's create and on the created cards it links to, not on new
/// fields: a value for a field the user unticked is dropped at commit.
final class CreateCardItem extends PlanItem {
  const CreateCardItem({
    required super.itemId,
    required super.callId,
    required super.collectionId,
    required super.label,
    required super.risk,
    required this.object,
    this.ref,
    super.detail,
    super.changes,
    super.dependsOn,
  }) : super(targetId: null);

  /// The card as it will be written (normalized to its schema).
  final MorkvaObject object;

  /// The turn-local `@ref` other calls used for it.
  final String? ref;

  @override
  String? get targetId => object.id;

  @override
  PlanItemKind get kind => PlanItemKind.createCard;

  @override
  Map<String, Object?> dataJson() => {'object': object.toJson(), 'ref': ?ref};
}

/// Some keys of one card; [changes] hold only the touched keys.
final class UpdateCardItem extends PlanItem {
  const UpdateCardItem({
    required super.itemId,
    required super.callId,
    required super.collectionId,
    required String super.targetId,
    required super.label,
    required super.risk,
    required super.changes,
    super.detail,
    super.dependsOn,
  });

  String get cardId => targetId!;

  /// Field id → stored JSON of the touched keys after the change.
  Map<String, Object?> get afterValues => {
    for (final c in changes) c.fieldId!: c.after,
  };

  /// Field id → stored JSON of the touched keys as previewed.
  Map<String, Object?> get beforeValues => {
    for (final c in changes) c.fieldId!: c.before,
  };

  @override
  PlanItemKind get kind => PlanItemKind.updateCard;

  @override
  Map<String, Object?> dataJson() => const {};
}

/// One card, with its before-image (undo re-creates it with the same id and
/// auto-number).
final class DeleteCardItem extends PlanItem {
  const DeleteCardItem({
    required super.itemId,
    required super.callId,
    required super.collectionId,
    required String super.targetId,
    required super.label,
    required super.risk,
    required this.before,
    super.detail,
  });

  final MorkvaObject before;

  @override
  PlanItemKind get kind => PlanItemKind.deleteCard;

  @override
  Map<String, Object?> dataJson() => {'before': before.toJson()};
}

/// A new collection, with every field the call gave it. Its fields are also
/// listed as [AddFieldItem]s (`newCollection: true`) depending on it, so the
/// card lists them and a deselected one is left out.
final class CreateCollectionItem extends PlanItem {
  const CreateCollectionItem({
    required super.itemId,
    required super.callId,
    required super.label,
    required super.risk,
    required this.collection,
    this.ref,
    super.detail,
  }) : super(collectionId: '');

  final Collection collection;

  /// The `@x` ref the call gave it.
  final String? ref;

  @override
  String get collectionId => collection.id;

  @override
  String? get targetId => collection.id;

  @override
  PlanItemKind get kind => PlanItemKind.createCollection;

  @override
  Map<String, Object?> dataJson() => {
    'collection': collection.toJson(),
    'ref': ?ref,
  };
}

/// A collection's name, description or icon; [changes] carry the keys
/// (`fieldId` null, `field` the key's display name), [keys] the raw values.
final class UpdateCollectionItem extends PlanItem {
  const UpdateCollectionItem({
    required super.itemId,
    required super.callId,
    required super.collectionId,
    required super.label,
    required super.risk,
    required super.changes,
    required this.keys,
    super.dependsOn,
  }) : super(targetId: null);

  /// `name` / `description` / `icon` → (before, after).
  final Map<String, ({Object? before, Object? after})> keys;

  @override
  String? get targetId => collectionId;

  @override
  PlanItemKind get kind => PlanItemKind.updateCollection;

  @override
  Map<String, Object?> dataJson() => {
    'keys': {
      for (final e in keys.entries)
        e.key: {'before': e.value.before, 'after': e.value.after},
    },
  };
}

/// A whole collection and its cards. Always its own plan.
final class DeleteCollectionItem extends PlanItem {
  const DeleteCollectionItem({
    required super.itemId,
    required super.callId,
    required super.label,
    required super.risk,
    required this.before,
    required this.cardCount,
    super.detail,
  }) : super(collectionId: '');

  final Collection before;
  final int cardCount;

  @override
  String get collectionId => before.id;

  @override
  String? get targetId => before.id;

  @override
  PlanItemKind get kind => PlanItemKind.deleteCollection;

  @override
  Map<String, Object?> dataJson() => {
    'before': before.toJson(),
    'cardCount': cardCount,
  };
}

/// A field added to a collection at [index], with the views and layout it
/// changes (for a new collection the field is part of its create item).
final class AddFieldItem extends PlanItem {
  const AddFieldItem({
    required super.itemId,
    required super.callId,
    required super.collectionId,
    required super.label,
    required super.risk,
    required this.field,
    required this.index,
    this.newCollection = false,
    this.views = const [],
    this.layoutBefore,
    this.layoutAfter,
    super.detail,
    super.dependsOn,
  }) : super(targetId: null);

  final FieldDefinition field;

  /// Its position in the collection's fields after the add.
  final int index;

  /// Whether the field belongs to a collection this plan creates.
  final bool newCollection;
  final List<ViewEntry> views;
  final CardLayout? layoutBefore;
  final CardLayout? layoutAfter;

  @override
  String? get targetId => field.id;

  @override
  PlanItemKind get kind => PlanItemKind.addField;

  @override
  Map<String, Object?> dataJson() => {
    'field': field.toJson(),
    'index': index,
    if (newCollection) 'newCollection': true,
    'views': [for (final v in views) v.toJson()],
    if (layoutBefore != null) 'layoutBefore': layoutBefore!.toJson(),
    if (layoutAfter != null) 'layoutAfter': layoutAfter!.toJson(),
  };
}

/// A field's definition, before → after, with the views it changes (a
/// removed option leaves filters).
final class UpdateFieldItem extends PlanItem {
  const UpdateFieldItem({
    required super.itemId,
    required super.callId,
    required super.collectionId,
    required super.label,
    required super.risk,
    required this.before,
    required this.after,
    this.views = const [],
    super.changes,
    super.detail,
    super.dependsOn,
  }) : super(targetId: null);

  final FieldDefinition before;
  final FieldDefinition after;
  final List<ViewEntry> views;

  @override
  String? get targetId => before.id;

  @override
  PlanItemKind get kind => PlanItemKind.updateField;

  @override
  Map<String, Object?> dataJson() => {
    'before': before.toJson(),
    'after': after.toJson(),
    'views': [for (final v in views) v.toJson()],
  };
}

/// A field removed from [index], with every view and the layout it changes
/// (stored card values survive, so undo brings them back).
final class DeleteFieldItem extends PlanItem {
  const DeleteFieldItem({
    required super.itemId,
    required super.callId,
    required super.collectionId,
    required super.label,
    required super.risk,
    required this.before,
    required this.index,
    this.views = const [],
    this.layoutBefore,
    this.layoutAfter,
    super.detail,
    super.dependsOn,
  }) : super(targetId: null);

  final FieldDefinition before;
  final int index;
  final List<ViewEntry> views;
  final CardLayout? layoutBefore;
  final CardLayout? layoutAfter;

  @override
  String? get targetId => before.id;

  @override
  PlanItemKind get kind => PlanItemKind.deleteField;

  @override
  Map<String, Object?> dataJson() => {
    'before': before.toJson(),
    'index': index,
    'views': [for (final v in views) v.toJson()],
    if (layoutBefore != null) 'layoutBefore': layoutBefore!.toJson(),
    if (layoutAfter != null) 'layoutAfter': layoutAfter!.toJson(),
  };
}

/// A view appended at [index].
final class CreateViewItem extends PlanItem {
  const CreateViewItem({
    required super.itemId,
    required super.callId,
    required super.collectionId,
    required super.label,
    required super.risk,
    required this.view,
    required this.index,
    super.detail,
    super.changes,
    super.dependsOn,
  }) : super(targetId: null);

  final ViewDefinition view;
  final int index;

  @override
  String? get targetId => view.id;

  @override
  PlanItemKind get kind => PlanItemKind.createView;

  @override
  Map<String, Object?> dataJson() => {'view': view.toJson(), 'index': index};
}

/// A view, before → after.
final class UpdateViewItem extends PlanItem {
  const UpdateViewItem({
    required super.itemId,
    required super.callId,
    required super.collectionId,
    required super.label,
    required super.risk,
    required this.before,
    required this.after,
    required this.index,
    super.detail,
    super.changes,
    super.dependsOn,
  }) : super(targetId: null);

  final ViewDefinition before;
  final ViewDefinition after;
  final int index;

  @override
  String? get targetId => before.id;

  @override
  PlanItemKind get kind => PlanItemKind.updateView;

  @override
  Map<String, Object?> dataJson() => {
    'before': before.toJson(),
    'after': after.toJson(),
    'index': index,
  };
}

/// A view removed from [index] (undo re-inserts it there).
final class DeleteViewItem extends PlanItem {
  const DeleteViewItem({
    required super.itemId,
    required super.callId,
    required super.collectionId,
    required super.label,
    required super.risk,
    required this.before,
    required this.index,
    super.detail,
    super.dependsOn,
  }) : super(targetId: null);

  final ViewDefinition before;
  final int index;

  @override
  String? get targetId => before.id;

  @override
  PlanItemKind get kind => PlanItemKind.deleteView;

  @override
  Map<String, Object?> dataJson() => {
    'before': before.toJson(),
    'index': index,
  };
}

/// A module install or update (`modules.save`) with the consent its approval
/// records. Not journaled: undo leaves it alone.
///
/// [toDisplayJson] (what the model sees) carries `codeBytes` and `codeHash`,
/// never the code; [toJson] (the UI) carries `code` for "View code".
final class SaveModuleItem extends PlanItem {
  const SaveModuleItem({
    required super.itemId,
    required super.callId,
    required super.label,
    required super.risk,
    required this.module,
    required this.consent,
    this.beforeCodeHash,
    super.detail,
    super.changes,
  }) : super(collectionId: '');

  /// The record to write (dated at plan time; the committer stamps its own).
  final ModuleRecord module;

  /// The consent approval records: the manifest's caps, the collections the
  /// plan named, `autoApply: false`, `via: assistant_plan`.
  final GrantRecord consent;

  /// The installed bundle's hash when planned (null for a new module): the
  /// committer's stale check.
  final String? beforeCodeHash;

  @override
  String? get targetId => module.id;

  @override
  PlanItemKind get kind => PlanItemKind.saveModule;

  @override
  Map<String, Object?> toDisplayJson() => {
    ...super.toDisplayJson(),
    'codeBytes': module.codeBytes,
    'codeHash': module.bundleHash,
  };

  @override
  Map<String, Object?> dataJson() => {
    'moduleId': module.id,
    'manifest': module.manifestJson,
    'code': module.code,
    'version': module.version,
    'caps': consent.caps,
    'collections': consent.collections,
    'beforeCodeHash': ?beforeCodeHash,
  };
}

/// An automation created or replaced (`automations.save`). [draft] is the
/// record as planned, stored `apply: ask`; [apply] is the mode to write, and
/// [recordFor] stamps the approving user as `autoBy` of an auto one.
final class SaveAutomationItem extends PlanItem {
  const SaveAutomationItem({
    required super.itemId,
    required super.callId,
    required super.collectionId,
    required super.label,
    required super.risk,
    required this.draft,
    required this.apply,
    this.before,
    super.detail,
    super.changes,
    super.dependsOn,
  });

  final AutomationRecord draft;
  final ApplyMode apply;

  /// The live automation when planned (an update): the committer's stale
  /// check compares its `updatedAt`.
  final AutomationRecord? before;

  @override
  String? get targetId => draft.id;

  @override
  PlanItemKind get kind => PlanItemKind.saveAutomation;

  /// The record to write, approved by [uid] at [now].
  AutomationRecord recordFor(String uid, DateTime now) =>
      AutomationRecord.fromJson(draft.id, {
        ...draft.toJson(),
        'apply': apply.name,
        'autoBy': apply == ApplyMode.auto ? uid : null,
        'createdAt': before?.createdAt ?? now,
        'updatedAt': now,
      });

  @override
  Map<String, Object?> toDisplayJson() => {
    ...super.toDisplayJson(),
    'apply': apply.name,
  };

  @override
  Map<String, Object?> dataJson() => {
    'automation': plainJson(draft.toJson()),
    'apply': apply.name,
    if (before case final b?)
      'beforeUpdatedAt': b.updatedAt.toUtc().toIso8601String(),
  };
}

/// An automation removed (`automations.delete`).
final class DeleteAutomationItem extends PlanItem {
  const DeleteAutomationItem({
    required super.itemId,
    required super.callId,
    required super.collectionId,
    required super.label,
    required super.risk,
    required this.before,
    super.detail,
    super.changes,
  });

  final AutomationRecord before;

  @override
  String? get targetId => before.id;

  @override
  PlanItemKind get kind => PlanItemKind.deleteAutomation;

  @override
  Map<String, Object?> dataJson() => {'before': plainJson(before.toJson())};
}

/// [value] with every [DateTime] as an ISO string, so record JSON can leave
/// the harness (op results are plain JSON).
Object? plainJson(Object? value) => switch (value) {
  DateTime() => value.toUtc().toIso8601String(),
  Map() => {for (final e in value.entries) '${e.key}': plainJson(e.value)},
  List() => [for (final v in value) plainJson(v)],
  _ => value,
};

/// A harness-written warning (`breaks_references`, `required_empty`, …).
final class PlanWarning {
  const PlanWarning(this.code, this.message);

  final String code;
  final String message;

  Map<String, Object?> toJson() => {'code': code, 'message': message};
}

/// Who built a plan and what they were allowed to plan; commit re-checks
/// every item against these grants.
final class PlanCreator {
  const PlanCreator(this.actor, this.grants);

  final Actor actor;
  final Grants grants;

  Map<String, Object?> toJson() => {
    'actor': actor.wire,
    'grants': grants.toJson(),
  };
}

/// The most items one plan may hold (`limit_exceeded` at `plans.seal`).
const int kMaxPlanItems = 500;

/// How many items the compact plan (the model's view) lists.
const int kCompactPlanItems = 5;

/// How many notes the compact plan lists.
const int kCompactPlanNotes = 10;

/// One sealed plan: every item of one turn's plan calls, merged.
final class Plan {
  Plan({
    required this.planId,
    required this.turnId,
    required this.title,
    required this.createdBy,
    required List<PlanItem> items,
    required this.createdAt,
    required this.expiresAt,
    this.warnings = const [],
    this.notes = const [],
    this.undo = UndoSupport.full,
  }) : items = List.unmodifiable(items),
       risk = items.fold(Risk.low, (r, i) => r.max(i.risk));

  final String planId;
  final String turnId;

  /// "Set Status to Shipped · 3 orders".
  final String title;
  final PlanCreator createdBy;
  final List<PlanItem> items;
  final DateTime createdAt;

  /// Past this instant the plan cannot be committed (`plan_expired`).
  final DateTime expiresAt;
  final List<PlanWarning> warnings;
  final List<String> notes;
  final UndoSupport undo;

  /// The max over [items].
  final Risk risk;

  int get itemCount => items.length;

  bool isExpired(DateTime now) => !now.isBefore(expiresAt);

  PlanItem? item(String itemId) =>
      items.where((i) => i.itemId == itemId).firstOrNull;

  /// The one diff every item shares (every item an `updateCard` writing the
  /// same key from the same value to the same value), shown once in the
  /// card header.
  FieldChange? get sharedChange {
    if (items.length < 2) return null;
    FieldChange? shared;
    for (final item in items) {
      if (item is! UpdateCardItem || item.changes.length != 1) return null;
      final change = item.changes.single;
      if (shared == null) {
        shared = change;
      } else if (!shared.sameAs(change)) {
        return null;
      }
    }
    return shared;
  }

  Map<String, Object?> _head() => {
    'planId': planId,
    'title': title,
    'risk': risk.name,
    'createdBy': createdBy.toJson(),
    'itemCount': itemCount,
    if (sharedChange case final s?) 'sharedChange': s.toDisplayJson(),
    'warnings': [for (final w in warnings) w.toJson()],
    'undo': undo.name,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
  };

  /// The full plan (`plans.get`).
  Map<String, Object?> toJson() => {
    ..._head(),
    'turnId': turnId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'items': [for (final i in items) i.toJson()],
    'notes': notes,
  };

  /// What the model sees (`plans.seal`): the first [kCompactPlanItems]
  /// items and [kCompactPlanNotes] notes, display text only.
  Map<String, Object?> toCompactJson() => {
    ..._head(),
    'items': [for (final i in items.take(kCompactPlanItems)) i.toDisplayJson()],
    'notes': notes.take(kCompactPlanNotes).toList(),
    if (notes.length > kCompactPlanNotes)
      'moreNotes': notes.length - kCompactPlanNotes,
    if (items.length > kCompactPlanItems)
      'moreItems': items.length - kCompactPlanItems,
  };
}

/// Deep equality of plain JSON values (lists in order, maps by key).
bool jsonEquals(Object? a, Object? b) {
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!jsonEquals(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (!b.containsKey(e.key) || !jsonEquals(e.value, b[e.key])) {
        return false;
      }
    }
    return true;
  }
  return a == b;
}
