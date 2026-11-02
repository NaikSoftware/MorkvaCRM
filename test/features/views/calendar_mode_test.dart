import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/views/modes/calendar_mode.dart';
import 'package:morkva_crm/features/views/views.dart';
import 'package:morkva_crm/features/views/widgets/calendar/month_calendar.dart';
import 'package:morkva_crm/features/views/widgets/calendar/no_date_tray.dart';

import '../collections/fake_data_repository.dart';
import 'views_fixtures.dart';

const _calendarView = ViewDefinition(
  id: 'cal',
  name: 'Due dates',
  mode: ViewModeIds.calendar,
  layoutFieldId: 'due',
  fieldIds: ['name', 'amount'],
);

final _today = DateTime(2026, 11, 2, 10);

class _Recorder {
  final notes = <(String, ViewUndo?)>[];
  final quickAdds = <DateTime?>[];
  final opened = <String>[];
}

Future<(CollectionViewsCubit, FakeDataRepository, _Recorder)> _pump(
  WidgetTester tester, {
  required List<MorkvaObject> objects,
  Collection? collection,
  Size size = const Size(1280, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final repo = FakeDataRepository([
    collection ?? deals.copyWith(views: [_calendarView]),
  ]);
  repo.seedObjects('deals', objects);
  final cubit = CollectionViewsCubit(repo, 'deals')..initialize();
  addTearDown(cubit.close);
  final rec = _Recorder();

  await tester.pumpWidget(
    BlocProvider.value(
      value: cubit,
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: BlocBuilder<CollectionViewsCubit, CollectionViewsState>(
            builder: (context, state) => state is! ViewsReady
                ? const SizedBox.shrink()
                : CalendarBody(
                    clock: () => _today,
                    data: ViewModeData(
                      state: state,
                      itemLabel: 'deal',
                      openObject: (o) => rec.opened.add(o.id),
                      quickAdd: ({groupKey, day}) => rec.quickAdds.add(day),
                      editFields: () {},
                      notify: (m, {undo}) => rec.notes.add((m, undo)),
                    ),
                  ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return (cubit, repo, rec);
}

Finder _cell(DateTime day) => find.byKey(ValueKey(day));

Future<void> _dragTo(WidgetTester tester, Finder from, Finder to) async {
  final gesture = await tester.startGesture(tester.getCenter(from));
  await gesture.moveBy(const Offset(12, 12));
  await tester.pump();
  await gesture.moveTo(tester.getCenter(to));
  await tester.pump();
  await gesture.up();
  await tester.pump();
  await tester.pump();
}

DateFieldValue _stored(FakeDataRepository repo, String id, String field) =>
    repo.objectsOf('deals').firstWhere((o) => o.id == id)[field]!
        as DateFieldValue;

void main() {
  group('CalendarMode', () {
    const mode = CalendarMode();

    test('lays out by a date field; unavailable without one', () {
      expect(mode.id, ViewModeIds.calendar);
      expect(mode.needsLayoutField, isTrue);
      expect(mode.acceptsLayoutField(dueField), isTrue);
      expect(mode.acceptsLayoutField(stageField), isFalse);
      expect(mode.unavailableReason(deals), isNull);
      expect(
        mode.unavailableReason(
          const Collection(
            id: 'x',
            name: 'X',
            fields: [TextFieldDefinition(id: 'name', name: 'Name')],
          ),
        ),
        'Needs a date field',
      );
      expect(
        defaultViewModeRegistry().byId(ViewModeIds.calendar),
        isA<CalendarMode>(),
      );
    });
  });

  group('month grid', () {
    testWidgets('November 2026: Monday-first, 6 weeks, today marked', (
      tester,
    ) async {
      await _pump(
        tester,
        objects: [deal('a', 0, name: 'Acme', due: DateTime.utc(2026, 11, 14))],
      );
      expect(find.text('November 2026'), findsOneWidget);
      // Nov 1 2026 is a Sunday: the grid starts Mon 26 Oct, ends Sun 6 Dec.
      expect(_cell(DateTime(2026, 10, 26)), findsOneWidget);
      expect(_cell(DateTime(2026, 10, 25)), findsNothing);
      expect(_cell(DateTime(2026, 12, 6)), findsOneWidget);
      expect(_cell(DateTime(2026, 12, 7)), findsNothing);
      final first = tester.getTopLeft(_cell(DateTime(2026, 10, 26)));
      final mon = tester.getTopLeft(_cell(DateTime(2026, 11, 2)));
      final sun = tester.getTopLeft(_cell(DateTime(2026, 11, 1)));
      expect(mon.dx, first.dx);
      expect(sun.dy, first.dy);
      expect(
        tester.getSize(_cell(DateTime(2026, 11, 2))).height,
        greaterThanOrEqualTo(MonthCalendar.minCellHeight - 1),
      );
      // A date-only value sits on its own day whatever the machine's zone.
      expect(
        find.descendant(
          of: _cell(DateTime(2026, 11, 14)),
          matching: find.text('Acme'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('prev / next / Today move the month', (tester) async {
      await _pump(tester, objects: const []);
      await tester.tap(find.byTooltip('Next month'));
      await tester.pump();
      expect(find.text('December 2026'), findsOneWidget);
      await tester.tap(find.byTooltip('Previous month'));
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pump();
      expect(find.text('October 2026'), findsOneWidget);
      await tester.tap(find.text('Today'));
      await tester.pump();
      expect(find.text('November 2026'), findsOneWidget);
    });

    testWidgets('a full day shows what fits, then "+N more" opens the list', (
      tester,
    ) async {
      final (_, _, rec) = await _pump(
        tester,
        objects: [
          for (var i = 0; i < 5; i++)
            deal('x$i', i, name: 'Deal $i', due: DateTime.utc(2026, 11, 10)),
        ],
      );
      final cell = _cell(DateTime(2026, 11, 10));
      final pills = find.descendant(
        of: cell,
        matching: find.byType(ObjectCard),
      );
      final shown = pills.evaluate().length;
      expect(shown, inInclusiveRange(1, 3));
      expect(
        find.descendant(of: cell, matching: find.text('+${5 - shown} more')),
        findsOneWidget,
      );
      await tester.tap(find.text('+${5 - shown} more'));
      await tester.pumpAndSettle();
      expect(find.text('Tue 10 Nov'), findsOneWidget);
      await tester.tap(find.text('Deal 4'));
      await tester.pumpAndSettle();
      expect(rec.opened, ['x4']);
    });

    testWidgets('three items fit a 112+ px cell without "+more"', (
      tester,
    ) async {
      await _pump(
        tester,
        size: const Size(1280, 1400),
        objects: [
          for (var i = 0; i < 3; i++)
            deal('x$i', i, name: 'Deal $i', due: DateTime.utc(2026, 11, 10)),
        ],
      );
      expect(find.textContaining('more'), findsNothing);
      expect(find.text('Deal 2'), findsOneWidget);
    });

    testWidgets('the cell "+" quick-adds on that day', (tester) async {
      final (_, _, rec) = await _pump(tester, objects: const []);
      await tester.tap(find.byTooltip('New deal on Fri 20 Nov'));
      expect(rec.quickAdds, [DateTime(2026, 11, 20)]);
    });

    testWidgets('drag a date-only pill to a day writes that UTC day', (
      tester,
    ) async {
      final (_, repo, rec) = await _pump(
        tester,
        objects: [deal('a', 0, name: 'Acme', due: DateTime.utc(2026, 11, 14))],
      );
      await _dragTo(tester, find.text('Acme'), _cell(DateTime(2026, 11, 15)));
      expect(
        _stored(repo, 'a', 'due'),
        DateFieldValue(DateTime.utc(2026, 11, 15)),
      );
      expect(rec.notes.single.$1, 'Moved "Acme" to Sun 15 Nov');
      expect(rec.notes.single.$2, isNotNull);
      expect(
        find.descendant(
          of: _cell(DateTime(2026, 11, 15)),
          matching: find.text('Acme'),
        ),
        findsOneWidget,
      );

      await rec.notes.single.$2!();
      await tester.pump();
      expect(
        _stored(repo, 'a', 'due'),
        DateFieldValue(DateTime.utc(2026, 11, 14)),
      );
    });

    testWidgets('drag a timed pill to a day keeps the time of day', (
      tester,
    ) async {
      final meeting = DateTime(2026, 11, 3, 14, 30).toUtc();
      final (_, repo, _) = await _pump(
        tester,
        collection: deals.copyWith(
          views: [_calendarView.copyWith(layoutFieldId: 'meeting')],
        ),
        objects: [deal('m', 0, name: 'Kickoff', meeting: meeting)],
      );
      await _dragTo(tester, find.text('Kickoff'), _cell(DateTime(2026, 11, 5)));
      final stored = _stored(repo, 'm', 'meeting').value!;
      expect(calendarDayOf(meetingField, stored), DateTime(2026, 11, 5));
      final local = stored.toLocal();
      expect([local.hour, local.minute], [14, 30]);
    });

    testWidgets('dropping on the same day does nothing', (tester) async {
      final (_, _, rec) = await _pump(
        tester,
        objects: [deal('a', 0, name: 'Acme', due: DateTime.utc(2026, 11, 14))],
      );
      await _dragTo(tester, find.text('Acme'), _cell(DateTime(2026, 11, 14)));
      expect(rec.notes, isEmpty);
    });

    testWidgets('tray lists undated items; dropping a pill on it clears', (
      tester,
    ) async {
      final (_, repo, rec) = await _pump(
        tester,
        objects: [
          deal('a', 0, name: 'Acme', due: DateTime.utc(2026, 11, 14)),
          deal('b', 1, name: 'Hooli'),
        ],
      );
      expect(find.text('No date'), findsOneWidget);
      final tray = find.byType(NoDateTray);
      expect(
        find.descendant(of: tray, matching: find.text('Hooli')),
        findsOneWidget,
      );
      await _dragTo(tester, find.text('Acme'), tray);
      expect(_stored(repo, 'a', 'due'), const DateFieldValue(null));
      expect(rec.notes.single.$1, 'Cleared the date of "Acme"');
      expect(rec.notes.single.$2, isNotNull);
      expect(
        find.descendant(of: tray, matching: find.text('Acme')),
        findsOneWidget,
      );

      // And from the tray onto a day.
      await _dragTo(tester, find.text('Hooli'), _cell(DateTime(2026, 11, 20)));
      expect(
        _stored(repo, 'b', 'due'),
        DateFieldValue(DateTime.utc(2026, 11, 20)),
      );
    });

    testWidgets('the tray collapses to a count', (tester) async {
      await _pump(tester, objects: [deal('b', 1, name: 'Hooli')]);
      await tester.tap(find.byTooltip('Hide No date'));
      await tester.pumpAndSettle();
      expect(find.text('Hooli'), findsNothing);
      expect(find.byTooltip('Show No date (1)'), findsOneWidget);
      await tester.tap(find.byTooltip('Show No date (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Hooli'), findsOneWidget);
    });
  });

  group('empty states', () {
    testWidgets('no date field → "Calendar needs a date field"', (
      tester,
    ) async {
      await _pump(
        tester,
        collection: const Collection(
          id: 'deals',
          name: 'Deals',
          fields: [TextFieldDefinition(id: 'name', name: 'Name')],
          views: [
            ViewDefinition(
              id: 'cal',
              name: 'Cal',
              mode: ViewModeIds.calendar,
              fieldIds: ['name'],
            ),
          ],
        ),
        objects: const [],
      );
      expect(find.text('Calendar needs a date field'), findsOneWidget);
      expect(find.text('Add date field'), findsOneWidget);
    });

    testWidgets('no layout field picked → choose one', (tester) async {
      final (cubit, _, _) = await _pump(
        tester,
        collection: deals.copyWith(
          views: [_calendarView.copyWith(layoutFieldId: null)],
        ),
        objects: const [],
      );
      expect(find.text('Choose a date field'), findsOneWidget);
      await tester.tap(find.text('Meeting'));
      await tester.pump();
      expect((cubit.state as ViewsReady).activeView.layoutFieldId, 'meeting');
    });
  });

  group('agenda (phone)', () {
    testWidgets('week strip, day headers, No date last; no drag', (
      tester,
    ) async {
      await _pump(
        tester,
        size: const Size(390, 844),
        objects: [
          deal('a', 0, name: 'Acme', due: DateTime.utc(2026, 11, 4)),
          deal('c', 2, name: 'Today deal', due: DateTime.utc(2026, 11, 2)),
          deal('b', 1, name: 'Hooli'),
        ],
      );
      await tester.pumpAndSettle();
      expect(find.byType(Draggable<String>), findsNothing);
      expect(find.text('Mon 2 Nov · Today'), findsOneWidget);
      expect(find.text('Wed 4 Nov'), findsOneWidget);
      expect(find.text('No date (1)'), findsOneWidget);
      expect(find.text('Hooli'), findsNothing);
      await tester.tap(find.text('No date (1)'));
      await tester.pump();
      expect(find.text('Hooli'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Wed 4 Nov')).dy,
        lessThan(tester.getTopLeft(find.text('No date (1)')).dy),
      );
    });

    testWidgets('long-press → Move to date writes the picked day', (
      tester,
    ) async {
      final (_, repo, rec) = await _pump(
        tester,
        size: const Size(390, 844),
        objects: [deal('a', 0, name: 'Acme', due: DateTime.utc(2026, 11, 4))],
      );
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Acme'));
      await tester.pumpAndSettle();
      expect(find.text('Move to date'), findsOneWidget);
      await tester.tap(find.text('12'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(
        _stored(repo, 'a', 'due'),
        DateFieldValue(DateTime.utc(2026, 11, 12)),
      );
      expect(rec.notes.single.$1, 'Moved "Acme" to Thu 12 Nov');
    });
  });
}
