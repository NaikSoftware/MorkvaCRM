import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/automation/runner_api.dart';
import '../../../core/domain/automation/automation.dart';
import '../../../core/domain/collection.dart';
import '../../../core/domain/ids.dart';
import '../../../core/domain/view/view_definition.dart';
import '../../assistant/bloc/assistant_bloc.dart' show currentAppStrings;
import 'modules_cubit.dart';

/// The editor's "When" (UX §3.2).
enum EditorKind {
  cardButton,
  collectionButton,
  created,
  updated,
  deleted;

  bool get isButton => this == cardButton || this == collectionButton;

  /// Whether an action of [scope] may be bound here.
  bool fits(ActionScope scope) =>
      this == collectionButton ? scope.onCollection : scope.onCard;

  static EditorKind of(TriggerSpec trigger) => switch (trigger) {
    ButtonTrigger(scope: ButtonScope.card) => cardButton,
    ButtonTrigger() => collectionButton,
    EventTrigger(kind: TriggerKind.cardCreated) => created,
    EventTrigger(kind: TriggerKind.cardDeleted) => deleted,
    EventTrigger() => updated,
  };
}

/// Why "Apply automatically" is or isn't offered (UX §3.7).
enum AutoAvailability {
  available,

  /// "Turn on auto-apply for this module first" (→ module details).
  turnOnFirst,

  /// "This module can delete or change structure, so it always asks."
  alwaysAsks,
}

/// A friendly condition from a `FilterBuilder` filter
/// (`{field, op, value}`; design spec, Evaluation).
Map<String, Object?> conditionOf(ViewFilter filter) => {
  'field': filter.fieldId,
  'op': filter.op.name,
  'value': ?filter.operand,
};

/// The `FilterBuilder` filter of a stored condition; null for a relative
/// condition (written by Ask Morkva: a read-only chip) or an unknown op.
ViewFilter? filterOf(Map<String, Object?> condition) {
  final op = FilterOp.values.asNameMap()[condition['op']];
  final field = condition['field'];
  if (condition.containsKey('relative') || op == null || field is! String) {
    return null;
  }
  return ViewFilter(fieldId: field, op: op, operand: condition['value']);
}

/// [label] cut to [ButtonSpec.kMaxLabel] with "…".
String buttonLabelOf(String label) => label.length <= ButtonSpec.kMaxLabel
    ? label
    : '${label.substring(0, ButtonSpec.kMaxLabel - 1)}…';

final class AutomationEditorState extends Equatable {
  const AutomationEditorState({
    required this.modules,
    required this.collections,
    required this.kind,
    this.existing,
    this.name = '',
    this.nameEdited = false,
    this.collectionId,
    this.where = const [],
    this.fields = const [],
    this.mode = TriggerMode.enters,
    this.anyChange = false,
    this.moduleId,
    this.actionId,
    this.params = const {},
    this.label = '',
    this.labelEdited = false,
    this.icon,
    this.tint,
    this.apply = ApplyMode.ask,
    this.enabled = true,
    this.scope,
    this.lastCheck,
    this.problems = const [],
    this.saving = false,
    this.saved = false,
    this.error,
  });

  final List<ModuleEntry> modules;
  final List<Collection> collections;

  /// The automation being edited; null for a new one.
  final AutomationRecord? existing;

  final String name;

  /// Until edited, the name follows "`<action>` on `<collection>`".
  final bool nameEdited;
  final EditorKind kind;
  final String? collectionId;

  /// Friendly conditions (events only).
  final List<Map<String, Object?>> where;

  /// "Only when these fields change" (updated only).
  final List<String> fields;
  final TriggerMode mode;

  /// "Run on any change": an updated automation with no condition and no
  /// field may save.
  final bool anyChange;
  final String? moduleId;
  final String? actionId;
  final Map<String, Object?> params;
  final String label;
  final bool labelEdited;
  final String? icon;
  final String? tint;
  final ApplyMode apply;
  final bool enabled;

