import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/design/theme/app_theme.dart';
import 'package:morkva_crm/features/collections/editor/collection_editor_cubit.dart';
import 'package:morkva_crm/features/collections/list/collections_list_cubit.dart';
import 'package:morkva_crm/features/collections/editor/collection_editor_state.dart';
import 'package:morkva_crm/features/collections/editor/layout_canvas.dart';
import 'package:morkva_crm/features/collections/field_editors/built_in_field_editors.dart';

import '../fake_data_repository.dart';

const _name = TextFieldDefinition(id: 'f1', name: 'Name');

Collection _deals(List<FieldDefinition> fields) =>
    Collection(id: 'c1', name: 'Deals', fields: fields);

Future<CollectionEditorCubit> _pump(
  WidgetTester tester,
  List<Collection> collections, {
  Size size = const Size(900, 1200),
  FakeDataRepository? repo,
  String id = 'c1',
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final registry = defaultFieldEditorRegistry();
  final cubit = CollectionEditorCubit(
    repo ?? FakeDataRepository(collections),
    registry,
  );
  await cubit.load(id);
  addTearDown(cubit.close);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: BlocProvider.value(
        value: cubit,
        child: Scaffold(
          body: BlocBuilder<CollectionEditorCubit, CollectionEditorState>(
            builder: (_, s) => s is CollectionEditorReady
                ? SingleChildScrollView(
                    child: LayoutCanvas(
                      collection: s.draft,
                      registry: registry,
                    ),
                  )
                : const SizedBox(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return cubit;
}

CollectionEditorReady _ready(CollectionEditorCubit c) =>
    c.state as CollectionEditorReady;

void main() {
  testWidgets('starter collection shows the guided empty state', (t) async {
    await _pump(t, [
      _deals(const [_name]),
    ]);
    expect(find.text('What do you track for each deal?'), findsOneWidget);
    for (final k in ['Status', 'Due date', 'Amount', 'Customer', 'Notes']) {
      expect(find.byKey(Key('suggest_$k')), findsOneWidget);
    }
    expect(find.byKey(const Key('suggest_custom')), findsOneWidget);
  });

  testWidgets('a collection with several saved fields does not', (t) async {
    await _pump(t, [
      _deals(const [_name, TextFieldDefinition(id: 'f2', name: 'Other')]),
    ]);
    expect(find.textContaining('What do you track'), findsNothing);
  });

  testWidgets('Status chip adds a choice with default options, unsaved', (
    t,
  ) async {
    final cubit = await _pump(t, [
      _deals(const [_name]),
    ]);
    await t.tap(find.byKey(const Key('suggest_Status')));
    await t.pumpAndSettle();
    final added = _ready(cubit).draft.fields.last;
    expect(added, isA<SingleSelectFieldDefinition>());
    expect(added.name, 'Status');
    expect((added as SingleSelectFieldDefinition).options.map((o) => o.label), [
      'To do',
      'In progress',
      'Done',
    ]);
    expect(_ready(cubit).dirty, isTrue);
    // The used chip disappears; the heading stays for more suggestions.
    expect(find.byKey(const Key('suggest_Status')), findsNothing);
    expect(find.text('What do you track for each deal?'), findsOneWidget);
  });

  testWidgets('date, number and text chips add typed, named fields', (t) async {
    final cubit = await _pump(t, [
      _deals(const [_name]),
    ]);
    for (final k in ['Due date', 'Amount', 'Notes']) {
      await t.tap(find.byKey(Key('suggest_$k')));
      await t.pumpAndSettle();
    }
    final f = _ready(cubit).draft.fields;
    expect(f.map((e) => e.name), ['Name', 'Due date', 'Amount', 'Notes']);
    expect(f[1], isA<DateFieldDefinition>());
    expect(f[2], isA<NumberFieldDefinition>());
  });

  testWidgets('Customer without a fitting collection leaves target unset', (
    t,
  ) async {
    final cubit = await _pump(t, [
      _deals(const [_name]),
    ]);
    await t.tap(find.byKey(const Key('suggest_Customer')));
    await t.pumpAndSettle();
    final ref = _ready(cubit).draft.fields.last as ReferenceFieldDefinition;
    expect(ref.targetCollectionId, '');
    expect(_ready(cubit).selectedFieldId, ref.id);
  });

  testWidgets('Customer never guesses a target, even with a Customers one', (
    t,
  ) async {
    final cubit = await _pump(t, [
      _deals(const [_name]),
      const Collection(id: 'c2', name: 'Customers'),
    ]);
    await t.tap(find.byKey(const Key('suggest_Customer')));
    await t.pumpAndSettle();
    final ref = _ready(cubit).draft.fields.last as ReferenceFieldDefinition;
    expect(ref.targetCollectionId, '');
  });

  testWidgets('phone width: every chip lies inside the card', (t) async {
    await _pump(t, [
      _deals(const [_name]),
    ], size: const Size(390, 844));
    final card = t.getRect(find.byKey(const Key('first_run_card')));
    expect(card.right, lessThanOrEqualTo(390));
    for (final c in find.byType(ActionChip).evaluate()) {
      final r = t.getRect(find.byWidget(c.widget));
      expect(card.contains(r.topLeft) && card.contains(r.bottomRight), isTrue);
    }
  });

  testWidgets('a collection from the real create path shows its Name field', (
    t,
  ) async {
    final repo = FakeDataRepository();
    final id = await CollectionsListCubit(repo).createCollection('Deals');
    await _pump(t, const [], repo: repo, id: id);
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('What do you track for each deal?'), findsOneWidget);
  });

  testWidgets('Custom field opens the add-field sheet', (t) async {
    await _pump(t, [
      _deals(const [_name]),
    ]);
    await t.tap(find.byKey(const Key('suggest_custom')));
    await t.pumpAndSettle();
    expect(find.text('Add a field'), findsOneWidget);
  });
}
