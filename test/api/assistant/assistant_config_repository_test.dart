import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:morkva_crm/api/assistant/assistant_config.dart';
import 'package:morkva_crm/api/assistant/assistant_config_repository.dart';

void main() {
  const workspaceId = 'ws-1';
  const uid = 'u-1';
  final now = DateTime.utc(2026, 11, 10, 9, 30);

  late FakeFirebaseFirestore firestore;
  late AssistantConfigRepository repository;

  DocumentReference<Map<String, dynamic>> globalDoc() =>
      firestore.collection('config').doc('assistant');
  DocumentReference<Map<String, dynamic>> flagDoc() =>
      firestore.collection('featureFlags').doc(uid);
  DocumentReference<Map<String, dynamic>> consentDoc() => firestore
      .collection('workspaces')
      .doc(workspaceId)
      .collection('config')
      .doc('assistant');

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = AssistantConfigRepository(firestore: firestore, now: () => now)
      ..initialize(workspaceId: workspaceId, uid: uid);
  });

  test('missing docs never block: the defaults apply, enabled', () async {
    final config = await repository.watch().first;

    expect(config, AssistantConfig.defaults);
    expect(config.enabled, isTrue);
  });

  test('merges the global doc, the user flag and the consent', () async {
    await globalDoc().set({'model': 'gemini-x', 'rpm': 8, 'dataUse': 'paid'});
    await flagDoc().set({'assistant': false});
    await consentDoc().set({
      'consentedBy': 'u-9',
      'consentedAt': '2026-11-09T08:00:00.000Z',
    });

    final config = await repository.watch().first;

    expect(
      config,
      AssistantConfig(
        enabled: false,
        model: 'gemini-x',
        rpm: 8,
        dataUse: AssistantDataUse.paid,
        consent: AssistantConsent(
          consentedBy: 'u-9',
          consentedAt: DateTime.utc(2026, 11, 9, 8),
        ),
      ),
    );
  });

  test('reads a console-written Timestamp consent date', () async {
    await consentDoc().set({
      'consentedBy': 'u-1',
      'consentedAt': Timestamp.fromDate(DateTime.utc(2026, 11, 1)),
    });

    final config = await repository.watch().first;

    expect(config.consent?.consentedAt, DateTime.utc(2026, 11, 1));
  });

  test('a consent doc without consentedBy is not consent', () async {
    await consentDoc().set({'consentedAt': '2026-11-09T08:00:00.000Z'});

    expect((await repository.watch().first).consented, isFalse);
  });

  test('emits live changes, without repeats for unchanged values', () async {
    final configs = <AssistantConfig>[];
    final sub = repository.watch().listen(configs.add);
    await pumpEventQueue();

    await globalDoc().set({'rpm': 6});
    await pumpEventQueue();
    await flagDoc().set({'assistant': false});
    await pumpEventQueue();
    await flagDoc().set({'assistant': false, 'unrelated': 1});
    await pumpEventQueue();
    await sub.cancel();

    expect(configs.map((c) => (c.rpm, c.enabled)), [
      (12, true),
      (6, true),
      (6, false),
    ]);
  });

  test('grantConsent records the user and the time; watch sees it', () async {
    final configs = <AssistantConfig>[];
    final sub = repository.watch().listen(configs.add);
    await pumpEventQueue();

    await repository.grantConsent();
    await pumpEventQueue();
    await sub.cancel();

    expect((await consentDoc().get()).data(), {
      'consentedBy': uid,
      'consentedAt': '2026-11-10T09:30:00.000Z',
    });
    expect(configs.map((c) => c.consent), [
      null,
      AssistantConsent(consentedBy: uid, consentedAt: now),
    ]);
  });

  test('grantConsent keeps other keys of the workspace doc', () async {
    await consentDoc().set({'note': 'kept'});

    await repository.grantConsent();

    expect((await consentDoc().get()).data()?['note'], 'kept');
  });

  test('an unreadable doc counts as missing instead of failing the '
      'stream', () async {
    await flagDoc().set({'assistant': false});
    final failing = AssistantConfigRepository(
      firestore: _DeniedFirestore(firestore, denied: {'config', 'workspaces'}),
    )..initialize(workspaceId: workspaceId, uid: uid);

    final config = await failing.watch().first;

    // Global and consent docs denied → defaults; the flag still applies.
    expect(config, const AssistantConfig(enabled: false));
  });

  test('using it before initialize is a StateError', () {
    final unbound = AssistantConfigRepository(firestore: firestore);

    expect(unbound.watch, throwsStateError);
    expect(unbound.grantConsent, throwsStateError);
  });
}

// Firestore's refs are sealed; a mock is the only way to fail one read.
// ignore: subtype_of_sealed_class
class _MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class _MockDocument extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

/// Delegates to [inner], except that every doc under the [denied] top-level
/// collections fails its snapshots like a permission-denied read.
class _DeniedFirestore extends Fake implements FirebaseFirestore {
  _DeniedFirestore(this.inner, {required this.denied});

  final FirebaseFirestore inner;
  final Set<String> denied;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      denied.contains(path) ? _deniedCollection(path) : inner.collection(path);
}

CollectionReference<Map<String, dynamic>> _deniedCollection(String path) {
  final collection = _MockCollection();
  when(() => collection.doc(any())).thenAnswer((invocation) {
    final docPath = '$path/${invocation.positionalArguments.first}';
    final doc = _MockDocument();
    when(() => doc.path).thenReturn(docPath);
    when(() => doc.collection(any())).thenAnswer(
      (inv) => _deniedCollection('$docPath/${inv.positionalArguments.first}'),
    );
    when(() => doc.snapshots()).thenAnswer(
      (_) => Stream.error(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      ),
    );
    return doc;
  });
  return collection;
}
