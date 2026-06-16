import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'auth_repository.dart';
import 'auth_user.dart';

/// State of the authentication flow.
///
/// Sealed so the UI can switch exhaustively. Equality is by value so the cubit
/// only emits on real changes.
sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => const [];
}

/// Before [AuthCubit.initialize] has resolved the first auth state.
final class AuthInitial extends AuthState {
  const AuthInitial();
}

/// A sign-in is in flight.
final class AuthLoading extends AuthState {
  const AuthLoading();
}

/// A user is signed in.
final class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);

  /// The signed-in user.
  final AuthUser user;

  @override
  List<Object?> get props => [user];
}

/// No user is signed in.
final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// A sign-in or sign-out failed; carries a user-facing [message].
final class AuthError extends AuthState {
  const AuthError({required this.message});

  /// Human-readable description of the failure.
  final String message;

  @override
  List<Object?> get props => [message];
}

/// Drives authentication for MorkvaCRM over an [AuthRepository].
///
/// The authenticated/unauthenticated state is driven by the repository's
/// [AuthRepository.authStateChanges] stream — sign-in/out only kick off the
/// operation; the resulting state arrives through the stream.
class AuthCubit extends Cubit<AuthState> {
  /// Creates an [AuthCubit] over [repository].
  AuthCubit(this._repository) : super(const AuthInitial());

  final AuthRepository _repository;
  StreamSubscription<AuthUser?>? _subscription;

  /// Subscribes to auth-state changes and reflects them into [AuthState].
  ///
  /// Idempotent: calling more than once does not stack subscriptions.
  void initialize() {
    _subscription?.cancel();
    _subscription = _repository.authStateChanges.listen((user) {
      emit(
        user == null ? const AuthUnauthenticated() : AuthAuthenticated(user),
      );
    });
  }

  /// Starts the Google sign-in flow.
  ///
  /// Emits [AuthLoading] immediately. On success the authenticated state is
  /// delivered via [initialize]'s stream subscription; on failure emits
  /// [AuthError].
  Future<void> signInWithGoogle() async {
    emit(const AuthLoading());
    try {
      await _repository.signInWithGoogle();
    } on AuthException catch (e) {
      // The cubit may have been closed while the await was in flight (e.g. the
      // user navigated away mid-sign-in); guard the post-await emit.
      if (!isClosed) emit(AuthError(message: e.message));
    }
  }

  /// Signs the current user out. The unauthenticated state arrives via the
  /// stream; emits [AuthError] only if the sign-out call itself fails.
  Future<void> signOut() async {
    try {
      await _repository.signOut();
    } on AuthException catch (e) {
      // Guard the post-await emit in case the cubit was closed mid-flight.
      if (!isClosed) emit(AuthError(message: e.message));
    } catch (e) {
      if (!isClosed) emit(AuthError(message: 'Sign-out failed: $e'));
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
