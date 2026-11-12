import 'dart:collection';

import '../../api/data/data_repository.dart';
import '../domain/automation/automation.dart';
import '../domain/domain.dart';
import '../harness/api/capability.dart';
import '../harness/api/envelope.dart';
import '../harness/api/harness_context.dart';
import '../harness/cache/workspace_cache.dart';
import '../harness/input/filter_compiler.dart';
import '../harness/input/ref_resolver.dart';
import '../harness/input/screen_line.dart' show describeFilter;
import '../harness/query/cache_workspace_reader.dart';
import '../harness/schema/arg_shapes.dart';

/// What evaluating one event automation against one [CardChange] decided.
sealed class TriggerOutcome {
  const TriggerOutcome(this.why);

  /// The last-check text ("'Status is Shipped' was false after the change →
  /// didn't run").
  final String why;
}

/// The fire rule passed: ask the `LoopGuard`, then enqueue.
final class TriggerFired extends TriggerOutcome {
  const TriggerFired(
    super.why, {
    required this.after,
    required this.before,
    required this.changedFields,
  });

  /// The card after / before the write with calculated values (null for a
  /// delete / a create).
  final MorkvaObject? after;
  final MorkvaObject? before;

  /// `card.updated`: the field ids whose value differs, calculated included.
  final Set<String> changedFields;
}

/// The conditions did not hold (or nothing watched changed).
final class TriggerNotFired extends TriggerOutcome {
  const TriggerNotFired(super.why);
}

/// No decision: `not_settled` (the write never showed up in the cache
/// within the settle timeout) or `broken` ([why] is the detail for
/// `brokenDetail`: pause the automation and skip the run).
final class TriggerSkipped extends TriggerOutcome {
  const TriggerSkipped(this.reason, super.why);

  final RunReason reason;
}

