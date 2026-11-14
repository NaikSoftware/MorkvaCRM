import 'package:flutter/foundation.dart';
import 'package:morkva_crm/core/agent/agent_event.dart';
import 'package:morkva_crm/core/harness/api/capability.dart' show Actor;
import 'package:morkva_crm/features/assistant/bloc/assistant_focus.dart';
import 'package:morkva_crm/features/assistant/bloc/assistant_state.dart';
import 'package:morkva_crm/features/assistant/bloc/chat_item.dart';

/// [AssistantState]s that reproduce the Epic 8 mockup artboards
/// (`docs/superpowers/mockups/epic-08/*.dc.html`) verbatim, for widget tests
/// and the design parity gate. Times are relative to [now] so countdowns
/// ("undo available for 9 min", "Retrying in 20 s") read as drawn.
abstract final class AssistantSeeds {
  static const String ordersId = 'c_orders';
  static const String fabricsId = 'c_fabrics';

  /// Main: wide panel with a table answer and a pending 3-order plan.
  static AssistantState main() => AssistantState(
    threadId: 't_unpaid',
    threadTitle: 'Unpaid orders this month',
    availability: const AvailabilityEnabled(),
    phase: const AwaitingApprovalPhase('p_ship'),
    focus: const AssistantFocus(
      page: FocusPage.collection,
      collectionId: ordersId,
      collectionName: 'Orders',
      collectionIcon: 'cart',
      viewId: 'all',
      mode: 'table',
    ),
    userFirstName: 'Olena',
    collectionNames: _collections,
    items: [
      const UserItem(
        id: 'm1',
        text: 'Which orders are still unpaid this month, and how much is that?',
      ),
      const StepsItem(
        id: 'm2',
        steps: [
          StepView(
            callId: 'r1.1',
            label: 'Reading Orders…',
            status: StepStatus.done,
            summary: 'Looked at Orders',
          ),
          StepView(
            callId: 'r2.1',
            label: 'Filtering 148 orders…',
            status: StepStatus.done,
            summary: 'filtered 148 → 5',
          ),
          StepView(
            callId: 'r2.2',
            label: 'Summing Total…',
            status: StepStatus.done,
            summary: 'summed Total',
          ),
        ],
      ),
      const AssistantTextItem(
        id: 'm3',
        text:
            'Five November orders have **Paid** unticked. Together they come '
            'to **₴ 9 840**.',
      ),
      const TableItem(
        id: 'm4',
        title: 'Unpaid orders this month',
        handle: 'h_unpaid',
        spec: {'kind': 'query', 'collectionId': ordersId},
        summary: 'Filtered 148 → 5 Orders',
        table: ResultTable(
          collectionId: ordersId,
          columns: [
            ResultColumn('#'),
            ResultColumn('Client'),
            ResultColumn('Delivery'),
            ResultColumn('Total', numeric: true),
          ],
          rows: [
            ResultRow(
              cardId: 'o_1042',
              cells: ['1042', 'Iryna Melnyk', 'Nova Poshta', '₴ 2 150'],
            ),
            ResultRow(
              cardId: 'o_1041',
              cells: ['1041', 'Taras Bondar', 'Pickup', '₴ 1 320'],
            ),
            ResultRow(
              cardId: 'o_1040',
              cells: ['1040', 'Oksana Lysenko', 'Nova Poshta', '₴ 1 980'],
            ),
            ResultRow(
              cardId: 'o_1038',
              cells: ['1038', 'Sofia Kravets', 'Nova Poshta', '₴ 1 640'],
            ),
            ResultRow(
              cardId: 'o_1037',
              cells: ['1037', 'Andrii Hnatyuk', 'Courier', '₴ 2 750'],
            ),
          ],
          totals: ['Total', '', '', '₴ 9 840'],
        ),
      ),
      const UserItem(
        id: 'm5',
        text: 'The three going by Nova Poshta are packed — mark them Shipped.',
      ),
      PlanItem.proposed(id: 'm6', plan: shipPlan),
    ],
  );

