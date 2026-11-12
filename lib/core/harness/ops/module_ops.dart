import 'dart:convert';

import '../../domain/automation/automation.dart';
import '../api/capability.dart';
import '../api/envelope.dart';
import '../api/harness_context.dart';
import '../api/operation.dart';
import '../automation_catalog.dart';
import '../automation_validation.dart';
import '../cache/workspace_cache.dart';
import '../input/ref_resolver.dart';
import '../plan/plan.dart';
import '../plan/planners/module_planners.dart';
import '../plan/planners/plan_call.dart';
import '../query/cache_workspace_reader.dart';
import '../schema/arg_shapes.dart';
import '../schema/json_schema.dart';
import 'registry.dart';

/// Registers the module ops: reads `modules.list/get`, `automations.list`,
/// `runs.list/get`, the dry run `modules.testRun`, and the plan ops
/// `modules.save`, `automations.save`, `automations.delete`. They reach the
/// automation docs through [catalog]; the plan ops plan on [services].
///
/// Module-written text (code, logs, errors, summaries, manifest names) is
/// untrusted data: the agent wraps these results in the workspace-data
/// envelope.
void registerModuleOps(
  OperationRegistry ops, {
  required AutomationCatalog catalog,
  required PlanServices services,
}) {
  final cache = services.cache;
  final testRuns = <String, int>{};
  for (final op in <Operation<Object?>>[
    _ModuleRead(_modulesList, (args, ctx) => _listModules(catalog)),
    _ModuleRead(_modulesGet, (args, ctx) => _getModule(catalog, args)),
    _ModuleRead(
      _automationsList,
      (args, ctx) => _listAutomations(catalog, cache, args, ctx),
    ),
    _ModuleRead(_runsList, (args, ctx) => _listRuns(catalog, args, ctx)),
    _ModuleRead(_runsGet, (args, ctx) => _getRun(catalog, args, ctx)),
    _ModuleRead(
      _modulesTestRun,
      (args, ctx) => _testRun(catalog, cache, testRuns, args, ctx),
    ),
    _ModulePlan(services, _modulesSave, planModulesSave, catalog),
    _ModulePlan(services, _automationsSave, planAutomationsSave, catalog),
    _ModulePlan(services, _automationsDelete, planAutomationsDelete, catalog),
  ]) {
    ops.register(op);
  }
}

/// At most this many `modules.testRun` calls per turn.
const int kMaxTestRunsPerTurn = 5;

/// `modules.get` returns at most this much code.
const int kModuleCodeResultBytes = 64 * 1024;

/// `runs.get` trims the decoded log to this.
const int kRunLogResultBytes = 8 * 1024;

typedef _Json = Map<String, Object?>;

final class _ModuleRead extends Operation<_Json> {
  _ModuleRead(this.descriptor, this._run);

  @override
  final OperationDescriptor descriptor;
  final Future<_Json> Function(_Json args, HarnessContext ctx) _run;

  @override
  _Json decode(_Json args, HarnessContext ctx) => args;

  @override
  Future<OpResult> run(
    _Json args,
    HarnessContext ctx,
    HarnessRequest r,
  ) async => OpResult(await _run(args, ctx));
}

final class _ModulePlan extends PlanOperation {
  _ModulePlan(super.services, this.descriptor, this._plan, this._catalog);

  @override
  final OperationDescriptor descriptor;
  final Future<void> Function(_Json, PlanCall, AutomationCatalog) _plan;
  final AutomationCatalog _catalog;

  @override
  Future<void> plan(_Json args, PlanCall call) => _plan(args, call, _catalog);
}

// -----------------------------------------------------------------------------
// Reads

Future<ModuleStatus?> _statusOf(
  AutomationCatalog catalog,
  ModuleRecord? module,
) async => module == null
    ? null
    : moduleStatusOf(module, await catalog.liveConsent(module.id));

Future<_Json> _listModules(AutomationCatalog catalog) async {
  final modules = await catalog.listModules();
  final automations = await catalog.listAutomations();
  return {
    'modules': [
      for (final m in modules)
        {
          'id': m.id,
          'name': m.name,
          'version': m.version,
          'description': ?m.manifest?.description,
          'status': (await _statusOf(catalog, m))!.wire,
          'caps': m.manifest?.capabilities ?? const <String>[],
          'actions': [
            for (final a in m.manifest?.actions ?? const <ActionSpec>[])
              {'id': a.id, 'label': a.label, 'scope': a.scope.name},
          ],
          'automationCount': automations
              .where((a) => a.moduleId == m.id)
              .length,
        },
    ],
  };
}

