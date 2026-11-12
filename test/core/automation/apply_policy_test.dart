import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/automation/apply_policy.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/core/harness/api/capability.dart';
import 'package:morkva_crm/core/harness/plan/plan.dart';

import '../domain/automation/fixtures.dart';

const _code = '(() => { morkva.action("stamp", async () => "ok"); })();';
const _orders = 'c_orders';

final _module = ModuleRecord.fromBundle(
  ModuleBundle.of(stampManifest(), _code),
  source: ModuleSource.import,
  createdBy: 'user:u1',
  now: fixtureNow,
);

GrantRecord _consent({
  bool autoApply = true,
  String? codeHash,
  List<String>? collections = const [_orders],
}) => GrantRecord(
  moduleId: _module.id,
  codeHash: codeHash ?? _module.bundleHash,
  version: _module.version,
  codeBytes: _module.codeBytes,
  caps: const ['schema:read', 'data:read', 'data:write'],
  collections: collections,
  autoApply: autoApply,
  grantedAt: fixtureNow,
  via: GrantVia.consentSheet,
);

final _auto = automation(apply: ApplyMode.auto, autoBy: 'u1');

UpdateCardItem _update(
  int i, {
  Risk risk = Risk.low,
  Object? before = 'a',
  Object? after = 'b',
  String collectionId = _orders,
}) => UpdateCardItem(
  itemId: 'i$i',
  callId: 'm.1',
  collectionId: collectionId,
  targetId: 'b_$i',
  label: '#$i',
  risk: risk,
  changes: [
    FieldChange(fieldId: 'f_item', field: 'Item', before: before, after: after),
  ],
);

Plan _plan(List<PlanItem> items) => Plan(
  planId: 'p_1',
  turnId: 't_1',
  title: 'Stamp',
  createdBy: PlanCreator(
    Actor.plugin(_module.id),
    Grants(const [Capability.dataWrite]),
  ),
  items: items,
  createdAt: fixtureNow,
  expiresAt: fixtureNow.add(const Duration(minutes: 15)),
);

void main() {
  const policy = ApplyPolicy();
  var budget = <int>[];

  ApplyDecision decide({
    AutomationRecord? automation,
    String uid = 'u1',
    ModuleRecord? module,
    GrantRecord? consent,
    bool noConsent = false,
    String? codeHash,
    Plan? plan,
    bool budgetLeft = true,
  }) => policy.decide(
    automation: automation ?? _auto,
    uid: uid,
    module: module ?? _module,
    consent: noConsent ? null : consent ?? _consent(),
    codeHash: codeHash ?? _module.bundleHash,
    plan: plan ?? _plan([_update(1)]),
    takeBudget: (n) {
      budget.add(n);
      return budgetLeft;
    },
  );

  String? why(ApplyDecision d) => switch (d) {
    ApplyReview(:final why) => why,
    ApplyAuto() => null,
  };

  setUp(() => budget = []);

  test('a small, low-risk plan of an auto automation applies and spends '
      'the budget', () {
    expect(decide(plan: _plan([_update(1), _update(2)])), isA<ApplyAuto>());
    expect(budget, [2]);
  });

  test('every failing check falls back to review and says which', () {
    expect(
      why(decide(automation: automation())),
      'review: the automation asks first',
    );
    expect(
      why(decide(uid: 'u2')),
      'review: auto-apply was set by another member',
    );
    expect(why(decide(consent: _consent(autoApply: false))), contains('off'));
    expect(why(decide(noConsent: true)), contains('permissions changed'));
    // The consent pins another bundle (the module changed under it).
    expect(
      why(decide(consent: _consent(codeHash: 'sha256:other'))),
      contains('permissions changed'),
    );
    // The run loaded other code than the live module's.
    expect(
      why(decide(codeHash: 'sha256:forged')),
      contains('permissions changed'),
    );
    final deleted = DeleteCardItem(
      itemId: 'i9',
      callId: 'm.1',
      collectionId: _orders,
      targetId: 'b_9',
      label: '#9',
      risk: Risk.low,
      before: MorkvaObject(
        id: 'b_9',
        collectionId: _orders,
        values: const {},
        createdAt: fixtureNow,
        updatedAt: fixtureNow,
      ),
    );
    expect(
      why(decide(plan: _plan([_update(1), deleted]))),
      'review: deleteCard always needs review',
    );
    expect(
      why(decide(plan: _plan([_update(1, risk: Risk.medium)]))),
      'review: a change is not low risk',
    );
    expect(
      why(decide(plan: _plan([for (var i = 0; i < 21; i++) _update(i)]))),
      'review: 21 items > 20',
    );
    expect(
      why(decide(plan: _plan([_update(1, after: null)]))),
      'review: it would clear Item',
    );
    expect(
      why(decide(plan: _plan([_update(1, collectionId: 'c_clients')]))),
      'review: a change is outside its permissions',
    );
    expect(budget, isEmpty, reason: 'the budget is asked last');
    expect(
      why(decide(budgetLeft: false)),
      'review: auto-apply paused for 10 min — too many changes',
    );
  });

  test('20 items still auto-apply; an empty value written into an empty '
      'field is not a blank', () {
    expect(
      decide(plan: _plan([for (var i = 0; i < 20; i++) _update(i)])),
      isA<ApplyAuto>(),
    );
    expect(
      decide(plan: _plan([_update(1, before: null, after: null)])),
      isA<ApplyAuto>(),
    );
  });
}
