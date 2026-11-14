import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/api/api.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/features/collections/list/collection_card.dart';

import '../../features/collections/fake_data_repository.dart';
import '../../widget_test.dart' show FakeAuthRepository, testApp;

/// Phone has no sidebar, so All collections' header carries Jump to (the
/// page itself has no filter).
void main() {
  Future<void> pumpPhone(
    WidgetTester tester,
    List<Collection> collections,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = FakeAuthRepository()
      ..emit(const AuthUser(uid: 'u1', email: 'olena@example.com'));
    await tester.pumpWidget(
      testApp(auth: auth, data: FakeDataRepository(collections)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the header search opens Jump to and opens the pick', (
    tester,
  ) async {
    await pumpPhone(tester, const [
      Collection(id: 'c_orders', name: 'Orders'),
      Collection(id: 'c_clients', name: 'Clients'),
    ]);
    expect(find.byType(CollectionCard), findsNWidgets(2));
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.byTooltip('Jump to…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'cli');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clients').last);
    await tester.pumpAndSettle();

    expect(find.byType(CollectionCard), findsNothing);
    expect(find.byTooltip('Jump to…'), findsNothing);
  });

  testWidgets('no header search without collections', (tester) async {
    await pumpPhone(tester, const []);
    expect(find.text('No collections yet'), findsOneWidget);
    expect(find.byTooltip('Jump to…'), findsNothing);
  });
}
