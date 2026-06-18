import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/design/components/buttons/primary_button.dart';
import 'package:morkva_crm/design/components/morkva_confirm_dialog.dart';
import 'package:morkva_crm/design/theme/app_theme.dart';

/// Pumps a button that opens [MorkvaConfirmDialog.show] and captures its result.
Future<void> _pumpHost(
  WidgetTester tester, {
  required bool destructive,
  required void Function(bool?) onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                final result = await MorkvaConfirmDialog.show(
                  context,
                  title: 'Delete collection?',
                  message: 'This cannot be undone.',
                  confirmLabel: 'Delete',
                  destructive: destructive,
                );
                onResult(result);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('MorkvaConfirmDialog', () {
    testWidgets('renders title, message, and both actions', (tester) async {
      await _pumpHost(tester, destructive: true, onResult: (_) {});
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Delete collection?'), findsOneWidget);
      expect(find.text('This cannot be undone.'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('confirm resolves to true', (tester) async {
      bool? result;
      await _pumpHost(
        tester,
        destructive: true,
        onResult: (value) => result = value,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('cancel resolves to false', (tester) async {
      bool? result;
      await _pumpHost(
        tester,
        destructive: true,
        onResult: (value) => result = value,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });

    testWidgets('non-destructive confirm uses the carrot PrimaryButton', (
      tester,
    ) async {
      await _pumpHost(tester, destructive: false, onResult: (_) {});
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(PrimaryButton), findsOneWidget);
    });
  });
}