  /// Advanced: "Collections it may touch" (null = the module's access).
  final List<String>? scope;

  /// "#1042 · 12:04 · … → didn't run" (existing event automations).
  final LastCheck? lastCheck;

  /// Inline problems from the last Save (path → message).
  final List<AutomationProblem> problems;
  final bool saving;
  final bool saved;
  final String? error;

  ModuleEntry? get module =>
      modules.where((m) => m.module.id == moduleId).firstOrNull;

  ActionSpec? get action => module?.module.manifest?.action(actionId ?? '');

  Collection? get collection =>
      collections.where((c) => c.id == collectionId).firstOrNull;

  /// The modules offered: parsed ones only.
  List<ModuleEntry> get usableModules => [
    for (final m in modules)
      if (m.module.manifest != null) m,
  ];

  /// The consent's collections (null = all, or no module yet).
  List<String>? get allowed => module?.consent?.collections;

  /// "Not allowed for this module · Change access" when false.
  bool collectionAllowed(String id) => allowed?.contains(id) ?? true;

  /// Collections the Advanced checklist offers.
  List<Collection> get scopeChoices => [
    for (final c in collections)
      if (collectionAllowed(c.id)) c,
  ];

  AutoAvailability get autoAvailability {
    final entry = module;
    if (entry == null || !(entry.module.manifest?.autoApplyEligible ?? false)) {
      return AutoAvailability.alwaysAsks;
    }
    return entry.consent?.autoApply == true && entry.status == ModuleStatus.ok
        ? AutoAvailability.available
        : AutoAvailability.turnOnFirst;
  }

  String? get defaultName {
    final a = action;
    final c = collection;
    if (a == null || c == null) return null;
    return currentAppStrings().automationWidgetsDefaultName(a.label, c.name);
  }

  String get defaultLabel => buttonLabelOf(action?.label ?? '');

  /// The problem for [path] (`name`, `actionId`, `params.<key>`, …).
  String? problemAt(String path) =>
      problems.where((p) => p.path == path).firstOrNull?.message;

  AutomationEditorState copyWith({
    List<ModuleEntry>? modules,
    String? name,
    bool? nameEdited,
    EditorKind? kind,
    String? Function()? collectionId,
    List<Map<String, Object?>>? where,
    List<String>? fields,
    TriggerMode? mode,
    bool? anyChange,
    String? Function()? moduleId,
    String? Function()? actionId,
    Map<String, Object?>? params,
    String? label,
    bool? labelEdited,
    String? Function()? icon,
    String? Function()? tint,
    ApplyMode? apply,
    bool? enabled,
    List<String>? Function()? scope,
    List<AutomationProblem>? problems,
    bool? saving,
    bool? saved,
    String? Function()? error,
  }) => AutomationEditorState(
    modules: modules ?? this.modules,
    collections: collections,
    existing: existing,
    lastCheck: lastCheck,
    name: name ?? this.name,
    nameEdited: nameEdited ?? this.nameEdited,
    kind: kind ?? this.kind,
    collectionId: collectionId == null ? this.collectionId : collectionId(),
    where: where ?? this.where,
    fields: fields ?? this.fields,
    mode: mode ?? this.mode,
    anyChange: anyChange ?? this.anyChange,
    moduleId: moduleId == null ? this.moduleId : moduleId(),
    actionId: actionId == null ? this.actionId : actionId(),
    params: params ?? this.params,
    label: label ?? this.label,
    labelEdited: labelEdited ?? this.labelEdited,
    icon: icon == null ? this.icon : icon(),
    tint: tint == null ? this.tint : tint(),
    apply: apply ?? this.apply,
    enabled: enabled ?? this.enabled,
    scope: scope == null ? this.scope : scope(),
    problems: problems ?? this.problems,
    saving: saving ?? this.saving,
    saved: saved ?? this.saved,
    error: error == null ? this.error : error(),
  );

