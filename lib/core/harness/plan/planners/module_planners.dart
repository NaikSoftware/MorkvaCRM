import 'dart:convert';

import '../../../domain/automation/automation.dart';
import '../../../domain/domain.dart';
import '../../api/envelope.dart';
import '../../api/harness_context.dart';
import '../../automation_catalog.dart';
import '../../automation_validation.dart';
import '../../input/filter_compiler.dart';
import '../../input/input_errors.dart';
import '../../input/ref_resolver.dart';
import '../../input/screen_line.dart';
import '../plan.dart';
import 'plan_call.dart';

/// `modules.save {manifest, code, collections}`: one `saveModule` item that
/// installs or updates the module and records the consent to its manifest's
/// permissions in [collections] (`"all"` or refs). Every manifest and code
/// problem comes back in `details`. Saving the installed bundle with the same
/// consent changes nothing (`no_change`).
Future<void> planModulesSave(
  Map<String, Object?> args,
  PlanCall call,
  AutomationCatalog catalog,
) async {
  final manifestJson = mapArg(args['manifest'], 'manifest');
  final code = args['code']! as String;
  final problems = [
    for (final p in _manifestProblems(manifestJson))
      ErrorDetail(
        path: p.path.isEmpty ? 'manifest' : 'manifest.${p.path}',
        code: _code(p.code),
        message: p.message,
      ),
    if (codeSizeProblem(code) case final p?)
      ErrorDetail(
        path: 'code',
        code: ErrorCode.limitExceeded,
        message: p.message,
      ),
  ];
  if (problems.isNotEmpty) {
    throw HarnessException(
      HarnessError.fromDetails(
        problems,
        hint: 'docs/sdk/manifest.md lists every manifest key.',
      ),
    );
  }
  final bundle = ModuleBundle.of(manifestJson, code);
  final manifest = bundle.manifest;
  if (call.view.items.any(
    (i) => i is SaveModuleItem && i.module.id == manifest.id,
  )) {
    throw invalidArgs(
      'Module "${manifest.id}" is already saved in this turn.',
      path: 'manifest.id',
    );
  }

  final collections = switch (args['collections']) {
    'all' => null,
    final List<Object?> refs when refs.isNotEmpty => <String>{
      for (final (i, ref) in refs.indexed)
        call.collection('$ref', path: 'collections[$i]').id,
    }.toList(),
    _ => throw invalidArgs(
      'Name the collections the module may use, or "all".',
      path: 'collections',
    ),
  };

  final existing = await catalog.getModule(manifest.id);
  final before = await catalog.liveConsent(manifest.id);
  final ctx = call.ctx;
  final module = ModuleRecord.fromBundle(
    bundle,
    source: ModuleSource.assistant,
    createdBy: existing?.createdBy ?? ctx.actor.wire,
    createdAt: existing?.createdAt,
    now: ctx.now,
  );
  final consent = GrantRecord(
    moduleId: manifest.id,
    codeHash: module.bundleHash,
    version: manifest.version,
    codeBytes: module.codeBytes,
    caps: manifest.capabilities,
    collections: collections,
    autoApply: false,
    grantedAt: ctx.now,
    via: GrantVia.assistantPlan,
  );
  if (existing?.bundleHash == module.bundleHash &&
      before != null &&
      before.codeHash == consent.codeHash &&
      _sameSet(before.caps, consent.caps) &&
      _sameScope(before.collections, consent.collections)) {
    call.note('"${call.name(manifest.name)}" is already installed as is.');
    return;
  }

  String scope(List<String>? ids) => ids == null
      ? 'All collections'
      : [
          for (final id in ids) call.name(call.view.collection(id)?.name ?? id),
        ].join(', ');
  final oldManifest = existing?.manifest;
  final newScope = scope(collections);
  final oldScope = before == null ? null : scope(before.collections);
  String? was(String? old, String now) => old == now ? null : old;
  // On an update a capability gained or lost reads `Not allowed`, so a new
  // permission never looks like a kept one.
  String? capBefore(String wire) => before == null
      ? null
      : !before.caps.contains(wire)
      ? _notAllowed
      : manifest.capabilities.contains(wire)
      ? was(oldScope, newScope)
      : oldScope;
  final actions = _actionsText(manifest);
  final codeText = _codeText(module);
  call.add(
    SaveModuleItem(
      itemId: call.nextItemId(),
      callId: call.callId,
      label: call.name(manifest.name),
      risk: Risk.high,
      module: module,
      consent: consent,
      beforeCodeHash: existing?.bundleHash,
      detail: switch (existing?.version) {
        final v? when v != manifest.version => 'v$v → v${manifest.version}',
        _ => 'v${manifest.version}',
      },
      changes: [
        for (final MapEntry(key: wire, value: copy) in kCapabilityCopy.entries)
          if (manifest.capabilities.contains(wire) ||
              (before?.caps.contains(wire) ?? false))
            FieldChange(
              field: copy.title,
              beforeText: capBefore(wire),
              afterText: manifest.capabilities.contains(wire)
                  ? newScope
                  : _notAllowed,
            ),
        FieldChange(
          field: 'Collections',
          beforeText: oldScope == null ? null : was(oldScope, newScope),
          afterText: newScope,
        ),
        FieldChange(
          field: 'Actions',
          beforeText: oldManifest == null
              ? null
              : was(_actionsText(oldManifest), actions),
          afterText: actions,
        ),
        FieldChange(
          field: 'Code',
          beforeText: existing == null
              ? null
              : was(_codeText(existing), codeText),
          afterText: codeText,
        ),
      ],
    ),
  );
  call.warn(
    'grants_permissions',
    before?.autoApply ?? false
        ? 'Auto-apply turns off for the new version. Turn it on again in '
              'module details.'
        : 'Approving installs this module and lets it use these '
              'permissions. Auto-apply stays off.',
  );
  call.title(
    '${existing == null ? 'Install' : 'Update'} ${call.quoted(manifest.name)}',
  );
}

