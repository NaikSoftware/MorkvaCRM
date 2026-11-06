import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/views/collection_views_state.dart';
import 'package:morkva_crm/features/views/modes/summary_mode.dart';
import 'package:morkva_crm/features/views/modes/view_mode.dart';

const _dash = Collection(
  id: 'dash',
  name: 'Dashboard',
  fields: [
    TextFieldDefinition(id: 'name', name: 'Name'),
    CalculatedFieldDefinition(
      id: 'perUnit',
      name: 'Cost per unit',
      declaredOutputType: 'number',
      decimalPlaces: 2,
      unitLabel: '₴',
      expression: '{fee} / 2',
    ),
    NumberFieldDefinition(id: 'fee', name: 'Sewing fee'),
    TextFieldDefinition(id: 'season', name: 'Season'),
  ],
  views: [
    ViewDefinition(
      id: 's',
      name: 'Summary',
      mode: ViewModeIds.summary,
      fieldIds: ['name', 'perUnit', 'fee', 'season'],
    ),
  ],
);

void main() {
  testWidgets('one panel per object with a tile per shown field', (
    tester,
  ) async {
    final t = DateTime.utc(2026);
    final object = MorkvaObject.create(
      id: 'd',
      collection: _dash,
      values: const {
        'name': TextFieldValue('Autumn drop'),
        'perUnit': CalculatedFieldValue(508.26),
        'fee': NumberFieldValue(1200),
      },
      createdAt: t,
      updatedAt: t,
    );
    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => const SummaryMode().buildBody(
              context,
              ViewModeData(
                state: ViewsReady(
                  collection: _dash,
                  activeViewId: 's',
                  objects: [object],
                  totalCount: 1,
                  calculationNotes: const {'perUnit': '= {Sewing fee} / 2'},
                ),
                itemLabel: 'dashboard',
                openObject: (o) => opened.add(o.id),
                quickAdd: ({groupKey, day}) {},
                editFields: () {},
                notify: (m, {undo}) {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Autumn drop'), findsOneWidget);
    expect(find.text('508.26 ₴'), findsOneWidget);
    expect(find.text('= {Sewing fee} / 2'), findsOneWidget);
    expect(find.text('1,200'), findsOneWidget);
    expect(find.text('Entered by hand'), findsOneWidget);
    // An empty value reads as a dash, not a blank tile.
    expect(find.text('—'), findsOneWidget);
    await tester.tap(find.text('Edit values'));
    expect(opened, ['d']);
  });
}
