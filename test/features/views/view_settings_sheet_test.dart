import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/views/views.dart';
import 'package:morkva_crm/features/views/widgets/fields_editor_sheet.dart';
import 'package:morkva_crm/features/views/widgets/view_settings_sheet.dart';

import '../collections/fake_data_repository.dart';
import 'views_fixtures.dart';
import 'work_page_harness.dart';

const _phone = Size(390, 844);

/// Holds every collection save until [release] (a server ack while offline).
class _SlowRepository extends FakeDataRepository {
  _SlowRepository(super.initial);

  final _held = <Completer<void>>[];

  @override
  Future<void> saveCollection(Collection collection) async {
    final ack = Completer<void>();
    _held.add(ack);
    await ack.future;
    return super.saveCollection(collection);
  }

  /// Acknowledges the held saves in order, and any they lead to.
  Future<void> release(WidgetTester tester) async {
    while (_held.isNotEmpty) {
      _held.removeAt(0).complete();
      await tester.pump();
    }
  }
}

ViewDefinition _view(CollectionViewsCubit cubit) =>
    (cubit.state as ViewsReady).activeView;

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byTooltip('View settings'));
  await tester.pumpAndSettle();
}

Finder _inSheet(Finder finder) =>
    find.descendant(of: find.byType(ViewSettingsSheet), matching: finder);

SegmentedButton<String> _modes(WidgetTester tester) =>
    tester.widget(_inSheet(find.byType(SegmentedButton<String>)));