Future<ModuleRecord> _module(AutomationCatalog catalog, String id) async =>
    await catalog.getModule(id) ??
    (throw HarnessException.of(
      ErrorCode.unknownObject,
      'There is no module "$id".',
      path: 'id',
      candidates: [for (final m in await catalog.listModules()) m.id],
      hint: 'modules.list lists the installed modules.',
    ));

Future<_Json> _getModule(AutomationCatalog catalog, _Json args) async {
  final module = await _module(catalog, args['id']! as String);
  final consent = await catalog.liveConsent(module.id);
  final code = utf8.encode(module.code);
  final cut = code.length > kModuleCodeResultBytes;
  return {
    'id': module.id,
    'manifest': module.manifestJson,
    'codeHash': module.bundleHash,
    'source': module.source.name,
    'status': moduleStatusOf(module, consent).wire,
    'consent': consent == null
        ? null
        : {
            'caps': consent.caps,
            'collections': consent.collections,
            'autoApply': consent.autoApply,
          },
    if (args['code'] == true) ...{
      'code': cut
          ? utf8.decode(
              code.sublist(0, kModuleCodeResultBytes),
              allowMalformed: true,
            )
          : module.code,
      if (cut) 'codeTruncated': true,
    },
  };
}

Future<_Json> _listAutomations(
  AutomationCatalog catalog,
  WorkspaceCache cache,
  _Json args,
  HarnessContext ctx,
) async {
  String? collectionId;
  if (args['collection'] case final String ref) {
    await cache.ready;
    collectionId = RefResolver(
      CacheWorkspaceReader(cache),
      ctx,
    ).collection(ref).id;
  }
  final moduleId = args['moduleId'] as String?;
  final modules = {for (final m in await catalog.listModules()) m.id: m};
  final statuses = <String, ModuleStatus?>{};
  final hooks = catalog.hooks;
  return {
    'automations': [
      for (final a in await catalog.listAutomations())
        if (ctx.grants.allowsCollection(a.trigger.collectionId) &&
            (collectionId == null || a.trigger.collectionId == collectionId) &&
            (moduleId == null || a.moduleId == moduleId))
          {
            'id': a.id,
            'name': a.name,
            'kind': a.trigger.kind.wire,
            'collectionId': a.trigger.collectionId,
            'moduleId': a.moduleId,
            'actionId': a.actionId,
            'status': automationStatusOf(
              a,
              statuses[a.moduleId] ??= await _statusOf(
                catalog,
                modules[a.moduleId],
              ),
            ).wire,
            'apply': a.apply.name,
            'enabled': a.enabled,
            'lastChecks': [
              for (final c in hooks?.lastChecks(a.id, limit: 5) ?? const [])
                c.toJson(),
            ],
          },
    ],
  };
}

Future<_Json> _listRuns(
  AutomationCatalog catalog,
  _Json args,
  HarnessContext ctx,
) async {
  final limit = (args['limit'] as num?)?.toInt() ?? 20;
  return {
    'runs': [
      for (final r in await catalog.listRuns())
        if (ctx.grants.allowsCollection(r.trigger.collectionId) &&
            (args['automationId'] == null ||
                r.automationId == args['automationId']) &&
            (args['moduleId'] == null || r.moduleId == args['moduleId']) &&
            (args['status'] == null || r.status.wire == args['status']))
          {
            'id': r.id,
            'status': r.status.wire,
            'reason': r.reason?.wire,
            'automationName': r.automationName,
            'actionLabel': r.actionLabel,
            'summary': r.summary,
            'startedAt': r.startedAt.toUtc().toIso8601String(),
            'trigger': {
              'kind': r.trigger.kind.wire,
              'cardLabel': r.trigger.cardLabel,
            },
          },
    ].take(limit).toList(),
  };
}

Future<_Json> _getRun(
  AutomationCatalog catalog,
  _Json args,
  HarnessContext ctx,
) async {
  final id = args['id']! as String;
  final run = await catalog.getRun(id);
  if (run == null || !ctx.grants.allowsCollection(run.trigger.collectionId)) {
    throw HarnessException.of(
      ErrorCode.unknownObject,
      'There is no run "$id".',
      path: 'id',
      hint: 'runs.list lists the latest runs.',
    );
  }
  return {
    'id': run.id,
    ...plainJson(run.toJson())! as _Json,
    'log': jsonDecode(encodeRunLog(run.log, maxBytes: kRunLogResultBytes)),
  };
}