  /// The Main artboard's plan: one shared Packing → Shipped diff.
  static const PlanView shipPlan = PlanView(
    planId: 'p_ship',
    title: 'Set Status to Shipped · 3 orders',
    sharedChange: PlanChange(
      fieldId: 'f_status',
      field: 'Status',
      beforeText: 'Packing',
      afterText: 'Shipped',
    ),
    rows: [
      PlanRow(
        itemId: 'i1',
        kind: 'updateCard',
        label: '#1042 · Iryna Melnyk',
        collectionId: ordersId,
        targetId: 'o_1042',
        detail: '₴ 2 150',
        changes: [_packingToShipped],
      ),
      PlanRow(
        itemId: 'i2',
        kind: 'updateCard',
        label: '#1040 · Oksana Lysenko',
        collectionId: ordersId,
        targetId: 'o_1040',
        detail: '₴ 1 980',
        changes: [_packingToShipped],
      ),
      PlanRow(
        itemId: 'i3',
        kind: 'updateCard',
        label: '#1038 · Sofia Kravets',
        collectionId: ordersId,
        targetId: 'o_1038',
        detail: '₴ 1 640',
        changes: [_packingToShipped],
      ),
    ],
  );

  static const _packingToShipped = PlanChange(
    fieldId: 'f_status',
    field: 'Status',
    beforeText: 'Packing',
    afterText: 'Shipped',
  );

  /// Empty: first open, greeting and suggestions.
  static AssistantState empty() => const AssistantState(
    availability: AvailabilityEnabled(),
    userFirstName: 'Olena',
    collectionNames: _collections,
  );

  /// Analyze: a bar chart, then an applied 12-of-14 plan with Undo.
  static AssistantState analyze({DateTime? now}) {
    final at = now ?? DateTime.now();
    return AssistantState(
      threadId: 't_revenue',
      threadTitle: 'Revenue by month',
      availability: const AvailabilityEnabled(),
      focus: const AssistantFocus(
        page: FocusPage.collection,
        collectionId: ordersId,
        collectionName: 'Orders',
        collectionIcon: 'cart',
      ),
      userFirstName: 'Olena',
      collectionNames: _collections,
      items: [
        const UserItem(id: 'a1', text: 'Show revenue by month this year'),
        const StepsItem(
          id: 'a2',
          steps: [
            StepView(
              callId: 'r1.1',
              label: 'Reading the Orders schema…',
              status: StepStatus.done,
              summary: 'Read the Orders schema',
            ),
            StepView(
              callId: 'r2.1',
              label: 'Grouping 148 orders…',
              status: StepStatus.done,
              summary: 'Grouped 148 orders by Created (month), summed Total',
            ),
            StepView(
              callId: 'r2.2',
              label: 'Making a bar chart…',
              status: StepStatus.done,
              summary: 'Made a bar chart',
            ),
          ],
        ),
        const AssistantTextItem(
          id: 'a3',
          text:
              'October was your best month at **₴ 48 200** — 31% above '
              'September. Summer dipped, then sales climbed every month since '
              'July.',
        ),
        const ChartItem(
          id: 'a4',
          title: 'Revenue by month, 2026',
          handle: 'h_revenue',
          summary: 'Grouped 148 orders by Created (month), summed Total',
          chart: ResultChart(
            collectionId: ordersId,
            metricLabel: 'Sum of Total, ₴',
            points: [
              ChartPoint('J', 21400),
              ChartPoint('F', 19800),
              ChartPoint('M', 26100),
              ChartPoint('A', 29000),
              ChartPoint('M', 31500),
              ChartPoint('J', 24200),
              ChartPoint('J', 22800),
              ChartPoint('A', 27600),
              ChartPoint('S', 36800),
              ChartPoint('O', 48200),
              ChartPoint('N', 14100, partial: true),
            ],
          ),
        ),
        const UserItem(
          id: 'a5',
          text: 'Mark the October orders without a delivery date as Done',
        ),
        AppliedItem(
          id: 'a6',
          plan: const PlanView(
            planId: 'p_done',
            title: 'Set Status to Done · 12 orders',
            itemCount: 14,
            sharedChange: PlanChange(
              fieldId: 'f_status',
              field: 'Status',
              beforeText: 'Shipped',
              afterText: 'Done',
            ),
          ),
          receipt: Receipt(
            planId: 'p_done',
            applied: [for (var i = 1; i <= 12; i++) 'i$i'],
            declinedByUser: const ['i13', 'i14'],
            journalId: 'j_done',
            undoUntil: at.add(const Duration(minutes: 9)),
            summary: 'Updated 12 orders',
          ),
          undoUntil: at.add(const Duration(minutes: 9)),
        ),
        const AssistantTextItem(
          id: 'a7',
          text: '#1012 and #1019 were left as they were.',
        ),
      ],
    );
  }

