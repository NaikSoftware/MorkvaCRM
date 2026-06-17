import 'package:firebase_auth/firebase_auth.dart';

/// Web Google sign-in: a Firebase popup with the [GoogleAuthProvider].
///
/// This file is only reachable on web (selected via the `dart.library.html`
/// branch of the conditional import in `firestore_auth_repository.dart`), so it
/// must NOT import `google_sign_in`, which has no web support in v7.
Future<UserCredential> signInWithGoogleCredential(FirebaseAuth auth) {
  return auth.signInWithPopup(GoogleAuthProvider());
}

/// Web has no separate Google client to sign out of — Firebase's own
/// [FirebaseAuth.signOut] is sufficient.
Future<void> signOutGoogle() async {}
