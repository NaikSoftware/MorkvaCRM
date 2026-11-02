import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/views/views.dart';
import 'package:morkva_crm/features/views/widgets/new_view_dialog.dart';

import 'views_fixtures.dart';
import 'work_page_harness.dart';

class _FakeMode extends ViewMode {
  const _FakeMode(this.id, this.label, this.accepts);

  @override
  final String id;
  @override
  final String label;
  final bool Function(FieldDefinition) accepts;

  @override
  IconData get icon => Icons.circle;
  @override
  String get description => '$label desc';
  @override
  bool get needsLayoutField => true;
  @override
  bool acceptsLayoutField(FieldDefinition f) => accepts(f);
  @override
  String? unavailableReason(Collection c) => c.fields.any(accepts)
      ? null
      : (id == 'calendar' ? 'Needs a date field' : 'Needs a select field');
  @override
  Widget buildBody(BuildContext context, ViewModeData data) => const SizedBox();
}

final _registry = ViewModeRegistry([
  const TableMode(),
  _FakeMode('board', 'Board', (f) => f is SingleSelectFieldDefinition),
  _FakeMode('calendar', 'Calendar', (f) => f is DateFieldDefinition),
]);

Future<ValueNotifier<NewViewRequest?>> _open(
  WidgetTester tester,
  Collection collection, {
  VoidCallback? onAddField,
  Size size = const Size(1280, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final result = ValueNotifier<NewViewRequest?>(null);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result.value = await NewViewDialog.show(
            context,
            collection: collection,
            modes: _registry,
            onAddField: onAddField ?? () {},
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

bool _createEnabled(WidgetTester tester) =>
    tester
        .widget<PrimaryButton>(
          find.widgetWithText(PrimaryButton, 'Create view'),
        )
        .onPressed !=
    null;

void main() {
  testWidgets('tiles come from the registry plus a disabled Gallery', (
    tester,
  ) async {
    await _open(tester, deals);
    for (final t in ['Table', 'Board', 'Calendar', 'Gallery']) {
      expect(find.text(t), findsOneWidget);
    }
    expect(find.text('Needs image files'), findsOneWidget);
    expect(find.text('Add date field'), findsNothing);
  });

  testWidgets('Table: needs only a name', (tester) async {
    final result = await _open(tester, deals);
    expect(_createEnabled(tester), isFalse);
    await tester.enterText(find.byType(TextField), '  Everything ');
    await tester.pump();
    expect(_createEnabled(tester), isTrue);
    await tester.tap(find.text('Create view'));
    await tester.pumpAndSettle();
    expect(result.value?.name, 'Everything');
    expect(result.value?.mode, 'table');
    expect(result.value?.layoutFieldId, isNull);
  });

  testWidgets('Board reveals a field picker and waits for a choice', (
    tester,
  ) async {
    final withTwo = deals.copyWith(
      fields: [
        ...deals.fields,
        const SingleSelectFieldDefinition(
          id: 'kind',
          name: 'Kind',
          options: [SelectOption(id: 'a', label: 'A', color: '#3A7CA5')],
        ),
      ],
    );
    final result = await _open(tester, withTwo);
    expect(find.text('Group by'), findsNothing);
    await tester.tap(find.text('Board'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Pipeline 2');
    await tester.pump();
    expect(find.text('Group by'), findsOneWidget);
    expect(_createEnabled(tester), isFalse);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Kind'));
    await tester.pump();
    expect(_createEnabled(tester), isTrue);
    await tester.tap(find.text('Create view'));
    await tester.pumpAndSettle();
    expect(result.value?.mode, 'board');
    expect(result.value?.layoutFieldId, 'kind');
  });

  testWidgets('a single candidate field is preselected', (tester) async {
    final result = await _open(tester, deals);
    await tester.tap(find.text('Board'));
    await tester.enterText(find.byType(TextField), 'B');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create view'));
    await tester.pumpAndSettle();
    expect(result.value?.layoutFieldId, 'stage');
  });

  testWidgets('unavailable tile shows the reason, ignores taps, deep-links', (
    tester,
  ) async {
    var added = 0;
    final noDates = deals.copyWith(
      fields: [
        for (final f in deals.fields)
          if (f is! DateFieldDefinition) f,
      ],
    );
    final result = await _open(tester, noDates, onAddField: () => added++);
    expect(find.text('Needs a date field'), findsOneWidget);
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    expect(find.text('Date field'), findsNothing);
    expect(find.byTooltip('Needs a date field'), findsOneWidget);

    await tester.tap(find.text('Add date field'));
    await tester.pumpAndSettle();
    expect(added, 1);
    expect(find.byType(NewViewDialog), findsNothing);
    expect(result.value, isNull);
  });

  testWidgets('phone: two columns', (tester) async {
    await _open(tester, deals, size: const Size(390, 844));
    final table = tester.getTopLeft(find.text('Table'));
    final board = tester.getTopLeft(find.text('Board'));
    final calendar = tester.getTopLeft(find.text('Calendar'));
    expect(board.dy, table.dy);
    expect(calendar.dy, greaterThan(table.dy));
  });

  group('on the Work page', () {
    testWidgets('+ creates a Table view and selects it', (tester) async {
      final cubit = await pumpWorkPage(tester);
      await tester.tap(find.byTooltip('New view'));
      await tester.pumpAndSettle();
      expect(find.text('Gallery'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Mine');
      await tester.pump();
      await tester.tap(find.text('Create view'));
      await tester.pumpAndSettle();
      final s = cubit.state as ViewsReady;
      expect(s.activeView.name, 'Mine');
      expect(s.collection.views.map((v) => v.name).last, 'Mine');
    });

    testWidgets('long-press opens the tab menu', (tester) async {
      await pumpWorkPage(tester);
      await tester.longPress(find.text('Pipeline'));
      await tester.pumpAndSettle();
      expect(find.text('Rename'), findsOneWidget);
      expect(find.text('Duplicate'), findsOneWidget);
    });
  });
}