  /// Schema: transient rate-limit banner, an applied schema change, a pending
  /// destructive plan and an error row.
  static AssistantState schema({DateTime? now}) {
    final at = now ?? DateTime.now();
    return AssistantState(
      threadId: 't_suppliers',
      threadTitle: 'Suppliers collection',
      availability: const AvailabilityEnabled(),
      phase: const AwaitingApprovalPhase('p_delete'),
      banner: RetryBanner(at.add(const Duration(seconds: 20)), RetryReason.rpm),
      userFirstName: 'Olena',
      collectionNames: _collections,
      items: [
        const UserItem(
          id: 's1',
          text:
              'Add a Suppliers collection — name, phone, city, and which '
              'fabrics they sell',
        ),
        AppliedItem(
          id: 's2',
          plan: const PlanView(
            planId: 'p_suppliers',
            title: 'Create “Suppliers” · 4 fields',
            notes: ['Fabrics now shows Suppliers'],
            rows: [
              PlanRow(
                itemId: 'i1',
                kind: 'addField',
                label: 'Name',
                detail: 'Text · title',
              ),
              PlanRow(
                itemId: 'i2',
                kind: 'addField',
                label: 'Phone',
                detail: 'Text',
              ),
              PlanRow(
                itemId: 'i3',
                kind: 'addField',
                label: 'City',
                detail: 'Select · Kyiv, Lviv, Odesa',
              ),
              PlanRow(
                itemId: 'i4',
                kind: 'addField',
                label: 'Fabrics sold',
                detail: 'Link → Fabrics, many',
              ),
            ],
          ),
          receipt: Receipt(
            planId: 'p_suppliers',
            applied: const ['i1', 'i2', 'i3', 'i4'],
            journalId: 'j_suppliers',
            undoUntil: at.add(const Duration(minutes: 8)),
            summary: 'Created “Suppliers” · 4 fields',
          ),
          undoUntil: at.add(const Duration(minutes: 8)),
        ),
        const UserItem(
          id: 's3',
          text: 'Also delete the test orders I made last week',
        ),
        PlanItem.proposed(id: 's4', plan: deletePlan),
        const ErrorItem(
          id: 's5',
          kind: ChatErrorKind.connection,
          message:
              'The connection dropped before I finished. Nothing was changed.',
        ),
      ],
    );
  }

  /// The Schema artboard's destructive plan: 7 test orders, 3 drawn then
  /// "Show 4 more".
  static final PlanView deletePlan = PlanView(
    planId: 'p_delete',
    title: 'Delete 7 orders',
    risk: PlanRisk.high,
    notes: ['Client is “Test”.'],
    rows: [
      _deleteRow('i1', '1029', 'Test · hoodie M', '3 Nov'),
      _deleteRow('i2', '1028', 'Test · tee S', '3 Nov'),
      _deleteRow('i3', '1027', 'Test · custom', '2 Nov'),
      _deleteRow('i4', '1026', 'Test · tote', '2 Nov'),
      _deleteRow('i5', '1025', 'Test · hoodie L', '1 Nov'),
      _deleteRow('i6', '1024', 'Test · cap', '1 Nov'),
      _deleteRow('i7', '1023', 'Test · tee M', '31 Oct'),
    ],
  );

  /// The module-install preview (UX §10): one high-risk `saveModule` item.
  static const PlanView moduleInstallPlan = PlanView(
    planId: 'p_module',
    title: 'Install “Stamp shipped date”',
    risk: PlanRisk.high,
    undo: 'none',
    createdBy: PlanCreatorView(
      actor: Actor.assistant,
      caps: ['data:read', 'data:write'],
    ),
    warnings: [
      PlanWarning(
        'grants_permissions',
        'Approving installs this module and lets it use these permissions. '
            'Auto-apply stays off.',
      ),
    ],
    rows: [
      PlanRow(
        itemId: 'i1',
        kind: 'saveModule',
        label: 'Stamp shipped date',
        risk: PlanRisk.high,
        code: '(() => { morkva.action("stamp", async () => {}); })();',
        changes: [
          PlanChange(field: 'Create and change cards', afterText: 'Orders'),
          PlanChange(field: 'Actions', afterText: 'Stamp (on a card)'),
          PlanChange(field: 'Code', afterText: '2.1 KB · sha256:3fa2…'),
        ],
      ),
    ],
  );

