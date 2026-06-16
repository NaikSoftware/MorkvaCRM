import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:morkva_crm/api/auth/auth_repository.dart';
import 'package:morkva_crm/api/auth/auth_user.dart';
import 'package:morkva_crm/api/auth/firestore_auth_repository.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockUser extends Mock implements User {}

class _MockUserCredential extends Mock implements UserCredential {}

void main() {
  late _MockFirebaseAuth auth;

  setUp(() => auth = _MockFirebaseAuth());

  _MockUser buildUser({
    String uid = 'uid-1',
    String? email = 'jane@example.com',
    String? displayName = 'Jane Doe',
    String? photoURL = 'https://example.com/jane.png',
  }) {
    final user = _MockUser();
    when(() => user.uid).thenReturn(uid);
    when(() => user.email).thenReturn(email);
    when(() => user.displayName).thenReturn(displayName);
    when(() => user.photoURL).thenReturn(photoURL);
    return user;
  }

  group('FirestoreAuthRepository.authStateChanges', () {
    test('maps a Firebase User to an AuthUser', () {
      final user = buildUser();
      when(() => auth.authStateChanges()).thenAnswer((_) => Stream.value(user));
      final repository = FirestoreAuthRepository(firebaseAuth: auth);

      return expectLater(
        repository.authStateChanges,
        emits(
          isA<AuthUser>()
              .having((u) => u.uid, 'uid', 'uid-1')
              .having((u) => u.email, 'email', 'jane@example.com')
              .having((u) => u.displayName, 'displayName', 'Jane Doe')
              .having(
                (u) => u.photoUrl,
                'photoUrl',
                Uri.parse('https://example.com/jane.png'),
              ),
        ),
      );
    });

    test('maps null Firebase user to null AuthUser', () {
      when(
        () => auth.authStateChanges(),
      ).thenAnswer((_) => Stream<User?>.value(null));
      final repository = FirestoreAuthRepository(firebaseAuth: auth);

      return expectLater(repository.authStateChanges, emits(isNull));
    });

    test('leaves optional profile fields null when absent', () {
      final user = buildUser(displayName: null, photoURL: null);
      when(() => auth.authStateChanges()).thenAnswer((_) => Stream.value(user));
      final repository = FirestoreAuthRepository(firebaseAuth: auth);

      return expectLater(
        repository.authStateChanges,
        emits(
          isA<AuthUser>()
              .having((u) => u.displayName, 'displayName', isNull)
              .having((u) => u.photoUrl, 'photoUrl', isNull),
        ),
      );
    });
  });

  group('FirestoreAuthRepository.currentUser', () {
    test('maps the current Firebase user', () {
      final user = buildUser();
      when(() => auth.currentUser).thenReturn(user);
      final repository = FirestoreAuthRepository(firebaseAuth: auth);

      final current = repository.currentUser;
      expect(current, isNotNull);
      expect(current!.uid, 'uid-1');
      expect(current.photoUrl, Uri.parse('https://example.com/jane.png'));
    });

    test('returns null when signed out', () {
      when(() => auth.currentUser).thenReturn(null);
      final repository = FirestoreAuthRepository(firebaseAuth: auth);

      expect(repository.currentUser, isNull);
    });
  });

  group('FirestoreAuthRepository.signOut', () {
    test('signs out of FirebaseAuth', () async {
      when(() => auth.signOut()).thenAnswer((_) async {});
      final repository = FirestoreAuthRepository(firebaseAuth: auth);

      await repository.signOut();

      verify(() => auth.signOut()).called(1);
    });
  });

  group('FirestoreAuthRepository.signInWithGoogle', () {
    // The credential flow is injected so the post-credential branches can be
    // exercised on the VM. The real web/mobile flows hit platform channels and
    // are covered by integration tests, not here (see the Task 4 spec note); the
    // last test confirms the default (platform) flow is wrapped in AuthException.

    test('returns the mapped AuthUser on success', () async {
      final user = buildUser();
      final credential = _MockUserCredential();
      when(() => credential.user).thenReturn(user);
      final repository = FirestoreAuthRepository(
        firebaseAuth: auth,
        credentialFlow: (_) async => credential,
      );

      final result = await repository.signInWithGoogle();

      expect(result.uid, 'uid-1');
      expect(result.email, 'jane@example.com');
    });

    test('throws AuthException when the credential has no user', () async {
      final credential = _MockUserCredential();
      when(() => credential.user).thenReturn(null);
      final repository = FirestoreAuthRepository(
        firebaseAuth: auth,
        credentialFlow: (_) async => credential,
      );

      await expectLater(
        repository.signInWithGoogle(),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            'Google sign-in returned no user.',
          ),
        ),
      );
    });

    test('wraps a thrown FirebaseAuthException in an AuthException', () async {
      final repository = FirestoreAuthRepository(
        firebaseAuth: auth,
        credentialFlow: (_) async =>
            throw FirebaseAuthException(code: 'network-request-failed'),
      );

      await expectLater(
        repository.signInWithGoogle(),
        throwsA(
          isA<AuthException>().having(
            (e) => e.cause,
            'cause',
            isA<FirebaseAuthException>(),
          ),
        ),
      );
    });

    test('rethrows an AuthException raised by the flow unchanged', () async {
      final repository = FirestoreAuthRepository(
        firebaseAuth: auth,
        credentialFlow: (_) async => throw const AuthException('cancelled'),
      );

      await expectLater(
        repository.signInWithGoogle(),
        throwsA(
          isA<AuthException>().having((e) => e.message, 'message', 'cancelled'),
        ),
      );
    });

    test(
      'wraps the default platform flow failure in an AuthException',
      () async {
        // No credentialFlow injected: the conditional import resolves to the
        // mobile impl on the VM, whose GoogleSignIn platform channel throws.
        final repository = FirestoreAuthRepository(firebaseAuth: auth);

        await expectLater(
          repository.signInWithGoogle(),
          throwsA(isA<AuthException>()),
        );
      },
    );
  });
}
