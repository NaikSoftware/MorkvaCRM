// Renders the Calendar mode to PNGs for visual review (not part of the test
// suite). Run:
//
//   flutter test tool/screenshots/calendar_shots_test.dart \
//     --dart-define=SHOTS_DIR=/abs/out --dart-define=FONTS_DIR=/abs/fonts
//
// FONTS_DIR holds BricolageGrotesque.ttf and HankenGrotesk.ttf (the app's
// Google Fonts); without them the theme's text falls back to Roboto.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/design/design.dart';

import '../../test/features/collections/fake_data_repository.dart';
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

DateTime _nov(int day) => DateTime.utc(2026, 11, day);

final _calendarDeals = [
  deal(
    'c1',
    0,
    name: 'Acme renewal',
    amount: 1200,
    stage: 'lead',
    due: _nov(3),
  ),
  deal('c2', 1, name: 'Globex pilot', amount: 300, stage: 'won', due: _nov(3)),
  deal('c3', 2, name: 'Initech', amount: 50, stage: 'lead', due: _nov(5)),
  for (var i = 0; i < 5; i++)
    deal(
      'm$i',
      3 + i,
      name: ['Umbrella', 'Stark', 'Wayne', 'Cyberdyne', 'Tyrell'][i],
      stage: ['lost', 'won', 'lead', 'lead', 'won'][i],
      due: _nov(12),
    ),
  deal(
    'c4',
    9,
    name: 'Soylent supply',
    amount: 15000,
    stage: 'won',
    due: _nov(19),
  ),
  deal('c5', 10, name: 'Oscorp', stage: 'lost', due: _nov(26)),
  deal('c6', 11, name: 'Hooli', amount: 900),
  deal('c7', 12, name: 'Pied Piper', stage: 'lead'),
];

final _calendarCollection = deals.copyWith(
  views: [
    const ViewDefinition(
      id: 'cal',
      name: 'Due dates',
      mode: ViewModeIds.calendar,
      layoutFieldId: 'due',
      fieldIds: ['name', 'amount', 'stage'],
    ),
    tableView,
  ],
);

void main() {
  // flutter_test draws elevation shadows as black outlines by default.
  setUp(() => debugDisableShadows = false);
  tearDown(() => debugDisableShadows = true);

  testWidgets('calendar shots', (tester) async {
    await tester.runAsync(_loadFonts);
    FakeDataRepository repo() => workRepository(
      collection: _calendarCollection,
      objects: _calendarDeals,
    );

    // A desktop has a mouse: cell "+" buttons stay hidden until hover.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);

    await pumpWorkPage(tester, repository: repo());
    await tester.pumpAndSettle();
    await _shot(tester, 'calendar-1280');

    await tester.tap(find.byTooltip('Hide No date'));
    await tester.pumpAndSettle();
    await _shot(tester, 'calendar-1280-tray-collapsed');

    await pumpWorkPage(tester, repository: repo());
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('more').first);
    await tester.pumpAndSettle();
    await _shot(tester, 'calendar-1280-more');

    await pumpWorkPage(tester, repository: repo(), size: const Size(390, 844));
    await tester.pumpAndSettle();
    await _shot(tester, 'calendar-390');

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('No date ('));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    await _shot(tester, 'calendar-390-scrolled');

    await pumpWorkPage(
      tester,
      repository: workRepository(
        collection: const Collection(
          id: 'deals',
          name: 'Deals',
          fields: [TextFieldDefinition(id: 'name', name: 'Name')],
          views: [
            ViewDefinition(
              id: 'cal',
              name: 'Calendar',
              mode: ViewModeIds.calendar,
              fieldIds: ['name'],
            ),
          ],
        ),
        objects: const [],
      ),
    );
    await tester.pumpAndSettle();
    await _shot(tester, 'calendar-no-date-field-1280');
  });
}