  /// [moduleInstallPlan] plus an automation that applies without asking.
  static final PlanView moduleWithAutoPlan = PlanView(
    planId: 'p_module_auto',
    title: 'Install “Stamp shipped date” · 2 changes',
    risk: PlanRisk.high,
    undo: 'none',
    warnings: moduleInstallPlan.warnings,
    rows: [
      moduleInstallPlan.rows.single,
      const PlanRow(
        itemId: 'i2',
        kind: 'saveAutomation',
        label: 'Stamp when shipped',
        collectionId: ordersId,
        apply: 'auto',
        changes: [
          PlanChange(
            field: 'When a card is updated in Orders',
            afterText: 'Status starts matching Shipped → Stamp',
          ),
          PlanChange(field: 'Applies changes without asking'),
        ],
      ),
    ],
  );

  /// Phone: an answer streaming in while a step still runs.
  static AssistantState phoneStreaming({ValueListenable<String>? live}) =>
      AssistantState(
        threadId: 't_fabrics',
        threadTitle: 'Low stock fabrics',
        availability: const AvailabilityEnabled(),
        phase: const StreamingPhase(),
        userFirstName: 'Olena',
        collectionNames: _collections,
        items: [
          const UserItem(id: 'f1', text: 'Which fabrics are running low?'),
          const StepsItem(
            id: 'f2',
            steps: [
              StepView(
                callId: 'r1.1',
                label: 'Reading the Fabrics schema…',
                status: StepStatus.done,
                summary: 'Read the Fabrics schema',
              ),
              StepView(
                callId: 'r2.1',
                label: 'Filtering 36 fabrics where Metres left < 5…',
              ),
            ],
          ),
          AssistantTextItem(
            id: 'f3',
            text: phoneStreamingText,
            streaming: true,
            live: live,
          ),
        ],
      );

  static const String phoneStreamingText =
      'Four fabrics are under 5 metres. The lowest is **Linen, sand** with '
      "1.2 m — and it's in two open orders";

  /// Tablet: the rail modal sheet showing the conversation history; the chat
  /// behind it is the Main conversation.
  static AssistantState tabletHistory() => main();

  /// The Tablet artboard's history list, in the thread-meta record shape
  /// `ThreadRepository.watchThreads` emits (`{id, title, createdAt,
  /// updatedAt, model, lastSnippet, tokens, schema}`, ISO UTC dates).
  static List<Map<String, Object?>> threads({DateTime? now}) {
    final at = now ?? DateTime.now();
    final today = DateTime(at.year, at.month, at.day);
    final yesterday = today.subtract(const Duration(days: 1));
    Map<String, Object?> thread(
      String id,
      String title,
      DateTime updatedAt,
      String? snippet,
    ) => {
      'id': id,
      'title': title,
      'createdAt': updatedAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'model': 'gemini-3.5-flash-lite',
      'lastSnippet': ?snippet,
      'tokens': {'prompt': 0, 'output': 0},
      'schema': 1,
    };
    return [
      thread(
        't_unpaid',
        'Unpaid orders this month',
        today.add(const Duration(hours: 12, minutes: 40)),
        '3 changes applied',
      ),
      thread(
        't_revenue',
        'Revenue by month',
        today.add(const Duration(hours: 10, minutes: 5)),
        'chart',
      ),
      thread(
        't_suppliers',
        'Suppliers collection',
        today.add(const Duration(hours: 9, minutes: 20)),
        'collection created',
      ),
      thread(
        't_fabrics',
        'Low stock fabrics',
        yesterday.add(const Duration(hours: 16)),
        null,
      ),
      thread(
        't_cleanup',
        'Clean up test orders',
        yesterday.add(const Duration(hours: 11)),
        '7 deleted',
      ),
    ];
  }

  static const List<String> _collections = [
    'Orders',
    'Clients',
    'Products',
    'Deliveries',
    'Fabrics',
    'Payments',
    'Tasks',
    'Notes',
  ];
}

/// A destructive plan row: `#n · what`, the date as the secondary line.
PlanRow _deleteRow(String itemId, String n, String what, String when) =>
    PlanRow(
      itemId: itemId,
      kind: 'deleteCard',
      label: '#$n · $what',
      collectionId: AssistantSeeds.ordersId,
      targetId: 'o_$n',
      risk: PlanRisk.high,
      detail: when,
    );