/// `automations.save {id?, name, moduleId, actionId, trigger, params?,
/// button?, apply?}`: one `saveAutomation` item. Refs are normalized to ids
/// (collection, condition fields and operands, watched fields, `format`
/// params; `relative` conditions stay relative) and the save-time rules of
/// [validateAutomation] apply, under the module's effective grants. The
/// module may be one this turn saves (the item then depends on it).
Future<void> planAutomationsSave(
  Map<String, Object?> args,
  PlanCall call,
  AutomationCatalog catalog,
) async {
  final ctx = call.ctx;
  final id = args['id'] as String?;
  final existing = id == null ? null : await catalog.getAutomation(id);
  if (id != null && existing == null) {
    throw HarnessException.of(
      ErrorCode.unknownObject,
      'There is no automation "$id".',
      path: 'id',
      hint: 'automations.list lists them; leave "id" out to add one.',
    );
  }
  if (id != null &&
      call.view.items.any((i) => i.kind.scoped == false && i.targetId == id)) {
    throw invalidArgs(
      'Automation "$id" is already changed in this turn.',
      path: 'id',
    );
  }

  final moduleId = args['moduleId']! as String;
  final pending = call.view.items
      .whereType<SaveModuleItem>()
      .where((i) => i.module.id == moduleId)
      .firstOrNull;
  final module = pending?.module ?? await catalog.getModule(moduleId);
  if (module == null) {
    final modules = await catalog.listModules();
    throw HarnessException.of(
      ErrorCode.unknownObject,
      'There is no module "$moduleId".',
      path: 'moduleId',
      candidates: [for (final m in modules) m.id],
      hint: 'modules.list lists the installed modules.',
    );
  }
  final manifest =
      module.manifest ??
      (throw invalidArgs(
        '"${call.name(module.name)}" no longer loads; save it again first.',
        path: 'moduleId',
      ));
  final consent = pending?.consent ?? await catalog.liveConsent(moduleId);
  final actionId = args['actionId']! as String;
  final action =
      manifest.action(actionId) ??
      (throw HarnessException.of(
        ErrorCode.invalidArgs,
        '"${call.name(manifest.name)}" has no action "$actionId".',
        path: 'actionId',
        candidates: [for (final a in manifest.actions) a.id],
      ));

  // Without a consent the grants would not bound the collections at all.
  if (consent == null) {
    throw HarnessException.of(
      ErrorCode.notPermitted,
      '"${call.name(manifest.name)}" needs the user\'s consent first.',
      path: 'moduleId',
      hint:
          'Save the module with modules.save in this turn, or ask the user '
          'to review its permissions in module details.',
    );
  }

  // Left out on an update, the stored mode stays (still gated below).
  final apply = switch (args['apply']) {
    'auto' => ApplyMode.auto,
    'ask' => ApplyMode.ask,
    _ => existing?.apply ?? ApplyMode.ask,
  };
  if (apply == ApplyMode.auto && !autoApplyAllowed(module, consent)) {
    throw invalidArgs(
      'Auto-apply needs the module\'s auto-apply switch for this version, '
      'which only the user turns on in module details, and a module that '
      'cannot delete cards or change collections or views.',
      path: 'apply',
      hint: 'Save it with "apply": "ask".',
    );
  }

  final rawTrigger = mapArg(args['trigger'], 'trigger');
  final kind = TriggerKind.fromWire(rawTrigger['kind'])!;
  if (kind != TriggerKind.cardUpdated) {
    for (final key in const ['mode', 'fields']) {
      if (rawTrigger[key] != null) {
        throw invalidArgs(
          '"$key" only goes with a card.updated trigger.',
          path: 'trigger.$key',
        );
      }
    }
  }
  final collection = call.collection(
    rawTrigger['collection']! as String,
    path: 'trigger.collection',
  );
  final grants = moduleGrants(
    manifest,
    consent,
    collections: existing?.collections,
  );
  // Refs resolve under the module's grants, so a condition reading a
  // collection outside them is refused at save.
  final refs = RefResolver(
    call.view,
    HarnessContext(
      workspaceId: ctx.workspaceId,
      actor: ctx.actor,
      grants: grants,
      now: ctx.now,
      today: ctx.today,
      focus: ctx.focus,
    ),
    cardAliases: call.view.cardAliases,
  );

  await call.leased([collection.id], () async {
    final schema = call.schemaOf(collection.id);
    final buttonArgs = args['button'] as Map?;
    if (kind.isEvent && buttonArgs != null) {
      throw invalidArgs(
        '"button" only goes with a button trigger.',
        path: 'button',
      );
    }
    final TriggerSpec trigger = kind == TriggerKind.button
        ? ButtonTrigger(
            scope: rawTrigger['scope'] == 'collection'
                ? ButtonScope.collection
                : ButtonScope.card,
            collectionId: schema.id,
          )
        : EventTrigger(
            kind: kind,
            collectionId: schema.id,
            where: _normalizeWhere(
              refs,
              schema,
              listArg<Object?>(rawTrigger['where'], 'trigger.where'),
            ),
            mode: rawTrigger['mode'] == 'matches'
                ? TriggerMode.matches
                : TriggerMode.enters,
            fields: switch (rawTrigger['fields']) {
              final List<Object?> l => _fieldIds(refs, schema, l),
              _ => null,
            },
          );
    final button = buttonArgs == null && kind != TriggerKind.button
        ? null
        : _button(buttonArgs?.cast<String, Object?>(), action);
    final params = _normalizeParams(
      refs,
      schema,
      action,
      mapArg(args['params'] ?? const <String, Object?>{}, 'params'),
    );
    final draft = AutomationRecord(
      id: existing?.id ?? _automationId(call),
      name: (args['name']! as String).trim(),
      enabled: existing?.enabled ?? true,
      moduleId: module.id,
      actionId: action.id,
      params: params,
      trigger: trigger,
      button: button,
      collections: existing?.collections,
      apply: ApplyMode.ask,
      // Saving revalidates, which clears `broken`; a loop or crash pause
      // stays until the user resumes it.
      pausedReason: existing?.pausedReason == PausedReason.broken
          ? null
          : existing?.pausedReason,
      createdBy: existing?.createdBy ?? ctx.actor.wire,
      createdAt: existing?.createdAt ?? ctx.now,
      updatedAt: ctx.now,
    );
    if (draft.name.isEmpty) {
      throw invalidArgs('Give the automation a name.', path: 'name');
    }
    final problems = validateAutomation(
      draft,
      module: module,
      consent: consent,
      workspace: call.view,
      today: ctx.today,
    );
    if (problems.isNotEmpty) {
      throw HarnessException(
        HarnessError.fromDetails([
          for (final p in problems)
            ErrorDetail(path: p.path, code: _code(p.code), message: p.message),
        ]),
      );
    }
    if (existing != null && _sameAutomation(existing, draft, apply)) {
      call.note('"${call.name(draft.name)}" already works this way.');
      return;
    }

    final header = _triggerHeader(trigger, call.name(schema.name));
    final rule = _ruleText(trigger, schema, action, refs);
    final before = existing == null
        ? null
        : _ruleTextOrNull(existing, call, refs, manifest);
    call.add(
      SaveAutomationItem(
        itemId: call.nextItemId(),
        callId: call.callId,
        collectionId: schema.id,
        label: call.name(draft.name),
        risk: apply == ApplyMode.auto ? Risk.medium : Risk.low,
        draft: draft,
        apply: apply,
        before: existing,
        detail: '${call.name(action.label)} · ${call.name(manifest.name)}',
        dependsOn: [?pending?.itemId],
        changes: [
          FieldChange(
            field: header,
            beforeText: before == rule ? null : before,
            afterText: rule,
          ),
          if (button != null)
            FieldChange(
              field: 'Button',
              beforeText: existing?.button?.label == button.label
                  ? null
                  : existing?.button?.label,
              afterText: call.name(button.label),
            ),
          if (params.isNotEmpty)
            FieldChange(field: 'Params', afterText: _paramsText(params, call)),
          if (existing != null && existing.apply != apply)
            FieldChange(
              field: 'Apply',
              beforeText: _applyText(existing.apply),
              afterText: _applyText(apply),
            ),
          if (apply == ApplyMode.auto)
            const FieldChange(field: 'Applies changes without asking'),
        ],
      ),
    );
    call.title(
      '${existing == null ? 'Add' : 'Update'} automation '
      '${call.quoted(draft.name)}',
    );
  });
}

