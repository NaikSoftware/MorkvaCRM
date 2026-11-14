import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:morkva_crm/api/api.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/core/domain/inbox/inbox.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/automation/widgets/action_buttons.dart';
import 'package:morkva_crm/features/inbox/bloc/inbox_cubit.dart';
import 'package:morkva_crm/features/inbox/bloc/inbox_page_cubit.dart';
import 'package:morkva_crm/features/inbox/view/inbox_item_editor.dart';
import 'package:morkva_crm/features/inbox/view_card/card_inbox_button.dart';
import 'package:morkva_crm/features/objects/object_editor.dart';

import '../../collections/fake_data_repository.dart';
import '../../views/views_fixtures.dart';
import '../fake_inbox_repository.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

final _today = localDay(DateTime.now());

InboxItem _item(
  String id, {
  String cardId = 'd1',
  InboxKind kind = InboxKind.task,
  DateTime? day,
  int? hour,
  bool done = false,
}) => InboxItem(
  id: id,
  kind: kind,
  title: 'Item $id',
  dueAt: day == null
      ? null
      : hour == null
      ? allDayDue(day)
      : DateTime(day.year, day.month, day.day, hour).toUtc(),
  allDay: day != null && hour == null,
  link: InboxLink(collectionId: 'deals', cardId: cardId, label: 'Card'),
  done: done,
  assigneeUid: 'u1',
  createdBy: 'u1',
  createdAt: DateTime.utc(2026, 11, 1),
  updatedAt: DateTime.utc(2026, 11, 1),
);

