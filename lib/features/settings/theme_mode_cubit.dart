import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app's theme: light, dark or the device's. Saved on this device, not
/// in the workspace, so it applies before sign-in and each device keeps its
/// own.
class ThemeModeCubit extends Cubit<ThemeMode> {
  ThemeModeCubit(this._prefs) : super(_read(_prefs));

  static const prefsKey = 'theme_mode';

  final SharedPreferences _prefs;

  static ThemeMode _read(SharedPreferences prefs) {
    final name = prefs.getString(prefsKey);
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == name,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> select(ThemeMode mode) async {
    emit(mode);
    await _prefs.setString(prefsKey, mode.name);
  }
}
