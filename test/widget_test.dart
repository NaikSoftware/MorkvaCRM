import 'package:flutter_test/flutter_test.dart';

import 'package:morkva_crm/main.dart';

void main() {
  testWidgets('App shell renders', (tester) async {
    await tester.pumpWidget(const MorkvaApp());
    expect(find.text('MorkvaCRM'), findsOneWidget);
  });
}
