// Renders the Work page states to PNGs for visual review (not part of the
// test suite). Run:
//
//   flutter test tool/screenshots/list_mode_shots_test.dart \
//     --dart-define=SHOTS_DIR=/abs/out --dart-define=FONTS_DIR=/abs/fonts
//
// FONTS_DIR holds BricolageGrotesque.ttf and HankenGrotesk.ttf (the app's
// Google Fonts); without them the theme's text falls back to Roboto.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/design/design.dart';

import '../../test/features/views/views_fixtures.dart';
import '../../test/features/views/work_page_harness.dart';

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
    final bytes = file.readAsBytesSync();
    await (FontLoader(
      family,
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  }

  await load('MaterialIcons', '$material/MaterialIcons-Regular.otf');
  await load('Roboto', '$material/Roboto-Regular.ttf');
  final text = AppTheme.light.textTheme;
  final families = {
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
    ])
      ?s?.fontFamily,
  };
  for (final family in families) {
    final file = family.startsWith('Bricolage')
        ? '$_fonts/BricolageGrotesque.ttf'
        : '$_fonts/HankenGrotesk.ttf';
    await load(
      family,
      File(file).existsSync() ? file : '$material/Roboto-Regular.ttf',
    );
  }
}

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final view = tester.binding.renderViews.first;
    final layer = view.debugLayer! as OffsetLayer;
    final size = view.size;
    final image = await layer.toImage(Offset.zero & size, pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$_out/$name.png')..createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

const _listView = ViewDefinition(
  id: 'list',
  name: 'Stages',
  mode: ViewModeIds.list,
  layoutFieldId: 'stage',
  fieldIds: ['name', 'amount', 'company', 'due'],
);

void main() {
  setUp(() => debugDisableShadows = false);
  tearDown(() => debugDisableShadows = true);

  testWidgets('list mode shots', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.runAsync(_loadFonts);
    final objects = [
      ...sampleDeals(),
      deal(
        'd6',
        5,
        name: 'Stark Industries expansion',
        amount: 48250.5,
        stage: 'won',
        company: 'k2',
        due: DateTime.utc(2026, 11, 14),
      ),
      deal(
        'd7',
        6,
        name: 'Wayne Enterprises',
        amount: 9900,
        stage: 'lead',
        company: 'k1',
        due: DateTime.utc(2026, 11, 3),
      ),
    ];
    for (final (name, size) in [
      ('list-1280', const Size(1280, 800)),
      ('list-390', const Size(390, 844)),
    ]) {
      await pumpWorkPage(
        tester,
        repository: workRepository(
          collection: deals.copyWith(views: [_listView]),
          objects: objects,
        ),
        size: size,
      );
      await tester.pumpAndSettle();
      await _shot(tester, name);
    }
    await tester.drag(find.byType(ReorderableListView), const Offset(0, -330));
    await tester.pumpAndSettle();
    await _shot(tester, 'list-390-scrolled');
  });
}
