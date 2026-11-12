import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:morkva_crm/api/data/data_repository.dart';
import 'package:morkva_crm/api/sync/sync_status.dart';
import 'package:morkva_crm/api/sync/sync_status_cubit.dart';
import 'package:morkva_crm/core/import/trello/trello_board.dart';
import 'package:morkva_crm/core/import/trello/trello_mapper.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/settings/import/trello_import_cubit.dart';
import 'package:morkva_crm/features/settings/import/trello_import_sheet.dart';

import '../../automation/view/automation_view_harness.dart'
    show phoneWindow, setWindow, wideWindow;
import '../../collections/fake_data_repository.dart';

class _MockSync extends MockCubit<SyncStatus> implements SyncStatusCubit {}

final _sample = File(
  'test/core/import/trello/fixtures/sample_board.json',
).readAsStringSync();

final _summary = summarizeTrelloBoard(
  TrelloBoard.parse(_sample),
  includeArchived: false,
);

/// The kit's targets are 44 px (DESIGN.md), not Android's 48.
const _tapTargets = MinimumTapTargetGuideline(
  size: Size(44, 44),
  link: 'DESIGN.md §7',
);

void main() {
  late FakeDataRepository repo;
  late List<TrelloExportFile> picked;

  setUp(() {
    repo = FakeDataRepository();
    picked = [(name: 'sales.json', text: _sample)];
  });

  /// Pumps a page with an "open" button; returns what the sheet completes
  /// with.
  Future<List<String?>> open(
    WidgetTester tester, {
    Size size = wideWindow,
    SyncStatus sync = const SyncSynced(),
  }) async {
    setWindow(tester, size);
    final syncCubit = _MockSync();
    when(() => syncCubit.state).thenReturn(sync);
    final result = <String?>[];
    await tester.pumpWidget(
      RepositoryProvider<DataRepository>.value(
        value: repo,
        child: BlocProvider<SyncStatusCubit>.value(
          value: syncCubit,
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async => result.add(
                    await showTrelloImportSheet(
                      context,
                      pickFiles: () async => picked,
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).last);
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  PrimaryButton primary(WidgetTester tester, String label) =>
      tester.widget(find.widgetWithText(PrimaryButton, label));

  Future<void> toChoose(WidgetTester tester) async {
    await tapText(tester, 'Choose files');
    await tapText(tester, 'Continue');
  }

  /// Writes are under way: the spinner never settles, so pump by time.
  Future<void> startImport(WidgetTester tester) async {
    await tester.tap(find.text('Import 3 collections'));
    await tester.pump();
    await tester.pump();
  }

  group('add boards', () {
    testWidgets('empty: no boards yet, Continue waits with its hint', (
      tester,
    ) async {
      await open(tester);
      expect(find.text('Import from Trello'), findsOneWidget);
      expect(find.text('Step 1 of 2 · Add boards'), findsOneWidget);
      expect(find.text('No boards yet'), findsOneWidget);
      expect(find.text('Add at least one board'), findsOneWidget);
      expect(primary(tester, 'Continue').onPressed, isNull);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Import from Trello'), findsNothing);
    });

    for (final (name, size) in [('wide', wideWindow), ('phone', phoneWindow)]) {
      testWidgets('$name: a scrim tap or drag keeps the sheet', (tester) async {
        await open(tester, size: size);
        await tester.tapAt(const Offset(4, 4));
        await tester.pumpAndSettle();
        expect(find.text('Import from Trello'), findsOneWidget);
        await tester.drag(
          find.text('Import from Trello'),
          const Offset(0, 600),
        );
        await tester.pumpAndSettle();
        expect(find.text('Import from Trello'), findsOneWidget);
      });
    }

    testWidgets('a picked file becomes a board row; remove takes it out', (
      tester,
    ) async {
      await open(tester);
      await tapText(tester, 'Choose files');
      expect(find.text('Sales Pipeline'), findsOneWidget);
      expect(find.text('Boards to import · 1'), findsOneWidget);
      expect(
        find.text(
          '${_summary.lists} lists · ${_summary.cards} cards · '
          '${_summary.checklistItems} checklist items · '
          '${_summary.comments} comments',
        ),
        findsOneWidget,
      );
      expect(find.text('No boards yet'), findsNothing);
      expect(primary(tester, 'Continue').onPressed, isNotNull);

      await tapText(tester, 'Choose files');
      expect(find.text('sales.json'), findsOneWidget);
      expect(find.text('Already added'), findsOneWidget);
      expect(find.text('Sales Pipeline'), findsOneWidget);

      await tester.tap(find.byTooltip('Remove Sales Pipeline'));
      await tester.pumpAndSettle();
      expect(find.text('Sales Pipeline'), findsNothing);
      expect(primary(tester, 'Continue').onPressed, isNull);
    });

    testWidgets('a file that is not a board shows a dismissible problem', (
      tester,
    ) async {
      picked = [(name: 'contacts.csv', text: 'name,email')];
      await open(tester);
      await tapText(tester, 'Choose files');
      expect(find.text('contacts.csv'), findsOneWidget);
      expect(
        find.text(
          "This isn't a Trello board export. Use Export as JSON on the board.",
        ),
        findsOneWidget,
      );
      expect(primary(tester, 'Continue').onPressed, isNull);

      await tester.tap(find.byTooltip('Dismiss contacts.csv'));
      await tester.pumpAndSettle();
      expect(find.text('contacts.csv'), findsNothing);
      expect(find.text('No boards yet'), findsOneWidget);
    });

    testWidgets('a picker that throws shows a problem, not a crash', (
      tester,
    ) async {
      setWindow(tester, wideWindow);
      await tester.pumpWidget(
        RepositoryProvider<DataRepository>.value(
          value: repo,
          child: MaterialApp(
            theme: AppTheme.light,
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => showTrelloImportSheet(
                  context,
                  pickFiles: () => throw StateError('no access'),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tapText(tester, 'Choose files');
      expect(
        find.text(
          "Couldn't read the chosen files. Choose them again, or paste one.",
        ),
        findsOneWidget,
      );
    });

    testWidgets('paste: Add board adds and clears; the same board again is '
        'noted under the field', (tester) async {
      await open(tester);
      await tapText(tester, 'Paste');
      expect(find.text('Board JSON'), findsOneWidget);
      final add = find.widgetWithText(SecondaryButton, 'Add board');
      expect(tester.widget<SecondaryButton>(add).onPressed, isNull);

      await tester.enterText(find.byType(TextField), _sample);
      await tester.pump();
      await tapText(tester, 'Add board');
      expect(find.text('Sales Pipeline'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );

      await tester.enterText(find.byType(TextField), _sample);
      await tester.pump();
      await tapText(tester, 'Add board');
      expect(find.text('Already added'), findsOneWidget);
      expect(find.text('Pasted text'), findsNothing, reason: 'not a row');
      expect(find.text('Sales Pipeline'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '{');
      await tester.pump();
      expect(find.text('Already added'), findsNothing, reason: 'edited');
    });
  });

  group('choose', () {
    testWidgets('defaults tick everything; unticking the board disables its '
        'children and recounts', (tester) async {
      await open(tester);
      await toChoose(tester);
      expect(find.text('Step 2 of 2 · Choose what to import'), findsOneWidget);
      expect(
        find.textContaining("Automations can't come along."),
        findsOneWidget,
      );
      expect(find.text('Include archived cards and lists'), findsOneWidget);
      expect(
        find.text(
          '${_summary.archivedCards} archived cards. They get an Archived '
          'checkbox and stay off the board view.',
        ),
        findsOneWidget,
      );
      expect(find.text('Checklist items'), findsOneWidget);
      expect(find.text('Comments'), findsOneWidget);
      for (final name in _summary.fieldNames) {
        expect(find.text(name), findsWidgets, reason: name);
      }
      expect(primary(tester, 'Import 3 collections').onPressed, isNotNull);

      await tapText(tester, 'Comments');
      expect(find.text('Import 2 collections'), findsOneWidget);

      await tapText(tester, 'Sales Pipeline');
      expect(find.text('Import 0 collections'), findsOneWidget);
      expect(find.text('Choose at least one collection'), findsOneWidget);
      expect(
        find.text('${_summary.checklistItems} items · needs the board'),
        findsOneWidget,
      );
      final boxes = tester.widgetList<Checkbox>(find.byType(Checkbox)).toList();
      expect(boxes.map((b) => b.onChanged != null), [true, false, false]);
      expect(boxes.map((b) => b.value), [false, false, false]);

      await tapText(tester, 'Back');
      expect(find.text('Step 1 of 2 · Add boards'), findsOneWidget);
      expect(find.text('Sales Pipeline'), findsOneWidget);
    });

    testWidgets('archived on: counts follow', (tester) async {
      final withArchived = summarizeTrelloBoard(
        TrelloBoard.parse(_sample),
        includeArchived: true,
      );
      await open(tester);
      await toChoose(tester);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(
        find.text('${withArchived.cards} cards · ${withArchived.lists} lists'),
        findsOneWidget,
      );
    });

    testWidgets('offline from the start: Import waits with the reason', (
      tester,
    ) async {
      await open(tester, sync: const SyncOffline());
      await toChoose(tester);
      expect(find.text("You're offline — connect to import"), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
      expect(primary(tester, 'Import 3 collections').onPressed, isNull);
    });

    testWidgets('a phone shows six field chips and the rest as a count', (
      tester,
    ) async {
      await open(tester, size: phoneWindow);
      await toChoose(tester);
      final more = _summary.fieldNames.length - 6;
      expect(more, greaterThan(0), reason: 'the fixture has enough fields');
      expect(
        find.text('+$more more ${more == 1 ? 'field' : 'fields'}'),
        findsOneWidget,
      );
      expect(find.text(_summary.fieldNames.last), findsNothing);
    });
  });

  group('importing', () {
    testWidgets('imports to Done; Open completes with the collection', (
      tester,
    ) async {
      final result = await open(tester);
      await toChoose(tester);
      await tester.tap(find.text('Import 3 collections'));
      await tester.pumpAndSettle();

      expect(find.text('Your boards are in'), findsOneWidget);
      final total =
          _summary.cards + _summary.checklistItems + _summary.comments;
      expect(find.text('3 collections · $total cards'), findsOneWidget);
      expect(
        find.text('${_summary.cards} cards · board view by List'),
        findsOneWidget,
      );
      expect(find.text('Open'), findsNWidgets(3));
      expect(
        find.text(
          'Used Butler in Trello? Set up the same steps as Morkva '
          'automations.',
        ),
        findsOneWidget,
      );

      final boardId = (await repo.getCollections())
          .firstWhere((c) => c.name == 'Sales Pipeline')
          .id;
      await tester.tap(find.text('Open').first);
      await tester.pumpAndSettle();
      expect(result, ['/collections/$boardId']);
    });

    testWidgets('Done step: Automations completes with /automations', (
      tester,
    ) async {
      final result = await open(tester);
      await toChoose(tester);
      await tester.tap(find.text('Import 3 collections'));
      await tester.pumpAndSettle();
      await tapText(tester, 'Automations');
      expect(result, ['/automations']);
    });

    testWidgets('a stall pauses with Close and Retry; Retry finishes', (
      tester,
    ) async {
      final result = await open(tester);
      await toChoose(tester);
      repo.batchNeverCompletes = true;
      await startImport(tester);

      expect(find.text('Importing from Trello'), findsOneWidget);
      expect(find.text('Writing — keep this open'), findsOneWidget);
      expect(find.text("Imported cards don't start automations."), findsOne);
      expect(primary(tester, 'Done').onPressed, isNull);
      expect(find.byTooltip('Close'), findsNothing);
      // Back can't close the sheet mid-write.
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Importing from Trello'), findsOneWidget);

      await tester.pump(const Duration(seconds: 30));
      await tester.pump();
      expect(
        find.text('Import paused. ${TrelloImportCubit.stalledMessage}'),
        findsOneWidget,
      );
      expect(find.text('Close'), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

      repo.batchNeverCompletes = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Your boards are in'), findsOneWidget);
      await tapText(tester, 'Done');
      expect(result, [null]);
    });

    testWidgets('a refused write pauses with its own copy; Close keeps it', (
      tester,
    ) async {
      final result = await open(tester);
      await toChoose(tester);
      repo.batchWriteError = (_) => 'permission-denied';
      await tester.tap(find.text('Import 3 collections'));
      await tester.pumpAndSettle();
      expect(
        find.text('Import paused. ${TrelloImportCubit.refusedMessage}'),
        findsOneWidget,
      );
      await tapText(tester, 'Close');
      expect(result, [null]);
      expect(await repo.getCollections(), hasLength(3));
    });
  });

  testWidgets('every step fits a phone', (tester) async {
    await open(tester, size: phoneWindow);
    expect(find.text('No boards yet'), findsOneWidget);
    await tapText(tester, 'Paste');
    await tapText(tester, 'Files');
    await tapText(tester, 'Choose files');
    await tapText(tester, 'Continue');
    await tapText(tester, 'Sales Pipeline');
    await tapText(tester, 'Sales Pipeline');
    repo.batchNeverCompletes = true;
    await startImport(tester);
    await tester.pump(const Duration(seconds: 30));
    await tester.pump();
    expect(find.text('Retry'), findsOneWidget);
    repo.batchNeverCompletes = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Your boards are in'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // No textContrastGuideline: it runs real async, where google_fonts tries
  // (and fails) to fetch the theme's fonts.
  group('desktop targets', () {
    testWidgets('add, choose and done meet 44 px targets', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester);
      final segments = tester.getSize(
        find.byWidgetPredicate((w) => w is SegmentedButton),
      );
      expect(segments.height, 44);
      await tapText(tester, 'Choose files');
      await expectLater(tester, meetsGuideline(_tapTargets));

      await tapText(tester, 'Continue');
      // Unticked: the disabled children are not targets.
      await tapText(tester, 'Sales Pipeline');
      await expectLater(tester, meetsGuideline(_tapTargets));
      await tapText(tester, 'Sales Pipeline');
      await tapText(tester, 'Comments');

      await tester.tap(find.text('Import 2 collections'));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(_tapTargets));
      handle.dispose();
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
  });
}
