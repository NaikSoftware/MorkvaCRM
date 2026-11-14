import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:morkva_crm/api/assistant/assistant_config.dart';
import 'package:morkva_crm/api/assistant/assistant_config_repository.dart';

void main() {
  const uid = 'u-1';

  late FakeFirebaseFirestore firestore;
  late AssistantConfigRepository repository;

  DocumentReference<Map<String, dynamic>> globalDoc() =>
      firestore.collection('config').doc('assistant');
  DocumentReference<Map<String, dynamic>> flagDoc() =>
      firestore.collection('featureFlags').doc(uid);

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = AssistantConfigRepository(firestore: firestore)
      ..initialize(uid: uid);
  });

  test('missing docs never block: the defaults apply, enabled', () async {
    final config = await repository.watch().first;

    expect(config, AssistantConfig.defaults);
    expect(config.enabled, isTrue);
  });

  test('merges the global doc and the user flag', () async {
    await globalDoc().set({'model': 'gemini-x', 'rpm': 8});
    await flagDoc().set({'assistant': false});

    final config = await repository.watch().first;

    expect(
      config,
      const AssistantConfig(enabled: false, model: 'gemini-x', rpm: 8),
    );
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

  test('an unreadable doc counts as missing instead of failing the '
      'stream', () async {
    await flagDoc().set({'assistant': false});
    final failing = AssistantConfigRepository(
      firestore: _DeniedFirestore(firestore, denied: {'config'}),
    )..initialize(uid: uid);

    final config = await failing.watch().first;

    // The global doc denied → defaults; the flag still applies.
    expect(config, const AssistantConfig(enabled: false));
  });

  test('using it before initialize is a StateError', () {
    final unbound = AssistantConfigRepository(firestore: firestore);

    expect(unbound.watch, throwsStateError);
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
