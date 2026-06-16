import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/design/components/morkva_app_bar.dart';
import 'package:morkva_crm/design/theme/app_theme.dart';

void main() {
  Widget host(MorkvaAppBar appBar) => MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(appBar: appBar),
      );

  group('MorkvaAppBar', () {
    testWidgets('renders the title', (tester) async {
      await tester.pumpWidget(host(const MorkvaAppBar(title: 'Contacts')));

      expect(find.text('Contacts'), findsOneWidget);
    });

    testWidgets('renders the provided actions', (tester) async {
      await tester.pumpWidget(
        host(
          MorkvaAppBar(
            title: 'Contacts',
            actions: [
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () {},
              ),
            ],
          ),
        ),
      );

      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('reports a preferred size that accounts for the bottom',
        (tester) async {
      const bottom = PreferredSize(
        preferredSize: Size.fromHeight(48),
        child: SizedBox(height: 48),
      );
      const appBar = MorkvaAppBar(title: 'Contacts', bottom: bottom);

      expect(appBar.preferredSize.height, kToolbarHeight + 48);
    });
  });
}
