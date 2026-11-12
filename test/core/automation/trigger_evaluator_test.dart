import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/api/data/data_repository.dart';
import 'package:morkva_crm/core/automation/trigger_evaluator.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/core/harness/api/capability.dart';
import 'package:morkva_crm/core/harness/cache/workspace_cache.dart';

import '../../features/collections/fake_data_repository.dart';
import '../harness/fixtures/seed_workspace.dart';

const _orders = SeedIds.orders;
final _at = DateTime.utc(2026, 11, 12, 12);
final _today = DateTime(2026, 11, 12);
final _grants = Grants(const [Capability.dataRead, Capability.dataWrite]);

SingleSelectFieldValue _status(String id) => SingleSelectFieldValue(id);

AutomationRecord _automation(
  TriggerKind kind, {
  List<Map<String, Object?>> where = const [],
  TriggerMode mode = TriggerMode.enters,
  List<String>? fields,
  String collectionId = _orders,
  bool enabled = true,
  String id = 'a_1',
}) => AutomationRecord(
  id: id,
  name: 'Watch orders',
  enabled: enabled,
  moduleId: 'stamp-shipped-date',
  actionId: 'stamp',
  trigger: EventTrigger(
    kind: kind,
    collectionId: collectionId,
    where: where,
    mode: mode,
    fields: fields,
  ),
  apply: ApplyMode.ask,
  createdBy: 'uid',
  createdAt: _at,
  updatedAt: _at,
);

const _shipped = {
  'field': OrderFields.status,
  'op': 'anyOf',
  'value': [SeedOptions.shipped],
};

