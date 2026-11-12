import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/view/view_definition.dart';
import 'package:morkva_crm/features/assistant/bloc/assistant_focus.dart';
import 'package:morkva_crm/features/assistant/bloc/assistant_state.dart';
import 'package:morkva_crm/features/assistant/bloc/chat_item.dart';

void main() {
  group('AssistantFocus', () {
    final unpaid = AssistantFocus(
      page: FocusPage.collection,
      collectionId: 'c_orders',
      collectionName: 'Orders',
      viewId: 'v_unpaid',
      viewName: 'Unpaid',
      mode: 'table',
      filters: const [
        ViewFilter(fieldId: 'f_paid', op: FilterOp.isFalse),
        ViewFilter(fieldId: 'f_status', op: FilterOp.anyOf, operand: ['o_p']),
      ],
      search: 'melnyk',
      sort: const ViewSort(fieldId: 'f_total', ascending: false),
      visibleFieldIds: const ['f_no', 'f_client', 'f_total'],
      shownCount: 80,
      shownIds: [for (var i = 0; i < 80; i++) 'o_$i'],
      selectedIds: const ['o_3'],
    );

    test('writes the ScreenContext JSON with at most 50 shown ids', () {
      final json = unpaid.toScreenContextJson();

      expect(json, {
        'page': 'collection',
        'collectionId': 'c_orders',
        'viewId': 'v_unpaid',
        'viewName': 'Unpaid',
        'mode': 'table',
        'filters': [
          {'fieldId': 'f_paid', 'op': 'isFalse'},
          {
            'fieldId': 'f_status',
            'op': 'anyOf',
            'operand': ['o_p'],
          },
        ],
        'search': 'melnyk',
        'sort': {'fieldId': 'f_total', 'ascending': false},
        'visibleFieldIds': ['f_no', 'f_client', 'f_total'],
        'shownCount': 80,
        'shownIds': [for (var i = 0; i < 50; i++) 'o_$i'],
        'selectedIds': ['o_3'],
      });
    });

    test('leaves out what is not on screen', () {
      expect(const AssistantFocus(page: FocusPage.home).toScreenContextJson(), {
        'page': 'home',
        'filters': <Object?>[],
        'visibleFieldIds': <Object?>[],
        'shownIds': <Object?>[],
        'selectedIds': <Object?>[],
      });
    });

    test('labels the chip with the view and count, or the open card', () {
      expect(unpaid.label, 'Looking at: Orders › Unpaid · 80 shown');
      expect(
        const AssistantFocus(
          page: FocusPage.collection,
          collectionName: 'Orders',
        ).label,
        'Looking at: Orders',
      );
      expect(
        const AssistantFocus(
          page: FocusPage.card,
          collectionName: 'Orders',
          openCardId: 'o_1042',
          openCardTitle: '#1042',
        ).label,
        'Looking at: #1042',
      );
      expect(const AssistantFocus(page: FocusPage.settings).label, isNull);
    });
  });

  group('PlanView', () {
    Map<String, Object?> item(String id, String kind, String risk) => {
      'itemId': id,
      'callId': 'r2.1',
      'kind': kind,
      'collectionId': 'c_orders',
      'targetId': 'o_$id',
      'label': '#$id',
      'risk': risk,
      'changes': [
        {
          'fieldId': 'f_st',
          'field': 'Status',
          'before': 'o_pack',
          'after': 'o_ship',
          'beforeText': 'Packing',
          'afterText': 'Shipped',
        },
      ],
    };

    test('parses the harness plan shape', () {
      final plan = PlanView.fromJson({
        'planId': 'p_1',
        'title': 'Set Status to Shipped · 3 orders',
        'risk': 'low',
        'createdBy': {
          'actor': 'agent:assistant',
          'grants': {
            'caps': ['data:read', 'data:write'],
            'collections': null,
          },
        },
        'items': [item('i1', 'updateCard', 'low')],
        'sharedChange': {
          'field': 'Status',
          'beforeText': 'Packing',
          'afterText': 'Shipped',
        },
        'itemCount': 3,
        'warnings': [
          {
            'code': 'breaks_references',
            'message': '2 Deliveries link to these',
          },
        ],
        'notes': ['#1012 is already Shipped — skipped'],
        'undo': 'full',
        'expiresAt': '2026-11-10T12:15:00Z',
      });

      expect(plan.rows.single.changes.single.afterText, 'Shipped');
      expect(plan.sharedChange!.beforeText, 'Packing');
      expect(plan.itemCount, 3);
      expect(plan.isComplete, isFalse, reason: 'a compact plan has 1 of 3');
      expect(plan.warnings.single.message, '2 Deliveries link to these');
      expect(plan.expiresAt, DateTime.utc(2026, 11, 10, 12, 15));
      expect(PlanView.fromJson(plan.toJson()), plan);
    });

    test('an item without its own risk takes the plan risk', () {
      final plan = PlanView.fromJson({
        'planId': 'p',
        'risk': 'high',
        'items': [
          {'itemId': 'i1', 'kind': 'deleteCard', 'label': '#1'},
        ],
      });

      expect(plan.rows.single.risk, PlanRisk.high);
      expect(plan.destructive, isTrue);
    });

    test('in a mixed plan only low-risk groups start ticked', () {
      final plan = PlanView.fromJson({
        'planId': 'p',
        'risk': 'high',
        'items': [
          item('i1', 'updateCard', 'low'),
          item('i2', 'deleteCard', 'medium'),
          item('i3', 'updateCard', 'low'),
          item('i4', 'deleteCard', 'medium'),
        ],
      });

      expect(plan.groups.map((g) => g.kind), ['updateCard', 'deleteCard']);
      expect(plan.groups.last.risk, PlanRisk.medium);
      expect(plan.defaultSelection, {'i1', 'i3'});
    });

    test('a single-kind plan starts fully ticked, even when destructive', () {
      final plan = PlanView.fromJson({
        'planId': 'p',
        'risk': 'high',
        'items': [
          item('i1', 'deleteCard', 'high'),
          item('i2', 'deleteCard', 'high'),
        ],
      });

      expect(plan.defaultSelection, {'i1', 'i2'});
    });

    test('compacting keeps the count but only the first items', () {
      final plan = PlanView.fromJson({
        'planId': 'p',
        'items': [
          for (var i = 1; i <= 8; i++) item('i$i', 'updateCard', 'low'),
        ],
      });

      final compact = plan.compact();
      expect(compact.rows.map((r) => r.itemId), ['i1', 'i2', 'i3', 'i4', 'i5']);
      expect(compact.itemCount, 8);
    });

    test('rejects a plan without an id or with a malformed item', () {
      expect(() => PlanView.fromJson({'title': 'x'}), throwsFormatException);
      expect(
        () => PlanView.fromJson({
          'planId': 'p',
          'items': ['oops'],
        }),
        throwsFormatException,
      );
    });
  });

  test('recovered failed steps are counted in the headline, not repeated', () {
    StepView step(String id, StepStatus status, String text) =>
        StepView(callId: id, label: text, status: status, summary: text);
    final steps = StepsItem(
      id: 's',
      steps: [
        step('r1.1', StepStatus.failed, "didn't go through"),
        step('r1.2', StepStatus.failed, "didn't go through"),
        step('r2.1', StepStatus.done, 'Set Status to Made · 3 orders'),
      ],
    );

    expect(
      steps.headline,
      "Set Status to Made · 3 orders · 2 steps didn't go through",
    );
  });

  test('a steps chip joins the step lines, running ones by their label', () {
    const steps = StepsItem(
      id: 's',
      steps: [
        StepView(
          callId: 'r1.1',
          label: 'Reading…',
          status: StepStatus.done,
          summary: 'Looked at Orders',
        ),
        StepView(callId: 'r1.2', label: 'Filtering 148 orders…'),
      ],
    );

    expect(steps.headline, 'Looked at Orders · Filtering 148 orders…');
    expect(steps.running, isTrue);
    expect(
      steps.steps.last
          .finish(ok: false, summary: 'No field "Totl"', code: 'unknown_field')
          .status,
      StepStatus.failed,
    );
  });

  group('AssistantState', () {
    test('compares items by identity, so equal contents in a new list '
        'still count as a change', () {
      final items = <ChatItem>[const UserItem(id: 'u', text: 'hi')];
      final a = AssistantState(items: items);

      expect(a, AssistantState(items: items));
      expect(
        a ==
            AssistantState(
              items: [const UserItem(id: 'u', text: 'hi')],
            ),
        isFalse,
      );
    });

    test('finds the one pending plan', () {
      const plan = PlanView(planId: 'p', title: 'x');
      final state = AssistantState(
        items: [
          const PlanItem(
            id: 'a',
            plan: plan,
            selected: {},
            status: PlanStatus.skipped,
          ),
          PlanItem.proposed(id: 'b', plan: plan),
        ],
      );

      expect(state.pendingPlan?.id, 'b');
    });

    test('only an enabled assistant can send', () {
      expect(const AvailabilityEnabled().canSend, isTrue);
      expect(const AvailabilityOffline().canSend, isFalse);
      expect(
        AvailabilityQuotaExhausted(DateTime(2026, 11, 11)).canSend,
        isFalse,
      );
    });

    test('Stop shows only while a turn runs', () {
      expect(const ThinkingPhase().active, isTrue);
      expect(const ApplyingPhase(1, 2).active, isTrue);
      expect(const AwaitingApprovalPhase('p').active, isFalse);
      expect(const IdlePhase().active, isFalse);
    });

    test('a new thread keeps availability, focus and the user', () {
      const focus = AssistantFocus(page: FocusPage.home);
      final state = AssistantState(
        threadId: 't',
        items: const [UserItem(id: 'u', text: 'hi')],
        availability: const AvailabilityEnabled(),
        focus: focus,
        userFirstName: 'Olena',
        phase: const IdlePhase(),
      ).cleared();

      expect(state.threadId, isNull);
      expect(state.items, isEmpty);
      expect(state.availability, const AvailabilityEnabled());
      expect(state.focus, focus);
      expect(state.userFirstName, 'Olena');
    });
  });
}
