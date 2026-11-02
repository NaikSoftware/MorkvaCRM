// Renders the Board mode to PNGs for visual review (not part of the test
// suite). Run:
//
//   flutter test tool/screenshots/board_shots_test.dart \
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
import 'package:morkva_crm/features/views/views.dart';
import 'package:morkva_crm/features/views/widgets/board/board_column.dart';

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

final _deals = [
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
  deal('d8', 7, name: 'Cyberdyne audit', amount: 2400, stage: 'lead'),
  deal('d9', 8, name: 'Soylent supply', amount: 15000, stage: 'lead'),
];

final _collection = deals.copyWith(
  views: [
    tableView,
    boardView.copyWith(fieldIds: ['name', 'amount', 'company', 'due']),
  ],
);

Future<CollectionViewsCubit> _board(
  WidgetTester tester, {
  Size size = const Size(1280, 800),
  Collection? collection,
}) async {
  final cubit = await pumpWorkPage(
    tester,
    size: size,
    repository: workRepository(
      collection: collection ?? _collection,
      objects: _deals,
    ),
  );
  cubit.selectView('board');
  // The app's ScaffoldMessenger outlives re-pumps; drop earlier snackbars.
  tester
      .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first)
      .clearSnackBars();
  await tester.pumpAndSettle();
  return cubit;
}

Finder _column(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(BoardColumn));

void main() {
  // flutter_test draws elevation shadows as black outlines by default.
  setUp(() => debugDisableShadows = false);
  tearDown(() => debugDisableShadows = true);

  testWidgets('board shots', (tester) async {
    await tester.runAsync(_loadFonts);

    await _board(tester);
    await _shot(tester, 'board-1280');

    await _board(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Initech')),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(0, 6));
    await tester.pump();
    await gesture.moveTo(
      tester.getCenter(_column('Won')) + const Offset(0, 30),
    );
    await tester.pump();
    await gesture.moveBy(const Offset(0, 1));
    await tester.pump(const Duration(milliseconds: 400));
    await _shot(tester, 'board-1280-drag');
    await gesture.up();
    await tester.pumpAndSettle();
    await _shot(tester, 'board-1280-dropped');

    await _board(tester);
    await tester.tap(find.text('Group: Stage'));
    await tester.pumpAndSettle();
    await _shot(tester, 'board-1280-group-menu');

    final byCompany = await _board(tester);
    await byCompany.setLayoutField('company');
    await tester.pumpAndSettle();
    await _shot(tester, 'board-1280-reference');

    final filtered = await _board(tester);
    await filtered.setFilters(const [
      ViewFilter(fieldId: 'name', op: FilterOp.contains, operand: 'zzz'),
    ]);
    await tester.pumpAndSettle();
    await _shot(tester, 'board-1280-no-matches');

    await _board(
      tester,
      collection: const Collection(
        id: 'deals',
        name: 'Deals',
        fields: [TextFieldDefinition(id: 'name', name: 'Name')],
        views: [
          ViewDefinition(
            id: 'board',
            name: 'Board',
            mode: ViewModeIds.board,
            fieldIds: ['name'],
          ),
        ],
      ),
    );
    await _shot(tester, 'board-1280-no-field');

    await _board(tester, size: const Size(390, 844));
    await _shot(tester, 'board-390');
  });
}
