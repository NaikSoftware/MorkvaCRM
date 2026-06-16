import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/design/design.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: child),
      );

  group('MorkvaTextField', () {
    testWidgets('renders an optional label above the field', (tester) async {
      await tester.pumpWidget(wrap(const MorkvaTextField(label: 'Email')));

      expect(find.text('Email'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows the error text', (tester) async {
      await tester.pumpWidget(
        wrap(const MorkvaTextField(label: 'Email', errorText: 'Required')),
      );

      expect(find.text('Required'), findsOneWidget);
    });

    testWidgets('fires onChanged with the typed value', (tester) async {
      String? changed;
      await tester.pumpWidget(
        wrap(MorkvaTextField(onChanged: (value) => changed = value)),
      );

      await tester.enterText(find.byType(TextField), 'hello');

      expect(changed, 'hello');
    });

    testWidgets('renders without a label when none is given', (tester) async {
      await tester.pumpWidget(wrap(const MorkvaTextField(hint: 'Type here')));

      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