Future<_Json> _testRun(
  AutomationCatalog catalog,
  WorkspaceCache cache,
  Map<String, int> perTurn,
  _Json args,
  HarnessContext ctx,
) async {
  final hooks =
      catalog.hooks ??
      (throw HarnessException.of(
        ErrorCode.unsupported,
        'Test runs are not available here.',
      ));
  final module = await _module(catalog, args['moduleId']! as String);
  final consent = await catalog.liveConsent(module.id);
  final status = moduleStatusOf(module, consent);
  final manifest = module.manifest;
  if (status != ModuleStatus.ok || manifest == null) {
    throw HarnessException.of(
      ErrorCode.notPermitted,
      status == ModuleStatus.broken
          ? '"${module.name}" no longer loads; save it again first.'
          : '"${module.name}" needs the user\'s consent to its current code '
                'before it can run.',
      path: 'moduleId',
    );
  }
  final actionId = args['actionId']! as String;
  final action =
      manifest.action(actionId) ??
      (throw HarnessException.of(
        ErrorCode.invalidArgs,
        '"${module.name}" has no action "$actionId".',
        path: 'actionId',
        candidates: [for (final a in manifest.actions) a.id],
      ));

  // Refs resolve under the module's grants, not the caller's.
  final refs = RefResolver(
    CacheWorkspaceReader(cache),
    HarnessContext(
      workspaceId: ctx.workspaceId,
      actor: Actor.plugin(module.id),
      grants: moduleGrants(manifest, consent),
      now: ctx.now,
      today: ctx.today,
      focus: ctx.focus,
    ),
  );
  await cache.ready;
  final cardRef = args['card'] as String?;
  final collection = switch (args['collection']) {
    final String ref => refs.collection(ref),
    _ when cardRef?.trim() == ScreenRefs.card => refs.screenCollection(
      path: 'card',
    ),
    _ => throw HarnessException.of(
      ErrorCode.invalidArgs,
      'Name the collection to run on.',
      path: 'collection',
    ),
  };
  String? cardId;
  if (cardRef != null) {
    final lease = await cache.lease([collection.id]);
    try {
      cardId = refs.card(collection, cardRef);
    } finally {
      lease.release();
    }
  }
  if (cardId != null ? !action.scope.onCard : !action.scope.onCollection) {
    throw HarnessException.of(
      ErrorCode.invalidArgs,
      cardId != null
          ? '"${action.label}" runs on a collection; leave "card" out.'
          : '"${action.label}" runs on a card; pass "card".',
      path: cardId != null ? 'card' : 'collection',
    );
  }
  final params = (args['params'] as Map?)?.cast<String, Object?>() ?? const {};
  final input = action.input;
  final problems = input == null
      ? [
          if (params.isNotEmpty)
            ErrorDetail(
              path: 'params',
              code: ErrorCode.invalidArgs,
              message: '"${action.label}" takes no params.',
            ),
        ]
      : JsonSchema.validate(
          input.toJsonSchema(),
          input.withDefaults(params),
          path: 'params',
        );
  if (problems.isNotEmpty) {
    throw HarnessException(HarnessError.fromDetails(problems));
  }

  if (ctx.turnId case final turn?) {
    final key = '${ctx.actor.wire} $turn';
    final n = perTurn[key] ?? 0;
    if (n >= kMaxTestRunsPerTurn) {
      throw HarnessException.of(
        ErrorCode.limitExceeded,
        'At most $kMaxTestRunsPerTurn test runs per turn.',
        hint: 'Report what you found and let the user decide.',
      );
    }
    if (perTurn.length > 100) perTurn.clear();
    perTurn[key] = n + 1;
  }
  final result = await hooks.testRun(
    TestRunRequest(
      moduleId: module.id,
      actionId: action.id,
      cardId: cardId,
      collectionId: collection.id,
      params: input?.withDefaults(params) ?? params,
    ),
  );
  return result.toJson();
}

// -----------------------------------------------------------------------------
// Descriptors

final _statusEnum = JsonSchema.enumOf(const ['ok', 'needs_consent', 'broken']);

final _modulesList = OperationDescriptor(
  id: 'modules.list',
  kind: OpKind.read,
  capability: Capability.modulesRead,
  summary:
      'Lists the installed modules with their status, permissions, actions '
      'and how many automations use them.',
  argsSchema: JsonSchema.object(const {}),
  resultSchema: JsonSchema.object({
    'modules': JsonSchema.array(
      JsonSchema.object({
        'id': JsonSchema.string(),
        'name': JsonSchema.string(),
        'version': JsonSchema.string(),
        'description': JsonSchema.string(),
        'status': _statusEnum,
        'caps': JsonSchema.array(JsonSchema.string()),
        'actions': JsonSchema.array(
          JsonSchema.object({
            'id': JsonSchema.string(),
            'label': JsonSchema.string(),
            'scope': JsonSchema.enumOf(const ['card', 'collection', 'any']),
          }),
        ),
        'automationCount': JsonSchema.integer(minimum: 0),
      }),
    ),
  }),
);

