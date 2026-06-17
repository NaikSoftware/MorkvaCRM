import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../auth_repository.dart';

/// Mobile Google sign-in using `google_sign_in` v7.
///
/// This file is only reachable on mobile/desktop (selected via the
/// `dart.library.io` branch of the conditional import in
/// `firestore_auth_repository.dart`), which keeps the `google_sign_in` import —
/// unsupported on web in v7 — out of any web build.
///
/// Flow (per the v7 API and the Epic 2 spec):
/// 1. `GoogleSignIn.instance.initialize()` — idempotent; safe to call repeatedly.
/// 2. `authenticate()` — interactive sign-in, returns a [GoogleSignInAccount].
/// 3. Read the `idToken` from the account's authentication.
/// 4. Build a [GoogleAuthProvider] credential and exchange it with Firebase.
Future<UserCredential> signInWithGoogleCredential(FirebaseAuth auth) async {
  final googleSignIn = GoogleSignIn.instance;

  if (!googleSignIn.supportsAuthenticate()) {
    throw const AuthException(
      'Google sign-in is not supported on this platform.',
    );
  }

  // Idempotent: initializing more than once is a no-op.
  await googleSignIn.initialize();

  final account = await googleSignIn.authenticate();
  final idToken = account.authentication.idToken;
  if (idToken == null) {
    throw const AuthException('Google sign-in did not return an ID token.');
  }

  final credential = GoogleAuthProvider.credential(idToken: idToken);
  return auth.signInWithCredential(credential);
}

/// Signs out of the Google client so the next sign-in re-prompts for an account.
Future<void> signOutGoogle() => GoogleSignIn.instance.signOut();
