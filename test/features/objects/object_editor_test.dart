import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/api/api.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/objects/object_editor.dart';

import '../collections/fake_data_repository.dart';
import '../views/views_fixtures.dart';

/// Deals with a required name and a laid-out card: "Deal" (name | amount,
/// then stage) and a collapsed "Notes" section holding Due.
final _laidOut = deals.copyWith(
  fields: [
    const TextFieldDefinition(id: 'name', name: 'Name', isRequired: true),
    ...deals.fields.skip(1),
  ],
  layout: const CardLayout(
    sections: [
      LayoutSection(
        id: 's1',
        title: 'Deal',
        rows: [
          LayoutRow(
            id: 'r1',
            cells: [
              LayoutCell(fieldId: 'name', span: 6),
              LayoutCell(fieldId: 'amount', span: 6),
            ],
          ),
          LayoutRow(
            id: 'r2',
            cells: [LayoutCell(fieldId: 'stage')],
          ),
        ],
      ),
      LayoutSection(
        id: 's2',
        title: 'Notes',
        collapsed: true,
        rows: [
          LayoutRow(
            id: 'r3',
            cells: [LayoutCell(fieldId: 'due')],
          ),
        ],
      ),
    ],
  ),
);

/// Holds [saveObject] until [gate] completes.
class _GatedRepo extends FakeDataRepository {
  _GatedRepo(super.initial);

  final gate = Completer<void>();

  @override
  Future<void> saveObject(
    MorkvaObject object, {
    required Collection schema,
  }) async {
    await gate.future;
    return super.saveObject(object, schema: schema);
  }
}

late FakeDataRepository _repo;
ObjectEditorResult? _result;
bool _closed = false;