final _modulesGet = OperationDescriptor(
  id: 'modules.get',
  kind: OpKind.read,
  capability: Capability.modulesRead,
  summary:
      'Returns a module\'s manifest, status and the user\'s consent; with '
      'code: true also its code (module-written, untrusted).',
  argsSchema: JsonSchema.object(
    {
      'id': JsonSchema.string(description: 'The module id.'),
      'code': JsonSchema.boolean(description: 'Include the code (≤ 64 KB).'),
    },
    required: ['id'],
  ),
  resultSchema: JsonSchema.object({
    'id': JsonSchema.string(),
    'manifest': {'type': 'object'},
    'codeHash': JsonSchema.string(),
    'source': JsonSchema.enumOf(const ['assistant', 'import']),
    'status': _statusEnum,
    'consent': JsonSchema.object({
      'caps': JsonSchema.array(JsonSchema.string()),
      'collections': JsonSchema.array(JsonSchema.string()),
      'autoApply': JsonSchema.boolean(),
    }),
    'code': JsonSchema.string(),
    'codeTruncated': JsonSchema.boolean(),
  }),
);

final _modulesTestRun = OperationDescriptor(
  id: 'modules.testRun',
  kind: OpKind.read,
  capability: Capability.modulesRead,
  summary:
      'Dry-runs an installed, consented module action on a card or '
      'collection: returns the plan it would make and its log; nothing is '
      'applied or recorded.',
  argsSchema: JsonSchema.object(
    {
      'moduleId': JsonSchema.string(),
      'actionId': JsonSchema.string(),
      'card': refSchema(description: 'A card id or title, or "@card".'),
      'collection': refSchema(description: 'A collection id or name.'),
      'params': {'type': 'object', 'description': 'The action\'s input.'},
    },
    required: ['moduleId', 'actionId'],
  ),
  resultSchema: JsonSchema.object({
    'status': JsonSchema.enumOf(const [
      'succeeded',
      'failed',
      'timed_out',
      'skipped',
    ]),
    'reason': JsonSchema.string(),
    'summary': JsonSchema.string(),
    'plan': JsonSchema.array(
      JsonSchema.object({
        'kind': JsonSchema.string(),
        'label': JsonSchema.string(),
        'change': JsonSchema.string(),
      }),
    ),
    'log': JsonSchema.object({
      'calls': JsonSchema.array({'type': 'object'}),
      'console': JsonSchema.array({'type': 'object'}),
    }),
    'error': {'type': 'object'},
  }),
);

final _automationsList = OperationDescriptor(
  id: 'automations.list',
  kind: OpKind.read,
  capability: Capability.modulesRead,
  summary:
      'Lists automations (buttons and card-event triggers) with their status '
      'and the latest checks of why they ran or not.',
  argsSchema: JsonSchema.object({
    'collection': refSchema(description: 'Only this trigger collection.'),
    'moduleId': JsonSchema.string(description: 'Only this module\'s.'),
  }),
  resultSchema: JsonSchema.object({
    'automations': JsonSchema.array(
      JsonSchema.object({
        'id': JsonSchema.string(),
        'name': JsonSchema.string(),
        'kind': JsonSchema.enumOf([for (final k in TriggerKind.values) k.wire]),
        'collectionId': JsonSchema.string(),
        'moduleId': JsonSchema.string(),
        'actionId': JsonSchema.string(),
        'status': JsonSchema.enumOf([
          for (final s in AutomationStatus.values) s.wire,
        ]),
        'apply': JsonSchema.enumOf(const ['ask', 'auto']),
        'enabled': JsonSchema.boolean(),
        'lastChecks': JsonSchema.array(
          JsonSchema.object({
            'cardLabel': JsonSchema.string(),
            'at': JsonSchema.string(),
            'result': JsonSchema.string(),
            'why': JsonSchema.string(),
          }),
        ),
      }),
    ),
  }),
);

