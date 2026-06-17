import 'package:equatable/equatable.dart';

/// An authenticated user, projected from the auth provider into a small,
/// platform-agnostic value type the rest of the app can depend on.
///
/// Intentionally minimal: only the fields MorkvaCRM needs. Equality is by value
/// so blocs can compare states cheaply.
class AuthUser extends Equatable {
  /// Creates an [AuthUser]. [uid] and [email] are always present; the optional
  /// profile fields may be absent depending on the provider.
  const AuthUser({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
  });

  /// Stable, provider-issued user id. Doubles as the workspace id today.
  final String uid;

  /// The user's email address.
  final String email;

  /// Human-readable display name, when the provider supplies one.
  final String? displayName;

  /// URL of the user's avatar, when the provider supplies one.
  final Uri? photoUrl;

  @override
  List<Object?> get props => [uid, email, displayName, photoUrl];
}
