import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/api/api.dart';
import 'package:morkva_crm/app/shell/jump_to_dialog.dart';
import 'package:morkva_crm/app/shell/shell_sidebar.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/design/design.dart';

const _orders = Collection(id: 'orders', name: 'Orders');
const _clients = Collection(id: 'clients', name: 'Clients');

void main() {
  Future<void> pump(
    WidgetTester tester, {
    bool extended = true,
    List<Collection> pinned = const [_orders, _clients],
    ShellPlace place = ShellPlace.allCollections,
    String? collectionId,
    ValueChanged<String>? onUnpin,
    ValueChanged<String>? onCollection,
  }) async {
    final sync = SyncStatusCubit();
    addTearDown(sync.close);
    await tester.pumpWidget(
      BlocProvider.value(
        value: sync,
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Row(
              children: [
                ShellSidebar(
                  extended: extended,
                  place: place,
                  collectionId: collectionId,
                  pinned: pinned,
                  user: const AuthUser(
                    uid: 'u',
                    email: 'o@k.ua',
                    displayName: 'Olena Kovalenko',
                  ),
                  onAllCollections: () {},
                  onCollection: onCollection ?? (_) {},
                  onSettings: () {},
                  onJumpTo: () {},
                  onUnpin: onUnpin ?? (_) {},
                  onReorder: (_, _) {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('full: pins, profile initials, and a tap opens a pin', (
    tester,
  ) async {
    String? opened;
    await pump(tester, onCollection: (id) => opened = id);
    expect(find.text('All collections'), findsOneWidget);
    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);
    expect(find.text('Olena Kovalenko'), findsOneWidget);
    await tester.tap(find.text('Clients'));
    expect(opened, 'clients');
  });

  testWidgets('full: right-click a pin to unpin it', (tester) async {
    String? unpinned;
    await pump(tester, onUnpin: (id) => unpinned = id);
    await tester.tap(find.text('Orders'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unpin'));
    await tester.pumpAndSettle();
    expect(unpinned, 'orders');
  });

  testWidgets('full: no pins shows the hint', (tester) async {
    await pump(tester, pinned: const []);
    expect(
      find.textContaining('Pin the collections you use most'),
      findsOneWidget,
    );
  });

  testWidgets('rail: pins are tiles with their names as tooltips', (
    tester,
  ) async {
    await pump(
      tester,
      extended: false,
      place: ShellPlace.collection,
      collectionId: 'orders',
    );
    expect(find.text('Orders'), findsNothing);
    expect(find.byTooltip('Orders'), findsOneWidget);
    expect(find.byTooltip('Clients'), findsOneWidget);
  });

  testWidgets('jump to filters by name and resolves to the picked id', (
    tester,
  ) async {
    String? picked;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => picked = await showJumpToDialog(
              context,
              const [_orders, _clients],
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'cli');
    await tester.pumpAndSettle();
    expect(find.text('Orders'), findsNothing);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(picked, 'clients');
  });

  test('initials come from the name, else the email', () {
    expect(
      UserAvatar.initialsOf(
        const AuthUser(uid: 'u', email: 'x@y.z', displayName: 'olena k'),
      ),
      'OK',
    );
    expect(
      UserAvatar.initialsOf(const AuthUser(uid: 'u', email: 'x@y.z')),
      'X',
    );
  });
}