  @override
  List<Object?> get props => [
    modules,
    collections,
    existing,
    name,
    nameEdited,
    kind,
    collectionId,
    where,
    fields,
    mode,
    anyChange,
    moduleId,
    actionId,
    params,
    label,
    labelEdited,
    icon,
    tint,
    apply,
    enabled,
    scope,
    lastCheck,
    problems,
    saving,
    saved,
    error,
  ];
}

/// The automation editor (UX §3): a draft over the collections it was
/// opened with and the live modules; Save checks the form, then saves
/// through the runner (whose `validate` is the planner's and the runner's
/// own check).
class AutomationEditorCubit extends Cubit<AutomationEditorState> {
  /// [moduleChanges] (e.g. `ModulesCubit.stream.map((s) => s.modules)`)
  /// keeps consent fresh after "Change access" / "Turn on auto-apply for
  /// this module first" and back.
  AutomationEditorCubit(
    this._runner, {
    required String uid,
    required List<ModuleEntry> modules,
    required List<Collection> collections,
    Stream<List<ModuleEntry>>? moduleChanges,
    AutomationRecord? existing,
    String? collectionId,
    String? moduleId,
    String? actionId,
    EditorKind kind = EditorKind.cardButton,
    DateTime Function() now = DateTime.now,
    String Function()? newId,
  }) : _uid = uid,
       _now = now,
       // Automation ids are `a_…` (design spec, Run log schema).
       _newId = newId ?? IdGenerator().attachmentId,
       super(
         existing == null
             ? AutomationEditorState(
                 modules: modules,
                 collections: collections,
                 kind: kind,
                 collectionId: collectionId,
               )
             : _from(existing, modules, collections, runner: _runner),
       ) {
    if (existing == null && moduleId != null) {
      setModule(moduleId);
      if (actionId != null) setAction(actionId);
    }
    _sub = moduleChanges?.listen((m) => emit(state.copyWith(modules: m)));
  }

  final AutomationRunnerApi _runner;
  StreamSubscription<Object?>? _sub;
  final String _uid;
  final DateTime Function() _now;
  final String Function() _newId;

  static AutomationEditorState _from(
    AutomationRecord a,
    List<ModuleEntry> modules,
    List<Collection> collections, {
    required AutomationRunnerApi runner,
  }) {
    final event = a.trigger is EventTrigger ? a.trigger as EventTrigger : null;
    return AutomationEditorState(
      modules: modules,
      collections: collections,
      existing: a,
      name: a.name,
      nameEdited: true,
      kind: EditorKind.of(a.trigger),
      collectionId: a.trigger.collectionId,
      where: event?.where ?? const [],
      fields: event?.fields ?? const [],
      mode: event?.mode ?? TriggerMode.enters,
      anyChange:
          event?.kind == TriggerKind.cardUpdated &&
          event!.where.isEmpty &&
          (event.fields?.isEmpty ?? true),
      moduleId: a.moduleId,
      actionId: a.actionId,
      params: a.params,
      label: a.button?.label ?? '',
      labelEdited: a.button != null,
      icon: a.button?.icon,
      tint: a.button?.tint,
      apply: a.apply,
      enabled: a.enabled,
      scope: a.collections,
      lastCheck: event == null
          ? null
          : runner.lastChecks(a.id, limit: 1).firstOrNull,
    );
  }

  void _set(AutomationEditorState next) {
    final name = next.nameEdited ? next.name : (next.defaultName ?? next.name);
    emit(next.copyWith(name: name, problems: const [], error: () => null));
  }

  void setName(String name) =>
      _set(state.copyWith(name: name, nameEdited: true));

  /// Switching kinds keeps what still fits: conditions only for events, the
  /// action only when its scope fits, Auto only while offered.
  void setKind(EditorKind kind) {
    final action = state.action;
    final keepAction = action == null || kind.fits(action.scope);
    _set(
      state.copyWith(
        kind: kind,
        where: kind.isButton ? const [] : null,
        fields: kind == EditorKind.updated ? null : const [],
        actionId: keepAction ? null : () => null,
        params: keepAction ? null : const {},
      ),
    );
  }

