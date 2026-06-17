import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:morkva_crm/api/auth/auth_cubit.dart';
import 'package:morkva_crm/api/auth/auth_repository.dart';
import 'package:morkva_crm/api/auth/auth_user.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  const user = AuthUser(
    uid: 'uid-1',
    email: 'jane@example.com',
    displayName: 'Jane',
  );

  late _MockAuthRepository repository;
  late StreamController<AuthUser?> authStateController;

  setUp(() {
    repository = _MockAuthRepository();
    authStateController = StreamController<AuthUser?>.broadcast();
    when(
      () => repository.authStateChanges,
    ).thenAnswer((_) => authStateController.stream);
  });

  tearDown(() => authStateController.close());

  group('AuthCubit', () {
    test('initial state is AuthInitial', () {
      final cubit = AuthCubit(repository);
      addTearDown(cubit.close);
      expect(cubit.state, const AuthInitial());
    });

    blocTest<AuthCubit, AuthState>(
      'initialize -> AuthAuthenticated when stream emits a user',
      build: () => AuthCubit(repository),
      act: (cubit) {
        cubit.initialize();
        authStateController.add(user);
      },
      expect: () => [const AuthAuthenticated(user)],
    );

    blocTest<AuthCubit, AuthState>(
      'initialize -> AuthUnauthenticated when stream emits null',
      build: () => AuthCubit(repository),
      act: (cubit) {
        cubit.initialize();
        authStateController.add(null);
      },
      expect: () => [const AuthUnauthenticated()],
    );

    blocTest<AuthCubit, AuthState>(
      'initialize reflects subsequent sign-in then sign-out transitions',
      build: () => AuthCubit(repository),
      act: (cubit) async {
        cubit.initialize();
        authStateController
          ..add(user)
          ..add(null);
      },
      expect: () => [
        const AuthAuthenticated(user),
        const AuthUnauthenticated(),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'signInWithGoogle success emits AuthLoading then state driven by stream',
      build: () {
        when(() => repository.signInWithGoogle()).thenAnswer((_) async => user);
        return AuthCubit(repository);
      },
      act: (cubit) async {
        cubit.initialize();
        await cubit.signInWithGoogle();
        authStateController.add(user);
      },
      expect: () => [const AuthLoading(), const AuthAuthenticated(user)],
      verify: (_) => verify(() => repository.signInWithGoogle()).called(1),
    );

    blocTest<AuthCubit, AuthState>(
      'signInWithGoogle on AuthException emits AuthLoading then AuthError',
      build: () {
        when(
          () => repository.signInWithGoogle(),
        ).thenThrow(const AuthException('cancelled'));
        return AuthCubit(repository);
      },
      act: (cubit) => cubit.signInWithGoogle(),
      expect: () => [
        const AuthLoading(),
        const AuthError(message: 'cancelled'),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'cancelSignIn while loading returns to AuthUnauthenticated',
      build: () {
        // A sign-in whose future never settles — the web popup-dismiss case.
        when(
          () => repository.signInWithGoogle(),
        ).thenAnswer((_) => Completer<AuthUser>().future);
        return AuthCubit(repository);
      },
      act: (cubit) {
        cubit.signInWithGoogle(); // emits AuthLoading, then awaits forever
        cubit.cancelSignIn();
      },
      expect: () => [const AuthLoading(), const AuthUnauthenticated()],
    );

    blocTest<AuthCubit, AuthState>(
      'cancelSignIn is a no-op when no sign-in is in flight',
      build: () => AuthCubit(repository),
      act: (cubit) => cubit.cancelSignIn(),
      expect: () => const <AuthState>[],
    );

    test('a late sign-in failure after cancel does not emit AuthError', () async {
      final completer = Completer<AuthUser>();
      when(
        () => repository.signInWithGoogle(),
      ).thenAnswer((_) => completer.future);
      final cubit = AuthCubit(repository);
      addTearDown(cubit.close);

      final states = <AuthState>[];
      final sub = cubit.stream.listen(states.add);

      cubit.signInWithGoogle(); // AuthLoading
      cubit.cancelSignIn(); // AuthUnauthenticated
      // The orphaned popup future rejects late — must be swallowed, not shown.
      completer.completeError(const AuthException('popup closed late'));
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(states, [const AuthLoading(), const AuthUnauthenticated()]);
    });

    blocTest<AuthCubit, AuthState>(
      'signOut transitions to AuthUnauthenticated via the stream',
      build: () {
        when(() => repository.signOut()).thenAnswer((_) async {});
        return AuthCubit(repository);
      },
      act: (cubit) async {
        cubit.initialize();
        authStateController.add(user);
        await cubit.signOut();
        authStateController.add(null);
      },
      expect: () => [
        const AuthAuthenticated(user),
        const AuthUnauthenticated(),
      ],
      verify: (_) => verify(() => repository.signOut()).called(1),
    );

    blocTest<AuthCubit, AuthState>(
      'signOut failure emits AuthError',
      build: () {
        when(
          () => repository.signOut(),
        ).thenThrow(const AuthException('network down'));
        return AuthCubit(repository);
      },
      act: (cubit) => cubit.signOut(),
      expect: () => [const AuthError(message: 'network down')],
    );

    test('close cancels the auth-state subscription', () async {
      final cubit = AuthCubit(repository);
      cubit.initialize();
      await cubit.close();
      // Emitting after close must not throw (subscription cancelled, cubit closed).
      expect(() => authStateController.add(user), returnsNormally);
    });

    test(
      'signInWithGoogle error after close does not throw StateError',
      () async {
        final completer = Completer<AuthUser>();
        when(
          () => repository.signInWithGoogle(),
        ).thenAnswer((_) => completer.future);
        final cubit = AuthCubit(repository);

        final future = cubit
            .signInWithGoogle(); // emits AuthLoading, then awaits
        await cubit.close();
        completer.completeError(const AuthException('too late'));

        // The guarded emit in the catch block must be a no-op after close.
        await expectLater(future, completes);
      },
    );

    test('signOut error after close does not throw StateError', () async {
      final completer = Completer<void>();
      when(() => repository.signOut()).thenAnswer((_) => completer.future);
      final cubit = AuthCubit(repository);

      final future = cubit.signOut();
      await cubit.close();
      completer.completeError(const AuthException('too late'));

      await expectLater(future, completes);
    });
  });
}
