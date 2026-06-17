import 'package:firebase_auth/firebase_auth.dart';

/// Stub used when neither `dart.library.io` (mobile/desktop) nor
/// `dart.library.html` (web) is available — e.g. during pure-Dart analysis of
/// the conditional import. It is never reached at runtime; the real
/// implementation is selected by the conditional `import` in
/// [FirestoreAuthRepository].
Future<UserCredential> signInWithGoogleCredential(FirebaseAuth auth) {
  throw UnsupportedError('Google sign-in is not supported on this platform.');
}

/// Signs out of the platform Google client, where one exists.
///
/// No-op in the stub; the web build has nothing to sign out of and the mobile
/// build provides its own implementation.
Future<void> signOutGoogle() async {}
