import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/core/harness/harness.dart';
import 'package:morkva_crm/core/harness/plan/plan.dart';
import 'package:morkva_crm/core/harness/plan/planners/view_planners.dart';
import 'package:morkva_crm/features/views/modes/built_in_modes.dart';

import 'plan_fixture.dart';

void main() {
  late PlanHarness h;

  setUp(() => h = PlanHarness());
  tearDown(() => h.dispose());

  group('views.create', () {
    test('a board needs a groupable layout field', () async {
      final none = await h.error('views.create', {
        'collection': 'Orders',
        'name': 'By status',
        'mode': 'board',
      });
      expect(none.code, ErrorCode.invalidArgs);
      expect(none.candidates, ['Client', 'Status']);
      final wrong = await h.error('views.create', {
        'collection': 'Orders',
        'name': 'By price',
        'mode': 'board',
        'layoutField': 'Price',
      });
      expect(wrong.code, ErrorCode.invalidArgs);
      final table = await h.error('views.create', {
        'collection': 'Orders',
        'name': 'T',
        'mode': 'table',
        'layoutField': 'Status',
      });
      expect(table.message, contains('takes no layoutField'));
    });

    test('filters and sort are compiled; the view is appended', () async {
      await h.ok('views.create', {
        'collection': 'Orders',
        'name': 'Due soon',
        'mode': 'calendar',
        'layoutField': 'Created',
        'where': [
          {'field': 'Status', 'op': 'equals', 'value': 'Packing'},
        ],
        'sort': {'field': 'Price', 'dir': 'desc'},
      });
      final plan = await h.sealPlan();
      final item = plan.items.single as CreateViewItem;
      expect(item.index, 2);
      expect(item.view.id, startsWith('v_'));
      expect(item.view.filters.single.operand, [SeedOptions.packing]);
      expect(
        item.view.sort,
        const ViewSort(fieldId: OrderFields.price, ascending: false),
      );
      expect(item.detail, 'Calendar · by Created');
      expect(plan.title, 'Create view “Due soon” in Orders');
      expect(h.repo.saveCount + h.repo.batchCalls, 0);
    });
  });

  group('views.update', () {
    test('switching a board to a table drops its layout field', () async {
      await h.ok('views.update', {
        'collection': 'Orders',
        'view': 'Unpaid',
        'mode': 'table',
        'name': 'Unpaid list',
      });
      final plan = await h.sealPlan();
      final item = plan.items.single as UpdateViewItem;
      expect(item.after.mode, 'table');
      expect(item.after.layoutFieldId, isNull);
      expect(item.after.filters, item.before.filters);
      expect(item.risk, Risk.medium);
      expect(item.changes.map((c) => c.field), ['Name', 'Mode', 'Laid out by']);
    });

    test('a calendar without a date layout field is refused', () async {
      final e = await h.error('views.update', {
        'collection': 'Orders',
        'view': 'Unpaid',
        'mode': 'calendar',
      });
      expect(e.code, ErrorCode.invalidArgs);
      expect(e.candidates, ['Created', 'Delivery slot']);
    });
  });

  group('views.delete', () {
    test('the last view stays', () async {
      await h.ok('views.delete', {'collection': 'Clients', 'view': 'VIP'});
      final e = await h.error('views.delete', {
        'collection': 'Clients',
        'view': 'All',
      });
      expect(e.code, ErrorCode.lastView);
      final sealed = await h.seal();
      expect(sealed['errors'], hasLength(1));
    });

    test('records the view and its index', () async {
      await h.ok('views.delete', {'collection': 'Orders', 'view': 'Unpaid'});
      final plan = await h.sealPlan();
      final item = plan.items.single as DeleteViewItem;
      expect(item.index, 1);
      expect(item.before.layoutFieldId, OrderFields.status);
      expect(item.detail, 'Board · by Status');
    });
  });

  test('the layout-field rule agrees with the app\'s view modes', () {
    final modes = defaultViewModeRegistry().modes;
    expect({for (final m in modes) m.id}, kViewModes.toSet());
    for (final mode in modes) {
      expect(
        modeNeedsLayoutField(mode.id),
        mode.needsLayoutField,
        reason: mode.id,
      );
      for (final c in h.resolved) {
        for (final f in c.fields) {
          expect(
            modeAcceptsLayoutField(mode.id, f),
            mode.acceptsLayoutField(f),
            reason: '${mode.id} × ${c.name}.${f.name}',
          );
        }
      }
    }
  });
}
