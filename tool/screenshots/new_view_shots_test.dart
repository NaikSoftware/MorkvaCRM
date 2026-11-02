// Renders the New view dialog to PNGs (not part of the test suite). Run:
//
//   flutter test tool/screenshots/new_view_shots_test.dart \
//     --dart-define=SHOTS_DIR=/abs/out --dart-define=FONTS_DIR=/abs/fonts
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/views/modes/table_mode.dart';
import 'package:morkva_crm/features/views/modes/view_mode.dart';
import 'package:morkva_crm/features/views/widgets/new_view_dialog.dart';

import '../../test/features/views/views_fixtures.dart';

const _out = String.fromEnvironment('SHOTS_DIR', defaultValue: 'build/shots');
const _fonts = String.fromEnvironment('FONTS_DIR');

Future<void> _loadFonts() async {
  final sdk =
      Platform.environment['FLUTTER_ROOT'] ??
      '${Platform.environment['HOME']}/Dev/flutter';
  final material = '$sdk/bin/cache/artifacts/material_fonts';
  Future<void> load(String family, String path) async {
    final file = File(path);
    if (!file.existsSync()) return;
    await (FontLoader(family)
          ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync()))))
        .load();
  }

  await load('MaterialIcons', '$material/MaterialIcons-Regular.otf');
  await load('Roboto', '$material/Roboto-Regular.ttf');
  final text = AppTheme.light.textTheme;
  for (final s in [
    text.displayLarge,
    text.displayMedium,
    text.displaySmall,
    text.headlineLarge,
    text.headlineMedium,
    text.headlineSmall,
    text.titleLarge,
    text.titleMedium,
    text.titleSmall,
    text.bodyLarge,
    text.bodyMedium,
    text.bodySmall,
    text.labelLarge,
    text.labelMedium,
    text.labelSmall,
  ]) {
    final family = s?.fontFamily;
    if (family == null) continue;
    await load(
      family,
      '$_fonts/${family.startsWith('Bricolage') ? 'BricolageGrotesque' : 'HankenGrotesk'}.ttf',
    );
  }
}

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final view = tester.binding.renderViews.first;
    final layer = view.debugLayer! as OffsetLayer;
    final image = await layer.toImage(Offset.zero & view.size, pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_out/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

class _Fake extends ViewMode {
  const _Fake(this.id, this.label, this.icon, this.description, this.accepts);

  @override
  final String id;
  @override
  final String label;
  @override
  final IconData icon;
  @override
  final String description;
  final bool Function(FieldDefinition) accepts;

  @override
  bool get needsLayoutField => true;
  @override
  bool acceptsLayoutField(FieldDefinition f) => accepts(f);
  @override
  String? unavailableReason(Collection c) =>
      c.fields.any(accepts) ? null : 'Needs a date field';
  @override
  Widget buildBody(BuildContext context, ViewModeData data) => const SizedBox();
}

final _modes = ViewModeRegistry([
  const TableMode(),
  _Fake(
    'board',
    'Board',
    Icons.view_kanban_outlined,
    'Cards in columns',
    (f) => f is SingleSelectFieldDefinition,
  ),
  _Fake(
    'list',
    'List',
    Icons.view_agenda_outlined,
    'Rows of cards',
    (f) => true,
  ),
  _Fake(
    'calendar',
    'Calendar',
    Icons.calendar_month_outlined,
    'Cards on days',
    (f) => f is DateFieldDefinition,
  ),
]);

Future<void> _open(WidgetTester tester, Collection c, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => NewViewDialog.show(
              context,
              collection: c,
              modes: _modes,
              onAddField: () {},
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => debugDisableShadows = false);
  tearDown(() => debugDisableShadows = true);

  Future<void> setup(WidgetTester tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.runAsync(_loadFonts);
  }

  final noDates = deals.copyWith(
    fields: [
      for (final f in deals.fields)
        if (f is! DateFieldDefinition) f,
    ],
  );

  testWidgets('board 1280', (tester) async {
    await setup(tester);
    await _open(tester, noDates, const Size(1280, 800));
    await tester.enterText(find.byType(TextField), 'Pipeline');
    await tester.tap(find.text('Board'));
    await tester.pumpAndSettle();
    await _shot(tester, 'dialog-board-1280');
  });

  testWidgets('calendar 1280', (tester) async {
    await setup(tester);
    await _open(tester, deals, const Size(1280, 800));
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    await _shot(tester, 'dialog-calendar-1280');
  });

  testWidgets('phone 390', (tester) async {
    await setup(tester);
    await _open(tester, noDates, const Size(390, 844));
    await tester.enterText(find.byType(TextField), 'Pipeline');
    await tester.pumpAndSettle();
    await _shot(tester, 'dialog-390');
  });
}
