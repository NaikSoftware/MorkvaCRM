import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/features/automation/bloc/automation_editor_cubit.dart';
import 'package:morkva_crm/features/automation/bloc/modules_cubit.dart';

import 'automation_fixtures.dart';

void main() {
  late FakeRunner runner;
  late ModuleRecord module;

  setUp(() {
    runner = FakeRunner();
    module = stampModule();
  });

  tearDown(() => runner.dispose());

  List<ModuleEntry> entries({GrantRecord? consent, ModuleRecord? record}) => [
    ModuleEntry(
      module: record ?? module,
      consent: consent ?? consentTo(record ?? module),
      automations: 0,
    ),
  ];

  AutomationEditorCubit build({
    List<ModuleEntry>? modules,
    AutomationRecord? existing,
    EditorKind kind = EditorKind.cardButton,
    String? moduleId = stampId,
    String? actionId = 'stamp',
  }) => AutomationEditorCubit(
    runner,
    uid: uid,
    modules: modules ?? entries(),
    collections: [orders, clients],
    existing: existing,
    collectionId: 'c_orders',
    moduleId: moduleId,
    actionId: actionId,
    kind: kind,
    now: () => fixtureNow,
    newId: () => 'a_new',
  );

  blocTest<AutomationEditorCubit, AutomationEditorState>(
    'a new card button: name and label follow the action, defaults filled',
    build: build,
    verify: (cubit) {
      final s = cubit.state;
      expect(s.name, 'Stamp shipped date on Orders');
      expect(s.defaultLabel, 'Stamp shipped date');
      expect(s.params, {'overwrite': false, 'days': 1, 'mode': 'today'});
      expect(s.icon, 'truck');
    },
  );

  test(
    'an edited name sticks; the default follows the collection until then',
    () {
      final cubit = build();
      cubit.setCollection('c_clients');
      expect(cubit.state.name, 'Stamp shipped date on Clients');
      cubit.setName('Ship it');
      cubit.setCollection('c_orders');
      expect(cubit.state.name, 'Ship it');
    },
  );

  test('button labels are cut to 24 with an ellipsis', () {
    expect(buttonLabelOf('Short'), 'Short');
    final cut = buttonLabelOf('Stamp the shipped date on every order');
    expect(cut.length, ButtonSpec.kMaxLabel);
    expect(cut, endsWith('…'));
  });

  test('switching kinds keeps only what still fits', () {
    final cubit = build(kind: EditorKind.updated);
    cubit.addCondition(
      const ViewFilter(fieldId: 'f_title', op: FilterOp.contains, operand: 'x'),
    );
    cubit.setFields(['f_title']);
    cubit.setKind(EditorKind.cardButton);
    expect(cubit.state.where, isEmpty);
    expect(cubit.state.fields, isEmpty);
    expect(cubit.state.actionId, 'stamp');
    // A card action can't sit on a collection button.
    cubit.setKind(EditorKind.collectionButton);
    expect(cubit.state.actionId, isNull);
    expect(cubit.state.params, isEmpty);
  });

  group('conditions', () {
    test('FilterBuilder filters convert both ways', () {
      const filter = ViewFilter(
        fieldId: 'f_status',
        op: FilterOp.anyOf,
        operand: ['o_shipped'],
      );
      expect(conditionOf(filter), {
        'field': 'f_status',
        'op': 'anyOf',
        'value': ['o_shipped'],
      });
      expect(filterOf(conditionOf(filter)), filter);
      expect(
        conditionOf(const ViewFilter(fieldId: 'f_x', op: FilterOp.isEmpty)),
        {'field': 'f_x', 'op': 'isEmpty'},
      );
      // Relative conditions are read-only chips.
      expect(
        filterOf({'field': 'f_due', 'op': 'onDay', 'relative': 'today'}),
        isNull,
      );
      expect(filterOf({'field': 'f_due', 'op': 'nope'}), isNull);
    });

    test('a relative condition saves back untouched', () async {
      final existing = automation();
      final cubit = build(existing: existing);
      expect(cubit.state.kind, EditorKind.updated);
      cubit.removeCondition(0);
      expect(await cubit.save(), isTrue);
      final saved = runner.calls.last.$2.single! as AutomationRecord;
      final trigger = saved.trigger as EventTrigger;
      expect(trigger.where, [
        {'field': 'f_due', 'op': 'onDay', 'relative': 'today'},
      ]);
      expect(trigger.fields, ['f_status']);
      expect(saved.id, 'a_1');
      expect(saved.createdAt, existing.createdAt);
    });
  });

  group('Auto', () {
    test('needs the module\'s auto-apply first', () async {
      final cubit = build();
      expect(cubit.state.autoAvailability, AutoAvailability.turnOnFirst);
      cubit.setApply(ApplyMode.auto);
      expect(await cubit.save(), isFalse);
      expect(
        cubit.state.problemAt('apply'),
        'Turn on auto-apply for this module first',
      );
      expect(runner.calls, isEmpty);
    });

    test('offered with the consent on; saves autoBy', () async {
      final cubit = build(
        modules: entries(consent: consentTo(module, autoApply: true)),
      );
      expect(cubit.state.autoAvailability, AutoAvailability.available);
      cubit.setParam('dateField', 'f_shipped');
      cubit.setApply(ApplyMode.auto);
      expect(await cubit.save(), isTrue);
      final saved = runner.calls.single.$2.single! as AutomationRecord;
      expect(saved.apply, ApplyMode.auto);
      expect(saved.autoBy, uid);
    });

    test('a module that can delete always asks', () {
      final deleter = stampModule(
        bundle: stampBundle(caps: ['data:read', 'data:write', 'data:delete']),
      );
      final cubit = build(
        modules: entries(
          record: deleter,
          consent: consentTo(deleter, autoApply: true),
        ),
      );
      expect(cubit.state.autoAvailability, AutoAvailability.alwaysAsks);
    });
  });

  test('collections outside the consent are refused', () async {
    final cubit = build();
    expect(cubit.state.collectionAllowed('c_orders'), isTrue);
    expect(cubit.state.collectionAllowed('c_clients'), isFalse);
    expect(cubit.state.scopeChoices, [orders]);
    cubit.setCollection('c_clients');
    cubit.setParam('dateField', 'f_name');
    expect(await cubit.save(), isFalse);
    expect(
      cubit.state.problemAt('collectionId'),
      'The module isn\'t allowed in Clients',
    );
  });

  test(
    'form checks: name, action, required input, updated needs a condition',
    () async {
      final cubit = build(kind: EditorKind.updated, actionId: null);
      cubit.setName('  ');
      expect(await cubit.save(), isFalse);
      expect(cubit.state.problemAt('name'), 'Give it a name');
      expect(cubit.state.problemAt('actionId'), 'Pick an action');
      expect(
        cubit.state.problemAt('where'),
        'Add at least one condition or pick fields to watch',
      );

      cubit.setName('Stamp');
      cubit.setAction('stamp');
      cubit.setAnyChange(true);
      expect(await cubit.save(), isFalse);
      expect(cubit.state.problems.single.message, 'Fill in Date field');

      cubit.setParam('dateField', 'f_shipped');
      expect(await cubit.save(), isTrue);
      final saved = runner.calls.single.$2.single! as AutomationRecord;
      expect(saved.trigger, isA<EventTrigger>());
      expect((saved.trigger as EventTrigger).fields, isNull);
      expect(saved.button, isNull);
      expect(cubit.state.saved, isTrue);
    },
  );

  test('a collection action asks for a collection button', () async {
    final collectionAction = stampModule(
      bundle: ModuleBundle.of({
        ...stampManifest(),
        'actions': [
          {'id': 'flag', 'label': 'Flag low stock', 'scope': 'collection'},
        ],
      }, 'x()'),
    );
    final cubit = build(
      modules: entries(record: collectionAction),
      actionId: null,
    );
    cubit.setAction('flag');
    expect(await cubit.save(), isFalse);
    expect(
      cubit.state.problemAt('actionId'),
      'This action runs on a collection — use a collection button',
    );
  });

  test('a new card button saves with the default label', () async {
    final cubit = build();
    cubit.setParam('dateField', 'f_shipped');
    cubit.setTint('leaf');
    expect(await cubit.save(), isTrue);
    final saved = runner.calls.single.$2.single! as AutomationRecord;
    expect(saved.id, 'a_new');
    expect(
      saved.trigger,
      const ButtonTrigger(scope: ButtonScope.card, collectionId: 'c_orders'),
    );
    expect(
      saved.button,
      const ButtonSpec(
        label: 'Stamp shipped date',
        icon: 'truck',
        tint: 'leaf',
      ),
    );
    expect(saved.apply, ApplyMode.ask);
    expect(saved.autoBy, isNull);
    expect(saved.createdBy, 'user:$uid');
  });

  test('the runner\'s save-time problems show inline', () async {
    runner.problems = const [
      AutomationProblem(
        'trigger.where[0]',
        'not_permitted',
        'This condition reads Clients, which the module isn\'t allowed in.',
      ),
    ];
    final cubit = build();
    cubit.setParam('dateField', 'f_shipped');
    expect(await cubit.save(), isFalse);
    expect(cubit.state.saving, isFalse);
    expect(
      cubit.state.problemAt('trigger.where[0]'),
      contains('which the module isn\'t allowed in'),
    );
  });

  test(
    'saving a broken automation clears the pause; a loop pause stays',
    () async {
      final broken = automation(paused: PausedReason.broken);
      var cubit = build(existing: broken);
      await cubit.save();
      expect(
        (runner.calls.last.$2.single! as AutomationRecord).pausedReason,
        isNull,
      );
      cubit = build(existing: automation(paused: PausedReason.loopSuspected));
      await cubit.save();
      expect(
        (runner.calls.last.$2.single! as AutomationRecord).pausedReason,
        PausedReason.loopSuspected,
      );
    },
  );

  test('an existing event automation shows its last check', () {
    final check = LastCheck(
      cardLabel: '#1042',
      at: fixtureNow,
      result: LastCheckResult.notRun,
      why: '\'Status is Shipped\' was false after the change',
    );
    runner.lastChecksBy['a_1'] = [check];
    expect(build(existing: automation()).state.lastCheck, check);
  });

  test('delete and resume go to the runner', () async {
    final cubit = build(existing: automation());
    expect(await cubit.resume(), isTrue);
    expect(await cubit.delete(), isTrue);
    expect(runner.methods, ['resume', 'deleteAutomation']);
    expect(await build().delete(), isFalse);
  });
}