/// `automations.delete {id}`: one `deleteAutomation` item.
Future<void> planAutomationsDelete(
  Map<String, Object?> args,
  PlanCall call,
  AutomationCatalog catalog,
) async {
  final id = args['id']! as String;
  final automation = await catalog.getAutomation(id);
  if (automation == null ||
      !call.ctx.grants.allowsCollection(automation.trigger.collectionId)) {
    throw HarnessException.of(
      ErrorCode.unknownObject,
      'There is no automation "$id".',
      path: 'id',
      hint: 'automations.list lists them.',
    );
  }
  if (call.view.items.any((i) => i.kind.scoped == false && i.targetId == id)) {
    throw invalidArgs(
      'Automation "$id" is already changed in this turn.',
      path: 'id',
    );
  }
  final collection = call.view.collection(automation.trigger.collectionId);
  call.add(
    DeleteAutomationItem(
      itemId: call.nextItemId(),
      callId: call.callId,
      collectionId: automation.trigger.collectionId,
      label: call.name(automation.name),
      risk: Risk.medium,
      before: automation,
      detail: collection == null
          ? null
          : _triggerHeader(automation.trigger, call.name(collection.name)),
    ),
  );
  call.title('Delete automation ${call.quoted(automation.name)}');
}

// -----------------------------------------------------------------------------

