import 'auth_user.dart';

/// Authentication boundary for MorkvaCRM.
///
/// MorkvaCRM uses Google sign-in only; this contract hides the platform split
/// (web popup vs. mobile `google_sign_in`) behind a single surface. Implementations
/// live in `lib/api/auth/` and must replay the current state on subscribe.
abstract interface class AuthRepository {
  /// Emits the current user (or `null` when signed out) and every subsequent
  /// change. Replays the current state immediately on subscribe.
  Stream<AuthUser?> get authStateChanges;

  /// The currently signed-in user, or `null` when signed out.
  AuthUser? get currentUser;

  /// Signs in with Google and resolves to the authenticated user.
  ///
  /// Throws [AuthException] on any failure (cancellation, network, provider
  /// error).
  Future<AuthUser> signInWithGoogle();

  /// Signs the current user out.
  Future<void> signOut();
}

/// What went wrong with sign-in or sign-out; the UI words it.
enum AuthFailure {
  /// The Google sign-in failed (provider error, network, cancelled popup).
  signInFailed,

  /// Sign-in succeeded but returned no user.
  noUser,

  /// Google sign-in is not available on this platform.
  unsupportedPlatform,

  /// Google returned no ID token to exchange with Firebase.
  noIdToken,

  /// Signing out failed.
  signOutFailed,
}

/// Error raised by an [AuthRepository] when authentication fails.
class AuthException implements Exception {
  /// Creates an [AuthException] of [failure], with an optional raw provider
  /// [detail] (shown as is) and underlying [cause].
  const AuthException(this.failure, {this.detail, this.cause});

  /// What went wrong.
  final AuthFailure failure;

  /// The provider's own message (e.g. `FirebaseAuthException.message`), if any.
  final String? detail;

  /// The underlying error, if any (e.g. a `FirebaseAuthException`).
  final Object? cause;

  @override
  String toString() =>
      'AuthException: ${failure.name}${detail != null ? ': $detail' : ''}'
      '${cause != null ? ' ($cause)' : ''}';
}
