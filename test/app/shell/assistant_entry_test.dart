import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:morkva_crm/api/api.dart';
import 'package:morkva_crm/app/shell/app_shell_scaffold.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/assistant/bloc/assistant_session.dart';
import 'package:morkva_crm/features/assistant/bloc/assistant_state.dart';
import 'package:morkva_crm/features/assistant/view/assistant_page.dart';
import 'package:morkva_crm/features/assistant/view/assistant_panel.dart';
import 'package:morkva_crm/features/assistant/view/thread_list_page.dart';
import 'package:morkva_crm/features/automation/widgets/run_indicator.dart';
import 'package:morkva_crm/features/home/home_page.dart';
import 'package:morkva_crm/features/views/collection_views_page.dart';

import '../../widget_test.dart'
    show FakeAuthRepository, FakeDataRepository, testApp;

/// Ask Morkva's entry points over the whole app: the sidebar toggle and its
/// side panel (beside the page at >= 1280, a sheet below), the rail icon,
/// the phone header action and its `/assistant` route, Ctrl+J, and the
/// feature flag hiding all of it.
void main() {
  late FakeAuthRepository auth;
  late FakeFirebaseFirestore firestore;

  setUp(() {
    auth = FakeAuthRepository()
      ..emit(
        const AuthUser(
          uid: 'u1',
          email: 'olena@example.com',
          displayName: 'Olena Koval',
        ),
      );
    firestore = FakeFirebaseFirestore();
  });

  Future<void> pumpApp(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(auth: auth, data: FakeDataRepository(), firestore: firestore),
    );
    await tester.pumpAndSettle();
  }

  AssistantSession session(WidgetTester tester) => tester
      .element(find.byType(AppShellScaffold, skipOffstage: false))
      .read<AssistantSession>();

  Future<void> pressCtrl(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  AssistantPanel panel(WidgetTester tester) =>
      tester.widget<AssistantPanel>(find.byType(AssistantPanel));

  group('sidebar (>= 1240)', () {
    testWidgets('at 1300 the panel pushes the page and the toggle shows it', (
      tester,
    ) async {
      await pumpApp(tester, const Size(1300, 900));
      expect(find.byType(AssistantPanel), findsNothing);

      await tester.tap(find.text('Ask Morkva'));
      await tester.pumpAndSettle();

      expect(panel(tester).overlay, isFalse);
      expect(session(tester).panel.isOpen, isTrue);
      // Beside the page: sidebar 272 + page + panel 440 = the window.
      final page = tester.getRect(find.byType(DoodleBackground).first);
      expect(page.width, 1300 - 272 - 440);
      expect(tester.getRect(find.byType(AssistantPanel)).left, page.right);
      // A toggle (aria-pressed), never styled as the current page.
      final toggle = tester.widget<Semantics>(
        find.ancestor(
          of: find.text('Ask Morkva').first,
          matching: find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.toggled != null,
          ),
        ),
      );
      expect(toggle.properties.toggled, isTrue);
      expect(toggle.properties.button, isTrue);
      expect(toggle.properties.selected, isNull);

      // The toggle closes it again.
      await tester.tap(find.text('Ask Morkva').first);
      await tester.pumpAndSettle();
      expect(find.byType(AssistantPanel), findsNothing);
      expect(session(tester).panel.isOpen, isFalse);
    });

    testWidgets('below 1280 it is a sheet over the page; the scrim closes it', (
      tester,
    ) async {
      await pumpApp(tester, const Size(1250, 900));
      final page = tester.element(find.byType(HomePage));
      await tester.tap(find.text('Ask Morkva'));
      await tester.pumpAndSettle();

      expect(panel(tester).overlay, isTrue);
      // The page under the sheet is the same one (not rebuilt from scratch).
      expect(tester.element(find.byType(HomePage)), same(page));
      // The page keeps its width under the sheet.
      expect(
        tester.getRect(find.byType(DoodleBackground).first).width,
        1250 - 272,
      );

      await tester.tapAt(const Offset(400, 450));
      await tester.pumpAndSettle();
      expect(find.byType(AssistantPanel), findsNothing);
    });

    testWidgets('Ctrl+J toggles it, Esc closes it, not over a dialog', (
      tester,
    ) async {
      await pumpApp(tester, const Size(1300, 900));

      await pressCtrl(tester, LogicalKeyboardKey.keyJ);
      expect(find.byType(AssistantPanel), findsOneWidget);
      // Focus went to the composer.
      expect(
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<AssistantPanel>(),
        isNotNull,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(AssistantPanel), findsNothing);

      await pressCtrl(tester, LogicalKeyboardKey.keyJ);
      expect(find.byType(AssistantPanel), findsOneWidget);
      await pressCtrl(tester, LogicalKeyboardKey.keyJ);
      expect(find.byType(AssistantPanel), findsNothing);

      // Over the Jump to dialog the shell does not take Ctrl+J.
      await pressCtrl(tester, LogicalKeyboardKey.keyK);
      expect(find.byType(Dialog), findsOneWidget);
      await pressCtrl(tester, LogicalKeyboardKey.keyJ);
      expect(session(tester).panel.isOpen, isFalse);
    });
  });

  testWidgets(
    'rail (840–1239): an icon with its tooltip opens a sheet over the page',
    (tester) async {
      await pumpApp(tester, const Size(1000, 800));
      expect(find.text('Ask Morkva'), findsNothing);

      await tester.tap(find.byTooltip('Ask Morkva · Ctrl J'));
      await tester.pumpAndSettle();

      expect(panel(tester).overlay, isTrue);
      final sheet = tester.getRect(find.byType(AssistantPanel));
      expect(sheet.right, 1000);
      expect(sheet.width, AssistantPanel.width);

      await tester.tap(find.byTooltip('Close assistant'));
      await tester.pumpAndSettle();
      expect(find.byType(AssistantPanel), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets('the Automations page offers Ask Morkva', (tester) async {
    await pumpApp(tester, const Size(1300, 900));
    await tester.tap(find.text('Automations'));
    await tester.pumpAndSettle();
    expect(find.text('Ask Morkva to write one'), findsOneWidget);

    await tester.tap(find.text('Ask Morkva to write one'));
    await tester.pumpAndSettle();
    // The panel opens and its composer takes the text.
    expect(session(tester).panel.isOpen, isTrue);
    expect(session(tester).draft.value, isNull);
    expect(
      find.descendant(
        of: find.byType(AssistantPanel),
        matching: find.widgetWithText(TextField, 'Write a module that '),
      ),
      findsOneWidget,
    );
  });

  testWidgets('phone: the header sparkle opens /assistant and its history', (
    tester,
  ) async {
    await pumpApp(tester, const Size(400, 800));
    expect(find.byType(AssistantPanel), findsNothing);

    await tester.tap(find.byTooltip('Ask Morkva'));
    await tester.pumpAndSettle();

    expect(find.byType(AssistantPage), findsOneWidget);
    expect(find.byType(AssistantPanel), findsNothing);
    // The run indicator stays in sight in the chat's header.
    expect(
      find.descendant(
        of: find.byType(AssistantPage),
        matching: find.byType(RunIndicatorButton),
      ),
      findsOneWidget,
    );
    // The route keeps the chat's collections warm.
    expect(session(tester).panel.isOpen, isTrue);

    await tester.tap(find.byTooltip('Conversation history'));
    await tester.pumpAndSettle();
    expect(find.byType(ThreadListPage), findsOneWidget);
    expect(find.text('No conversations yet'), findsOneWidget);

    await tester.tap(find.byTooltip('Back').last);
    await tester.pumpAndSettle();
    expect(find.byType(ThreadListPage), findsNothing);
    expect(find.byType(AssistantPage), findsOneWidget);

    await tester.tap(find.byTooltip('Back').last);
    await tester.pumpAndSettle();
    expect(find.byType(AssistantPage), findsNothing);
    expect(find.text('No collections yet'), findsOneWidget);
    expect(session(tester).panel.isOpen, isFalse);
  });

  testWidgets('phone: a collection page header has the sparkle too', (
    tester,
  ) async {
    await pumpApp(tester, const Size(400, 800));
    GoRouter.of(
      tester.element(find.byType(AppShellScaffold)),
    ).go('/collections/c1');
    await tester.pumpAndSettle();
    expect(find.byType(CollectionViewsPage), findsOneWidget);
    // The shell draws no header over a collection: this one is the page's.
    final ask = find.descendant(
      of: find.byType(AppBar),
      matching: find.byTooltip('Ask Morkva'),
    );
    expect(ask, findsOneWidget);

    await tester.tap(ask);
    await tester.pumpAndSettle();
    expect(find.byType(AssistantPage), findsOneWidget);
    expect(session(tester).panel.isOpen, isTrue);
  });

  group('feature flag off', () {
    setUp(
      () => firestore.collection('featureFlags').doc('u1').set({
        'assistant': false,
      }),
    );

    Future<void> flagRead(WidgetTester tester) async {
      final bloc = session(tester).bloc;
      expect(bloc.state.availability, isA<AvailabilityDisabledByFlag>());
    }

    testWidgets('no sidebar toggle, and Ctrl+J does nothing', (tester) async {
      await pumpApp(tester, const Size(1300, 900));
      await flagRead(tester);

      expect(find.text('Ask Morkva'), findsNothing);
      await pressCtrl(tester, LogicalKeyboardKey.keyJ);
      expect(find.byType(AssistantPanel), findsNothing);
    });

    testWidgets('no Ask Morkva entries on the Automations page', (
      tester,
    ) async {
      await pumpApp(tester, const Size(1300, 900));
      await flagRead(tester);
      await tester.tap(find.text('Automations'));
      await tester.pumpAndSettle();
      expect(find.text('No modules yet'), findsOneWidget);
      expect(find.text('Ask Morkva to write one'), findsNothing);
      expect(find.text('Ask Morkva'), findsNothing);
      expect(find.text('Import module'), findsWidgets);
    });

    testWidgets('no rail icon', (tester) async {
      await pumpApp(tester, const Size(1000, 800));
      await flagRead(tester);
      expect(find.byTooltip('Ask Morkva'), findsNothing);
      expect(find.byTooltip('Ask Morkva · Ctrl J'), findsNothing);
    });

    testWidgets('no phone header action', (tester) async {
      await pumpApp(tester, const Size(400, 800));
      await flagRead(tester);
      expect(find.byTooltip('Ask Morkva'), findsNothing);
      expect(find.byTooltip('Account and settings'), findsOneWidget);
    });

    testWidgets('no phone header action on a collection page', (tester) async {
      await pumpApp(tester, const Size(400, 800));
      await flagRead(tester);
      GoRouter.of(
        tester.element(find.byType(AppShellScaffold)),
      ).go('/collections/c1');
      await tester.pumpAndSettle();
      expect(find.byType(CollectionViewsPage), findsOneWidget);
      expect(find.byTooltip('Ask Morkva'), findsNothing);
    });

    testWidgets('an open panel closes when the flag turns off', (tester) async {
      await firestore.collection('featureFlags').doc('u1').delete();
      await pumpApp(tester, const Size(1300, 900));
      await tester.tap(find.text('Ask Morkva'));
      await tester.pumpAndSettle();
      expect(find.byType(AssistantPanel), findsOneWidget);

      await firestore.collection('featureFlags').doc('u1').set({
        'assistant': false,
      });
      await tester.pumpAndSettle();

      expect(find.byType(AssistantPanel), findsNothing);
      expect(session(tester).panel.isOpen, isFalse);
      expect(find.text('Ask Morkva'), findsNothing);
    });
  });

  testWidgets('signing out closes the panel', (tester) async {
    await pumpApp(tester, const Size(1300, 900));
    await tester.tap(find.text('Ask Morkva'));
    await tester.pumpAndSettle();
    final assistant = session(tester);
    expect(assistant.panel.isOpen, isTrue);

    auth.emit(null);
    await tester.pumpAndSettle();

    expect(find.text('Welcome to your workspace'), findsOneWidget);
    expect(assistant.panel.isOpen, isFalse);
    expect(assistant.workspaceId, isNull);
  });
}
