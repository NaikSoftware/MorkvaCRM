// Renders the Build editor header (Task 4) to PNGs for visual review (not part of the
// test suite). Run:
//
//   flutter test tool/screenshots/work_page_shots_test.dart \
//     --dart-define=SHOTS_DIR=/abs/out --dart-define=FONTS_DIR=/abs/fonts
//
// FONTS_DIR holds BricolageGrotesque.ttf and HankenGrotesk.ttf (the app's
// Google Fonts); without them the theme's text falls back to Roboto.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:morkva_crm/design/design.dart';
import 'package:morkva_crm/features/collections/editor/collection_editor_cubit.dart';
import 'package:morkva_crm/features/collections/editor/collection_editor_page.dart';
import 'package:morkva_crm/features/collections/field_editors/built_in_field_editors.dart';
import '../../test/features/collections/fake_data_repository.dart';

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

const _collection = Collection(
  id: 'c1',
  name: 'Deals',
  fields: [
    TextFieldDefinition(id: 'f1', name: 'Name'),
    TextFieldDefinition(id: 'f2', name: 'Notes'),
  ],
);

void main() {
  setUp(() {
    debugDisableShadows = false;
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  tearDown(() => debugDisableShadows = true);

  for (final (name, w, h) in [('1280', 1280.0, 800.0), ('390', 390.0, 844.0)]) {
    testWidgets('editor header $name', (tester) async {
      await tester.runAsync(_loadFonts);
      tester.view.physicalSize = Size(w, h);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final registry = defaultFieldEditorRegistry();
      final cubit = CollectionEditorCubit(
        FakeDataRepository(const [_collection]),
        registry,
      );
      await cubit.load('c1');
      addTearDown(cubit.close);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: BlocProvider.value(
            value: cubit,
            child: CollectionEditorPage(registry: registry),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _shot(tester, 'editor-header-$name');
    });
  }
}
