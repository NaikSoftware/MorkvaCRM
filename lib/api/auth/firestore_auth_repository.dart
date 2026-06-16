import 'package:firebase_auth/firebase_auth.dart';

import 'auth_repository.dart';
import 'auth_user.dart';

// Platform split for the Google credential flow. The conditional import keeps
// `google_sign_in` (mobile-only in v7, no web support) out of web builds: the
// `dart.library.html` branch resolves to the web file, which never touches
// `google_sign_in`; only the `dart.library.io` branch pulls in the mobile file.
// The stub covers analysis contexts where neither library is present.
import '_platform/auth_impl_stub.dart'
    if (dart.library.io) '_platform/auth_impl_mobile.dart'
    if (dart.library.html) '_platform/auth_impl_web.dart';

/// Firebase-backed [AuthRepository] for MorkvaCRM's Google-only sign-in.
///
/// Maps Firebase's `User` into the app's platform-agnostic [AuthUser] and
/// dispatches the Google credential flow to the correct platform implementation
/// (web popup vs. mobile `google_sign_in`).
class FirestoreAuthRepository implements AuthRepository {
  /// Creates a repository over [firebaseAuth], defaulting to the singleton
  /// [FirebaseAuth.instance]. Inject a mock in tests.
  FirestoreAuthRepository({FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _firebaseAuth;

  @override
  Stream<AuthUser?> get authStateChanges =>
      _firebaseAuth.authStateChanges().map(_mapFirebaseUser);

  @override
  AuthUser? get currentUser => _mapFirebaseUser(_firebaseAuth.currentUser);

  @override
  Future<AuthUser> signInWithGoogle() async {
    try {
      final credential = await signInWithGoogleCredential(_firebaseAuth);
      final user = _mapFirebaseUser(credential.user);
      if (user == null) {
        throw const AuthException('Google sign-in returned no user.');
      }
      return user;
    } on AuthException {
      rethrow;
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Google sign-in failed.', cause: e);
    } catch (e) {
      throw AuthException('Google sign-in failed.', cause: e);
    }
  }

  @override
  Future<void> signOut() async {
    // Sign out of the Google client first so the next sign-in re-prompts, but
    // never let a platform Google failure block clearing the Firebase session —
    // the Firebase sign-out is what actually unauthenticates the app.
    try {
      await signOutGoogle();
    } catch (_) {
      // Best-effort: ignore Google client sign-out failures.
    }
    await _firebaseAuth.signOut();
  }

  /// Projects a Firebase [User] into an [AuthUser], or `null` when signed out.
  ///
  /// Google accounts always carry an email; the empty-string fallback only
  /// guards against an unexpected null and never occurs in practice.
  AuthUser? _mapFirebaseUser(User? user) {
    if (user == null) return null;
    final photoUrl = user.photoURL;
    return AuthUser(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      photoUrl: photoUrl == null ? null : Uri.tryParse(photoUrl),
    );
  }
}
