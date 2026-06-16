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

/// Error raised by an [AuthRepository] when authentication fails.
class AuthException implements Exception {
  /// Creates an [AuthException] with a human-readable [message] and an optional
  /// underlying [cause].
  const AuthException(this.message, {this.cause});

  /// Human-readable description of what went wrong.
  final String message;

  /// The underlying error, if any (e.g. a `FirebaseAuthException`).
  final Object? cause;

  @override
  String toString() =>
      'AuthException: $message${cause != null ? ' ($cause)' : ''}';
}