  /// A new collection: its conditions, watched fields and field params no
  /// longer apply.
  void setCollection(String collectionId) {
    final fieldInputs = {
      for (final MapEntry(:key, :value)
          in state.action?.input?.properties.entries ??
              const <MapEntry<String, InputProperty>>[])
        if (value.format == InputFormat.field) key,
    };
    _set(
      state.copyWith(
        collectionId: () => collectionId,
        where: const [],
        fields: const [],
        params: {
          for (final MapEntry(:key, :value) in state.params.entries)
            if (!fieldInputs.contains(key)) key: value,
        },
      ),
    );
  }

  /// "+ Condition" → `FilterBuilder` → here.
  void addCondition(ViewFilter filter) =>
      _set(state.copyWith(where: [...state.where, conditionOf(filter)]));

  void replaceCondition(int index, ViewFilter filter) => _set(
    state.copyWith(where: [...state.where]..[index] = conditionOf(filter)),
  );

  void removeCondition(int index) =>
      _set(state.copyWith(where: [...state.where]..removeAt(index)));

  void setFields(List<String> fieldIds) =>
      _set(state.copyWith(fields: fieldIds));

  void setMode(TriggerMode mode) => _set(state.copyWith(mode: mode));

  void setAnyChange(bool on) => _set(state.copyWith(anyChange: on));

  void setModule(String moduleId) => _set(
    state.copyWith(
      moduleId: () => moduleId,
      actionId: () => null,
      params: const {},
      apply: ApplyMode.ask,
      scope: () => null,
    ),
  );

  /// Picks an action and fills its declared defaults.
  void setAction(String actionId) {
    final action = state.module?.module.manifest?.action(actionId);
    _set(
      state.copyWith(
        actionId: () => actionId,
        params: action?.input?.withDefaults(const {}) ?? const {},
        icon: state.icon == null ? () => action?.icon : null,
      ),
    );
  }

  /// [value] null clears the input.
  void setParam(String key, Object? value) => _set(
    state.copyWith(
      params: {
        for (final MapEntry(key: k, :value) in state.params.entries)
          if (k != key) k: value,
        key: ?value,
      },
    ),
  );

  void setLabel(String label) =>
      _set(state.copyWith(label: label, labelEdited: label.isNotEmpty));

  void setIcon(String? icon) => _set(state.copyWith(icon: () => icon));

  void setTint(String? tint) => _set(state.copyWith(tint: () => tint));

  void setApply(ApplyMode apply) => _set(state.copyWith(apply: apply));

  void setEnabled(bool enabled) => _set(state.copyWith(enabled: enabled));

  /// Advanced: null = "Same as the module's access".
  void setScope(List<String>? collections) =>
      _set(state.copyWith(scope: () => collections));

  /// The form's own checks (UX §3 "Validation"), before the runner's.
  List<AutomationProblem> _check() {
    final s = state;
    final l10n = currentAppStrings();
    final problems = <AutomationProblem>[];
    void add(String path, String message) =>
        problems.add(AutomationProblem(path, 'invalid', message));
    if (s.name.trim().isEmpty) add('name', l10n.automationWidgetsProblemName);
    final collection = s.collection;
    if (collection == null) {
      add('collectionId', l10n.automationWidgetsProblemCollection);
    } else if (s.module != null && !s.collectionAllowed(collection.id)) {
      add(
        'collectionId',
        l10n.automationWidgetsProblemCollectionNotAllowed(collection.name),
      );
    }
    final action = s.action;
    if (action == null) {
      add('actionId', l10n.automationWidgetsProblemAction);
    } else if (!s.kind.fits(action.scope)) {
      add(
        'actionId',
        s.kind == EditorKind.collectionButton
            ? l10n.automationWidgetsProblemCardAction
            : l10n.automationWidgetsProblemCollectionAction,
      );
    }
    for (final key in action?.input?.required ?? const <String>[]) {
      if (s.params[key] == null || s.params[key] == '') {
        final title = action!.input!.properties[key]?.title ?? key;
        add('params.$key', l10n.automationWidgetsProblemFillIn(title));
      }
    }
    if (s.kind == EditorKind.updated &&
        s.where.isEmpty &&
        s.fields.isEmpty &&
        !s.anyChange) {
      add('where', l10n.automationWidgetsProblemWhere);
    }
    if (s.apply == ApplyMode.auto &&
        s.autoAvailability != AutoAvailability.available) {
      add(
        'apply',
        s.autoAvailability == AutoAvailability.alwaysAsks
            ? l10n.automationWidgetsProblemAlwaysAsks
            : l10n.automationWidgetsProblemTurnOnAutoFirst,
      );
    }
    return problems;
  }