List<AutomationProblem> _manifestProblems(Map<String, Object?> json) {
  try {
    parseManifest(json);
    return const [];
  } on ManifestProblems catch (e) {
    return e.problems;
  }
}

/// A problem's code as a harness error code (the parser's own codes read as
/// `invalid_args`).
ErrorCode _code(String code) =>
    ErrorCode.fromWire(code) ??
    (code == 'too_large' ? ErrorCode.limitExceeded : ErrorCode.invalidArgs);

const String _notAllowed = 'Not allowed';

String _applyText(ApplyMode mode) => switch (mode) {
  ApplyMode.ask => 'Ask first',
  ApplyMode.auto => 'Auto',
};

bool _sameSet(List<String> a, List<String> b) =>
    a.toSet().containsAll(b) && b.toSet().containsAll(a);

bool _sameScope(List<String>? a, List<String>? b) =>
    a == null ? b == null : b != null && _sameSet(a, b);

String _actionsText(ModuleManifest manifest) => [
  for (final a in manifest.actions)
    '${sanitizeName(a.label)} (${switch (a.scope) {
      ActionScope.card => 'on a card',
      ActionScope.collection => 'on a collection',
      ActionScope.any => 'on a card or a collection',
    }})',
].join(', ');

/// `2.1 KB · sha256:3fa2…`.
String _codeText(ModuleRecord module) {
  final bytes = module.codeBytes;
  final size = bytes < 1024
      ? '$bytes B'
      : '${(bytes / 1024).toStringAsFixed(1)} KB';
  final hash = module.bundleHash;
  return '$size · ${hash.substring(0, 'sha256:'.length + 4)}…';
}