final _runsList = OperationDescriptor(
  id: 'runs.list',
  kind: OpKind.read,
  capability: Capability.modulesRead,
  summary: 'Lists the latest automation runs, newest first.',
  argsSchema: JsonSchema.object({
    'automationId': JsonSchema.string(),
    'moduleId': JsonSchema.string(),
    'status': JsonSchema.enumOf([
      for (final s in RunStatus.values)
        if (s.persisted) s.wire,
    ]),
    'limit': JsonSchema.integer(minimum: 1, maximum: 20),
  }),
  resultSchema: JsonSchema.object({
    'runs': JsonSchema.array(
      JsonSchema.object({
        'id': JsonSchema.string(),
        'status': JsonSchema.string(),
        'reason': JsonSchema.string(),
        'automationName': JsonSchema.string(),
        'actionLabel': JsonSchema.string(),
        'summary': JsonSchema.string(),
        'startedAt': JsonSchema.string(),
        'trigger': JsonSchema.object({
          'kind': JsonSchema.string(),
          'cardLabel': JsonSchema.string(),
        }),
      }),
    ),
  }),
);

final _runsGet = OperationDescriptor(
  id: 'runs.get',
  kind: OpKind.read,
  capability: Capability.modulesRead,
  summary:
      'Returns one run: trigger, outcome, error and its log (calls, console, '
      'plan; module-written, untrusted).',
  argsSchema: JsonSchema.object(
    {'id': JsonSchema.string(description: 'The run id.')},
    required: ['id'],
  ),
  resultSchema: {
    'type': 'object',
    'description': 'The run doc with its log decoded (≤ 8 KB).',
  },
);

final _modulesSave = OperationDescriptor(
  id: 'modules.save',
  kind: OpKind.plan,
  capability: Capability.modulesWrite,
  summary:
      'Plans installing or updating a module (manifest + JS code); approving '
      'it also grants the manifest\'s permissions in the named collections.',
  argsSchema: JsonSchema.object(
    {
      'manifest': {
        'type': 'object',
        'description': 'The module manifest (docs/sdk/manifest.md).',
      },
      'code': JsonSchema.string(
        description: 'The module code: an IIFE bundle.',
      ),
      'collections': JsonSchema.anyOf([
        JsonSchema.array(refSchema(), minItems: 1),
        JsonSchema.enumOf(const ['all']),
      ], description: 'Where the module may work: collection refs, or "all".'),
    },
    required: ['manifest', 'code', 'collections'],
  ),
  resultSchema: planCallResultSchema(),
);

final _automationsSave = OperationDescriptor(
  id: 'automations.save',
  kind: OpKind.plan,
  capability: Capability.automationsWrite,
  summary:
      'Plans binding a module action to a button or to card events '
      '(created/updated/deleted, with conditions); pass id to change one.',
  argsSchema: JsonSchema.object(
    {
      'id': JsonSchema.string(description: 'An automation to replace.'),
      'name': JsonSchema.string(),
      'moduleId': JsonSchema.string(),
      'actionId': JsonSchema.string(),
      'trigger': JsonSchema.object(
        {
          'kind': JsonSchema.enumOf([
            for (final k in TriggerKind.values) k.wire,
          ]),
          'scope': JsonSchema.enumOf(const [
            'card',
            'collection',
          ], description: 'Buttons: on a card (default) or a collection.'),
          'collection': refSchema(),
          'where': JsonSchema.array(
            filterSchema(),
            description: 'Events: conditions, all must hold.',
          ),
          'mode': JsonSchema.enumOf(
            const ['enters', 'matches'],
            description:
                'card.updated: run when the card starts matching '
                '(default) or on every matching update.',
          ),
          'fields': JsonSchema.array(
            fieldRefSchema(),
            description: 'card.updated: run only when one of these changed.',
          ),
        },
        required: ['kind', 'collection'],
      ),
      'params': {'type': 'object', 'description': 'The action\'s input.'},
      'button': JsonSchema.object({
        'label': JsonSchema.string(),
        'icon': JsonSchema.enumOf(kActionIconIds),
        'tint': JsonSchema.string(),
      }),
      'apply': JsonSchema.enumOf(const [
        'ask',
        'auto',
      ], description: 'ask (default): the user reviews each run.'),
    },
    required: ['name', 'moduleId', 'actionId', 'trigger'],
  ),
  resultSchema: planCallResultSchema(),
);

final _automationsDelete = OperationDescriptor(
  id: 'automations.delete',
  kind: OpKind.plan,
  capability: Capability.automationsWrite,
  summary: 'Plans removing an automation.',
  argsSchema: JsonSchema.object(
    {'id': JsonSchema.string(description: 'The automation id.')},
    required: ['id'],
  ),
  resultSchema: planCallResultSchema(),
);
