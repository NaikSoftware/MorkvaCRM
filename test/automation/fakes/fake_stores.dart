import 'package:morkva_crm/core/domain/automation/automation.dart';
import 'package:rxdart/rxdart.dart';

/// In-memory automation stores. Docs are kept as `toJson()` maps and read
/// back through `fromJson`, so the record codecs run as they do over
/// Firestore; a doc that does not decode is left out (see `putRaw`).
final class FakeStores {
  final modules = FakeModuleStore();
  final automations = FakeAutomationStore();
  final runs = FakeRunStore();
  final grants = FakeGrantStore();

  AutomationStores get stores => AutomationStores(
    modules: modules,
    automations: automations,
    runs: runs,
    grants: grants,
  );

  Future<void> dispose() => Future.wait([
    modules.dispose(),
    automations.dispose(),
    runs.dispose(),
    grants.dispose(),
  ]);
}

/// Docs by id with a replaying change stream.
class _Docs<T> {
  _Docs(this._decode);

  final T Function(String id, Map<String, Object?> json) _decode;
  final docs = <String, Map<String, Object?>>{};
  late final _subject = BehaviorSubject<List<T>>.seeded(const []);

  T? read(String id) {
    final json = docs[id];
    if (json == null) return null;
    try {
      return _decode(id, json);
    } on FormatException {
      return null;
    }
  }

  List<T> get all => [for (final id in docs.keys) ?read(id)];

  Stream<List<T>> watch() => _subject.stream;

  void put(String id, Map<String, Object?> json) {
    docs[id] = json;
    _subject.add(all);
  }

  void remove(String id) {
    if (docs.remove(id) != null) _subject.add(all);
  }

  Future<void> dispose() => _subject.close();
}

final class FakeModuleStore implements ModuleStore {
  final _docs = _Docs<ModuleRecord>(ModuleRecord.fromJson);
  int saves = 0;

  /// Stores [json] as is (e.g. a malformed or forged doc).
  void putRaw(String id, Map<String, Object?> json) => _docs.put(id, json);

  @override
  Stream<List<ModuleRecord>> watch() => _docs.watch();

  @override
  Future<ModuleRecord?> get(String moduleId) async => _docs.read(moduleId);

  @override
  Future<void> save(ModuleRecord module) async {
    saves++;
    _docs.put(module.id, module.toJson());
  }

  @override
  Future<void> delete(String moduleId) async => _docs.remove(moduleId);

  Future<void> dispose() => _docs.dispose();
}

final class FakeAutomationStore implements AutomationStore {
  final _docs = _Docs<AutomationRecord>(AutomationRecord.fromJson);
  int saves = 0;

  void putRaw(String id, Map<String, Object?> json) => _docs.put(id, json);

  @override
  Stream<List<AutomationRecord>> watch() => _docs.watch();

  @override
  Future<AutomationRecord?> get(String automationId) async =>
      _docs.read(automationId);

  @override
  Future<void> save(AutomationRecord automation) async {
    saves++;
    _docs.put(automation.id, automation.toJson());
  }

  @override
  Future<void> delete(String automationId) async => _docs.remove(automationId);

  Future<void> dispose() => _docs.dispose();
}

final class FakeRunStore implements RunStore {
  final _docs = _Docs<RunRecord>(RunRecord.fromJson);

  /// Every `update` call: the run id and the fields it wrote.
  final updates = <(String, Set<String>)>[];

  void putRaw(String id, Map<String, Object?> json) => _docs.put(id, json);

  @override
  Stream<List<RunRecord>> watchRecent() => _docs.watch().map(
    (runs) => ([...runs]..sort((a, b) => b.startedAt.compareTo(a.startedAt)))
        .take(RunStore.kWindow)
        .toList(),
  );

  @override
  Future<RunRecord?> get(String runId) async => _docs.read(runId);

  @override
  Future<void> create(RunRecord run) async {
    if (_docs.docs.containsKey(run.id)) {
      throw StateError('Run ${run.id} exists');
    }
    _docs.put(run.id, run.toJson());
  }

  @override
  Future<void> update(RunRecord run, {required Set<String> fields}) async {
    final current = _docs.docs[run.id];
    if (current == null) throw StateError('No run ${run.id}');
    updates.add((run.id, fields));
    final json = run.toJson();
    _docs.put(run.id, {...current, for (final f in fields) f: json[f]});
  }

  @override
  Future<int> prune({int keep = RunStore.kWindow}) async {
    final oldestFirst = _docs.all
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    if (oldestFirst.length <= keep) return 0;
    bool cheap(RunRecord r) =>
        r.status == RunStatus.succeeded || r.status == RunStatus.skipped;
    final doomed = [
      ...oldestFirst.where(cheap),
      ...oldestFirst.where((r) => !cheap(r) && r.status != RunStatus.applying),
    ].take(oldestFirst.length - keep).toList();
    for (final run in doomed) {
      _docs.remove(run.id);
    }
    return doomed.length;
  }

  Future<void> dispose() => _docs.dispose();
}

final class FakeGrantStore implements GrantStore {
  final _byUid = <String, _Docs<GrantRecord>>{};

  _Docs<GrantRecord> _of(String uid) =>
      _byUid.putIfAbsent(uid, () => _Docs(GrantRecord.fromJson));

  void putRaw(String uid, String moduleId, Map<String, Object?> json) =>
      _of(uid).put(moduleId, json);

  @override
  Stream<Map<String, GrantRecord>> watch(String uid) =>
      _of(uid).watch().map((grants) => {for (final g in grants) g.moduleId: g});

  @override
  Future<GrantRecord?> get(String uid, String moduleId) async =>
      _of(uid).read(moduleId);

  @override
  Future<void> save(String uid, GrantRecord grant) async =>
      _of(uid).put(grant.moduleId, grant.toJson());

  @override
  Future<void> delete(String uid, String moduleId) async =>
      _of(uid).remove(moduleId);

  Future<void> dispose() =>
      Future.wait([for (final d in _byUid.values) d.dispose()]);
}
