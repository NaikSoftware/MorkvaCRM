import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/design/theme/app_theme.dart';
import 'package:morkva_crm/features/collections/list/collection_card.dart';

void main() {
  testWidgets('overflow menu offers Customize and reports it', (tester) async {
    CollectionCardAction? picked;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: CollectionCard(
            collection: Collection(id: 'c1', name: 'Tasks', fields: const []),
            onOpen: () {},
            onAction: (a) => picked = a,
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Customize'));
    await tester.pumpAndSettle();
    expect(picked, CollectionCardAction.customize);
  });
}