  AutomationRecord _build() {
    final s = state;
    final existing = s.existing;
    final now = _now();
    final collectionId = s.collectionId!;
    final kind = s.kind;
    return AutomationRecord(
      id: existing?.id ?? _newId(),
      name: s.name.trim(),
      enabled: s.enabled,
      moduleId: s.moduleId!,
      actionId: s.actionId!,
      params: s.params,
      trigger: switch (kind) {
        EditorKind.cardButton => ButtonTrigger(
          scope: ButtonScope.card,
          collectionId: collectionId,
        ),
        EditorKind.collectionButton => ButtonTrigger(
          scope: ButtonScope.collection,
          collectionId: collectionId,
        ),
        _ => EventTrigger(
          kind: switch (kind) {
            EditorKind.created => TriggerKind.cardCreated,
            EditorKind.deleted => TriggerKind.cardDeleted,
            _ => TriggerKind.cardUpdated,
          },
          collectionId: collectionId,
          where: s.where,
          mode: kind == EditorKind.updated ? s.mode : TriggerMode.enters,
          fields: kind == EditorKind.updated && s.fields.isNotEmpty
              ? s.fields
              : null,
        ),
      },
      button: kind.isButton
          ? ButtonSpec(
              label: s.label.trim().isEmpty
                  ? s.defaultLabel
                  : buttonLabelOf(s.label.trim()),
              icon: s.icon,
              tint: s.tint,
              order: existing?.button?.order ?? 0,
            )
          : null,
      collections: s.scope,
      apply: s.apply,
      autoBy: s.apply == ApplyMode.auto ? _uid : null,
      // Fixing and saving clears a broken pause; crash and loop pauses
      // clear only through Resume.
      pausedReason: existing?.pausedReason == PausedReason.broken
          ? null
          : existing?.pausedReason,
      createdBy: existing?.createdBy ?? 'user:$_uid',
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
  }

  /// Checks the form, then saves through the runner. True when saved.
  Future<bool> save() async {
    final problems = _check();
    if (problems.isNotEmpty) {
      emit(state.copyWith(problems: problems));
      return false;
    }
    emit(state.copyWith(saving: true, problems: const [], error: () => null));
    try {
      await _runner.saveAutomation(_build());
      if (!isClosed) emit(state.copyWith(saving: false, saved: true));
      return true;
    } on ManifestProblems catch (e) {
      if (!isClosed) emit(state.copyWith(saving: false, problems: e.problems));
    } on AutomationRefused catch (e) {
      if (!isClosed) {
        emit(state.copyWith(saving: false, error: () => e.message));
      }
    }
    return false;
  }

  /// "Delete" (existing only). True when deleted.
  Future<bool> delete() async {
    final existing = state.existing;
    if (existing == null) return false;
    try {
      await _runner.deleteAutomation(existing.id);
      return true;
    } on AutomationRefused catch (e) {
      if (!isClosed) emit(state.copyWith(error: () => e.message));
      return false;
    }
  }

  /// The loop / crash banner's Resume.
  Future<bool> resume() async {
    final existing = state.existing;
    if (existing == null) return false;
    try {
      await _runner.resume(existing.id);
      return true;
    } on AutomationRefused catch (e) {
      if (!isClosed) emit(state.copyWith(error: () => e.message));
      return false;
    }
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
