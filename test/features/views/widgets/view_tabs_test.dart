import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/features/views/views.dart';

import '../views_fixtures.dart';

void main() {
  testWidgets('⋯ menu opens under the button inside an offset overlay', (
    tester,
  ) async {
    // A nested Navigator to the right of a 300 px sidebar, like the shell.
    await tester.pumpWidget(
      MaterialApp(
        home: Row(
          children: [
            const SizedBox(width: 300),
            Expanded(
              child: Navigator(
                onGenerateRoute: (_) => MaterialPageRoute(
                  builder: (_) => Material(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: ViewTabs(
                        views: const [tableView, boardView],
                        activeViewId: tableView.id,
                        modes: defaultViewModeRegistry(),
                        onSelect: (_) {},
                        onNewView: () {},
                        onRename: (_, _) {},
                        onDuplicate: (_) {},
                        onDelete: (_) {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final button = find.byTooltip('View options');
    await tester.tap(button);
    await tester.pumpAndSettle();

    final buttonLeft = tester.getBottomLeft(button);
    final menuLeft = tester.getTopLeft(
      find.byWidgetPredicate((w) => w is PopupMenuItem).first,
    );
    expect((menuLeft.dx - buttonLeft.dx).abs(), lessThan(24));
  });
}
