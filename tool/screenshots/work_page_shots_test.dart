// ignore_for_file: invalid_use_of_visible_for_testing_member
// Renders the Work page states to PNGs for visual review (not part of the
// test suite). Run:
//
//   flutter test tool/screenshots/work_page_shots_test.dart \
//     --dart-define=SHOTS_DIR=/abs/out --dart-define=FONTS_DIR=/abs/fonts
//
// FONTS_DIR holds BricolageGrotesque.ttf and HankenGrotesk.ttf (the app's
// Google Fonts); without them the theme's text falls back to Roboto.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:morkva_crm/features/collections/editor/collection_editor_cubit.dart';
import 'package:morkva_crm/features/collections/editor/collection_editor_page.dart';
import 'package:morkva_crm/features/collections/field_editors/built_in_field_editors.dart';
import 'package:morkva_crm/features/views/views.dart';
import '../../test/features/collections/fake_data_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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

final _richDeals = [
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
  deal(
    'd8',
    7,
    name: 'Cyberdyne audit',
    amount: 0.1 + 0.2,
    stage: 'lost',
    due: DateTime.utc(2026, 12, 1),
  ),
  deal('d9', 8, name: 'Soylent supply', amount: 15000, stage: 'lead'),
];

final _shotDeals = deals.copyWith(
  views: [
    tableView.copyWith(
      fieldIds: ['name', 'amount', 'stage', 'company', 'due', 'meeting'],
    ),
    boardView,
  ],
);

void main() {
  // flutter_test draws elevation shadows as black outlines by default.
  setUp(() {
    debugDisableShadows = false;
  });
  tearDown(() => debugDisableShadows = true);

  testWidgets('work page shots', (tester) async {
    await tester.runAsync(_loadFonts);

    await pumpWorkPage(tester, initialize: false);
    await tester.pump(const Duration(milliseconds: 600));
    await _shot(tester, 'loading-1280');

    await pumpWorkPage(
      tester,
      repository: workRepository(collection: _shotDeals, objects: _richDeals),
    );
    await tester.pumpAndSettle();
    await _shot(tester, 'table-1280');

    await pumpWorkPage(
      tester,
      repository: workRepository(collection: _shotDeals, objects: _richDeals),
      size: const Size(390, 844),
    );
    await tester.pumpAndSettle();
    await _shot(tester, 'table-390');

    await pumpWorkPage(
      tester,
      repository: workRepository(collection: _shotDeals, objects: _richDeals),
      size: const Size(390, 844),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.text('Amount').first, const Offset(-300, 0));
    await tester.pumpAndSettle();
    await _shot(tester, 'table-390-scrolled');

    await pumpWorkPage(
      tester,
      repository: workRepository(collection: _shotDeals, objects: const []),
    );
    await tester.pumpAndSettle();
    await _shot(tester, 'empty-1280');

    await pumpWorkPage(
      tester,
      repository: workRepository(collection: _shotDeals, objects: const []),
      size: const Size(390, 844),
    );
    await tester.pumpAndSettle();
    await _shot(tester, 'empty-390');

    final filtered = await pumpWorkPage(
      tester,
      repository: workRepository(collection: _shotDeals, objects: _richDeals),
    );
    await filtered.setFilters(const [
      ViewFilter(fieldId: 'stage', op: FilterOp.anyOf, operand: ['lead']),
      ViewFilter(fieldId: 'amount', op: FilterOp.greaterThan, operand: 100),
    ]);
    await tester.pumpAndSettle();
    await _shot(tester, 'filtered-1280');
    await filtered.setFilters(const [
      ViewFilter(fieldId: 'name', op: FilterOp.contains, operand: 'zzz'),
    ]);
    await tester.pumpAndSettle();
    await _shot(tester, 'no-matches-1280');

    await pumpWorkPage(
      tester,
      repository: workRepository(
        collection: const Collection(id: 'deals', name: 'Deals'),
        objects: const [],
      ),
    );
    await tester.pumpAndSettle();
    await _shot(tester, 'no-fields-1280');

    await pumpWorkPage(
      tester,
      repository: workRepository(collection: _shotDeals, objects: _richDeals),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stark Industries expansion'));
    await tester.pumpAndSettle();
    await _shot(tester, 'detail-1280');
  });

  testWidgets('first run shots', (tester) async {
    await tester.runAsync(_loadFonts);
    resetFirstItemNudges();
    for (final (name, size) in [
      ('1280', const Size(1280, 800)),
      ('390', const Size(390, 844)),
    ]) {
      resetFirstItemNudges();
      await pumpWorkPage(
        tester,
        size: size,
        repository: workRepository(objects: const []),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await _shot(tester, 'first-run-work-$name');

      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      final registry = defaultFieldEditorRegistry();
      final cubit = CollectionEditorCubit(
        FakeDataRepository([
          const Collection(
            id: 'c1',
            name: 'Deals',
            fields: [TextFieldDefinition(id: 'f1', name: 'Name')],
          ),
          const Collection(id: 'c2', name: 'Customers'),
        ]),
        registry,
      );
      await cubit.load('c1');
      final router = GoRouter(
        initialLocation: '/e',
        routes: [
          GoRoute(
            path: '/e',
            builder: (_, _) => BlocProvider.value(
              value: cubit,
              child: CollectionEditorPage(registry: registry),
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      );
      await tester.pumpAndSettle();
      await _shot(tester, 'first-run-build-$name');
      await tester.tap(find.byKey(const Key('suggest_Status')));
      await tester.pumpAndSettle();
      await _shot(tester, 'first-run-build-chip-$name');
      await cubit.close();
    }
  });
}
