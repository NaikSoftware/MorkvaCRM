import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/harness/plan/plan.dart';

import 'module_fixture.dart';

void main() {
  late ModuleHarness m;

  setUp(() => m = ModuleHarness());
  tearDown(() => m.dispose());

  Future<void> saveModule() => m.p.ok('modules.save', {
    'manifest': stampManifest(),
    'code': moduleCode,
    'collections': 'all',
  });

  test('undo is none for module items alone, partial when mixed', () async {
    await saveModule();
    expect((await m.p.sealPlan()).undo, UndoSupport.none);

    m.p.newTurn();
    await saveModule();
    await m.p.ok('cards.update', {
      'collection': 'Orders',
      'target': {
        'ids': [SeedCards.order(1001)],
      },
      'set': {'Qty': 7},
    });
    expect((await m.p.sealPlan()).undo, UndoSupport.partial);
  });

  test(
    'extend moves a sealed plan\'s expiry; unknown or expired: no-op',
    () async {
      await saveModule();
      final plan = await m.p.sealPlan();
      m.p.store.extend(plan.planId, const Duration(hours: 8), now: now);
      final extended = m.p.store.get(plan.planId)!;
      expect(extended.expiresAt, now.add(const Duration(hours: 8)));
      expect(extended.items, plan.items);
      expect(extended.risk, plan.risk);

      final late = now.add(const Duration(hours: 9));
      m.p.store.extend(plan.planId, const Duration(hours: 8), now: late);
      expect(m.p.store.get(plan.planId)!.expiresAt, extended.expiresAt);
      m.p.store.extend('p_unknown', const Duration(hours: 8), now: now);
      expect(m.p.store.get('p_unknown'), isNull);
    },
  );

  test('module and automation kinds are unscoped and need their caps', () {
    expect(PlanItemKind.saveModule.scoped, isFalse);
    expect(PlanItemKind.saveAutomation.scoped, isFalse);
    expect(PlanItemKind.deleteAutomation.scoped, isFalse);
    expect(PlanItemKind.updateCard.scoped, isTrue);
    expect(PlanItemKind.saveModule.capability.wire, 'modules:write');
    expect(PlanItemKind.deleteAutomation.capability.wire, 'automations:write');
  });
}