// shortcut: IdGenerator has no automation minter (ids.dart is T1's); reuse
// the object id's time + random parts under an `au` prefix.
String _automationId(PlanCall call) => 'au${call.ids.objectId().substring(1)}';

/// Friendly filters stored id-normalized: `{field, op, value}`, or `{field,
/// op, relative, n?}` kept relative. A filter that does not compile is left
/// as given (field normalized when it resolves); validation reports it.
List<Map<String, Object?>> _normalizeWhere(
  RefResolver refs,
  Collection collection,
  List<Object?> where,
) {
  final compiler = FilterCompiler(refs);
  return [
    for (final (i, raw) in where.indexed)
      if (raw is Map)
        _normalizeFilter(compiler, collection, raw.cast<String, Object?>(), i)
      else
        throw invalidArgs(
          'A condition is an object.',
          path: 'trigger.where[$i]',
        ),
  ];
}

Map<String, Object?> _normalizeFilter(
  FilterCompiler compiler,
  Collection collection,
  Map<String, Object?> raw,
  int i,
) {
  final path = 'trigger.where[$i]';
  String? fieldId;
  try {
    fieldId = compiler.refs.fieldIdOrMeta(
      collection,
      '${raw['field']}',
      path: '$path.field',
    );
  } on HarnessException {
    return raw;
  }
  if (raw['relative'] != null) return {...raw, 'field': fieldId};
  try {
    final compiled = compiler.compileOne(collection, raw, path: path);
    if (compiled.length != 1) return {...raw, 'field': fieldId};
    final f = compiled.single;
    final value = raw['value'];
    // A day word (`today`, `+3d`) compiles to a date, which would freeze the
    // condition on the day it was saved; kept raw, every evaluation
    // recompiles it with the run's today.
    if (value is String &&
        value != f.operand &&
        f.operand is String &&
        DateTime.tryParse(value.trim()) == null &&
        DateTime.tryParse(f.operand! as String) != null) {
      return {'field': f.fieldId, 'op': f.op.name, 'value': value.trim()};
    }
    return {'field': f.fieldId, 'op': f.op.name, 'value': ?f.operand};
  } on HarnessException {
    return {...raw, 'field': fieldId};
  }
}

List<String> _fieldIds(
  RefResolver refs,
  Collection collection,
  List<Object?> fields,
) {
  final errors = InputErrors();
  final ids = [
    for (final (i, ref) in fields.indexed)
      ?errors.guard(
        () => refs.field(collection, '$ref', path: 'trigger.fields[$i]').id,
      ),
  ];
  errors.throwIfAny();
  return ids.toSet().toList();
}

/// [params] with `format: field` / `format: collection` names turned into
/// ids where they resolve.
Map<String, Object?> _normalizeParams(
  RefResolver refs,
  Collection collection,
  ActionSpec action,
  Map<String, Object?> params,
) {
  final properties = action.input?.properties ?? const {};
  return {
    for (final MapEntry(:key, :value) in params.entries)
      key: switch ((properties[key]?.format, value)) {
        (InputFormat.field, final String ref) =>
          collection.fields
                  .where((f) => f.id == ref || f.name == ref)
                  .firstOrNull
                  ?.id ??
              ref,
        (InputFormat.collection, final String ref) =>
          refs.visibleCollections
                  .where((c) => c.id == ref || c.name == ref)
                  .firstOrNull
                  ?.id ??
              ref,
        _ => value,
      },
  };
}

