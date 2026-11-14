import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/core/domain/inbox/inbox.dart';
import 'package:morkva_crm/features/inbox/inbox.dart';

import '../../collections/fake_data_repository.dart';
import 'inbox_view_harness.dart';

/// Its first collections listener fails (permission denied), later ones work.
class _FlakyCollections extends FakeDataRepository {
  _FlakyCollections(super.initial);

  var _failed = false;

  @override
  Stream<List<Collection>> watchCollections() {
    if (_failed) return super.watchCollections();
    _failed = true;
    return Stream.error(Exception('permission-denied'));
  }
}

void main() {
  late InboxRig rig;

  setUp(() => rig = InboxRig());
  tearDown(() => rig.dispose());

  for (final size in [kWide, kPhone]) {
    testWidgets('picker: collection, then card (${size.width})', (
      tester,
    ) async {
      InboxLink? picked;
      await rig.pump(
        tester,
        size: size,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => picked = await showCardLinkPicker(context),
            child: const Text('Pick'),
          ),
        ),
      );
      await tester.tap(find.text('Pick'));
      await tester.pumpAndSettle();
      expect(find.text('Step 1 of 2 · Choose a collection'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();
      expect(find.text('Orders'), findsNothing);
      await tester.enterText(find.byType(TextField), 'ord');
      await tester.pump();
      await tester.tap(find.text('Orders'));
      await tester.pumpAndSettle();

      expect(find.text('Step 2 of 2 · Choose a card'), findsOneWidget);
      expect(find.text('#1042'), findsOneWidget);
      expect(find.text('#1043'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '1043');
      await tester.pump();
      expect(find.text('#1042'), findsNothing);
      expect(find.text('1 of 2'), findsOneWidget);

      await tester.tap(find.text('#1043'));
      await tester.pumpAndSettle();
      expect(
        picked,
        const InboxLink(collectionId: 'orders', cardId: 'o2', label: '#1043'),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('picker: a failed collections listener shows an error and '
      'Retry listens again', (tester) async {
    final data = _FlakyCollections([kOrders]);
    await rig.pump(
      tester,
      data: data,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showCardLinkPicker(context),
          child: const Text('Pick'),
        ),
      ),
    );
    await tester.tap(find.text('Pick'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't load the collections"), findsOneWidget);
    expect(find.text('Orders'), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't load the collections"), findsNothing);
    expect(find.text('Orders'), findsOneWidget);
  });

  testWidgets('picker: back returns to the collections', (tester) async {
    await rig.pump(
      tester,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showCardLinkPicker(context),
          child: const Text('Pick'),
        ),
      ),
    );
    await tester.tap(find.text('Pick'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Orders'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back to collections'));
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 2 · Choose a collection'), findsOneWidget);
  });

  group('chip', () {
    Future<void> pumpRow(WidgetTester tester, InboxLink link) async {
      rig.seed([item('t', 'Ship', link: link)]);
      await rig.pump(tester);
    }

    testWidgets('opens the card', (tester) async {
      await pumpRow(
        tester,
        const InboxLink(collectionId: 'orders', cardId: 'o1', label: '#1042'),
      );
      expect(find.text('Orders · #1042'), findsOneWidget);
      await tester.tap(find.text('Orders · #1042'));
      await tester.pumpAndSettle();
      expect(find.text('card orders/o1'), findsOneWidget);
    });

    testWidgets('a deleted card: snackbar, muted, stays', (tester) async {
      await pumpRow(
        tester,
        const InboxLink(collectionId: 'orders', cardId: 'gone', label: '#9'),
      );
      await tester.tap(find.text('Orders · #9'));
      await tester.pumpAndSettle();
      expect(find.text('Card deleted'), findsOneWidget);
      expect(find.text('card orders/gone'), findsNothing);
      expect(find.byIcon(Icons.link_off), findsOneWidget);
    });

    testWidgets('a deleted collection', (tester) async {
      await pumpRow(
        tester,
        const InboxLink(collectionId: 'nope', cardId: 'x', label: '#1'),
      );
      expect(find.text('Collection deleted'), findsOneWidget);
      await tester.tap(find.text('Collection deleted'));
      await tester.pumpAndSettle();
      // Tapping the muted chip opens the row's editor, not a card.
      expect(find.text('Save'), findsOneWidget);
    });
  });
}