/// Decides whether an event automation fires for a [CardChange] (design
/// spec, Triggers › Evaluation): settle, derive both images, compile the
/// conditions fresh, apply the fire rule, and note the result in a
/// per-automation ring of the last [kLastChecks] checks.
///
/// Writes nothing: the runner persists `broken`, asks the loop guard and
/// enqueues in change order.
final class TriggerEvaluator {
  TriggerEvaluator(
    this._cache, {
    this.settleTimeout = const Duration(seconds: 5),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const int kLastChecks = 20;

  final WorkspaceCache _cache;
  final Duration settleTimeout;
  final DateTime Function() _now;
  final Map<String, Queue<LastCheck>> _checks = {};

  /// Whether [automation] is evaluated for [change] at all: an origin the
  /// triggers see (ui, plan, automation), an enabled event automation on
  /// the change's collection, and the kind that matches the write.
  static bool watches(AutomationRecord automation, CardChange change) {
    final trigger = automation.trigger;
    if (!automation.enabled ||
        trigger is! EventTrigger ||
        trigger.collectionId != change.collectionId) {
      return false;
    }
    final seen = switch (change.origin.kind) {
      WriteKind.ui || WriteKind.plan || WriteKind.automation => true,
      _ => false,
    };
    return seen &&
        switch (trigger.kind) {
          TriggerKind.cardCreated => change.before == null,
          TriggerKind.cardDeleted => change.after == null,
          TriggerKind.cardUpdated =>
            change.before != null && change.after != null,
          TriggerKind.button => false,
        };
  }

  /// Evaluates [automation] (one [watches] accepts) for [change] under the
  /// run's effective [grants] and day [today], and records the check.
  ///
  /// Throws (and records nothing) when the cache is reset meanwhile
  /// (`StateError`) or a collection's stream fails; a deleted collection is
  /// `broken`.
  Future<TriggerOutcome> evaluate(
    CardChange change,
    AutomationRecord automation, {
    required Grants grants,
    required DateTime today,
  }) async {
    final trigger = automation.trigger as EventTrigger;
    final image = change.after ?? change.before!;
    var label = 'Untitled';
    TriggerOutcome outcome;
    try {
      final collection = _cache.collection(change.collectionId);
      if (collection != null) {
        label = objectLabels(collection, [image])[image.id] ?? label;
      }
      outcome = await _evaluate(change, automation, trigger, grants, today);
    } on MissingCollectionException catch (e) {
      outcome = TriggerSkipped(
        RunReason.broken,
        e.collectionId == change.collectionId
            ? 'The collection it watches was deleted'
            : 'A condition reads a collection that was deleted',
      );
    }
    record(
      automation.id,
      LastCheck(
        cardLabel: label,
        at: _now(),
        result: switch (outcome) {
          TriggerFired() => LastCheckResult.ran,
          TriggerNotFired() => LastCheckResult.notRun,
          TriggerSkipped() => LastCheckResult.skipped,
        },
        why: outcome.why,
      ),
    );
    return outcome;
  }

  /// Appends [check] to [automationId]'s ring (the runner adds its own,
  /// e.g. a loop guard skip after a fire).
  void record(String automationId, LastCheck check) {
    final ring = _checks.putIfAbsent(automationId, Queue.new)..addFirst(check);
    if (ring.length > kLastChecks) ring.removeLast();
  }

  /// [automationId]'s latest checks, newest first (`RunnerHooks.lastChecks`).
  List<LastCheck> lastChecks(String automationId, {int limit = kLastChecks}) =>
      (_checks[automationId] ?? Queue<LastCheck>()).take(limit).toList();

  /// Drops [automationId]'s checks (deleted automation).
  void forget(String automationId) => _checks.remove(automationId);

  /// Drops every check (sign-out).
  void reset() => _checks.clear();

  Future<TriggerOutcome> _evaluate(
    CardChange change,
    AutomationRecord automation,
    EventTrigger trigger,
    Grants grants,
    DateTime today,
  ) async {
    final after = change.after;
    final settled = await _cache.settled(
      change.collectionId,
      change.cardId,
      after == null
          ? (card) => card == null
          : (card) => card != null && !card.updatedAt.isBefore(after.updatedAt),
      timeout: settleTimeout,
    );
    if (settled == null) {
      return TriggerSkipped(
        RunReason.notSettled,
        "The change didn't reach this device's data within "
        "${settleTimeout.inSeconds} s → didn't run",
      );
    }

    final ctx = HarnessContext(
      workspaceId: _cache.workspaceId ?? '',
      actor: Actor.plugin(automation.moduleId),
      grants: grants,
      now: _now(),
      today: today,
    );
    final derived = await _cache.derive(change.collectionId, today: ctx.today);
    final schema = derived.schema;
    final a = derived.deriveWith(change.after);
    final b = derived.deriveWith(change.before);

    final compiled = await _compile(schema, trigger.where, ctx);
    if (compiled case String detail) {
      return TriggerSkipped(RunReason.broken, detail);
    }
    final filters = compiled as List<(ViewFilter, FieldDefinition)>;

    /// The first condition [image] fails, or null when all hold.
    String? failing(MorkvaObject image) {
      for (final (f, field) in filters) {
        if (!matchesFilter(f, field, _read(image, field))) {
          return _describe(field, f);
        }
      }
      return null;
    }

    final conditions = filters.map((p) => _describe(p.$2, p.$1)).join(' and ');
    final verb = filters.length == 1 ? 'was' : 'were';
    TriggerFired fired(String why, [Set<String> changed = const {}]) =>
        TriggerFired(why, after: a, before: b, changedFields: changed);

    switch (trigger.kind) {
      case TriggerKind.cardCreated:
        if (failing(a!) case final miss?) {
          return TriggerNotFired(
            "$miss was false for the new card → didn't run",
          );
        }
        return fired(
          filters.isEmpty
              ? 'A card was created → ran'
              : '$conditions $verb true for the new card → ran',
        );
      case TriggerKind.cardDeleted:
        if (failing(b!) case final miss?) {
          return TriggerNotFired(
            "$miss was false before the delete → didn't run",
          );
        }
        return fired(
          filters.isEmpty
              ? 'A card was deleted → ran'
              : '$conditions $verb true before the delete → ran',
        );
      case TriggerKind.cardUpdated:
        final changed = {
          for (final f in schema.fields)
            if (_read(b!, f) != _read(a!, f)) f.id,
        };
        final watched = trigger.fields ?? const [];
        if (watched.isNotEmpty && !watched.any(changed.contains)) {
          final names = _names(schema, watched);
          return TriggerNotFired("$names didn't change → didn't run");
        }
        if (filters.isEmpty) {
          return changed.isEmpty
              ? const TriggerNotFired("Nothing changed → didn't run")
              : fired('${_names(schema, changed)} changed → ran', changed);
        }
        if (failing(a!) case final miss?) {
          return TriggerNotFired(
            "$miss was false after the change → didn't run",
          );
        }
        if (trigger.mode == TriggerMode.enters && failing(b!) == null) {
          return TriggerNotFired(
            "$conditions $verb already true before the change → didn't run",
          );
        }
        return fired(
          trigger.mode == TriggerMode.enters
              ? '$conditions became true → ran'
              : '$conditions $verb true after the change → ran',
          changed,
        );
      case TriggerKind.button:
        throw ArgumentError.value(automation.id, 'automation', 'not an event');
    }
  }

  /// [where] compiled and checked under [ctx], or the broken detail. The
  /// collections reference operands point into are leased for the compile,
  /// so a stored card id resolves instead of reading as unknown.
  Future<Object> _compile(
    Collection schema,
    List<Map<String, Object?>> where,
    HarnessContext ctx,
  ) async {
    final targets = {
      for (final w in where)
        if (w['field'] case final String id)
          if (_presented(schema.fieldById(id))
              case ReferenceFieldDefinition(:final targetCollectionId)
              when _cache.collection(targetCollectionId) != null &&
                  ctx.grants.allowsCollection(targetCollectionId))
            targetCollectionId,
    };
    final lease = targets.isEmpty ? null : await _cache.lease(targets);
    try {
      final compiler = FilterCompiler(
        RefResolver(CacheWorkspaceReader(_cache), ctx),
      );
      final out = <(ViewFilter, FieldDefinition)>[];
      for (final f in compiler.compile(schema, where)) {
        final field = filterFieldOf(schema, f.fieldId)!;
        if (filterProblem(field, f) case final problem?) {
          return 'A condition is incomplete: $problem';
        }
        out.add((f, field));
      }
      return out;
    } on HarnessException catch (e) {
      final error = e.error;
      return switch (error.code) {
        ErrorCode.unknownField => 'A condition uses a field that was deleted',
        _ => 'A condition no longer works: ${error.message}',
      };
    } finally {
      lease?.release();
    }
  }

  static FieldDefinition? _presented(FieldDefinition? field) =>
      field is CalculatedFieldDefinition ? field.outputField : field;

  static FieldValue _read(MorkvaObject object, FieldDefinition field) =>
      switch (field.id) {
        kCreatedAtRef => DateFieldValue(object.createdAt),
        kUpdatedAtRef => DateFieldValue(object.updatedAt),
        _ => object[field.id] ?? field.emptyValue(),
      };

  /// `'Status is Shipped'`, `'Qty < 5'`.
  static String _describe(FieldDefinition field, ViewFilter filter) {
    final options = switch (_presented(field)) {
      SingleSelectFieldDefinition(:final options) ||
      MultiSelectFieldDefinition(:final options) => options,
      _ => null,
    };
    final ids = filter.operand is List
        ? (filter.operand as List).whereType<String>()
        : const <String>[];
    String labels(String sep) => [
      for (final id in ids)
        options!.where((o) => o.id == id).firstOrNull?.label ?? 'unknown',
    ].join(sep);
    final text = switch (filter.op) {
      FilterOp.anyOf when options != null => 'is ${labels(' or ')}',
      FilterOp.noneOf when options != null => 'is none of ${labels(', ')}',
      _ => describeFilter(field, filter, quote: (s) => s),
    };
    return "'${field.name} $text'";
  }

  /// "Status", "Status and Qty", "Status, Qty and 2 more".
  static String _names(Collection schema, Iterable<String> fieldIds) {
    final names = [for (final id in fieldIds) schema.fieldById(id)?.name ?? id];
    if (names.length == 1) return names.single;
    if (names.length <= 3) {
      return '${names.take(names.length - 1).join(', ')} and ${names.last}';
    }
    return '${names.take(2).join(', ')} and ${names.length - 2} more';
  }
}