ButtonSpec _button(Map<String, Object?>? args, ActionSpec action) {
  final label = ((args?['label'] as String?)?.trim() ?? '').isEmpty
      ? action.label
      : (args!['label']! as String).trim();
  final icon = args?['icon'] as String? ?? action.icon;
  if (icon != null && !kActionIconIds.contains(icon)) {
    throw HarnessException.of(
      ErrorCode.invalidArgs,
      'There is no button icon "$icon".',
      path: 'button.icon',
      candidates: kActionIconIds,
    );
  }
  return ButtonSpec(
    label: label.length <= ButtonSpec.kMaxLabel
        ? label
        : label.substring(0, ButtonSpec.kMaxLabel),
    icon: icon,
    // The descriptor's enum already limits it to kButtonTintIds.
    tint: args?['tint'] as String?,
  );
}

bool _sameAutomation(
  AutomationRecord existing,
  AutomationRecord draft,
  ApplyMode apply,
) {
  Map<String, Object?> key(AutomationRecord a, ApplyMode mode) => {
    'name': a.name,
    'moduleId': a.moduleId,
    'actionId': a.actionId,
    'params': a.params,
    'trigger': a.trigger.toJson(),
    'button': a.button?.toJson(),
    'apply': mode.name,
  };
  // A broken one is worth saving again: that revalidates it.
  return existing.pausedReason != PausedReason.broken &&
      jsonEquals(key(existing, existing.apply), key(draft, apply));
}

/// `When a card is updated in Orders`, `Button on cards in Orders`.
String _triggerHeader(TriggerSpec trigger, String collection) =>
    switch (trigger) {
      ButtonTrigger(scope: ButtonScope.card) =>
        'Button on cards in $collection',
      ButtonTrigger() => 'Button in $collection',
      EventTrigger(:final kind) =>
        'When a card is ${switch (kind) {
          TriggerKind.cardCreated => 'created',
          TriggerKind.cardDeleted => 'deleted',
          _ => 'updated',
        }} in $collection',
    };

/// `Status any of ["Shipped"] (starts matching) → Stamp`.
String _ruleText(
  TriggerSpec trigger,
  Collection collection,
  ActionSpec action,
  RefResolver refs,
) {
  final label = sanitizeName(action.label);
  if (trigger is! EventTrigger || trigger.where.isEmpty) return '→ $label';
  final compiler = FilterCompiler(refs);
  final clauses = [
    for (final raw in trigger.where)
      ..._clauses(compiler, collection, raw, quote: _plainQuote),
  ];
  final when = clauses.join(' and ');
  final starts =
      trigger.kind == TriggerKind.cardUpdated &&
          trigger.mode == TriggerMode.enters
      ? ' (starts matching)'
      : '';
  return '$when$starts → $label';
}

Iterable<String> _clauses(
  FilterCompiler compiler,
  Collection collection,
  Map<String, Object?> raw, {
  required String Function(String) quote,
}) {
  if (raw['relative'] case final String relative) {
    final field = collection.fieldById('${raw['field']}');
    return ['${field?.name ?? raw['field']} ${raw['op']} $relative'];
  }
  try {
    return [
      for (final f in compiler.compileOne(collection, raw, path: 'where'))
        if (filterFieldOf(collection, f.fieldId) case final field?)
          '${field.name} ${describeFilter(field, f, quote: quote)}',
    ];
  } on HarnessException {
    return [jsonEncode(raw)];
  }
}

String _plainQuote(String text) => '“${sanitizeName(text)}”';

String? _ruleTextOrNull(
  AutomationRecord existing,
  PlanCall call,
  RefResolver refs,
  ModuleManifest manifest,
) {
  final collection = call.view.collection(existing.trigger.collectionId);
  final action = manifest.action(existing.actionId);
  if (collection == null || action == null) return null;
  return _ruleText(existing.trigger, collection, action, refs);
}

String _paramsText(Map<String, Object?> params, PlanCall call) => call.name(
  [
    for (final e in params.entries) '${e.key}: ${jsonEncode(e.value)}',
  ].join(', '),
);
