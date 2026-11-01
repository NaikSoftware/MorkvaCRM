import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/features/views/views.dart';

import 'views_fixtures.dart';

void main() {
  group('ViewModeRegistry', () {
    final registry = defaultViewModeRegistry();

    test('ships Table first; unknown ids fall back to it', () {
      expect(registry.modes.first, isA<TableMode>());
      expect(registry.byId(ViewModeIds.table), isA<TableMode>());
      expect(registry.byId('gallery'), isNull);
      expect(registry.resolve('gallery'), isA<TableMode>());
    });

    test('Table needs no layout field and is always available', () {
      const table = TableMode();
      expect(table.needsLayoutField, isFalse);
      expect(table.acceptsLayoutField(stageField), isFalse);
      expect(table.unavailableReason(deals), isNull);
      expect(table.fieldsLabel, 'Columns');
    });
  });

  group('labels', () {
    test('itemLabelOf singularizes naively', () {
      String of(String name) => itemLabelOf(Collection(id: 'c', name: name));
      expect(of('Deals'), 'deal');
      expect(of('Companies'), 'company');
      expect(of('Inventory'), 'inventory');
      expect(of('Glass'), 'glass');
      expect(of('  '), 'item');
    });

    test('filterLabel names the field, operator and value', () {
      String of(ViewFilter f) => filterLabel(f, deals);
      expect(
        of(
          const ViewFilter(
            fieldId: 'stage',
            op: FilterOp.anyOf,
            operand: ['lead', 'won'],
          ),
        ),
        'Stage is Lead, Won',
      );
      expect(
        of(
          const ViewFilter(
            fieldId: 'amount',
            op: FilterOp.greaterThan,
            operand: 100,
          ),
        ),
        'Amount > 100',
      );
      expect(
        of(const ViewFilter(fieldId: 'due', op: FilterOp.isEmpty)),
        'Due is empty',
      );
      expect(
        of(const ViewFilter(fieldId: 'gone', op: FilterOp.isEmpty)),
        'Unknown field',
      );
    });
  });
}
