import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/api/api.dart';
import 'package:morkva_crm/app/app.dart';
import 'package:morkva_crm/core/domain/domain.dart';

/// In-memory [AuthRepository] whose auth state is driven by the test via
/// [emit]. Replays the latest value on subscribe, matching the real Firebase
/// stream contract the [AuthCubit] relies on.
class FakeAuthRepository implements AuthRepository {
  final _controller = StreamController<AuthUser?>.broadcast();
  AuthUser? _current;

  void emit(AuthUser? user) {
    _current = user;
    _controller.add(user);
  }

  @override
  Stream<AuthUser?> get authStateChanges async* {
    yield _current;
    yield* _controller.stream;
  }

  @override
  AuthUser? get currentUser => _current;

  @override
  Future<AuthUser> signInWithGoogle() async {
    const user = AuthUser(uid: 'u1', email: 'u1@example.com');
    emit(user);
    return user;
  }

  @override
  Future<void> signOut() async => emit(null);
}

/// No-op [DataRepository]: records the workspace it was initialized with and
/// never touches Firestore, so widget tests can drive the auth-gated shell.
class FakeDataRepository implements DataRepository {
  String? initializedWorkspaceId;

  /// When set, `initialize` waits on this before completing, so a test can
  /// observe the authenticated-but-not-ready loading state.
  Completer<void>? gate;

  @override
  Future<void> initialize(String workspaceId) async {
    if (gate != null) await gate!.future;
    initializedWorkspaceId = workspaceId;
  }

  @override
  Future<void> dispose() async {
    initializedWorkspaceId = null;
  }

  @override
  Stream<List<Collection>> watchCollections() =>
      // The real repository always emits the current list (empty included) and
      // replays on subscribe; emit an empty list so the Home collections cubit
      // reaches its ready-empty state instead of hanging on a loading spinner.
      Stream<List<Collection>>.value(const []);

  @override
  Future<List<Collection>> getCollections() async => const [];

  @override
  Future<Collection?> getCollection(String collectionId) async => null;

  @override
  Future<void> saveCollection(Collection collection) async {}

  @override
  Future<void> deleteCollection(String collectionId) async {}

  @override
  Stream<List<MorkvaObject>> watchObjects(
    String collectionId, {
    Collection? schema,
  }) => const Stream.empty();

  @override
  Future<List<MorkvaObject>> getObjects(
    String collectionId, {
    required Collection schema,
  }) async => const [];

  @override
  Future<MorkvaObject?> getObject(
    String collectionId,
    String objectId, {
    required Collection schema,
  }) async => null;

  @override
  Future<void> saveObject(
    MorkvaObject object, {
    required Collection schema,
  }) async {}

  @override
  Future<void> deleteObject(String collectionId, String objectId) async {}
}

void main() {
  late FakeAuthRepository auth;
  late FakeDataRepository data;
  late SyncStatusCubit sync;

  setUp(() {
    auth = FakeAuthRepository();
    data = FakeDataRepository();
    sync = SyncStatusCubit();
  });

  Widget buildApp() => MorkvaApp(
    authRepository: auth,
    dataRepository: data,
    syncStatusCubit: sync,
  );

  testWidgets('unauthenticated user is redirected to the sign-in screen', (
    tester,
  ) async {
    auth.emit(null); // unauthenticated
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // The sign-in page is shown, not the shell.
    expect(find.text('Welcome to your workspace'), findsOneWidget);
    expect(find.text('No collections yet'), findsNothing);
  });

  testWidgets(
    'authenticated user lands on the shell and the data repo is initialized',
    (tester) async {
      auth.emit(const AuthUser(uid: 'u1', email: 'u1@example.com'));
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // The themed shell renders (home empty state), not the sign-in page.
      expect(find.text('No collections yet'), findsOneWidget);
      expect(find.text('Welcome to your workspace'), findsNothing);
      // Workspace id resolved to the uid and the data layer initialized.
      expect(data.initializedWorkspaceId, 'u1');
    },
  );

  testWidgets(
    'authenticated-but-not-ready shows loading, then the shell once ready',
    (tester) async {
      // Hold initialize() open so the session stays not-ready.
      data.gate = Completer<void>();
      auth.emit(const AuthUser(uid: 'u1', email: 'u1@example.com'));
      await tester.pumpWidget(buildApp());
      // Use pump (not pumpAndSettle): the loading spinner animates forever, so
      // there is nothing to settle while the session is gated.
      await tester.pump();
      await tester.pump();

      // Gated: the loading interstitial is shown, not the shell.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('No collections yet'), findsNothing);
      expect(data.initializedWorkspaceId, isNull);

      // Release the gate → initialize completes → session becomes ready.
      data.gate!.complete();
      await tester.pumpAndSettle();

      expect(find.text('No collections yet'), findsOneWidget);
      expect(data.initializedWorkspaceId, 'u1');
    },
  );

  testWidgets('signing out from the shell redirects back to sign-in', (
    tester,
  ) async {
    auth.emit(const AuthUser(uid: 'u1', email: 'u1@example.com'));
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // Go to Settings and tap sign out.
    await tester.tap(find.byIcon(Icons.settings_outlined).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    // Back on the sign-in screen; data repo torn down.
    expect(find.text('Welcome to your workspace'), findsOneWidget);
    expect(data.initializedWorkspaceId, isNull);
  });
}
