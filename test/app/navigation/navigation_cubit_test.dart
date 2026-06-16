import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/app/navigation/navigation_cubit.dart';

void main() {
  group('NavigationCubit', () {
    test('initial state is home', () {
      final cubit = NavigationCubit();
      addTearDown(cubit.close);

      expect(cubit.state, AppSection.home);
    });

    test('select(settings) emits settings', () {
      final cubit = NavigationCubit();
      addTearDown(cubit.close);

      expectLater(cubit.stream, emits(AppSection.settings));

      cubit.select(AppSection.settings);
      expect(cubit.state, AppSection.settings);
    });

    test('selecting the same section twice does not re-emit', () {
      final cubit = NavigationCubit();
      addTearDown(cubit.close);

      expectLater(
        cubit.stream,
        emitsInOrder([AppSection.settings, AppSection.home]),
      );

      cubit.select(AppSection.settings);
      cubit.select(AppSection.settings); // no-op: same state
      cubit.select(AppSection.home);
    });

    test('kAppSections is ordered home then settings', () {
      expect(kAppSections, [AppSection.home, AppSection.settings]);
    });

    test('every section exposes a label and icon', () {
      for (final section in AppSection.values) {
        expect(section.label, isNotEmpty);
        expect(section.icon, isNotNull);
      }
    });
  });
}