void main() {
  testWidgets('tune opens the sheet: mode, layout field, sort, fields', (
    tester,
  ) async {
    final cubit = await pumpWorkPage(tester, size: _phone);
    cubit.selectView('board');
    await tester.pumpAndSettle();
    // One tune only.
    expect(find.byIcon(Icons.tune), findsOneWidget);
    await _open(tester);

    expect(
      _inSheet(find.text('View settings  Pipeline', findRichText: true)),
      findsOneWidget,
    );
    expect(_inSheet(find.text('Mode')), findsOneWidget);
    final modes = _modes(tester);
    expect(modes.segments.map((s) => s.value), [
      ViewModeIds.table,
      ViewModeIds.board,
      ViewModeIds.list,
      ViewModeIds.calendar,
    ]);
    expect(modes.selected, {ViewModeIds.board});
    expect(_inSheet(find.text('Group by')), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(
            _inSheet(find.widgetWithText(ChoiceChip, 'Stage')),
          )
          .selected,
      isTrue,
    );
    expect(
      _inSheet(find.widgetWithText(ChoiceChip, 'Company')),
      findsOneWidget,
    );
    // Board needs a field: no "None"; dates can't group.
    expect(_inSheet(find.widgetWithText(ChoiceChip, 'None')), findsNothing);
    expect(_inSheet(find.widgetWithText(ChoiceChip, 'Due')), findsNothing);
    expect(_inSheet(find.text('Sort')), findsOneWidget);
    expect(_inSheet(find.text('Manual order')), findsOneWidget);
    expect(_inSheet(find.text('Card fields')), findsOneWidget);
    expect(_inSheet(find.text('2 shown')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('picking a group field updates the view live', (tester) async {
    final cubit = await pumpWorkPage(tester, size: _phone);
    cubit.selectView('board');
    await tester.pumpAndSettle();
    await _open(tester);
    await tester.tap(_inSheet(find.widgetWithText(ChoiceChip, 'Company')));
    await tester.pumpAndSettle();
    expect(_view(cubit).layoutFieldId, 'company');
    expect(
      tester
          .widget<ChoiceChip>(
            _inSheet(find.widgetWithText(ChoiceChip, 'Company')),
          )
          .selected,
      isTrue,
    );
  });

  testWidgets('switching mode picks a fitting layout field', (tester) async {
    final cubit = await pumpWorkPage(tester, size: _phone);
    await _open(tester);
    expect(_modes(tester).selected, {ViewModeIds.table});
    expect(_inSheet(find.text('Columns')), findsOneWidget);
    // Table has no layout field.
    expect(_inSheet(find.text('Group by')), findsNothing);

    await tester.tap(_inSheet(find.byIcon(const CalendarMode().icon)));
    await tester.pumpAndSettle();
    expect(_view(cubit).mode, ViewModeIds.calendar);
    expect(_view(cubit).layoutFieldId, 'due');
    expect(_inSheet(find.text('Date field')), findsOneWidget);
    expect(_inSheet(find.text('Card fields')), findsOneWidget);

    await tester.tap(_inSheet(find.byIcon(const BoardMode().icon)));
    await tester.pumpAndSettle();
    expect(_view(cubit).mode, ViewModeIds.board);
    expect(_view(cubit).layoutFieldId, 'stage');

    // List grouping is optional and keeps the board's field.
    await tester.tap(_inSheet(find.byIcon(const ListMode().icon)));
    await tester.pumpAndSettle();
    expect(_view(cubit).mode, ViewModeIds.list);
    expect(_view(cubit).layoutFieldId, 'stage');
    await tester.tap(_inSheet(find.widgetWithText(ChoiceChip, 'None')));
    await tester.pumpAndSettle();
    expect(_view(cubit).layoutFieldId, isNull);
  });

  testWidgets('unavailable modes are disabled, with the reason', (
    tester,
  ) async {
    const plain = Collection(
      id: 'deals',
      name: 'Deals',
      fields: [TextFieldDefinition(id: 'name', name: 'Name')],
      views: [
        ViewDefinition(id: 'all', name: 'All', fieldIds: ['name']),
      ],
    );
    final cubit = await pumpWorkPage(
      tester,
      size: _phone,
      repository: workRepository(
        collection: plain,
        // An object, so the table draws rows rather than its ghost row.
        objects: [deal('d1', 0, name: 'Acme')],
      ),
    );
    await _open(tester);
    final segments = {for (final s in _modes(tester).segments) s.value: s};
    expect(segments[ViewModeIds.table]!.enabled, isTrue);
    expect(segments[ViewModeIds.list]!.enabled, isTrue);
    expect(segments[ViewModeIds.board]!.enabled, isFalse);
    expect(segments[ViewModeIds.calendar]!.enabled, isFalse);
    expect(
      _inSheet(find.text('Board: needs a choice or reference field')),
      findsOneWidget,
    );
    expect(_inSheet(find.text('Calendar: needs a date field')), findsOneWidget);
    await tester.tap(_inSheet(find.byIcon(const BoardMode().icon)));
    await tester.pumpAndSettle();
    expect(_view(cubit).mode, ViewModeIds.table);
  });

  testWidgets('Sort replaces the sheet with the sort menu', (tester) async {
    await pumpWorkPage(tester, size: _phone);
    await _open(tester);
    await tester.tap(_inSheet(find.text('Sort')));
    await tester.pumpAndSettle();
    expect(find.byType(ViewSettingsSheet), findsNothing);
    expect(find.byType(SortMenu), findsOneWidget);
  });

  testWidgets('Columns opens the fields editor', (tester) async {
    await pumpWorkPage(tester, size: _phone);
    await _open(tester);
    await tester.tap(_inSheet(find.text('Columns')));
    await tester.pumpAndSettle();
    expect(find.byType(ViewSettingsSheet), findsNothing);
    expect(find.byType(FieldsEditorSheet), findsOneWidget);
  });

  testWidgets('a board that cannot draw hides Sort and Card fields', (
    tester,
  ) async {
    const plain = Collection(
      id: 'deals',
      name: 'Deals',
      fields: [TextFieldDefinition(id: 'name', name: 'Name')],
      views: [
        ViewDefinition(
          id: 'all',
          name: 'Board',
          mode: ViewModeIds.board,
          fieldIds: ['name'],
        ),
      ],
    );
    await pumpWorkPage(
      tester,
      size: _phone,
      repository: workRepository(collection: plain, objects: const []),
    );
    await _open(tester);
    expect(_inSheet(find.text('Mode')), findsOneWidget);
    expect(_inSheet(find.text('Sort')), findsNothing);
    expect(_inSheet(find.text('Card fields')), findsNothing);
  });

  testWidgets('no fields: no view settings; Customize uses tune', (
    tester,
  ) async {
    await pumpWorkPage(
      tester,
      size: _phone,
      repository: workRepository(
        collection: const Collection(id: 'deals', name: 'Deals'),
        objects: const [],
      ),
    );
    expect(find.byTooltip('View settings'), findsNothing);
    // Only the Customize button: tune means Customize everywhere.
    expect(find.byIcon(Icons.tune), findsOneWidget);
    expect(find.widgetWithIcon(PrimaryButton, Icons.tune), findsOneWidget);
    expect(find.byTooltip('More'), findsOneWidget);
  });

  testWidgets('desktop no fields: both Customize actions use tune', (
    tester,
  ) async {
    await pumpWorkPage(
      tester,
      repository: workRepository(
        collection: const Collection(id: 'deals', name: 'Deals'),
        objects: const [],
      ),
    );
    expect(find.byIcon(Icons.tune), findsNWidgets(2));
    expect(find.text('Customize'), findsNWidgets(2));
  });

  testWidgets('rapid mode switches with slow saves end consistent', (
    tester,
  ) async {
    final repo = _SlowRepository([deals, companies]);
    repo.seedObjects('deals', sampleDeals());
    final cubit = await pumpWorkPage(tester, size: _phone, repository: repo);
    await _open(tester);
    for (final mode in const [CalendarMode(), ListMode(), BoardMode()]) {
      await tester.tap(_inSheet(find.byIcon(mode.icon)));
      await tester.pump();
    }
    await repo.release(tester);
    await tester.pumpAndSettle();
    expect(_view(cubit).mode, ViewModeIds.board);
    expect(_view(cubit).layoutFieldId, 'stage');
  });

  testWidgets('a mode that can\'t use the layout field clears it', (
    tester,
  ) async {
    final cubit = await pumpWorkPage(tester, size: _phone);
    await _open(tester);
    await tester.tap(_inSheet(find.byIcon(const CalendarMode().icon)));
    await tester.pumpAndSettle();
    expect(_view(cubit).layoutFieldId, 'due');

    // List can't group by a date: no "Group: Due".
    await tester.tap(_inSheet(find.byIcon(const ListMode().icon)));
    await tester.pumpAndSettle();
    expect(_view(cubit).mode, ViewModeIds.list);
    expect(_view(cubit).layoutFieldId, isNull);
    expect(
      tester
          .widget<ChoiceChip>(_inSheet(find.widgetWithText(ChoiceChip, 'None')))
          .selected,
      isTrue,
    );
  });

  testWidgets('Board → Table → Board keeps the group-by field', (tester) async {
    final cubit = await pumpWorkPage(tester, size: _phone);
    await _open(tester);
    await tester.tap(_inSheet(find.byIcon(const BoardMode().icon)));
    await tester.pumpAndSettle();
    await cubit.setLayoutField('company');
    await tester.pumpAndSettle();
    await tester.tap(_inSheet(find.byIcon(const TableMode().icon)));
    await tester.pumpAndSettle();
    expect(_view(cubit).mode, ViewModeIds.table);
    expect(_view(cubit).layoutFieldId, 'company');
    await tester.tap(_inSheet(find.byIcon(const BoardMode().icon)));
    await tester.pumpAndSettle();
    expect(_view(cubit).mode, ViewModeIds.board);
    expect(_view(cubit).layoutFieldId, 'company');
  });
}
