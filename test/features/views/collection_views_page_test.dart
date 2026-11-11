import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/app/shell/shell_sidebar.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:morkva_crm/features/objects/object_editor.dart';
import 'package:morkva_crm/features/objects/object_editor_cubit.dart';
import 'package:morkva_crm/features/views/views.dart';
import 'package:morkva_crm/features/views/widgets/no_matches_notice.dart';

import 'views_fixtures.dart';
import 'work_page_harness.dart';

const _phone = Size(390, 844);

List<String> _rowTitles(WidgetTester tester) =>
    [
      for (final name in [
        'Acme renewal',
        'Globex pilot',
        'Initech',
        'Umbrella',
        'Hooli',
      ])
        if (find.text(name).evaluate().isNotEmpty) name,
    ]..sort(
      (a, b) => tester
          .getTopLeft(find.text(a))
          .dy
          .compareTo(tester.getTopLeft(find.text(b)).dy),
    );

void main() {
  setUp(resetFirstItemNudges);

  group('loading', () {
    testWidgets('the skeleton shows only after 150 ms', (tester) async {
      await pumpWorkPage(tester, initialize: false);
      expect(find.bySemanticsLabel('Loading'), findsNothing);
      await tester.pump(const Duration(milliseconds: 160));
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    });
  });

  group('wide', () {
    testWidgets('header, rail, tabs, toolbar and the table', (tester) async {
      await pumpWorkPage(tester);
      expect(find.byType(ShellSidebar), findsOneWidget);
      expect(find.text('Deals'), findsOneWidget);
      expect(find.text('Customize'), findsOneWidget);
      expect(find.text('New deal'), findsWidgets);
      expect(find.text('All deals'), findsOneWidget);
      expect(find.text('Pipeline'), findsOneWidget);
      expect(find.text('Filter'), findsOneWidget);
      expect(find.text('Sort'), findsOneWidget);
      expect(find.text('Columns'), findsOneWidget);
      expect(_rowTitles(tester), [
        'Acme renewal',
        'Globex pilot',
        'Initech',
        'Umbrella',
        'Hooli',
      ]);
      // Select cells as pills, references by label.
      expect(find.widgetWithText(OptionPill, 'Lead'), findsNWidgets(2));
      expect(find.text('Alpha Ltd'), findsOneWidget);
      expect(find.text('1,200 USD'), findsOneWidget);
      expect(find.text('5 deals'), findsOneWidget);
    });

    testWidgets('header taps cycle the sort asc → desc → none', (tester) async {
      final cubit = await pumpWorkPage(tester);
      await tester.tap(find.bySemanticsLabel('Sort by Amount'));
      await tester.pumpAndSettle();
      expect(
        (cubit.state as ViewsReady).activeView.sort,
        const ViewSort(fieldId: 'amount'),
      );
      expect(_rowTitles(tester).take(3), [
        'Initech',
        'Globex pilot',
        'Acme renewal',
      ]);
      expect(find.byIcon(Icons.arrow_upward), findsWidgets);

      await tester.tap(find.bySemanticsLabel('Sort by Amount'));
      await tester.pumpAndSettle();
      expect(_rowTitles(tester).take(3), [
        'Acme renewal',
        'Globex pilot',
        'Initech',
      ]);

      await tester.tap(find.bySemanticsLabel('Sort by Amount'));
      await tester.pumpAndSettle();
      expect((cubit.state as ViewsReady).activeView.sort, isNull);
    });

    testWidgets('Customize opens the editor', (tester) async {
      await pumpWorkPage(tester);
      await tester.tap(find.text('Customize'));
      await tester.pumpAndSettle();
      expect(find.text('editor:deals'), findsOneWidget);
    });

    testWidgets('Columns opens the fields editor', (tester) async {
      await pumpWorkPage(tester);
      await tester.tap(find.text('Columns'));
      await tester.pumpAndSettle();
      expect(find.text('PREVIEW'), findsOneWidget);
    });

    testWidgets('Columns Save writes the view fieldIds', (tester) async {
      final cubit = await pumpWorkPage(tester);
      await tester.tap(find.text('Columns'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Company').last);
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect((cubit.state as ViewsReady).activeView.fieldIds, [
        'name',
        'amount',
        'stage',
      ]);
      expect(find.text('PREVIEW'), findsNothing);
    });

    testWidgets('switching tabs shows the other view', (tester) async {
      final cubit = await pumpWorkPage(tester);
      await tester.tap(find.text('Pipeline'));
      await tester.pumpAndSettle();
      expect((cubit.state as ViewsReady).activeViewId, 'board');
    });
  });

  group('fix round 1', () {
    testWidgets('Customize is a quiet outlined button', (tester) async {
      await pumpWorkPage(tester);
      expect(
        find.ancestor(
          of: find.text('Customize'),
          matching: find.byWidgetPredicate((w) => w is OutlinedButton),
        ),
        findsOneWidget,
      );
    });

    testWidgets('no ghost row while the table has objects', (tester) async {
      await pumpWorkPage(tester);
      // Only the header button.
      expect(find.text('New deal'), findsOneWidget);
      expect(find.text('Change fields'), findsNothing);
    });

    testWidgets('the table card hugs its rows on phone', (tester) async {
      await pumpWorkPage(tester, size: _phone);
      final table = tester.getRect(
        find
            .descendant(
              of: find.byType(ViewTable),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      // header 44 + 5 rows x 52 + footer 40.
      expect(table.height, 44 + 5 * 52 + 40);
    });
  });

  group('squeezed by a side panel', () {
    for (final width in [590.0, 750.0]) {
      testWidgets('keeps the desktop frame at $width px', (tester) async {
        final cubit = await pumpWorkPage(
          tester,
          size: const Size(1440, 900),
          pageWidth: width,
        );
        await tester.pumpAndSettle();
        for (final view in ['all', 'board']) {
          cubit.selectView(view);
          await tester.pumpAndSettle();
          expect(find.byTooltip('Back'), findsNothing);
          expect(find.byType(FloatingActionButton), findsNothing);
          expect(find.text('New deal'), findsOneWidget);
          expect(
            width < 720 ? find.byTooltip('Customize') : find.text('Customize'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull, reason: '$view at $width');
        }
      });
    }
  });

  group('phone', () {
    testWidgets('an empty one-column table fits at 390', (tester) async {
      const narrow = Collection(
        id: 'deals',
        name: 'Deals',
        fields: [TextFieldDefinition(id: 'name', name: 'Name')],
        views: [
          ViewDefinition(id: 'all', name: 'All', fieldIds: ['name']),
        ],
      );
      await pumpWorkPage(
        tester,
        size: _phone,
        repository: workRepository(collection: narrow, objects: const []),
      );
      expect(find.text('Change fields'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('pushed-route header, FAB, chips row only', (tester) async {
      await pumpWorkPage(tester, size: _phone);
      expect(find.byType(ShellSidebar), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byTooltip('Back'), findsOneWidget);
      expect(find.byTooltip('View settings'), findsOneWidget);
      // No assistant provided: no Ask Morkva entry.
      expect(find.byTooltip('Ask Morkva'), findsNothing);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      // A round "+" floating over the body, "New <item>" on hover.
      expect(find.byTooltip('New deal'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(FloatingActionButton),
          matching: find.byIcon(Icons.add),
        ),
        findsOneWidget,
      );
      expect(find.text('Sort'), findsNothing);
      expect(find.text('Filter'), findsOneWidget);
      expect(find.text('Acme renewal'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('overflow → Customize collection', (tester) async {
      await pumpWorkPage(tester, size: _phone);
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Customize collection'));
      await tester.pumpAndSettle();
      expect(find.text('editor:deals'), findsOneWidget);
    });

    testWidgets('back returns home', (tester) async {
      await pumpWorkPage(tester, size: _phone);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    });
  });

  group('states', () {
    testWidgets('the nudge action opens quick add', (tester) async {
      await pumpWorkPage(tester, repository: workRepository(objects: []));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SnackBarAction, 'New deal'));
      await tester.pumpAndSettle();
      expect(find.byType(QuickAddDialog), findsOneWidget);
    });

    testWidgets('mode bodies are keyed by view', (tester) async {
      final cubit = await pumpWorkPage(tester);
      expect(find.byKey(const ValueKey('all')), findsOneWidget);
      cubit.selectView('board');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('board')), findsOneWidget);
      expect(find.byKey(const ValueKey('all')), findsNothing);
    });

    testWidgets('no objects: header plus a ghost row and Change fields', (
      tester,
    ) async {
      await pumpWorkPage(tester, repository: workRepository(objects: []));
      expect(find.bySemanticsLabel('Sort by Amount'), findsOneWidget);
      // The ghost row, the New button and the first-item nudge's action.
      expect(find.text('New deal'), findsNWidgets(3));
      expect(find.text('Change fields'), findsOneWidget);
    });

    testWidgets('empty collection nudges once per session', (tester) async {
      final repo = workRepository(objects: []);
      await pumpWorkPage(tester, repository: repo);
      await tester.pump();
      expect(find.text('Add your first deal'), findsOneWidget);
      // Floating, 480 wide on desktop (never over the rail), with an action.
      final bar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(bar.width, 480);
      expect(bar.behavior, SnackBarBehavior.floating);
      expect(find.widgetWithText(SnackBarAction, 'New deal'), findsOneWidget);
      ScaffoldMessenger.of(
        tester.element(find.byType(Scaffold).first),
      ).hideCurrentSnackBar();
      await tester.pumpAndSettle();
      // Reopening the same collection in this session does not nag again.
      await pumpWorkPage(tester, repository: repo);
      await tester.pumpAndSettle();
      expect(find.text('Add your first deal'), findsNothing);
    });

    testWidgets('no nudge while loading, nor once objects arrive', (
      tester,
    ) async {
      final cubit = await pumpWorkPage(tester, initialize: false);
      await tester.pump();
      expect(find.text('Add your first deal'), findsNothing);
      cubit.initialize();
      await tester.pump();
      await tester.pump();
      expect(find.text('Add your first deal'), findsNothing);
    });

    testWidgets('no nudge when the collection has objects', (tester) async {
      await pumpWorkPage(tester);
      await tester.pump();
      expect(find.text('Add your first deal'), findsNothing);
    });

    testWidgets('no nudge when filters hide every object', (tester) async {
      final filtered = deals.copyWith(
        views: [
          tableView.copyWith(
            filters: const [
              ViewFilter(
                fieldId: 'name',
                op: FilterOp.contains,
                operand: 'no such deal',
              ),
            ],
          ),
        ],
      );
      await pumpWorkPage(
        tester,
        repository: workRepository(collection: filtered),
      );
      await tester.pump();
      expect(find.textContaining('0 of '), findsOneWidget);
      expect(find.text('Add your first deal'), findsNothing);
    });

    testWidgets('no fields: set up fields', (tester) async {
      await pumpWorkPage(
        tester,
        repository: workRepository(
          collection: const Collection(id: 'deals', name: 'Deals'),
          objects: [],
        ),
      );
      expect(find.text('This collection has no fields yet'), findsOneWidget);
      expect(find.text('Add your first deal'), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('filters hiding everything: no matches + clear', (
      tester,
    ) async {
      final cubit = await pumpWorkPage(tester);
      await cubit.setFilters(const [
        ViewFilter(fieldId: 'name', op: FilterOp.contains, operand: 'zzz'),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Nothing matches these filters'), findsOneWidget);
      // The Table keeps its header under the same inline banner as Board.
      expect(find.byType(NoMatchesNotice), findsOneWidget);
      expect(find.bySemanticsLabel('Sort by Amount'), findsOneWidget);
      expect(find.text('0 of 5'), findsOneWidget);
      expect(find.text('Name contains zzz'), findsOneWidget);
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(find.text('Acme renewal'), findsOneWidget);
    });

    testWidgets('filtered footer counts "N of M"; chip ✕ removes', (
      tester,
    ) async {
      final cubit = await pumpWorkPage(tester);
      await cubit.setFilters(const [
        ViewFilter(fieldId: 'stage', op: FilterOp.anyOf, operand: ['lead']),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('2 of 5'), findsOneWidget);
      expect(find.text('Stage is Lead'), findsOneWidget);
      await tester.tap(find.byTooltip('Remove filter'));
      await tester.pumpAndSettle();
      expect(find.text('5 deals'), findsOneWidget);
    });

    testWidgets('an unknown mode renders as a table with a notice', (
      tester,
    ) async {
      await pumpWorkPage(
        tester,
        repository: workRepository(
          collection: deals.copyWith(
            views: [tableView.copyWith(mode: 'gallery')],
          ),
        ),
      );
      expect(find.textContaining('"gallery" mode'), findsOneWidget);
      expect(find.text('Acme renewal'), findsOneWidget);
    });

    testWidgets('a stream error shows the error card; Retry reloads', (
      tester,
    ) async {
      final repo = workRepository();
      await pumpWorkPage(tester, repository: repo);
      repo.failObjects('deals', StateError('boom'));
      await tester.pump();
      await tester.pump();
      expect(find.text("Couldn't load this view"), findsOneWidget);
      repo.seedObjects('deals', sampleDeals());
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Acme renewal'), findsOneWidget);
    });

    testWidgets('a failed write shows an error snackbar', (tester) async {
      final repo = workRepository();
      final cubit = await pumpWorkPage(tester, repository: repo);
      repo.objectWriteError = () => StateError('denied');
      cubit.deleteObject('d1');
      await tester.pump();
      await tester.pump();
      expect(find.text("Couldn't delete it"), findsOneWidget);
      expect(find.text('Acme renewal'), findsOneWidget);
    });
  });

  group('objects', () {
    Finder inEditor(Finder f) =>
        find.descendant(of: find.byType(ObjectEditor), matching: f);

    testWidgets('tap → editor → Delete → Undo', (tester) async {
      await pumpWorkPage(tester);
      await tester.tap(find.text('Globex pilot'));
      await tester.pumpAndSettle();
      expect(find.byType(ObjectEditor), findsOneWidget);
      expect(inEditor(find.text('Zeta Corp')), findsOneWidget);

      await tester.tap(inEditor(find.text('Delete')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(MorkvaConfirmDialog),
          matching: find.text('Delete'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ObjectEditor), findsNothing);
      expect(find.text('Globex pilot'), findsNothing);
      expect(find.text('Deleted "Globex pilot"'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('Globex pilot'), findsOneWidget);
    });

    testWidgets('the Undo snackbar expires on its own', (tester) async {
      await pumpWorkPage(tester);
      await tester.tap(find.text('Globex pilot'));
      await tester.pumpAndSettle();
      await tester.tap(inEditor(find.text('Delete')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(MorkvaConfirmDialog),
          matching: find.text('Delete'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Deleted "Globex pilot"'), findsOneWidget);

      // An action makes a SnackBar persist by default; this one must not.
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(find.text('Deleted "Globex pilot"'), findsNothing);
    });

    testWidgets('edit → Save → the table shows the new value', (tester) async {
      final repo = workRepository();
      await pumpWorkPage(tester, repository: repo);
      await tester.tap(find.text('Globex pilot'));
      await tester.pumpAndSettle();
      // Name, then Amount.
      await tester.enterText(inEditor(find.byType(TextField)).at(1), '450');
      await tester.pump();
      await tester.tap(inEditor(find.text('Save')));
      await tester.pumpAndSettle();
      expect(find.byType(ObjectEditor), findsNothing);
      expect(find.text('450 USD'), findsOneWidget);
      final saved = repo.objectsOf('deals').firstWhere((o) => o.id == 'd2');
      expect(saved['amount'], const NumberFieldValue(450));
      expect(saved['name'], const TextFieldValue('Globex pilot'));
    });

    testWidgets('the editor title is a text field, not the first column', (
      tester,
    ) async {
      final repo = workRepository(
        collection: deals.copyWith(
          views: [
            tableView.copyWith(fieldIds: ['amount', 'name']),
          ],
        ),
      );
      await pumpWorkPage(tester, repository: repo);
      await tester.tap(find.text('Globex pilot'));
      await tester.pumpAndSettle();
      final editor = tester.element(find.byType(ObjectEditor));
      expect(editor.read<ObjectEditorCubit>().state.title, 'Globex pilot');
    });

    testWidgets('New deal → editor → Save → a new row', (tester) async {
      final repo = workRepository();
      await pumpWorkPage(tester, repository: repo);
      await tester.tap(find.widgetWithText(PrimaryButton, 'New deal'));
      await tester.pumpAndSettle();
      expect(inEditor(find.text('New deal')), findsOneWidget);
      await tester.enterText(
        inEditor(find.byType(TextField)).first,
        'Wayne Enterprises',
      );
      await tester.tap(inEditor(find.text('Save')));
      await tester.pumpAndSettle();
      expect(find.text('Wayne Enterprises'), findsOneWidget);
      expect(find.text('6 deals'), findsOneWidget);
      expect(repo.objectsOf('deals'), hasLength(6));
    });

    testWidgets('phone: the FAB opens the editor as a full page', (
      tester,
    ) async {
      final repo = workRepository();
      await pumpWorkPage(tester, repository: repo, size: const Size(390, 844));
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      final appBar = find.descendant(
        of: find.byType(ObjectEditor),
        matching: find.byType(AppBar),
      );
      expect(appBar, findsOneWidget);
      await tester.enterText(inEditor(find.byType(TextField)).first, 'Wayne');
      await tester.tap(
        find.descendant(of: appBar, matching: find.text('Save')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ObjectEditor), findsNothing);
      expect(repo.objectsOf('deals'), hasLength(6));
    });

    testWidgets('a saved object the filters hide says so', (tester) async {
      final cubit = await pumpWorkPage(tester);
      await cubit.setFilters([
        const ViewFilter(
          fieldId: 'stage',
          op: FilterOp.anyOf,
          operand: ['won'],
        ),
      ]);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PrimaryButton, 'New deal'));
      await tester.pumpAndSettle();
      await tester.enterText(inEditor(find.byType(TextField)).first, 'Wayne');
      await tester.tap(inEditor(find.text('Save')));
      await tester.pumpAndSettle();
      expect(find.text('Saved — hidden by the filters'), findsOneWidget);
    });

    testWidgets('board quick add → Add details → editor prefilled', (
      tester,
    ) async {
      final repo = workRepository();
      final cubit = await pumpWorkPage(tester, repository: repo);
      cubit.selectView('board');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('New deal in Won'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Hooli renewal');
      await tester.tap(find.text('Add details'));
      await tester.pumpAndSettle();
      expect(find.byType(ObjectEditor), findsOneWidget);
      expect(inEditor(find.text('Hooli renewal')), findsOneWidget);
      expect(inEditor(find.text('Filled from the Won column')), findsOneWidget);
      await tester.tap(inEditor(find.text('Save')));
      await tester.pumpAndSettle();
      final added = repo.objectsOf('deals').last;
      expect(added['name'], const TextFieldValue('Hooli renewal'));
      expect(added['stage'], const SingleSelectFieldValue('won'));
    });

    testWidgets('quick add Add still adds at once', (tester) async {
      final repo = workRepository();
      final cubit = await pumpWorkPage(tester, repository: repo);
      cubit.selectView('board');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('New deal in Won'));
      await tester.pumpAndSettle();
      expect(find.byType(QuickAddDialog), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Wayne');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(find.byType(ObjectEditor), findsNothing);
      expect(repo.objectsOf('deals'), hasLength(6));
    });
  });

  group('tab menu', () {
    testWidgets('duplicate, inline rename, delete with confirm', (
      tester,
    ) async {
      final cubit = await pumpWorkPage(tester);
      await tester.tap(find.byTooltip('View options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Duplicate'));
      await tester.pumpAndSettle();
      expect(find.text('All deals copy'), findsOneWidget);

      await tester.tap(find.byTooltip('View options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Big ones');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Big ones'), findsOneWidget);

      await tester.tap(find.byTooltip('View options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      // The confirm dialog's Delete sits above the menu's.
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      final views = (cubit.state as ViewsReady).collection.views;
      expect(views.map((v) => v.name), ['All deals', 'Pipeline']);
    });

    testWidgets('the last view cannot be deleted', (tester) async {
      await pumpWorkPage(
        tester,
        repository: workRepository(
          collection: deals.copyWith(views: const [tableView]),
        ),
      );
      await tester.tap(find.byTooltip('View options'));
      await tester.pumpAndSettle();
      final item = tester.widget<PopupMenuItem<Object?>>(
        find.ancestor(
          of: find.text('Delete'),
          matching: find.byWidgetPredicate((w) => w is PopupMenuItem),
        ),
      );
      expect(item.enabled, isFalse);
    });
  });

  group('filters and sort', () {
    ViewsReady ready(CollectionViewsCubit c) => c.state as ViewsReady;

    testWidgets('+ Filter → popover under the toolbar → a saved chip', (
      tester,
    ) async {
      final cubit = await pumpWorkPage(tester);
      await tester.tap(find.bySemanticsLabel('Add filter'));
      await tester.pumpAndSettle();
      expect(find.text('Filter by'), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(
        tester.getTopLeft(find.byType(FilterBuilder)).dy,
        greaterThan(tester.getBottomLeft(find.byType(ViewToolbar)).dy),
      );
      expect(tester.getSize(find.byType(FilterBuilder)).width, 360);
      await tester.tap(find.bySemanticsLabel('Stage').last);
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('is any of'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Won'));
      await tester.pump();
      await tester.tap(find.text('Add filter'));
      await tester.pumpAndSettle();
      expect(find.byType(FilterBuilder), findsNothing);
      expect(ready(cubit).activeView.filters, const [
        ViewFilter(fieldId: 'stage', op: FilterOp.anyOf, operand: ['won']),
      ]);
      expect(find.text('Stage is Won'), findsOneWidget);
      expect(find.text('1 of 5'), findsOneWidget);
    });

    testWidgets('tapping a chip reopens at the value step and replaces it', (
      tester,
    ) async {
      final cubit = await pumpWorkPage(tester);
      await cubit.setFilters(const [
        ViewFilter(fieldId: 'name', op: FilterOp.isNotEmpty),
        ViewFilter(fieldId: 'amount', op: FilterOp.greaterThan, operand: 100),
      ]);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Amount > 100'));
      await tester.pumpAndSettle();
      expect(find.text('Amount >'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, '1000');
      await tester.tap(find.text('Update filter'));
      await tester.pumpAndSettle();
      expect(ready(cubit).activeView.filters, const [
        ViewFilter(fieldId: 'name', op: FilterOp.isNotEmpty),
        ViewFilter(fieldId: 'amount', op: FilterOp.greaterThan, operand: 1000),
      ]);
    });

    testWidgets('outside tap dismisses without saving', (tester) async {
      final cubit = await pumpWorkPage(tester);
      await tester.tap(find.bySemanticsLabel('Add filter'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(1200, 780));
      await tester.pumpAndSettle();
      expect(find.byType(FilterBuilder), findsNothing);
      expect(ready(cubit).activeView.filters, isEmpty);
    });

    testWidgets('a reference filter lists target names; the chip names them', (
      tester,
    ) async {
      final cubit = await pumpWorkPage(tester);
      cubit.selectView('board');
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Add filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Company').last);
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('is any of'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Zeta Corp'));
      await tester.pump();
      await tester.tap(find.text('Add filter'));
      await tester.pumpAndSettle();
      expect(ready(cubit).activeView.filters.single.operand, ['k1']);
      expect(find.text('Company is Zeta Corp'), findsOneWidget);
    });

    testWidgets('names load into an open builder for a hidden reference', (
      tester,
    ) async {
      final repo = workRepository(
        collection: deals.copyWith(views: const [boardView]),
      );
      final cubit = await pumpWorkPage(tester, repository: repo);
      await tester.pumpAndSettle();
      expect(repo.watchObjectsCalls['companies'], isNull);
      await tester.tap(find.bySemanticsLabel('Add filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Company').last);
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('is any of'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Zeta Corp'), findsOneWidget);
      expect(find.bySemanticsLabel('Alpha Ltd'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Alpha Ltd'));
      await tester.pump();
      await tester.tap(find.text('Add filter'));
      await tester.pumpAndSettle();
      expect(ready(cubit).activeView.filters.single.operand, ['k2']);
      expect(find.text('Company is Alpha Ltd'), findsOneWidget);
    });

    testWidgets('Esc closes the filter popover without saving', (tester) async {
      final cubit = await pumpWorkPage(tester);
      await tester.tap(find.bySemanticsLabel('Add filter'));
      await tester.pumpAndSettle();
      expect(find.byType(FilterBuilder), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(FilterBuilder), findsNothing);
      expect(ready(cubit).activeView.filters, isEmpty);
    });

    testWidgets('Sort popover: pick a field, then flip the direction', (
      tester,
    ) async {
      final cubit = await pumpWorkPage(tester);
      await tester.tap(find.bySemanticsLabel('Sort'));
      await tester.pumpAndSettle();
      expect(find.byType(SortMenu), findsOneWidget);
      expect(find.bySemanticsLabel('Manual'), findsNothing);
      // Right-aligned with the toolbar cluster.
      expect(
        tester.getTopRight(find.byType(SortMenu)).dx,
        closeTo(tester.getTopRight(find.byType(ViewToolbar)).dx - 24, 1),
      );
      await tester.tap(find.bySemanticsLabel('Amount').last);
      await tester.pumpAndSettle();
      expect(find.byType(SortMenu), findsNothing);
      expect(ready(cubit).activeView.sort, const ViewSort(fieldId: 'amount'));
      expect(_rowTitles(tester).first, 'Initech');

      await tester.tap(find.bySemanticsLabel('Amount').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Desc'));
      await tester.pumpAndSettle();
      expect(
        ready(cubit).activeView.sort,
        const ViewSort(fieldId: 'amount', ascending: false),
      );
      expect(find.byType(SortMenu), findsOneWidget);
    });

    testWidgets('Board offers Manual, which clears the sort', (tester) async {
      final cubit = await pumpWorkPage(tester);
      cubit.selectView('board');
      await cubit.setSort(const ViewSort(fieldId: 'name'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Name').first);
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Manual'));
      await tester.pumpAndSettle();
      expect(ready(cubit).activeView.sort, isNull);
    });

    testWidgets('phone: chips row + Filter opens a bottom sheet', (
      tester,
    ) async {
      final cubit = await pumpWorkPage(tester, size: _phone);
      await tester.tap(find.bySemanticsLabel('Add filter'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Name').last);
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('is empty'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(ready(cubit).activeView.filters, const [
        ViewFilter(fieldId: 'name', op: FilterOp.isEmpty),
      ]);
    });
  });
}