void main() {
  late SeedWorkspace seed;
  late FakeDataRepository repo;
  late WorkspaceCache cache;
  late TriggerEvaluator evaluator;
  late List<CardChange> changes;
  late StreamSubscription<CardChange> sub;
  var clock = 0;

  setUp(() {
    seed = SeedWorkspace();
    repo = seed.repository();
    cache = WorkspaceCache(repo)..initialize('ws');
    evaluator = TriggerEvaluator(cache, now: () => _at);
    changes = [];
    sub = repo.changes.listen(changes.add);
  });

  tearDown(() async {
    await sub.cancel();
    await cache.reset();
  });

  MorkvaObject stored(String id) =>
      repo.objectsOf(_orders).firstWhere((o) => o.id == id);

  /// Writes [values] over order [n] (a minute later each time) and returns
  /// the change it emitted.
  Future<CardChange> update(int n, Map<String, FieldValue> values) async {
    final o = stored(SeedCards.order(n));
    final count = changes.length;
    await repo.saveObject(
      o.copyWith(
        values: {...o.values, ...values},
        updatedAt: _at.add(Duration(minutes: ++clock)),
      ),
      schema: seed.orders,
    );
    expect(changes, hasLength(count + 1), reason: 'a no-op write');
    return changes.last;
  }

  Future<TriggerOutcome> evaluate(
    CardChange change,
    AutomationRecord automation, {
    DateTime? today,
  }) => evaluator.evaluate(
    change,
    automation,
    grants: _grants,
    today: today ?? _today,
  );

  group('watches', () {
    CardChange change({
      MorkvaObject? before,
      MorkvaObject? after,
      WriteKind kind = WriteKind.ui,
    }) => CardChange(
      collectionId: _orders,
      cardId: 'b_1',
      before: before,
      after: after,
      writeId: 'w_1',
      origin: WriteOrigin(kind: kind),
    );

    test('matches the event kind to the write', () {
      final o = seed.orderCards.first;
      final created = change(after: o);
      final updated = change(before: o, after: o);
      final deleted = change(before: o);

      bool w(TriggerKind k, CardChange c) =>
          TriggerEvaluator.watches(_automation(k), c);
      expect(w(TriggerKind.cardCreated, created), isTrue);
      expect(w(TriggerKind.cardCreated, updated), isFalse);
      expect(w(TriggerKind.cardUpdated, updated), isTrue);
      expect(w(TriggerKind.cardUpdated, deleted), isFalse);
      expect(w(TriggerKind.cardDeleted, deleted), isTrue);
      expect(w(TriggerKind.cardDeleted, created), isFalse);
    });

    test('undo, template and collection-delete writes are ignored; ui, plan '
        'and automation writes are seen', () {
      final o = seed.orderCards.first;
      final a = _automation(TriggerKind.cardUpdated);
      for (final kind in WriteKind.values) {
        expect(
          TriggerEvaluator.watches(a, change(before: o, after: o, kind: kind)),
          switch (kind) {
            WriteKind.ui || WriteKind.plan || WriteKind.automation => isTrue,
            _ => isFalse,
          },
          reason: kind.name,
        );
      }
    });

    test('disabled automations, buttons and other collections are not '
        'evaluated', () {
      final o = seed.orderCards.first;
      final c = change(before: o, after: o);
      expect(
        TriggerEvaluator.watches(
          _automation(TriggerKind.cardUpdated, enabled: false),
          c,
        ),
        isFalse,
      );
      expect(
        TriggerEvaluator.watches(
          _automation(TriggerKind.cardUpdated, collectionId: 'c_clients'),
          c,
        ),
        isFalse,
      );
      final button = AutomationRecord(
        id: 'a_b',
        name: 'Button',
        enabled: true,
        moduleId: 'm',
        actionId: 'x',
        trigger: const ButtonTrigger(
          scope: ButtonScope.card,
          collectionId: _orders,
        ),
        apply: ApplyMode.ask,
        createdBy: 'uid',
        createdAt: _at,
        updatedAt: _at,
      );
      expect(TriggerEvaluator.watches(button, c), isFalse);
    });
  });

  group('card.updated', () {
    test('enters fires when the conditions become true, not while they stay '
        'true', () async {
      await update(1001, {
        OrderFields.status: _status(SeedOptions.packing),
        OrderFields.qty: const NumberFieldValue(101),
      });
      final into = await update(1001, {
        OrderFields.status: _status(SeedOptions.shipped),
      });
      final stays = await update(1001, {
        OrderFields.qty: const NumberFieldValue(7),
      });
      final a = _automation(TriggerKind.cardUpdated, where: [_shipped]);

      final fired = await evaluate(into, a);
      expect(fired, isA<TriggerFired>());
      expect(
        (fired as TriggerFired).changedFields,
        contains(OrderFields.status),
      );
      expect(fired.why, "'Status is Shipped' became true → ran");

      final again = await evaluate(stays, a);
      expect(again, isA<TriggerNotFired>());
      expect(
        again.why,
        "'Status is Shipped' was already true before the change → didn't run",
      );
    });

    test('matches fires on every matching update', () async {
      await update(1001, {OrderFields.status: _status(SeedOptions.shipped)});
      final stays = await update(1001, {
        OrderFields.qty: const NumberFieldValue(7),
      });
      final out = await evaluate(
        stays,
        _automation(
          TriggerKind.cardUpdated,
          where: [_shipped],
          mode: TriggerMode.matches,
        ),
      );
      expect(out, isA<TriggerFired>());
    });

    test('a false condition after the change does not fire', () async {
      final c = await update(1001, {
        OrderFields.status: _status(SeedOptions.done),
      });
      final out = await evaluate(
        c,
        _automation(TriggerKind.cardUpdated, where: [_shipped]),
      );
      expect(out, isA<TriggerNotFired>());
      expect(
        out.why,
        "'Status is Shipped' was false after the change → didn't run",
      );
    });

    test('the fields watch-list skips changes to other fields', () async {
      final c = await update(1002, {
        OrderFields.status: _status(SeedOptions.shipped),
      });
      final watchQty = _automation(
        TriggerKind.cardUpdated,
        fields: [OrderFields.qty],
      );
      final out = await evaluate(c, watchQty);
      expect(out, isA<TriggerNotFired>());
      expect(out.why, "Qty didn't change → didn't run");

      final q = await update(1002, {
        OrderFields.qty: const NumberFieldValue(77),
      });
      expect(await evaluate(q, watchQty), isA<TriggerFired>());
    });

    test('no conditions: fires when something changed, names it', () async {
      final c = await update(1003, {
        OrderFields.qty: const NumberFieldValue(55),
      });
      final out = await evaluate(c, _automation(TriggerKind.cardUpdated));
      expect(out, isA<TriggerFired>());
      // Total and the yes/no "Large" are calculated from Qty: they changed too.
      expect(
        (out as TriggerFired).changedFields,
        containsAll([OrderFields.qty, OrderFields.total]),
      );
      expect(out.why, startsWith('Qty'));
    });

    test(
      'a condition on a calculated field reads the derived images',
      () async {
        await update(1004, {
          OrderFields.price: const NumberFieldValue(100),
          OrderFields.qty: const NumberFieldValue(1),
        });
        final c = await update(1004, {
          OrderFields.qty: const NumberFieldValue(90),
        });
        final a = _automation(
          TriggerKind.cardUpdated,
          where: [
            {'field': OrderFields.large, 'op': 'isTrue'},
          ],
        );

        final out = await evaluate(c, a);

        expect(out, isA<TriggerFired>());
        final fired = out as TriggerFired;
        expect(
          fired.after![OrderFields.total],
          const CalculatedFieldValue(9000),
        );
        expect(
          fired.before![OrderFields.total],
          const CalculatedFieldValue(100),
        );
      },
    );

    test(
      'two quick writes to one card each evaluate their own images',
      () async {
        await update(1005, {OrderFields.status: _status(SeedOptions.packing)});
        final first = await update(1005, {
          OrderFields.status: _status(SeedOptions.shipped),
        });
        final second = await update(1005, {
          OrderFields.status: _status(SeedOptions.done),
        });
        final a = _automation(TriggerKind.cardUpdated, where: [_shipped]);

        // Both evaluated after the second write landed.
        final outs = await Future.wait([
          evaluate(first, a),
          evaluate(second, a),
        ]);

        expect(outs[0], isA<TriggerFired>());
        expect(outs[1], isA<TriggerNotFired>());
      },
    );

    test('a reference condition resolves its card in a collection the cache '
        'did not hold', () async {
      final c = await update(1006, {
        OrderFields.client: const ReferenceFieldValue([SeedCards.olena]),
      });
      expect(cache.current(SeedIds.clients), isNull);
      final out = await evaluate(
        c,
        _automation(
          TriggerKind.cardUpdated,
          where: [
            {
              'field': OrderFields.client,
              'op': 'anyOf',
              'value': [SeedCards.olena],
            },
          ],
          mode: TriggerMode.matches,
        ),
      );
      expect(out, isA<TriggerFired>());
    });

    test('a relative condition is recompiled with the run\'s day', () async {
      final c = await update(1007, {
        OrderFields.created: DateFieldValue(DateTime.utc(2026, 11, 12)),
      });
      final a = _automation(
        TriggerKind.cardUpdated,
        where: [
          {'field': OrderFields.created, 'op': 'onDay', 'relative': 'today'},
        ],
        mode: TriggerMode.matches,
      );

      expect(await evaluate(c, a), isA<TriggerFired>());
      expect(
        await evaluate(c, a, today: DateTime(2026, 11, 13)),
        isA<TriggerNotFired>(),
      );
    });
  });

  group('card.created / card.deleted', () {
    MorkvaObject newOrder(String status) => MorkvaObject.create(
      id: 'b_or_new',
      collection: seed.orders,
      values: {OrderFields.status: _status(status)},
      createdAt: _at,
      updatedAt: _at,
    );

    test('created reads the new card (with its auto-number)', () async {
      await repo.saveObject(newOrder(SeedOptions.shipped), schema: seed.orders);
      final c = changes.last;
      expect(c.after![OrderFields.no]!.isEmpty, isFalse);
      final a = _automation(TriggerKind.cardCreated, where: [_shipped]);

      final out = await evaluate(c, a);

      expect(out, isA<TriggerFired>());
      expect(
        (out as TriggerFired).after![OrderFields.no],
        c.after![OrderFields.no],
      );
    });

    test('created with a false condition does not fire', () async {
      await repo.saveObject(
        newOrder(SeedOptions.statusNew),
        schema: seed.orders,
      );
      final out = await evaluate(
        changes.last,
        _automation(TriggerKind.cardCreated, where: [_shipped]),
      );
      expect(out, isA<TriggerNotFired>());
      expect(
        out.why,
        "'Status is Shipped' was false for the new card → didn't run",
      );
    });

    test('deleted reads the card before the delete', () async {
      await update(1008, {OrderFields.status: _status(SeedOptions.shipped)});
      final before = stored(SeedCards.order(1008));
      await repo.deleteObject(_orders, before.id, before: before);
      final c = changes.last;
      expect(c.after, isNull);

      final out = await evaluate(
        c,
        _automation(TriggerKind.cardDeleted, where: [_shipped]),
      );
      expect(out, isA<TriggerFired>());
      expect(out.why, "'Status is Shipped' was true before the delete → ran");
    });
  });

  group('broken', () {
    test('a condition on a deleted field is broken', () async {
      final c = await update(1009, {
        OrderFields.qty: const NumberFieldValue(333),
      });
      final out = await evaluate(
        c,
        _automation(
          TriggerKind.cardUpdated,
          where: [
            {
              'field': 'f_gone',
              'op': 'anyOf',
              'value': ['o_x'],
            },
          ],
        ),
      );
      expect(out, isA<TriggerSkipped>());
      expect((out as TriggerSkipped).reason, RunReason.broken);
      expect(out.why, 'A condition uses a field that was deleted');
    });

    test('a deleted option is broken', () async {
      final c = await update(1009, {
        OrderFields.qty: const NumberFieldValue(444),
      });
      final out = await evaluate(
        c,
        _automation(
          TriggerKind.cardUpdated,
          where: [
            {
              'field': OrderFields.status,
              'op': 'anyOf',
              'value': ['o_removed'],
            },
          ],
        ),
      );
      expect((out as TriggerSkipped).reason, RunReason.broken);
      expect(out.why, startsWith('A condition no longer works: '));
    });

    test('a reference condition into a collection outside the grants is '
        'broken', () async {
      final c = await update(1010, {
        OrderFields.qty: const NumberFieldValue(555),
      });
      final out = await evaluator.evaluate(
        c,
        _automation(
          TriggerKind.cardUpdated,
          where: [
            {
              'field': OrderFields.client,
              'op': 'anyOf',
              'value': [SeedCards.olena],
            },
          ],
        ),
        grants: Grants(const [Capability.dataRead], collections: [_orders]),
        today: _today,
      );
      expect((out as TriggerSkipped).reason, RunReason.broken);
    });
  });

  test('a write the cache never shows is not_settled after 5 s', () {
    fakeAsync((async) {
      final repo = seed.repository();
      final cache = WorkspaceCache(repo)..initialize('ws');
      final evaluator = TriggerEvaluator(cache, now: () => _at);
      final changes = <CardChange>[];
      repo.changes.listen(changes.add);
      final o = seed.card(_orders, SeedCards.order(1011));
      repo.hiddenFromWatch.add(o.id);
      repo.saveObject(
        o.copyWith(
          values: {...o.values, OrderFields.qty: const NumberFieldValue(8)},
          updatedAt: _at,
        ),
        schema: seed.orders,
      );
      async.flushMicrotasks();
      TriggerOutcome? out;
      evaluator
          .evaluate(
            changes.single,
            _automation(TriggerKind.cardUpdated),
            grants: _grants,
            today: _today,
          )
          .then((o) => out = o);
      async.elapse(const Duration(seconds: 4));
      expect(out, isNull);
      async.elapse(const Duration(seconds: 1));

      expect((out as TriggerSkipped).reason, RunReason.notSettled);
      expect(
        evaluator.lastChecks('a_1').single.result,
        LastCheckResult.skipped,
      );
      cache.reset();
      async.flushMicrotasks();
    });
  });

  test('a collection deleted while settling is broken', () {
    fakeAsync((async) {
      final repo = seed.repository();
      final cache = WorkspaceCache(repo)..initialize('ws');
      final evaluator = TriggerEvaluator(cache, now: () => _at);
      final changes = <CardChange>[];
      repo.changes.listen(changes.add);
      final o = seed.card(_orders, SeedCards.order(1013));
      repo.hiddenFromWatch.add(o.id);
      repo.saveObject(
        o.copyWith(
          values: {...o.values, OrderFields.qty: const NumberFieldValue(8)},
          updatedAt: _at,
        ),
        schema: seed.orders,
      );
      async.flushMicrotasks();
      TriggerOutcome? out;
      evaluator
          .evaluate(
            changes.single,
            _automation(TriggerKind.cardUpdated),
            grants: _grants,
            today: _today,
          )
          .then((o) => out = o);
      async.elapse(const Duration(seconds: 1));
      repo.deleteCollection(_orders);
      async.flushMicrotasks();

      expect((out as TriggerSkipped).reason, RunReason.broken);
      expect(out!.why, 'The collection it watches was deleted');
      cache.reset();
      async.flushMicrotasks();
    });
  });

  group('last checks', () {
    test(
      'every evaluation is noted, newest first, with the card label',
      () async {
        final c = await update(1012, {
          OrderFields.status: _status(SeedOptions.done),
        });
        await evaluate(
          c,
          _automation(TriggerKind.cardUpdated, where: [_shipped]),
        );
        await evaluate(c, _automation(TriggerKind.cardUpdated));

        final checks = evaluator.lastChecks('a_1');
        expect(checks.map((c) => c.result), [
          LastCheckResult.ran,
          LastCheckResult.notRun,
        ]);
        final label = objectLabels(seed.orders, [c.after!])[c.cardId];
        expect(checks.first.cardLabel, label);
        expect(checks.first.at, _at);
      },
    );

    test('the ring keeps 20; limit trims; forget and reset drop', () {
      for (var i = 0; i < 25; i++) {
        evaluator.record(
          'a_1',
          LastCheck(
            cardLabel: '#$i',
            at: _at,
            result: LastCheckResult.notRun,
            why: 'w',
          ),
        );
      }
      final checks = evaluator.lastChecks('a_1');
      expect(checks, hasLength(20));
      expect(checks.first.cardLabel, '#24');
      expect(checks.last.cardLabel, '#5');
      expect(evaluator.lastChecks('a_1', limit: 5), hasLength(5));

      evaluator.forget('a_1');
      expect(evaluator.lastChecks('a_1'), isEmpty);
      evaluator.record(
        'a_2',
        LastCheck(
          cardLabel: 'x',
          at: _at,
          result: LastCheckResult.ran,
          why: 'w',
        ),
      );
      evaluator.reset();
      expect(evaluator.lastChecks('a_2'), isEmpty);
    });
  });
}
