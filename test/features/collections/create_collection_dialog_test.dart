import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/design/collection_icons.dart';
import 'package:morkva_crm/features/collections/list/create_collection_dialog.dart';

void main() {
  testWidgets('create dialog returns the icon chosen from the picker',
      (tester) async {
    CollectionFormResult? result;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await CollectionFormDialog.create(context);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Name it.
    await tester.enterText(find.byType(TextField).first, 'Orders');

    // Open the icon picker via the glyph tile, then choose "cart".
    final cart = CollectionIcons.all.firstWhere((o) => o.key == 'cart');
    await tester.tap(find.byIcon(CollectionIcons.fallback)); // glyph tile
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(cart.icon));
    await tester.pumpAndSettle();

    // Confirm.
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.name, 'Orders');
    expect(result!.icon, 'cart');
  });

  testWidgets('rename dialog pre-selects the existing icon', (tester) async {
    CollectionFormResult? result;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await CollectionFormDialog.rename(
                  context,
                  name: 'Orders',
                  icon: 'truck',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final truck = CollectionIcons.all.firstWhere((o) => o.key == 'truck');
    // The glyph tile shows the pre-selected truck icon (not the fallback).
    expect(find.byIcon(truck.icon), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result!.icon, 'truck');
  });
}
