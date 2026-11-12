/// The save-time checks of an automation, shared by the `automations.save`
/// planner, the editor (through `AutomationRunnerApi.validate`) and the
/// runner's schema revalidation. Here, in the harness, because the harness
/// may not import lib/core/automation.
library;

import '../domain/automation/automation.dart';
import '../domain/domain.dart';
import 'api/capability.dart';
import 'api/envelope.dart';
import 'api/harness_context.dart';
import 'input/filter_compiler.dart';
import 'input/ref_resolver.dart';
import 'input/screen_line.dart';
import 'schema/arg_shapes.dart';
import 'schema/json_schema.dart';

/// What a module may plan: its manifest's grantable capabilities ∩ the
/// [consent]'s, in the consent's collections ∩ [collections] (an
/// automation's narrowing scope; null = no narrowing). Without a consent
/// only the manifest and [collections] bound it.
Grants moduleGrants(
  ModuleManifest manifest,
  GrantRecord? consent, {
  List<String>? collections,
}) {
  final caps = [
    for (final wire in manifest.capabilities)
      if (Capability.fromWire(wire) case final cap?
          when kModuleGrantable.contains(cap) &&
              (consent == null || consent.caps.contains(wire)))
        cap,
  ];
  final consented = consent?.collections;
  return Grants(
    caps,
    collections: consented == null
        ? collections
        : collections == null
        ? consented
        : consented.where(collections.contains),
  );
}

/// Every problem that keeps [automation] from being saved, empty when it may
/// be: its module and action exist, the trigger collection exists and lies
/// inside the effective collections, the action takes that trigger, the
/// conditions compile under the module's effective grants on [today], the
/// watched fields exist and the params match the action's input (`format:
/// field` params name fields of the trigger collection, `format:
/// collection` ones an allowed collection).
///
/// [workspace] must hold the trigger collection's cards and its reference
/// targets' (lease them) when a condition names cards.
List<AutomationProblem> validateAutomation(
  AutomationRecord automation, {
  required ModuleRecord? module,
  required GrantRecord? consent,
  required WorkspaceReader workspace,
  required DateTime today,
}) {
  final problems = <AutomationProblem>[];
  void add(String path, ErrorCode code, String message) =>
      problems.add(AutomationProblem(path, code.wire, message));

  final manifest = module?.manifest;
  if (module == null) {
    add(
      'moduleId',
      ErrorCode.unknownObject,
      'Module "${automation.moduleId}" is not installed.',
    );
    return problems;
  }
  if (manifest == null) {
    add(
      'moduleId',
      ErrorCode.invalidArgs,
      '${quoteName(module.name)} no longer loads.',
    );
    return problems;
  }
  final action = manifest.action(automation.actionId);
  if (action == null) {
    add(
      'actionId',
      ErrorCode.invalidArgs,
      '${quoteName(manifest.name)} has no action "${automation.actionId}".',
    );
  }

  final trigger = automation.trigger;
  final collection = workspace.collections
      .where((c) => c.id == trigger.collectionId)
      .firstOrNull;
  if (collection == null) {
    add(
      'trigger.collection',
      ErrorCode.unknownCollection,
      'Collection "${trigger.collectionId}" no longer exists.',
    );
    return problems;
  }
  final grants = moduleGrants(
    manifest,
    consent,
    collections: automation.collections,
  );
  if (!grants.allowsCollection(collection.id)) {
    add(
      'trigger.collection',
      ErrorCode.notPermitted,
      '${quoteName(manifest.name)} isn\'t allowed in ${collection.name}.',
    );
  }

  if (action != null) {
    final onCard = switch (trigger) {
      ButtonTrigger(:final scope) => scope == ButtonScope.card,
      EventTrigger() => true,
    };
    if (onCard ? !action.scope.onCard : !action.scope.onCollection) {
      add(
        'actionId',
        ErrorCode.invalidArgs,
        '${quoteName(action.label)} runs on ${onCard ? 'a collection' : 'a card'}, '
            'not on ${onCard ? 'a card' : 'a collection'}.',
      );
    }
  }

  if (trigger case EventTrigger(:final where, :final fields)) {
    final ctx = HarnessContext(
      workspaceId: '',
      actor: Actor.plugin(manifest.id),
      grants: grants,
      now: today,
      today: today,
    );
    final compiler = FilterCompiler(RefResolver(workspace, ctx));
    for (final (i, raw) in where.indexed) {
      final path = 'trigger.where[$i]';
      try {
        for (final f in compiler.compileOne(collection, raw, path: path)) {
          final field = filterFieldOf(collection, f.fieldId)!;
          if (f.fieldId == kCreatedAtRef || f.fieldId == kUpdatedAtRef) {
            add(
              '$path.field',
              ErrorCode.invalidFilter,
              'Conditions can\'t use ${field.name}: every change moves it.',
            );
          } else if (filterProblem(field, f) case final problem?) {
            add(path, ErrorCode.invalidFilter, problem);
          }
        }
      } on HarnessException catch (e) {
        final error = e.error;
        final target = switch (collection.fieldById('${raw['field']}')) {
          ReferenceFieldDefinition(:final targetCollectionId) =>
            workspace.collections
                .where((c) => c.id == targetCollectionId)
                .firstOrNull,
          _ => null,
        };
        if (error.code == ErrorCode.notPermitted && target != null) {
          add(
            error.path ?? path,
            ErrorCode.notPermitted,
            'This condition reads ${target.name}, which the module isn\'t '
            'allowed in.',
          );
        } else {
          for (final d in error.details ?? [_detail(error, path)]) {
            add(d.path, d.code, d.message);
          }
        }
      }
    }
    for (final (i, id) in (fields ?? const <String>[]).indexed) {
      if (collection.fieldById(id) == null) {
        add(
          'trigger.fields[$i]',
          ErrorCode.unknownField,
          'No field "$id" in ${collection.name}.',
        );
      }
    }
  }

  if (action != null) {
    final input = action.input;
    final params = automation.params;
    if (input == null) {
      if (params.isNotEmpty) {
        add(
          'params',
          ErrorCode.invalidArgs,
          '${quoteName(action.label)} takes no params.',
        );
      }
    } else {
      for (final d in JsonSchema.validate(
        input.toJsonSchema(),
        input.withDefaults(params),
        path: 'params',
      )) {
        add(d.path, d.code, d.message);
      }
      for (final MapEntry(:key, :value) in input.properties.entries) {
        final param = params[key];
        if (param is! String) continue;
        switch (value.format) {
          case InputFormat.field when collection.fieldById(param) == null:
            add(
              'params.$key',
              ErrorCode.unknownField,
              'No field "$param" in ${collection.name}.',
            );
          case InputFormat.collection
              when !workspace.collections.any((c) => c.id == param) ||
                  !grants.allowsCollection(param):
            add(
              'params.$key',
              ErrorCode.unknownCollection,
              'No collection "$param" the module may use.',
            );
          default:
            break;
        }
      }
    }
  }
  return problems;
}

ErrorDetail _detail(HarnessError e, String path) =>
    ErrorDetail(path: e.path ?? path, code: e.code, message: e.message);