/// The card editor's Inbox button (spec §4 "From a card", AC13).
void main() {
  late FakeInboxRepository repo;
  late InboxCubit inbox;

  setUp(() {
    repo = FakeInboxRepository();
    inbox = InboxCubit(repo);
  });

  tearDown(() async {
    await inbox.close();
    await repo.dispose();
  });

  /// Opens the editor for deal d1 (null [object]: create mode), with the
  /// app's [InboxCubit] above the app like `MorkvaApp` provides it.
  Future<void> open(
    WidgetTester tester, {
    MorkvaObject? object,
    bool create = false,
    bool withInbox = true,
    Size size = const Size(1280, 800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = _MockAuthRepository();
    when(() => auth.authStateChanges).thenAnswer(
      (_) => Stream.value(const AuthUser(uid: 'u1', email: 'a@b.c')),
    );
    final authCubit = AuthCubit(auth)..initialize();
    addTearDown(authCubit.close);
    final data = FakeDataRepository([deals, companies]);
    data.seedObjects('deals', sampleDeals());
    final app = MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showObjectEditor(
              context,
              collection: deals,
              object: create ? null : sampleDeals().first,
              titleFieldId: 'name',
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.pumpWidget(
      RepositoryProvider<DataRepository>.value(
        value: data,
        child: BlocProvider.value(
          value: authCubit,
          child: withInbox ? BlocProvider.value(value: inbox, child: app) : app,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  final desktop = TargetPlatformVariant.only(TargetPlatform.linux);

  testWidgets('no linked items: "Add to Inbox", no badge', (tester) async {
    repo.seed([_item('other', cardId: 'd2')]);
    await open(tester);
    expect(find.byType(CardInboxButton), findsOneWidget);
    expect(find.byTooltip('Add to Inbox'), findsOneWidget);
    expect(find.text('1'), findsNothing);
    // Before Close.
    expect(
      tester.getCenter(find.byTooltip('Add to Inbox')).dx,
      lessThan(tester.getCenter(find.byTooltip('Close')).dx),
    );

    // A new task pre-linked to this card.
    await tester.tap(find.byTooltip('Add to Inbox'));
    await tester.pumpAndSettle();
    final editor = find.byType(InboxItemEditor);
    expect(tester.widget<InboxItemEditor>(editor).item, isNull);
    expect(
      find.descendant(
        of: editor,
        matching: find.textContaining('Acme renewal'),
      ),
      findsWidgets,
    );
  }, variant: desktop);

  testWidgets('open linked items: a count badge and a menu of them', (
    tester,
  ) async {
    repo.seed([
      _item('a', day: _today, hour: 10),
      _item(
        'b',
        kind: InboxKind.task,
        day: DateTime(_today.year, _today.month, _today.day - 2),
      ),
      _item('n', kind: InboxKind.note),
      _item('done', day: _today, done: true),
      _item('other', cardId: 'd2', day: _today),
    ]);
    await open(tester);
    expect(find.byTooltip('Inbox · 3 open'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.byTooltip('Inbox · 3 open'));
    await tester.pumpAndSettle();
    expect(find.text('Item a'), findsOneWidget);
    expect(find.text('Today · 10:00'), findsOneWidget);
    expect(find.text('Item b'), findsOneWidget);
    expect(find.textContaining('2 d late'), findsOneWidget);
    expect(find.text('Item n'), findsOneWidget);
    expect(find.text('No date'), findsOneWidget);
    expect(find.text('Item done'), findsNothing);
    expect(find.text('Item other'), findsNothing);
    expect(find.text('Add to Inbox…'), findsOneWidget);
    // The panel opens under the button, right edges aligned.
    final add = tester.getRect(
      find.ancestor(
        of: find.text('Add to Inbox…'),
        matching: find.byType(MenuItemButton),
      ),
    );
    final button = tester.getRect(find.byTooltip('Inbox · 3 open'));
    expect(add.width, CardInboxButton.menuWidth);
    expect(add.right, button.right);
    expect(add.top, greaterThan(button.bottom));
    // Overdue first, undated last.
    final ys = [
      for (final t in ['Item b', 'Item a', 'Item n'])
        tester.getTopLeft(find.text(t)).dy,
    ];
    expect(ys, orderedEquals([...ys]..sort()));

    await tester.tap(find.text('Item a'));
    await tester.pumpAndSettle();
    expect(find.byType(InboxItemEditor), findsOneWidget);
    expect(
      tester.widget<InboxItemEditor>(find.byType(InboxItemEditor)).item?.id,
      'a',
    );
  }, variant: desktop);

  testWidgets('the header gives the card buttons 44 px less', (tester) async {
    await open(tester);
    final withButton = tester
        .widget<CardActions>(find.byType(CardActions))
        .headerWidth;
    Navigator.of(tester.element(find.byType(ObjectEditor))).pop();
    await tester.pumpAndSettle();

    await open(tester, withInbox: false);
    expect(find.byType(CardInboxButton), findsOneWidget);
    expect(find.byTooltip('Add to Inbox'), findsNothing);
    final without = tester
        .widget<CardActions>(find.byType(CardActions))
        .headerWidth;
    expect(without - withButton, CardInboxButton.width);
  }, variant: desktop);

  testWidgets('a long card title is cut to the link label limit', (
    tester,
  ) async {
    final auth = _MockAuthRepository();
    when(() => auth.authStateChanges).thenAnswer(
      (_) => Stream.value(const AuthUser(uid: 'u1', email: 'a@b.c')),
    );
    final authCubit = AuthCubit(auth)..initialize();
    addTearDown(authCubit.close);
    final title = 'x' * 300;
    await tester.pumpWidget(
      RepositoryProvider<DataRepository>.value(
        value: FakeDataRepository([deals]),
        child: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: authCubit),
            BlocProvider.value(value: inbox),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: CardInboxButton(
                collectionId: 'deals',
                cardId: 'd1',
                label: title,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Add to Inbox'));
    await tester.pumpAndSettle();

    final draft = tester
        .element(find.byType(InboxItemEditor))
        .read<InboxDraftCubit>()
        .state;
    expect(draft.link?.label, 'x' * InboxLink.labelMax);
  }, variant: desktop);

  testWidgets('hidden while creating a card', (tester) async {
    await open(tester, create: true);
    expect(find.byType(CardInboxButton), findsNothing);
  }, variant: desktop);

  testWidgets('phone: in the app bar before Save', (tester) async {
    await open(tester, size: const Size(390, 844));
    final inboxX = tester.getCenter(find.byTooltip('Add to Inbox')).dx;
    expect(inboxX, lessThan(tester.getCenter(find.text('Save')).dx));
  });
}
