import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/design/collection_icons.dart';
import 'package:morkva_crm/design/components/collection_glyph.dart';
import 'package:morkva_crm/design/morkva_icons.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

  testWidgets('renders the fallback glyph when iconKey is null', (tester) async {
    await tester.pumpWidget(host(const CollectionGlyph(iconKey: null)));
    expect(find.byIcon(CollectionIcons.fallback), findsOneWidget);
  });

  testWidgets('renders the chosen glyph for a known key', (tester) async {
    final truck = CollectionIcons.all.firstWhere((o) => o.key == 'truck');
    await tester.pumpWidget(host(const CollectionGlyph(iconKey: 'truck')));
    expect(find.byIcon(truck.icon), findsOneWidget);
  });

  testWidgets('without onTap it is not interactive (no edit badge)', (tester) async {
    await tester.pumpWidget(host(const CollectionGlyph(iconKey: 'truck')));
    expect(find.byIcon(MorkvaIcons.edit), findsNothing);
  });

  testWidgets('with onTap it shows an edit badge and fires the callback',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      host(CollectionGlyph(iconKey: null, onTap: () => tapped = true)),
    );
    expect(find.byIcon(MorkvaIcons.edit), findsOneWidget);
    await tester.tap(find.byType(CollectionGlyph));
    expect(tapped, isTrue);
  });
}
