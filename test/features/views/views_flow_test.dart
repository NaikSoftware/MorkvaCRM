import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/api/api.dart';
import 'package:morkva_crm/app/app.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/features/objects/object_editor.dart';
import 'package:morkva_crm/features/views/views.dart';
import 'package:morkva_crm/features/views/widgets/board/board_column.dart';
import 'package:morkva_crm/features/views/widgets/calendar/no_date_tray.dart';

import '../../widget_test.dart' show FakeAuthRepository;
import '../collections/fake_data_repository.dart';

void main() {
  testWidgets(
    'create, add objects, Board drag, filter, List and Calendar over the whole app',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = FakeAuthRepository()
        ..emit(const AuthUser(uid: 'u1', email: 'u1@example.com'));
      final repo = FakeDataRepository();
      await tester.pumpWidget(
        MorkvaApp(authRepository: auth, dataRepository: repo),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('New collection').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Deals');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Status · choice'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      for (final n in ['Acme', 'Globex', 'Initech']) {
        // "+ New deal" opens the object form.
        await tester.tap(find.text('New deal').first);
        await tester.pumpAndSettle();
        final form = find.byType(ObjectEditor);
        await tester.enterText(
          find.descendant(of: form, matching: find.byType(TextField)).first,
          n,
        );
        await tester.tap(
          find.descendant(of: form, matching: find.text('Save')),
        );
        await tester.pumpAndSettle();
        expect(find.text(n), findsOneWidget);
      }
      final cid = (await repo.getCollections()).single.id;
      expect(repo.objectsOf(cid), hasLength(3));
      // Table first: header cells and rows.
      expect(find.byType(ViewTable), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ViewTable),
          matching: find.text('Name'),
        ),
        findsOneWidget,
      );

      Future<void> createView(
        String mode,
        String name, {
        String? layoutField,
      }) async {
        await tester.tap(find.byTooltip('New view'));
        await tester.pumpAndSettle();
        final dialog = find.byType(AlertDialog);
        await tester.tap(
          find.descendant(of: dialog, matching: find.text(mode)),
        );
        await tester.pumpAndSettle();
        if (layoutField != null) {
          await tester.tap(
            find.descendant(of: dialog, matching: find.text(layoutField)),
          );
          await tester.pumpAndSettle();
        }
        await tester.enterText(find.byType(TextField).last, name);
        await tester.pump();
        await tester.tap(find.text('Create view'));
        await tester.pumpAndSettle();
      }

      await createView('Board', 'Pipeline', layoutField: 'Status');
      Finder column(String label) => find.ancestor(
        of: find.text(label),
        matching: find.byType(BoardColumn),
      );
      for (final label in ['To do', 'In progress', 'Done', 'No Status']) {
        expect(column(label), findsOneWidget);
      }
      expect(
        find.descendant(
          of: column('No Status'),
          matching: find.byType(ObjectCard),
        ),
        findsNWidgets(3),
      );

      final coll = (await repo.getCollections()).single;
      final status = coll.fields
          .whereType<SingleSelectFieldDefinition>()
          .single;
      String? stored(String name) {
        final o = repo
            .objectsOf(cid)
            .firstWhere(
              (o) => o.values.values.any(
                (v) => v is TextFieldValue && v.text == name,
              ),
            );
        return switch (o[status.id]) {
          SingleSelectFieldValue(:final optionId) => optionId,
          _ => null,
        };
      }

      expect(stored('Acme'), isNull);
      Future<void> dragAcmeToTodo() async {
        await tester.ensureVisible(find.text('Acme'));
        await tester.pumpAndSettle();
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('Acme')),
          kind: PointerDeviceKind.mouse,
        );
        await gesture.moveBy(const Offset(0, 6));
        await tester.pump();
        // Aim at the visible part of the column: ensureVisible can leave it
        // partly scrolled under the board's left clip edge (x 281, right of
        // the 256 px rail), where a drop at the column's own centre misses.
        final viewport = tester.getRect(
          find
              .ancestor(of: column('To do'), matching: find.byType(Scrollable))
              .first,
        );
        final col = tester.getRect(column('To do'));
        final to = Offset(
          (col.left.clamp(viewport.left, viewport.right) +
                  col.right.clamp(viewport.left, viewport.right)) /
              2,
          col.center.dy,
        );
        final from = tester.getCenter(find.text('Acme').first);
        for (var i = 1; i <= 10; i++) {
          await gesture.moveTo(Offset.lerp(from, to, i / 10)!);
          await tester.pump(const Duration(milliseconds: 50));
        }
        await tester.pump(const Duration(milliseconds: 300));
        await gesture.up();
        await tester.pumpAndSettle();
      }

      await dragAcmeToTodo();
      expect(find.text('Moved to To do'), findsOneWidget);
      expect(stored('Acme'), status.options.first.id);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(stored('Acme'), isNull);

      // Drag again (kept this time) so a filter has something to match.
      await dragAcmeToTodo();
      expect(stored('Acme'), status.options.first.id);

      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();
      Future<void> pick(String label) async {
        await tester.tap(find.bySemanticsLabel(label).last);
        await tester.pumpAndSettle();
      }

      await pick('Status');
      await pick('is any of');
      await pick('To do');
      await tester.tap(find.text('Add filter'));
      await tester.pumpAndSettle();
      expect(find.byType(InputChip), findsOneWidget);
      expect(find.text('Globex'), findsNothing);
      expect(find.text('Initech'), findsNothing);
      expect(
        find.descendant(of: column('To do'), matching: find.text('Acme')),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Remove filter'));
      await tester.pumpAndSettle();
      expect(find.byType(InputChip), findsNothing);
      expect(find.text('Globex'), findsOneWidget);
      expect(find.text('Initech'), findsOneWidget);

      // List view.
      await createView('List', 'Plain');
      for (final n in ['Acme', 'Globex', 'Initech']) {
        expect(find.text(n), findsOneWidget);
      }

      // Calendar needs a date field: "Add date field" opens the editor.
      await tester.tap(find.byTooltip('New view'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Calendar'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add date field'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add field').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect((await repo.getCollections()).single.fields, hasLength(3));
      await createView('Calendar', 'Schedule');
      // Calendar renders the month grid; undated objects wait in "No date".
      expect(find.text('Today'), findsOneWidget);
      final tray = find.byType(NoDateTray);
      expect(tray, findsOneWidget);
      for (final n in ['Acme', 'Globex', 'Initech']) {
        expect(
          find.descendant(of: tray, matching: find.text(n)),
          findsOneWidget,
        );
      }

      // Back to the Table: rows, and Acme's stored Status shows in its row.
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      final table = find.byType(ViewTable);
      expect(table, findsOneWidget);
      for (final n in ['Acme', 'Globex', 'Initech']) {
        expect(
          find.descendant(of: table, matching: find.text(n)),
          findsOneWidget,
        );
      }
      // Status was added in Build, so the editor save put it in this view.
      // Acme's row (same baseline) shows its stored Status;
      final todo = find.descendant(of: table, matching: find.text('To do'));
      expect(todo, findsOneWidget);
      expect(
        (tester.getCenter(todo).dy - tester.getCenter(find.text('Acme')).dy)
            .abs(),
        lessThan(8),
      );
    },
  );
}
