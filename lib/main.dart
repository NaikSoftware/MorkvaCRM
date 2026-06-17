import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Offline persistence (spec §5.1). cloud_firestore 6.5.0 no longer exposes
  // the standalone `enablePersistence` method (it was removed in the v4
  // FlutterFire major); the cross-platform path is to set `Settings` with
  // persistence on. On web this enables IndexedDB persistence; on mobile it is
  // on by default but we set it explicitly so the cache size is unbounded.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  runApp(const MorkvaApp());
}
