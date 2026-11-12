import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';
import 'package:morkva_crm/core/harness/automation_validation.dart';
import 'package:morkva_crm/core/harness/harness.dart';
import 'package:morkva_crm/core/harness/input/ref_resolver.dart';
import 'package:morkva_crm/core/harness/plan/plan.dart';

import 'module_fixture.dart';

void main() {
  late ModuleHarness m;

  setUp(() => m = ModuleHarness());
  tearDown(() => m.dispose());

  Map<String, Object?> save({
    Map<String, Object?>? trigger,
    Map<String, Object?> params = const {'dateField': 'Delivery slot'},
    String? apply,
    String actionId = 'stamp',
    String moduleId = 'stamp-shipped-date',
    Map<String, Object?>? button,
    String? id,
  }) => {
    'id': ?id,
    'name': 'Stamp when shipped',
    'moduleId': moduleId,
    'actionId': actionId,
    'trigger':
        trigger ??
        {
          'kind': 'card.updated',
          'collection': 'Orders',
          'where': [
            {'field': 'Status', 'op': 'equals', 'value': 'Shipped'},
            {'field': 'Created', 'op': 'onDay', 'relative': 'today'},
          ],
          'fields': ['Status'],
        },
    'params': params,
    'apply': ?apply,
    'button': ?button,
  };

  Future<SaveAutomationItem> planned(Map<String, Object?> args) async {
    await m.p.ok('automations.save', args);
    return (await m.p.sealPlan()).items.single as SaveAutomationItem;
  }

  test(
    'normalizes refs to ids and keeps relative conditions relative',
    () async {
      await m.install();
      final item = await planned(save());
      final trigger = item.draft.trigger as EventTrigger;

      expect(trigger.collectionId, SeedIds.orders);
      expect(trigger.where, [
        {
          'field': OrderFields.status,
          'op': 'anyOf',
          'value': [SeedOptions.shipped],
        },
        {'field': OrderFields.created, 'op': 'onDay', 'relative': 'today'},
      ]);
      expect(trigger.fields, [OrderFields.status]);
      expect(trigger.mode, TriggerMode.enters);
      expect(item.draft.params, {'dateField': OrderFields.delivery});
      expect(item.apply, ApplyMode.ask);
      expect(item.risk, Risk.low);
      expect(item.collectionId, SeedIds.orders);
      expect(item.kind.scoped, isFalse);
      expect(item.draft.id, startsWith('au_'));
      expect(item.changes.first.field, 'When a card is updated in Orders');
      expect(
        item.changes.first.afterText,
        'Status any of [“Shipped”] and Created onDay today (starts matching) '
        '→ Stamp shipped date',
      );

      // The stored form compiles again (what the evaluator and revalidation
      // do), on another day too.
      final problems = validateAutomation(
        item.recordFor('u1', now),
        module: await m.catalog.getModule('stamp-shipped-date'),
        consent: await m.catalog.liveConsent('stamp-shipped-date'),
        workspace: StaticWorkspace(m.p.resolved),
        today: today.add(const Duration(days: 40)),
      );
      expect(problems, isEmpty);
    },
  );

  test(
    'the full plan JSON is plain and carries apply at the item top',
    () async {
      await m.install();
      await m.p.ok('automations.save', save());
      final compact = await m.p.seal();
      expect(((compact['items']! as List).single as Map)['apply'], 'ask');
      final full = await m.p.ok('plans.get', {'planId': compact['planId']});
      final item = (full['items']! as List).single as Map;
      expect(item['apply'], 'ask');
      expect((item['automation']! as Map)['createdAt'], isA<String>());
    },
  );

  test(
    'a module saved in the same turn: the automation depends on it',
    () async {
      await m.p.ok('modules.save', {
        'manifest': stampManifest(),
        'code': moduleCode,
        'collections': ['Orders'],
      });
      await m.p.ok('automations.save', save());
      final plan = await m.p.sealPlan();
      final [module, automation] = plan.items;
      expect(module, isA<SaveModuleItem>());
      expect((automation as SaveAutomationItem).dependsOn, [module.itemId]);
    },
  );

  test('apply auto needs the consent\'s auto-apply', () async {
    await m.install();
    final e = await m.p.error('automations.save', save(apply: 'auto'));
    expect(e.code, ErrorCode.invalidArgs);
    expect(e.path, 'apply');
  });

  test(
    'apply auto with auto-apply consent: shown, stamped by approver',
    () async {
      await m.install(autoApply: true);
      final item = await planned(save(apply: 'auto'));
      expect(item.apply, ApplyMode.auto);
      expect(item.risk, Risk.medium);
      expect(
        item.changes.map((c) => c.field),
        contains('Applies changes without asking'),
      );
      final record = item.recordFor('u1', now);
      expect(record.apply, ApplyMode.auto);
      expect(record.autoBy, 'u1');
      expect(item.draft.apply, ApplyMode.ask);
    },
  );

  test('the trigger collection must be inside the consent', () async {
    await m.install();
    final e = await m.p.error(
      'automations.save',
      save(
        trigger: {'kind': 'card.created', 'collection': 'Clients'},
        params: const {'dateField': 'Client since'},
      ),
    );
    expect(e.code, ErrorCode.notPermitted);
    expect(e.path, 'trigger.collection');
  });

  test('a condition reading an unconsented collection is refused', () async {
    await m.install();
    final e = await m.p.error(
      'automations.save',
      save(
        trigger: {
          'kind': 'card.created',
          'collection': 'Orders',
          'where': [
            {'field': 'Client', 'op': 'anyOf', 'value': SeedCards.olena},
          ],
        },
      ),
    );
    expect(e.code, ErrorCode.notPermitted);
    expect(
      e.message,
      'This condition reads Clients, which the module isn\'t allowed in.',
    );
  });

  test('field params must name a field of the trigger collection', () async {
    await m.install();
    final e = await m.p.error(
      'automations.save',
      save(params: const {'dateField': 'Nope'}),
    );
    expect(e.code, ErrorCode.unknownField);
    expect(e.path, 'params.dateField');
  });

  test('params are checked against the action input', () async {
    await m.install();
    final e = await m.p.error(
      'automations.save',
      save(params: const {'dateField': 'Created', 'days': 99}),
    );
    expect(e.code, ErrorCode.invalidArgs);
    expect(e.path, 'params.days');
  });

  test('a card action cannot sit on a collection button', () async {
    await m.install();
    final e = await m.p.error(
      'automations.save',
      save(
        trigger: {
          'kind': 'button',
          'scope': 'collection',
          'collection': 'Orders',
        },
      ),
    );
    expect(e.code, ErrorCode.invalidArgs);
    expect(e.path, 'actionId');
  });

  test('a card button defaults its label to the action, cut to 24', () async {
    await m.install();
    final item = await planned(
      save(trigger: {'kind': 'button', 'collection': 'Orders'}),
    );
    expect(item.draft.trigger, isA<ButtonTrigger>());
    expect(item.draft.button!.label, 'Stamp shipped date');
    expect(item.draft.button!.icon, 'truck');
  });

  test('a button label over 24 characters is cut', () async {
    await m.install();
    final item = await planned(
      save(
        trigger: {'kind': 'button', 'collection': 'Orders'},
        button: {'label': 'Stamp the shipped date on this order'},
      ),
    );
    expect(item.draft.button!.label, hasLength(ButtonSpec.kMaxLabel));
  });

  Map<String, Object?> onCreated(Object value) => {
    'kind': 'card.created',
    'collection': 'Orders',
    'where': [
      {'field': 'Created', 'op': 'onDay', 'value': value},
    ],
  };

  test('a day word is stored relative, never frozen to a date', () async {
    await m.install();
    for (final word in ['tomorrow', '+3d']) {
      final item = await planned(save(trigger: onCreated(word)));
      expect((item.draft.trigger as EventTrigger).where.single, {
        'field': OrderFields.created,
        'op': 'onDay',
        'value': word,
      });
      m.p.newTurn();
    }
    final fixed = await planned(save(trigger: onCreated('2026-12-01')));
    expect(
      (fixed.draft.trigger as EventTrigger).where.single['value'],
      '2026-12-01',
    );
  });

  test('an update keeps a loop pause but clears broken', () async {
    await m.install();
    final stored = (await planned(save())).recordFor('u1', now);
    await m.fakes.automations.save(
      stored.withPause(PausedReason.loopSuspected, now: now),
    );
    m.p.newTurn();
    final kept = await planned(
      save(id: stored.id, params: const {'dateField': 'Created'}),
    );
    expect(kept.draft.pausedReason, PausedReason.loopSuspected);

    await m.fakes.automations.save(
      stored.withPause(PausedReason.broken, detail: 'gone', now: now),
    );
    m.p.newTurn();
    // Saving a broken one as it is revalidates it (not no_change).
    final fixed = await planned(save(id: stored.id));
    expect(fixed.draft.pausedReason, isNull);
    expect(fixed.draft.brokenDetail, isNull);
  });

  test('timestamps are not offered in conditions', () async {
    await m.install();
    final e = await m.p.error(
      'automations.save',
      save(
        trigger: {
          'kind': 'card.updated',
          'collection': 'Orders',
          'where': [
            {'field': '@updatedAt', 'op': 'onDay', 'relative': 'today'},
          ],
        },
      ),
    );
    expect(e.code, ErrorCode.invalidFilter);
  });

  test('an unknown module lists the installed ones', () async {
    await m.install();
    final e = await m.p.error('automations.save', save(moduleId: 'nope'));
    expect(e.code, ErrorCode.unknownObject);
    expect(e.candidates, ['stamp-shipped-date']);
  });

  test('saving an automation as it is is no_change', () async {
    await m.install();
    final item = await planned(save());
    await m.fakes.automations.save(item.recordFor('u1', now));
    m.p.newTurn();
    final e = await m.p.error('automations.save', save(id: item.draft.id));
    expect(e.code, ErrorCode.noChange);
  });

  test('an update keeps the id and records the before', () async {
    await m.install();
    final first = await planned(save());
    final stored = first.recordFor('u1', now);
    await m.fakes.automations.save(stored);
    m.p.newTurn();
    final item = await planned(
      save(id: stored.id, params: const {'dateField': 'Created'}),
    );
    expect(item.draft.id, stored.id);
    expect(item.before, stored);
    expect(item.draft.createdAt, stored.createdAt);
  });

  group('automations.delete', () {
    test('plans one deleteAutomation item', () async {
      await m.install();
      final stored = (await planned(save())).recordFor('u1', now);
      await m.fakes.automations.save(stored);
      m.p.newTurn();
      await m.p.ok('automations.delete', {'id': stored.id});
      final plan = await m.p.sealPlan();
      final item = plan.items.single as DeleteAutomationItem;
      expect(item.before, stored);
      expect(item.collectionId, SeedIds.orders);
      expect(plan.title, 'Delete automation “Stamp when shipped”');
      expect(plan.undo, UndoSupport.none);
    });

    test('an unknown automation is unknown_object', () async {
      final e = await m.p.error('automations.delete', {'id': 'au_nope'});
      expect(e.code, ErrorCode.unknownObject);
    });
  });

  test('revalidation flags a condition on a deleted field', () {
    final module = ModuleRecord.fromBundle(
      ModuleBundle.of(stampManifest(), moduleCode),
      source: ModuleSource.import,
      createdBy: 'user:u1',
      now: now,
    );
    final orders = m.p.collection(SeedIds.orders);
    final withoutStatus = orders.copyWith(
      fields: [
        for (final f in orders.fields)
          if (f.id != OrderFields.status) f,
      ],
    );
    final record = AutomationRecord(
      id: 'au_1',
      name: 'Stamp',
      enabled: true,
      moduleId: module.id,
      actionId: 'stamp',
      params: const {'dateField': OrderFields.created},
      trigger: const EventTrigger(
        kind: TriggerKind.cardUpdated,
        collectionId: SeedIds.orders,
        where: [
          {
            'field': OrderFields.status,
            'op': 'anyOf',
            'value': [SeedOptions.shipped],
          },
        ],
      ),
      apply: ApplyMode.ask,
      createdBy: 'user:u1',
      createdAt: now,
      updatedAt: now,
    );
    final problems = validateAutomation(
      record,
      module: module,
      consent: null,
      workspace: StaticWorkspace([withoutStatus]),
      today: today,
    );
    expect(problems.single.code, ErrorCode.unknownField.wire);
    expect(problems.single.path, 'trigger.where[0].field');
  });
}
