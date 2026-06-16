---
name: flutterfire
description: Use when setting up or reconfiguring Firebase in this Flutter app via the flutterfire CLI — installing the CLI, running flutterfire configure, regenerating firebase_options.dart, adding platforms or Firebase plugins (firebase_core, firebase_auth, cloud_firestore, firebase_storage), or when you need a quick correct reference for current FlutterFire init/Auth/Storage APIs.
---

# FlutterFire

FlutterFire is the official set of Firebase plugins for Flutter. The **flutterfire CLI** generates `lib/firebase_options.dart` and the native config files so one Dart call (`Firebase.initializeApp`) wires up every platform.

## Prerequisites (one-time)

```sh
# 1. Firebase CLI (Node) — needed by flutterfire to talk to your account
npm install -g firebase-tools
firebase login

# 2. FlutterFire CLI (Dart global)
dart pub global activate flutterfire_cli
# Ensure the Dart pub global bin is on PATH (zsh):
#   export PATH="$PATH:$HOME/.pub-cache/bin"
```

If `flutterfire` is "command not found", the pub-cache bin dir is not on PATH — fix that, don't reinstall.

## Configure a project

```sh
flutter pub add firebase_core
flutterfire configure
```

`flutterfire configure` is **interactive** — it lists your Firebase projects and platforms, then writes:

| File | Purpose |
|------|---------|
| `lib/firebase_options.dart` | `DefaultFirebaseOptions.currentPlatform` — keys per platform |
| `android/app/google-services.json` | Android native config |
| `ios/Runner/GoogleService-Info.plist` | iOS native config (also macOS) |
| `firebase.json` | records the configured apps |

Useful non-interactive flags:

```sh
flutterfire configure \
  --project=<firebase-project-id> \
  --platforms=android,ios,web \
  --yes                      # accept defaults, no prompts
```

**Re-run `flutterfire configure` whenever** you add a platform, add a Firebase app, or the keys change. It regenerates `firebase_options.dart` in place — never hand-edit that file.

## Add Firebase plugins

```sh
flutter pub add firebase_auth cloud_firestore firebase_storage
flutterfire configure   # re-run after adding plugins (updates native gradle/pods)
```

Common plugins: `firebase_core` (required), `firebase_auth`, `cloud_firestore`, `firebase_storage`, `cloud_functions`, `firebase_messaging`, `firebase_analytics`. For Google sign-in also add `google_sign_in`.

## Initialize in main

```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();   // REQUIRED before initializeApp
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}
```

Do not touch any `FirebaseAuth.instance` / `FirebaseFirestore.instance` before `initializeApp` completes.

## Quick API reference (current)

**Auth — email/password:**
```dart
try {
  await FirebaseAuth.instance.signInWithEmailAndPassword(email: e, password: p);
} on FirebaseAuthException catch (err) {
  // Email-enumeration protection (default since Sep 2023) returns
  // 'invalid-credential' for both wrong email AND wrong password.
}
```

**Auth — Google sign-in (`google_sign_in` 7.x, current):**
```dart
// Native (Android/iOS): authenticate() returns an idToken only — no accessToken.
final user = await GoogleSignIn.instance.authenticate();
final cred = GoogleAuthProvider.credential(idToken: user.authentication.idToken);
await FirebaseAuth.instance.signInWithCredential(cred);

// Web: use the provider popup instead.
await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
```

**Auth — reactive user / sign out:**
```dart
Stream<User?> user = FirebaseAuth.instance.authStateChanges();
await FirebaseAuth.instance.signOut();
```

**Storage — upload + URL:**
```dart
final ref = FirebaseStorage.instance.ref('workspaces/$uid/data.json');
await ref.putFile(file, SettableMetadata(contentType: 'application/json'));
final url = await ref.getDownloadURL();
```

**Firestore — write / merge / stream:**
```dart
final db = FirebaseFirestore.instance;
await db.collection('cities').doc('id').set({'name': 'Chicago'});
await db.collection('cities').doc('id').set({'pop': 1}, SetOptions(merge: true));
await db.collection('cities').doc('id').update({'at': FieldValue.serverTimestamp()});
Stream<QuerySnapshot> live =
    db.collection('cities').where('state', isEqualTo: 'IL').snapshots();
```

## Common mistakes

| Mistake | Fix |
|---------|-----|
| Old `google_sign_in` 6.x API (`GoogleSignIn().signIn()`, `accessToken`) | Use 7.x: `GoogleSignIn.instance.authenticate()`, idToken-only credential |
| Handling only `wrong-password`/`user-not-found` | Also handle `invalid-credential` (the default code now) |
| Hand-editing `firebase_options.dart` | Re-run `flutterfire configure` |
| Forgetting `WidgetsFlutterBinding.ensureInitialized()` | Always call it before `Firebase.initializeApp` |
| Adding a plugin but not re-running `flutterfire configure` | Re-run it so native gradle/pods update |
| Committing real keys to a public repo | `firebase_options.dart` keys are not secrets, but lock down access with **Security Rules** |

## Docs

- Setup & CLI: https://firebase.google.com/docs/flutter/setup
- Plugin reference: https://firebase.google.com/docs/reference/flutter
- For deeper API needs, query current docs via context7 (`/firebase/flutterfire`) rather than relying on memory — these APIs drift between major versions.
