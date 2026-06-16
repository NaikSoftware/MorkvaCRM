import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:morkva_crm/api/auth/auth_repository.dart';
import 'package:morkva_crm/api/auth/auth_user.dart';
import 'package:morkva_crm/api/auth/firestore_auth_repository.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockUser extends Mock implements User {}

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
    // On the Dart VM the conditional import resolves to the mobile
    // implementation (dart.library.io), which calls into `GoogleSignIn.instance`
    // — a platform channel that cannot be initialized under `flutter test`. The
    // repository's job is to wrap whatever the platform flow throws in an
    // AuthException; we assert exactly that boundary contract here. The
    // web/mobile credential flows themselves are exercised in integration, not
    // unit tests (see the spec note for Task 4).
    test('wraps platform sign-in failures in an AuthException', () async {
      final repository = FirestoreAuthRepository(firebaseAuth: auth);

      await expectLater(
        repository.signInWithGoogle(),
        throwsA(isA<AuthException>()),
      );
    });
  });
}
