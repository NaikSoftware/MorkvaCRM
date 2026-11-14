import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/features/settings/theme_mode_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<ThemeModeCubit> cubitWith(Map<String, Object> saved) async {
    SharedPreferences.setMockInitialValues(saved);
    return ThemeModeCubit(await SharedPreferences.getInstance());
  }

  test('nothing saved: follows the system', () async {
    expect((await cubitWith({})).state, ThemeMode.system);
  });

  test('starts on the saved choice', () async {
    expect((await cubitWith({'theme_mode': 'dark'})).state, ThemeMode.dark);
    expect((await cubitWith({'theme_mode': 'light'})).state, ThemeMode.light);
  });

  test('an unknown saved value falls back to the system', () async {
    expect((await cubitWith({'theme_mode': 'sepia'})).state, ThemeMode.system);
  });

  test('select emits and saves, so the next start keeps it', () async {
    final cubit = await cubitWith({});
    await cubit.select(ThemeMode.dark);
    expect(cubit.state, ThemeMode.dark);
    final next = ThemeModeCubit(await SharedPreferences.getInstance());
    expect(next.state, ThemeMode.dark);
    await cubit.select(ThemeMode.system);
    expect(
      ThemeModeCubit(await SharedPreferences.getInstance()).state,
      ThemeMode.system,
    );
  });
}
