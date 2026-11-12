import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/api/api.dart';
import 'package:morkva_crm/api/assistant/assistant_config_repository.dart';
import 'package:morkva_crm/api/assistant/firestore_thread_repository.dart';
import 'package:morkva_crm/app/app.dart';
import 'package:morkva_crm/core/automation/runner_api.dart';
import 'package:morkva_crm/core/domain/automation/automation.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/features/automation/bloc/automation_runs_cubit.dart';
import 'package:morkva_crm/features/automation/bloc/modules_cubit.dart';
import 'package:morkva_crm/features/automation/bloc/run_log_cubit.dart';

import 'automation/fakes/fake_script_engine.dart';
import 'automation/fakes/fake_stores.dart';

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

  /// Subscriptions in order: `changes+`, `collections-`, `pins+`, …
  final log = <String>[];

  /// A fresh stream that replays [value] and logs its listen and cancel.
  Stream<T> _logged<T>(String name, T? value) {
    late final StreamController<T> controller;
    controller = StreamController<T>(
      onListen: () {
        log.add('$name+');
        if (value != null) controller.add(value);
      },
      onCancel: () => log.add('$name-'),
    );
    return controller.stream;
  }

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
      _logged<List<Collection>>('collections', const []);

  @override
  Stream<List<String>> watchPinnedCollectionIds() =>
      _logged<List<String>>('pins', const []);

  @override
  Future<void> savePinnedCollectionIds(List<String> ids) async {}

  @override
  Future<List<Collection>> getCollections() async => const [];

  @override
  Future<Collection?> getCollection(String collectionId) async => null;

  @override
  Future<void> saveCollection(Collection collection) async {}

  @override
  Future<void> saveViews(
    String collectionId,
    List<ViewDefinition> views,
  ) async {}

  @override
  Future<void> deleteCollection(String collectionId) async {}

  @override
  Stream<List<MorkvaObject>> watchObjects(
    String collectionId, {
    Collection? schema,
  }) => const Stream.empty();

  @override
  Stream<MorkvaObject?> watchObject(
    String collectionId,
    String objectId, {
    required Collection schema,
  }) => const Stream.empty();

  @override
  Future<List<MorkvaObject>> getObjects(
    String collectionId, {
    required Collection schema,
  }) async => const [];

  @override
  Future<List<MorkvaObject>> getServerObjects(
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
    WriteOrigin origin = const WriteOrigin.ui(),
  }) async {}

  @override
  Future<void> deleteObject(
    String collectionId,
    String objectId, {
    MorkvaObject? before,
    WriteOrigin origin = const WriteOrigin.ui(),
  }) async {}

  @override
  Future<BatchResult> saveObjectsBatch(
    List<ObjectWrite> writes, {
    required Map<String, Collection> schemas,
    WriteOrigin origin = const WriteOrigin.ui(),
  }) async => BatchResult(written: [for (final w in writes) w.id]);

  @override
  Stream<CardChange> get changes => _logged<CardChange>('changes', null);

  @override
  Future<void> updateCollection(
    String id,
    Collection Function(Collection server) apply,
  ) async {}

  @override
  Future<void> updateViews(
    String collectionId,
    List<ViewDefinition> Function(List<ViewDefinition> server) apply,
  ) async {}
}

/// [MorkvaApp] over in-memory backends: Ask Morkva's conversations and
/// config live in [firestore] (a fresh fake by default).
MorkvaApp testApp({
  required AuthRepository auth,
  required DataRepository data,
  SyncStatusCubit? sync,
  FakeFirebaseFirestore? firestore,
}) {
  final db = firestore ?? FakeFirebaseFirestore();
  return MorkvaApp(
    authRepository: auth,
    dataRepository: data,
    syncStatusCubit: sync,
    threadRepository: FirestoreThreadRepository(firestore: db),
    assistantConfigRepository: AssistantConfigRepository(firestore: db),
    automationStores: FakeStores().stores,
    scriptEngine: FakeScriptEngine(),
  );
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

  Widget buildApp() => testApp(auth: auth, data: data, sync: sync);

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
    await tester.tap(find.byTooltip('Account and settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    // Back on the sign-in screen; data repo torn down.
    expect(find.text('Welcome to your workspace'), findsOneWidget);
    expect(data.initializedWorkspaceId, isNull);
  });

  testWidgets('sign-in: the runner subscribes before the shell mounts, and the '
      'automation wiring is app-wide', (tester) async {
    auth.emit(const AuthUser(uid: 'u1', email: 'u1@example.com'));
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // The shell's pins listener comes only once the session is ready.
    expect(data.log, contains('changes+'));
    expect(data.log.indexOf('changes+'), lessThan(data.log.indexOf('pins+')));
    final shell = tester.element(find.text('No collections yet'));
    expect(shell.read<AutomationRunnerApi>(), isNotNull);
    expect(shell.read<AutomationStores>(), isNotNull);
    expect(shell.read<ModulesCubit>(), isNotNull);
    expect(shell.read<AutomationRunsCubit>(), isNotNull);
    expect(shell.read<RunLogCubit>(), isNotNull);
    // Built over injected fakes: Firebase was never touched.
    expect(tester.takeException(), isNull);
  });

  testWidgets('sign-out resets the runner before the assistant', (
    tester,
  ) async {
    auth.emit(const AuthUser(uid: 'u1', email: 'u1@example.com'));
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    data.log.clear();

    auth.emit(null);
    await tester.pumpAndSettle();

    expect(find.text('Welcome to your workspace'), findsOneWidget);
    // The runner's card-change listener goes before the cache's schema one.
    expect(data.log.first, 'changes-');
    expect(data.log, contains('collections-'));
  });

  testWidgets('signing out on the Automations page closes its cubits cleanly', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    auth.emit(const AuthUser(uid: 'u1', email: 'u1@example.com'));
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Automations'));
    await tester.pumpAndSettle();
    expect(find.text('No modules yet'), findsOneWidget);

    auth.emit(null);
    await tester.pumpAndSettle();
    expect(find.text('Welcome to your workspace'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
