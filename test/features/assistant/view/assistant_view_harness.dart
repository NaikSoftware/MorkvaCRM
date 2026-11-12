import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/assistant/bloc/assistant_state.dart';
import 'package:morkva_crm/features/assistant/bloc/chat_item.dart';
import 'package:morkva_crm/features/assistant/view/assistant_actions.dart';
import 'package:morkva_crm/features/assistant/view/assistant_panel.dart';
import 'package:morkva_crm/features/assistant/view/widgets/assistant_scope.dart';
import 'package:morkva_crm/features/assistant/view/widgets/plan_card_scope.dart';

/// Records every [AssistantActions] call as `name(args)` for assertions.
class RecordingActions implements AssistantActions {
  final List<String> calls = [];
  final Map<String, Set<String>> selections = {};
  final List<TableItem> openedTables = [];

  @override
  void submit(String text) => calls.add('submit($text)');

  @override
  void suggest(String text) => calls.add('suggest($text)');

  @override
  void stop() => calls.add('stop()');

  @override
  void changePlanSelection(String planId, Set<String> itemIds) {
    selections[planId] = itemIds;
    calls.add('select($planId, ${(itemIds.toList()..sort()).join(',')})');
  }

  @override
  void approvePlan(String planId) => calls.add('approve($planId)');

  @override
  void rejectPlan(String planId) => calls.add('reject($planId)');

  @override
  void undo(String journalId) => calls.add('undo($journalId)');

  @override
  void retryFailed(String planId) => calls.add('retryFailed($planId)');

  @override
  void retry() => calls.add('retry()');

  @override
  void retryNow() => calls.add('retryNow()');

  @override
  void clearFocus() => calls.add('clearFocus()');

  @override
  void newThread() => calls.add('newThread()');

  @override
  void grantConsent() => calls.add('grantConsent()');

  @override
  void openObject({
    required String collectionId,
    String? cardId,
    String? viewId,
  }) => calls.add('open($collectionId, $cardId, $viewId)');

  @override
  void openTable(TableItem item) {
    openedTables.add(item);
    calls.add('openTable(${item.id})');
  }

  @override
  void viewCode(PlanRow row) => calls.add('viewCode(${row.itemId})');
}

/// A pinned clock for countdowns.
final testNow = DateTime(2026, 11, 10, 12, 40);

/// Hosts [child] (a single assistant widget) in the app theme with both
/// scopes, as the chat list provides them.
Future<void> pumpInScope(
  WidgetTester tester,
  Widget child, {
  required AssistantActions actions,
  ThemeData? theme,
  DateTime Function()? now,
  bool phone = false,
  double width = 404,
}) async {
  final clock = now ?? () => testNow;
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme ?? AppTheme.light,
      home: Scaffold(
        body: AssistantScope(
          actions: actions,
          now: clock,
          phone: phone,
          child: PlanCardScope(
            actions: actions,
            now: clock,
            child: _Sized(width: width, child: child),
          ),
        ),
      ),
    ),
  );
}

/// Hosts a plan widget ([child]) under [PlanCardScope] only — no
/// `AssistantScope`, as the automation review sheet does.
Future<void> pumpInPlanScope(
  WidgetTester tester,
  Widget child, {
  required PlanCardActions actions,
  DateTime Function()? now,
  double width = 404,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(
        body: PlanCardScope(
          actions: actions,
          now: now ?? () => testNow,
          child: _Sized(width: width, child: child),
        ),
      ),
    ),
  );
}

class _Sized extends StatelessWidget {
  const _Sized({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: width,
      child: SingleChildScrollView(child: child),
    ),
  );
}

/// Hosts an [AssistantPanel] on a 440 × 900 surface.
Future<void> pumpPanel(
  WidgetTester tester,
  StateStreamable<AssistantState> bloc, {
  required AssistantActions actions,
  ThemeData? theme,
  Size size = const Size(440, 900),
  DateTime Function()? now,
  VoidCallback? onClose,
  AssistantHistoryBuilder? historyBuilder,
  bool initiallyShowHistory = false,
  bool autofocus = false,
}) async {
  await setSurface(tester, size);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme ?? AppTheme.light,
      home: Scaffold(
        body: Align(
          alignment: Alignment.centerRight,
          child: AssistantPanel(
            bloc: bloc,
            actions: actions,
            onClose: onClose ?? () {},
            historyBuilder: historyBuilder,
            initiallyShowHistory: initiallyShowHistory,
            autofocus: autofocus,
            now: now ?? () => testNow,
          ),
        ),
      ),
    ),
  );
}

Future<void> setSurface(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}

bool _fontsLoaded = false;

/// Loads real glyphs so goldens are readable: the Flutter SDK's Roboto under
/// the app's Google Fonts family names (Hanken / Bricolage are not on this
/// machine and tests never touch the network) and the Material icons.
Future<void> loadAppFonts() async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;
  // google_fonts would fetch the real families and, on the test binding's
  // 400s, throw into the golden comparison; let those requests never land.
  HttpOverrides.global = _OfflineHttp();
  // flutter_tester lives in <sdk>/bin/cache/artifacts/engine/<platform>/.
  final engine = File(Platform.resolvedExecutable).parent;
  final artifacts = engine.parent.parent;
  final fonts = Directory('${artifacts.path}/material_fonts');
  Future<ByteData> read(String name) async {
    final bytes = await File('${fonts.path}/$name').readAsBytes();
    return ByteData.sublistView(bytes);
  }

  // google_fonts names a style's family `<Family>_<variant>` (`regular`,
  // `500`, …); the test engine does not fall back across families.
  final families = [
    'Roboto',
    for (final f in ['HankenGrotesk', 'BricolageGrotesque']) ...[
      f,
      '${f}_regular',
      for (var w = 100; w <= 900; w += 100)
        if (w != 400) '${f}_$w',
    ],
  ];
  for (final family in families) {
    final loader = FontLoader(family);
    for (final w in ['Regular', 'Medium', 'Bold']) {
      loader.addFont(read('Roboto-$w.ttf'));
    }
    await loader.load();
  }
  final icons = FontLoader('MaterialIcons')
    ..addFont(read('MaterialIcons-Regular.otf'));
  await icons.load();
}

class _OfflineHttp extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _PendingClient();
}

/// An [HttpClient] whose requests stay pending forever.
class _PendingClient implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) =>
      Completer<HttpClientRequest>().future;

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
