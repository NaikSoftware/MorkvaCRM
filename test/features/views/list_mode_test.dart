import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/features/views/views.dart';

import 'views_fixtures.dart';
import 'work_page_harness.dart';

const _grouped = ViewDefinition(
  id: 'list',
  name: 'Stages',
  mode: ViewModeIds.list,
  layoutFieldId: 'stage',
  fieldIds: ['name', 'amount'],
);

Collection _with(ViewDefinition v) => deals.copyWith(views: [v]);

double _y(WidgetTester t, String text) => t.getCenter(find.text(text)).dy;

/// Half the height of the row (or section header) showing [text].
double _half(WidgetTester t, String text) {
  final card = find.ancestor(
    of: find.text(text),
    matching: find.byType(ObjectCard),
  );
  return card.evaluate().isEmpty
      ? ViewList.headerHeight / 2
      : t.getSize(card.first).height / 2;
}

/// Long-press [from], drag it onto [over] (into its lower half, or its upper
/// half with [up]) and drop it.
Future<void> _drag(
  WidgetTester t,
  String from,
  String over, {
  bool up = false,
}) async {
  final g = await t.startGesture(t.getCenter(find.text(from)));
  await t.pump(const Duration(milliseconds: 700));
  await g.moveBy(Offset(0, up ? -8 : 8));
  await t.pump();
  final dy = _half(t, over) * (up ? -3 : 0.6);
  await g.moveTo(t.getCenter(find.text(over)) + Offset(0, dy));
  await t.pump();
  await g.up();
  await t.pumpAndSettle();
}

List<String> _ids(Iterable<MorkvaObject> os) => [for (final o in os) o.id];

void main() {
  test('accepts groupable fields only; needs none', () {
    const mode = ListMode();
    expect(mode.needsLayoutField, isFalse);
    expect(mode.acceptsLayoutField(stageField), isTrue);
    expect(mode.acceptsLayoutField(companyField), isTrue);
    expect(mode.acceptsLayoutField(dueField), isFalse);
    expect(defaultViewModeRegistry().byId(ViewModeIds.list), isA<ListMode>());
  });

  testWidgets('sections with counts, rows and per-section add', (t) async {
    await pumpWorkPage(
      t,
      repository: workRepository(collection: _with(_grouped)),
    );
    for (final h in ['LEAD', 'WON', 'LOST', 'NO STAGE']) {
      expect(find.text(h), findsOneWidget);
    }
    expect(find.text('Group: Stage'), findsOneWidget);
    expect(_y(t, 'Acme renewal'), lessThan(_y(t, 'WON')));
    expect(_y(t, 'Globex pilot'), greaterThan(_y(t, 'WON')));
    expect(find.widgetWithText(InkWell, 'New deal'), findsNWidgets(4));
  });

  testWidgets('no layout field: one flat list, group chip says None', (
    t,
  ) async {
    const flat = ViewDefinition(
      id: 'list',
      name: 'Flat',
      mode: ViewModeIds.list,
      fieldIds: ['name'],
    );
    await pumpWorkPage(t, repository: workRepository(collection: _with(flat)));
    expect(find.text('Group: None'), findsOneWidget);
    expect(find.text('LEAD'), findsNothing);
    expect(find.text('Hooli'), findsOneWidget);
  });

  testWidgets('group chip menu clears the layout field', (t) async {
    final cubit = await pumpWorkPage(
      t,
      repository: workRepository(collection: _with(_grouped)),
    );
    await t.tap(find.text('Group: Stage'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(CheckedPopupMenuItem<String>, 'None'));
    await t.pumpAndSettle();
    expect(find.text('Group: None'), findsOneWidget);
    expect((cubit.state as ViewsReady).activeView.layoutFieldId, isNull);
  });

  testWidgets('long-press drag to another section writes the value', (t) async {
    final cubit = await pumpWorkPage(
      t,
      repository: workRepository(collection: _with(_grouped)),
    );
    await _drag(t, 'Initech', 'Globex pilot');
    await t.pump();
    final state = cubit.state as ViewsReady;
    expect(
      state.objectById('d3')!['stage'],
      const SingleSelectFieldValue('won'),
    );
    expect(find.text('Moved to Won'), findsOneWidget);
  });

  testWidgets('a sorted view cannot be dragged', (t) async {
    final sorted = _grouped.copyWith(sort: const ViewSort(fieldId: 'name'));
    final cubit = await pumpWorkPage(
      t,
      repository: workRepository(collection: _with(sorted)),
    );
    await _drag(t, 'Initech', 'Globex pilot');
    expect(
      (cubit.state as ViewsReady).objectById('d3')!['stage'],
      const SingleSelectFieldValue('lead'),
    );
  });

  testWidgets('reorders within a section; undo restores the order', (t) async {
    final cubit = await pumpWorkPage(
      t,
      repository: workRepository(collection: _with(_grouped)),
    );
    List<String> lead() =>
        _ids((cubit.state as ViewsReady).groups!.first.objects);
    final before = lead();
    expect(before, ['d1', 'd3']);
    await _drag(t, 'Initech', 'Acme renewal', up: true);
    await t.pump();
    expect(lead(), ['d3', 'd1']);
    expect(find.text('Order changed'), findsOneWidget);
    await t.tap(find.text('Undo'));
    await t.pumpAndSettle();
    expect(lead(), before);
  });

  testWidgets('dropping above the first header lands first in section 1', (
    t,
  ) async {
    final cubit = await pumpWorkPage(
      t,
      repository: workRepository(collection: _with(_grouped)),
    );
    await _drag(t, 'Initech', 'LEAD', up: true);
    await t.pump();
    expect(_ids((cubit.state as ViewsReady).groups!.first.objects), [
      'd3',
      'd1',
    ]);
  });

  testWidgets('reorders a flat list and undo restores it', (t) async {
    const flat = ViewDefinition(
      id: 'list',
      name: 'Flat',
      mode: ViewModeIds.list,
      fieldIds: ['name'],
    );
    final cubit = await pumpWorkPage(
      t,
      repository: workRepository(collection: _with(flat)),
    );
    List<String> order() => _ids((cubit.state as ViewsReady).objects);
    final before = order();
    await _drag(t, 'Globex pilot', 'Acme renewal', up: true);
    await t.pump();
    expect(order().take(2), ['d2', 'd1']);
    await t.tap(find.text('Undo'));
    await t.pumpAndSettle();
    expect(order(), before);
  });

  testWidgets('the section header sticks while its section scrolls', (t) async {
    await pumpWorkPage(
      t,
      size: const Size(1280, 520),
      repository: workRepository(collection: _with(_grouped)),
    );
    final pinned = find.byKey(const ValueKey('pinned-header'));
    expect(pinned, findsNothing);
    await t.drag(find.byType(ReorderableListView), const Offset(0, -300));
    await t.pumpAndSettle();
    expect(pinned, findsOneWidget);
    expect(
      find.descendant(of: pinned, matching: find.text('WON')),
      findsOneWidget,
    );
    // Pinned at the top edge of the card.
    expect(
      t.getTopLeft(pinned).dy,
      closeTo(t.getTopLeft(find.byType(SingleChildScrollView).last).dy, 1),
    );
  });

  testWidgets('phone width renders without the hover handle', (t) async {
    await pumpWorkPage(
      t,
      size: const Size(390, 844),
      repository: workRepository(collection: _with(_grouped)),
    );
    expect(find.text('Acme renewal'), findsOneWidget);
    expect(find.byIcon(Icons.drag_indicator), findsNothing);
  });
}
