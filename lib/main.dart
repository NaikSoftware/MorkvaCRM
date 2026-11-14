import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'features/settings/theme_mode_cubit.dart';
import 'firebase_options.dart';

/// The web app's reCAPTCHA Enterprise key (public by design); override with
/// `--dart-define=APP_CHECK_SITE_KEY=…`, or pass an empty one to skip App
/// Check on web.
const _appCheckSiteKey = String.fromEnvironment(
  'APP_CHECK_SITE_KEY',
  defaultValue: '6LfFrhguAAAAAIZj85LzZCfOYz6lJETlj8BgU-j1',
);

/// Android/iOS App Check: `debug` (debug providers, register the logged
/// token in the console) or `device` (Play Integrity / DeviceCheck). Off by
/// default: the mobile apps are not registered yet, so Ask Morkva shows
/// "not set up" there.
const _appCheckMobile = String.fromEnvironment('APP_CHECK_MOBILE');

/// `host:port` of a local Firestore emulator (e2e), e.g.
/// `--dart-define=MORKVA_FIRESTORE_EMULATOR=127.0.0.1:8080`. Persistence is
/// off then, so no write queued in the browser profile can later flush to
/// production.
const _firestoreEmulator = String.fromEnvironment('MORKVA_FIRESTORE_EMULATOR');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Firebase AI Logic enforces App Check. Never blocks startup: a failure
  // (e.g. the reCAPTCHA script unreachable) only stops the assistant.
  unawaited(
    _activateAppCheck().catchError((Object error, StackTrace stack) {
      developer.log(
        'App Check activation failed',
        name: 'app_check',
        error: error,
        stackTrace: stack,
      );
    }),
  );

  // Offline persistence (spec §5.1). cloud_firestore 6.5.0 no longer exposes
  // the standalone `enablePersistence` method (it was removed in the v4
  // FlutterFire major); the cross-platform path is to set `Settings` with
  // persistence on. On web this enables IndexedDB persistence; on mobile it is
  // on by default but we set it explicitly so the cache size is unbounded.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: _firestoreEmulator == '',
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  if (_firestoreEmulator.isNotEmpty) {
    final i = _firestoreEmulator.lastIndexOf(':');
    FirebaseFirestore.instance.useFirestoreEmulator(
      _firestoreEmulator.substring(0, i),
      int.parse(_firestoreEmulator.substring(i + 1)),
    );
  }

  // Read before the first frame, so a saved theme never flashes the other.
  final prefs = await SharedPreferences.getInstance();
  runApp(MorkvaApp(themeModeCubit: ThemeModeCubit(prefs)));
}

Future<void> _activateAppCheck() async {
  if (kIsWeb) {
    if (_appCheckSiteKey.isEmpty) return;
    await FirebaseAppCheck.instance.activate(
      providerWeb: ReCaptchaEnterpriseProvider(_appCheckSiteKey),
    );
    return;
  }
  final mobile =
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
  if (!mobile) return;
  switch (_appCheckMobile) {
    case 'debug':
      await FirebaseAppCheck.instance.activate(
        providerAndroid: const AndroidDebugProvider(),
        providerApple: const AppleDebugProvider(),
      );
    case 'device':
      await FirebaseAppCheck.instance.activate(
        providerAndroid: const AndroidPlayIntegrityProvider(),
        providerApple: const AppleDeviceCheckProvider(),
      );
  }
}