/// Pumps a page with an "open" button that shows the editor for [object]
/// (create mode when null) at [size], and taps it.
Future<void> _open(
  WidgetTester tester, {
  Collection collection = deals,
  MorkvaObject? object,
  Size size = const Size(1280, 800),
  FakeDataRepository? repository,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  _repo = repository ?? FakeDataRepository([collection, companies]);
  _repo.seedObjects('deals', sampleDeals());
  _repo.seedObjects('companies', [company('k1', 'Zeta Corp', 0)]);
  _result = null;
  _closed = false;
  await tester.pumpWidget(
    RepositoryProvider<DataRepository>.value(
      value: _repo,
      child: MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                _result = await showObjectEditor(
                  context,
                  collection: collection,
                  object: object,
                  titleFieldId: 'name',
                );
                _closed = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Finder _inEditor(Finder f) =>
    find.descendant(of: find.byType(ObjectEditor), matching: f);

Finder get _fields => _inEditor(find.byType(TextField));

void main() {
  group('layout', () {
    testWidgets('panel: 560 px, side-by-side row, collapsed section', (
      tester,
    ) async {
      await _open(tester, collection: _laidOut);
      expect(tester.getSize(find.byType(ObjectEditor)).width, 560);
      expect(find.byType(AppBar), findsNothing);
      final name = tester.getTopLeft(_fields.at(0));
      final amount = tester.getTopLeft(_fields.at(1));
      expect(amount.dy, name.dy);
      expect(amount.dx, greaterThan(name.dx));
      // "Notes" starts collapsed and says how much it hides (Due, plus the
      // unplaced Company and Meeting that reconcile appends there).
      expect(_inEditor(find.text('Notes')), findsOneWidget);
      expect(find.byKey(const ValueKey('section-s2')), findsOneWidget);
      expect(_inEditor(find.text(' · 3 fields')), findsOneWidget);
      expect(_inEditor(find.text('Due')), findsNothing);
      await tester.tap(_inEditor(find.text('Notes')));
      await tester.pumpAndSettle();
      expect(_inEditor(find.text('Due')), findsOneWidget);
    });

    testWidgets('phone: full page with Save in the app bar; cells stack', (
      tester,
    ) async {
      await _open(tester, collection: _laidOut, size: const Size(390, 844));
      expect(find.byType(AppBar), findsOneWidget);
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('Save')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('New deal'),
        ),
        findsOneWidget,
      );
      final name = tester.getTopLeft(_fields.at(0));
      final amount = tester.getTopLeft(_fields.at(1));
      expect(amount.dx, name.dx);
      expect(amount.dy, greaterThan(name.dy));
    });

    testWidgets('an untitled single section has no header', (tester) async {
      await _open(tester);
      expect(find.byKey(const ValueKey('section-sec_main')), findsNothing);
      expect(_inEditor(find.text('Name')), findsOneWidget);
      expect(_inEditor(find.text('Meeting')), findsOneWidget);
    });

    testWidgets('edit mode: header meta, changed dot, Delete in the footer', (
      tester,
    ) async {
      await _open(tester, object: sampleDeals().first);
      expect(_inEditor(find.text('Acme renewal')), findsWidgets);
      expect(_inEditor(find.textContaining('Deal · created')), findsOneWidget);
      final dot = _inEditor(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Changed',
        ),
      );
      expect(dot, findsNothing);
      await tester.enterText(_fields.at(1), '5');
      await tester.pump();
      expect(dot, findsOneWidget);
      await tester.tap(_inEditor(find.text('Delete')));
      await tester.pumpAndSettle();
      expect(_result, isA<ObjectEditorDeleted>());
    });
  });

  group('save', () {
    testWidgets('invalid: blocked with a banner, nothing written', (
      tester,
    ) async {
      await _open(tester, collection: _laidOut);
      await tester.tap(_inEditor(find.text('Save')));
      await tester.pumpAndSettle();
      expect(_inEditor(find.text('Fix 1 field to save')), findsOneWidget);
      expect(_inEditor(find.text('Name is required')), findsOneWidget);
      expect(_repo.objectsOf('deals'), hasLength(5));
      expect(_closed, isFalse);
      // Fixing it clears the banner; Save then closes with the new id.
      await tester.enterText(_fields.at(0), 'Wayne');
      await tester.pump();
      expect(_inEditor(find.text('Fix 1 field to save')), findsNothing);
      await tester.tap(_inEditor(find.text('Save')));
      await tester.pumpAndSettle();
      expect(_result, isA<ObjectEditorSaved>());
      expect(_repo.objectsOf('deals'), hasLength(6));
    });

    testWidgets('an invalid field in a collapsed section is revealed', (
      tester,
    ) async {
      final collection = _laidOut.copyWith(
        fields: [
          for (final f in _laidOut.fields)
            f.id == 'due'
                ? const DateFieldDefinition(
                    id: 'due',
                    name: 'Due',
                    isRequired: true,
                  )
                : f,
        ],
      );
      await _open(tester, collection: collection, object: sampleDeals().first);
      expect(_inEditor(find.text('Due')), findsNothing);
      await tester.tap(_inEditor(find.text('Save')));
      await tester.pumpAndSettle();
      expect(_inEditor(find.text('Due is required')), findsOneWidget);
      expect(_inEditor(find.text('Fix 1 field to save')), findsOneWidget);
    });

    testWidgets('a failed write shows the banner and keeps the form', (
      tester,
    ) async {
      await _open(tester, object: sampleDeals().first);
      await tester.enterText(_fields.at(1), '5');
      _repo.objectWriteError = () => Exception('offline');
      await tester.tap(_inEditor(find.text('Save')));
      await tester.pumpAndSettle();
      expect(
        _inEditor(find.text("Couldn't save — check your connection")),
        findsOneWidget,
      );
      expect(_closed, isFalse);
    });

    testWidgets('a dirty field changed elsewhere shows the conflict banner', (
      tester,
    ) async {
      await _open(tester, object: sampleDeals().first);
      await tester.enterText(_fields.at(1), '5');
      await tester.pump();
      await _repo.saveObject(
        sampleDeals().first.copyWith(
          values: {'amount': const NumberFieldValue(9)},
        ),
        schema: deals,
      );
      await tester.pumpAndSettle();
      expect(
        _inEditor(find.textContaining('Amount was changed elsewhere.')),
        findsOneWidget,
      );
    });

    testWidgets('deleted elsewhere: banner and Save as new', (tester) async {
      await _open(tester, object: sampleDeals().first);
      await _repo.deleteObject('deals', 'd1');
      await tester.pumpAndSettle();
      expect(
        _inEditor(find.textContaining('This deal was deleted elsewhere.')),
        findsOneWidget,
      );
      await tester.tap(_inEditor(find.text('Save as new')));
      await tester.pumpAndSettle();
      expect(_repo.objectsOf('deals').map((o) => o.id), contains('d1'));
    });
  });

  group('closing while saving', () {
    Future<_GatedRepo> openAndSave(WidgetTester tester) async {
      final repo = _GatedRepo([deals, companies]);
      await _open(tester, object: sampleDeals().first, repository: repo);
      await tester.enterText(_fields.at(0), 'Changed');
      await tester.pump();
      await tester.tap(_inEditor(find.text('Save')));
      await tester.pump();
      return repo;
    }

    testWidgets('is blocked silently; the save then closes with the result', (
      tester,
    ) async {
      final repo = await openAndSave(tester);
      final cancel = tester.widget<TextActionButton>(
        find.widgetWithText(TextActionButton, 'Cancel'),
      );
      expect(cancel.onPressed, isNull);
      await tester.tap(_inEditor(find.text('Cancel')));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.tapAt(const Offset(20, 400)); // the scrim
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Discard changes?'), findsNothing);
      expect(find.byType(ObjectEditor), findsOneWidget);

      repo.gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(ObjectEditor), findsNothing);
      expect(_closed, isTrue);
      expect(_result, isA<ObjectEditorSaved>());
      expect(
        _repo.objectsOf('deals').first['name'],
        const TextFieldValue('Changed'),
      );
    });

    testWidgets('a route on top does not swallow the result', (tester) async {
      final repo = await openAndSave(tester);
      unawaited(
        showDialog<void>(
          context: tester.element(find.byType(ObjectEditor)),
          builder: (_) => const AlertDialog(content: Text('on top')),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('on top'), findsOneWidget);

      repo.gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('on top'), findsNothing);
      expect(find.byType(ObjectEditor), findsNothing);
      expect(_result, isA<ObjectEditorSaved>());
    });
  });

  group('discard guard', () {
    testWidgets('closing with changes asks first', (tester) async {
      await _open(tester);
      await tester.enterText(_fields.at(0), 'Draft');
      await tester.pump();
      await tester.tap(_inEditor(find.byTooltip('Close')));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.byType(ObjectEditor), findsOneWidget);

      await tester.tap(_inEditor(find.text('Cancel')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.byType(ObjectEditor), findsNothing);
      expect(_closed, isTrue);
      expect(_result, isNull);
      expect(_repo.objectsOf('deals'), hasLength(5));
    });

    testWidgets('closing without changes closes at once', (tester) async {
      await _open(tester, size: const Size(390, 844));
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsNothing);
      expect(find.byType(ObjectEditor), findsNothing);
    });
  });
}
