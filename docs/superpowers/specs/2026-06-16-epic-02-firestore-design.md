# Epic 2 — Cloud Firestore & Sync: Design Spec (contract of record)

Approved architecture for Epic 2. Implementers build against the exact signatures
here. Domain model (`lib/core/domain/`) and design system (`lib/design/`) are
UNCHANGED. This supersedes the JSON-in-Storage approach in
`docs/plan/epic-02-storage-sync.md` (pivot to Firestore, user-approved 2026-06-16).

## Locked decisions
1. **Auth: Google sign-in ONLY.** Web → `FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider())`.
   Mobile → `google_sign_in` v7 (`GoogleSignIn.instance.initialize()` then `.authenticate()`)
   → `GoogleAuthProvider.credential(idToken:)` → `signInWithCredential`. Switch on `kIsWeb`.
2. **Structured data in Cloud Firestore** (not JSON-in-Storage). Firebase Storage deferred
   (file-field blobs only, later epic).
3. **Document layout** (`workspaceId == uid` today, membership-ready):
   ```
   workspaces/{workspaceId}                    ← workspace doc
   workspaces/{workspaceId}/collections/{cid}  ← Collection schema (Collection.toJson)
   workspaces/{workspaceId}/objects/{oid}      ← MorkvaObject; carries collectionId + rev
   ```
4. **Typed values, not JSON blobs.** Object `values` map uses native Firestore types.
   ONLY non-passthrough mapping: `date` ISO-8601 string ↔ Firestore `Timestamp`.
   `createdAt`/`updatedAt` stay ISO-8601 strings (exact round-trip with MorkvaObject.toJson).
5. **Conflict = last-write-wins + VISIBLE warning** via integer `rev` per object doc.
6. **Sync status derives from Firestore snapshot metadata** (`isFromCache`, `hasPendingWrites`).
   No custom sync engine, no Hive, no connectivity_plus.

## Packages
```yaml
dependencies:
  firebase_core: ^4.10.0
  firebase_auth: ^6.5.2
  cloud_firestore: ^6.5.0     # if resolution conflicts with fake_cloud_firestore, pin ">=6.2.0 <6.6.0"
  google_sign_in: ^7.2.0      # mobile only — guarded import, never on web
dev_dependencies:
  fake_cloud_firestore: ^4.1.1
  bloc_test: ^10.0.0          # 9.x pins bloc ^8 — INCOMPATIBLE with our bloc ^9.2.1; 10.x is correct
  mocktail: ^1.x
```
`lib/firebase_options.dart` ALREADY EXISTS (PR #11) — reuse it, do NOT run interactive `flutterfire configure`.

## Codec contract (verified against domain)
- `FieldValue.toJson() -> Object?` = canonical JSON repr. `FieldDefinition.valueFromJson(Object?)` parses it back (tolerates null).
- `date`: `DateFieldValue.toJson()` → ISO-8601 UTC String (`includeTime` matters); convert ↔ `Timestamp`.
- Pass-through (canonical JSON already native Firestore): text→String?, number→num?, boolean→bool?,
  auto_number→int?, single_select→String?, multi_select→List<String>, reference→List<String>,
  file→List<Map>, calculated→Object?.
- Collection schemas are pure JSON pass-through — NO codec applies; only object `values` go through the codec.

## Interface signatures (build verbatim)

### lib/api/auth/auth_user.dart
```dart
import 'package:equatable/equatable.dart';

class AuthUser extends Equatable {
  const AuthUser({required this.uid, required this.email, this.displayName, this.photoUrl});
  final String uid;
  final String email;
  final String? displayName;
  final Uri? photoUrl;
  @override
  List<Object?> get props => [uid, email, displayName, photoUrl];
}
```

### lib/api/auth/auth_repository.dart
```dart
import 'auth_user.dart';

abstract interface class AuthRepository {
  Stream<AuthUser?> get authStateChanges; // replays current state on subscribe
  AuthUser? get currentUser;
  Future<AuthUser> signInWithGoogle();     // throws AuthException
  Future<void> signOut();
}

class AuthException implements Exception {
  const AuthException(this.message, {this.cause});
  final String message;
  final Object? cause;
  @override
  String toString() => 'AuthException: $message${cause != null ? ' ($cause)' : ''}';
}
```

### lib/api/workspace/workspace_resolver.dart
```dart
abstract interface class WorkspaceResolver {
  Future<String> resolveWorkspaceId(String uid); // must not throw; uid is safe fallback
}

final class UidWorkspaceResolver implements WorkspaceResolver {
  const UidWorkspaceResolver();
  @override
  Future<String> resolveWorkspaceId(String uid) async => uid;
}
```
Future shared-workspaces: swap to a `MembershipWorkspaceResolver` — paths unchanged.

### lib/api/sync/sync_status.dart
```dart
import 'package:equatable/equatable.dart';

sealed class SyncStatus extends Equatable { const SyncStatus(); }
final class SyncSynced  extends SyncStatus { const SyncSynced();  @override List<Object?> get props => const []; }
final class SyncPending extends SyncStatus { const SyncPending(); @override List<Object?> get props => const []; }
final class SyncOffline extends SyncStatus { const SyncOffline(); @override List<Object?> get props => const []; }
final class SyncConflict extends SyncStatus {
  const SyncConflict({required this.affectedObjectIds});
  final Set<String> affectedObjectIds;
  @override List<Object?> get props => [affectedObjectIds];
}
final class SyncError extends SyncStatus {
  const SyncError({required this.message, this.cause});
  final String message; final Object? cause;
  @override List<Object?> get props => [message];
}
```

### lib/api/sync/sync_status_cubit.dart
```dart
class SyncStatusCubit extends Cubit<SyncStatus> {
  SyncStatusCubit() : super(const SyncOffline());
  void reportPendingWrite();                 // -> SyncPending (unless in conflict)
  void reportSnapshotMeta({required bool isFromCache, required bool hasPendingWrites});
  void reportConflict(Set<String> affectedObjectIds); // -> SyncConflict
  void dismissConflict();                    // SyncConflict -> SyncPending
  void reportError(String message, {Object? cause});
}
```
Rules: while in `SyncConflict`, `reportSnapshotMeta` is ignored (explicit dismiss required).
`reportSnapshotMeta`: (cache && !pending)→Offline; pending→Pending; else→Synced.

### lib/api/data/data_repository.dart  (NO Firestore type may leak through)
```dart
import 'package:morkva_crm/core/domain/domain.dart';

abstract interface class DataRepository {
  Future<void> initialize(String workspaceId);
  // collections
  Stream<List<Collection>> watchCollections();
  Future<List<Collection>> getCollections();
  Future<Collection?> getCollection(String collectionId);
  Future<void> saveCollection(Collection collection);
  Future<void> deleteCollection(String collectionId);
  // objects
  Stream<List<MorkvaObject>> watchObjects(String collectionId, {Collection? schema});
  Future<List<MorkvaObject>> getObjects(String collectionId, {required Collection schema});
  Future<MorkvaObject?> getObject(String collectionId, String objectId, {required Collection schema});
  Future<void> saveObject(MorkvaObject object, {required Collection schema});
  Future<void> deleteObject(String collectionId, String objectId);
  Future<void> dispose();
}
```

### lib/api/firestore/firestore_value_codec.dart
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:morkva_crm/core/domain/domain.dart';

abstract interface class FirestoreValueCodec {
  Object? encode(FieldDefinition field, Object? jsonValue);     // canonical JSON -> Firestore native
  Object? decode(FieldDefinition field, Object? firestoreValue); // Firestore native -> canonical JSON
}
```

### lib/api/firestore/firestore_refs.dart
```dart
import 'package:cloud_firestore/cloud_firestore.dart';

abstract interface class FirestoreRefs {
  DocumentReference<Map<String, dynamic>> workspace(String workspaceId);
  CollectionReference<Map<String, dynamic>> collections(String workspaceId);
  DocumentReference<Map<String, dynamic>> collection(String workspaceId, String collectionId);
  CollectionReference<Map<String, dynamic>> objects(String workspaceId);
  DocumentReference<Map<String, dynamic>> object(String workspaceId, String objectId);
  Query<Map<String, dynamic>> objectsByCollection(String workspaceId, String collectionId); // orderBy updatedAt desc
}
```

### lib/api/auth/auth_cubit.dart  (AuthState + AuthCubit)
```dart
sealed class AuthState extends Equatable { const AuthState(); }
final class AuthInitial         extends AuthState { const AuthInitial();        @override List<Object?> get props => const []; }
final class AuthLoading         extends AuthState { const AuthLoading();        @override List<Object?> get props => const []; }
final class AuthAuthenticated   extends AuthState { const AuthAuthenticated(this.user); final AuthUser user; @override List<Object?> get props => [user]; }
final class AuthUnauthenticated extends AuthState { const AuthUnauthenticated();@override List<Object?> get props => const []; }
final class AuthError           extends AuthState { const AuthError({required this.message}); final String message; @override List<Object?> get props => [message]; }

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(AuthRepository repository) : super(const AuthInitial());
  void initialize();              // subscribe to authStateChanges
  Future<void> signInWithGoogle();
  Future<void> signOut();
}
```

## Object document shape
```json
{ "collectionId": "<id>", "rev": <int>, "createdAt": "<iso8601>", "updatedAt": "<iso8601>",
  "values": { "<fieldId>": <native: string|num|bool|Timestamp|array|map> } }
```
`rev` starts at 1 on create, +1 each update via a Firestore transaction (read rev, write rev+1).

## Conflict algorithm
Repository tracks `Map<String,int> _localRev` and `Set<String> _pendingObjects`.
- saveObject: reportPendingWrite(); _pendingObjects.add(id); transaction read rev→write rev+1; on success _localRev[id]=newRev; on failure reportError + remove pending.
- snapshot listener per doc: incomingRev = data['rev']??0; isServer = !metadata.hasPendingWrites.
  - id in pending && isServer → our write confirmed → remove from pending.
  - id NOT in pending && isServer && incomingRev > (_localRev[id]??0)+1 → conflict.
  - after loop: conflicts non-empty → reportConflict(ids); else reportSnapshotMeta(isFromCache, hasPendingWrites).
- LWW: no merge; user dismisses warning; next saveObject overwrites remote.

## firestore.rules (workspace-scoped, membership-ready)
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isWorkspaceOwner(workspaceId) {
      return request.auth != null && request.auth.uid == workspaceId;
    }
    function revIsMonotonic(existing, incoming) {
      return !existing.data.keys().hasAll(['rev'])
          || incoming.data.get('rev', 0) >= existing.data.get('rev', 0);
    }
    match /workspaces/{workspaceId} {
      allow read, write: if isWorkspaceOwner(workspaceId);
      match /collections/{collectionId} {
        allow read, create, update, delete: if isWorkspaceOwner(workspaceId);
      }
      match /objects/{objectId} {
        allow read: if isWorkspaceOwner(workspaceId);
        allow create: if isWorkspaceOwner(workspaceId)
            && request.resource.data.keys().hasAll(['collectionId', 'rev']);
        allow update: if isWorkspaceOwner(workspaceId) && revIsMonotonic(resource, request.resource);
        allow delete: if isWorkspaceOwner(workspaceId);
      }
    }
  }
}
```
Future sharing: replace `isWorkspaceOwner` with a membership `get()` check — data/paths unchanged.

## firestore.indexes.json
```json
{ "indexes": [
  { "collectionGroup": "objects", "queryScope": "COLLECTION",
    "fields": [ {"fieldPath":"collectionId","order":"ASCENDING"}, {"fieldPath":"updatedAt","order":"DESCENDING"} ] },
  { "collectionGroup": "objects", "queryScope": "COLLECTION",
    "fields": [ {"fieldPath":"collectionId","order":"ASCENDING"}, {"fieldPath":"createdAt","order":"ASCENDING"} ] }
], "fieldOverrides": [] }
```

## Offline persistence init (main.dart, after Firebase.initializeApp)
Web: `await FirebaseFirestore.instance.enablePersistence(const PersistenceSettings(synchronizeTabs: true))`
wrapped in try/catch swallowing `failed-precondition`/`unimplemented`.
Mobile: persistence ON by default; `FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true)`.
IMPLEMENTER MUST verify this API against the resolved cloud_firestore version; fallback:
`Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED)` for all platforms.

## File partition (one owner per file)
- **Task 3** (interfaces+pubspec): pubspec.yaml, lib/api/api.dart, auth/auth_user.dart, auth/auth_repository.dart,
  workspace/workspace_resolver.dart, sync/sync_status.dart, sync/sync_status_cubit.dart, data/data_repository.dart,
  firestore/firestore_value_codec.dart, firestore/firestore_refs.dart.
- **Task 4** (auth impl): auth/firestore_auth_repository.dart, auth/auth_cubit.dart,
  auth/_platform/auth_impl_web.dart, auth/_platform/auth_impl_mobile.dart, test/api/auth/*.
- **Task 5** (data impl): firestore/firestore_refs_impl.dart, firestore/firestore_value_codec_impl.dart,
  data/firestore_data_repository.dart, test/api/data/*, test/api/firestore/*.
- **Task 6** (sync tests): test/api/sync/*.
- **Task 7** (infra): firestore.rules, firestore.indexes.json, firebase.json.
- **Task 8** (UI): features/auth/sign_in_page.dart, app/shell/sync_status_indicator.dart,
  features/auth/conflict_warning_banner.dart.
- **Task 9** (wiring): lib/main.dart, lib/app/app.dart, lib/app/router/app_router.dart (reuse existing firebase_options.dart).

## Test plan: see each task; key coverage = typed round-trip incl. date↔Timestamp, rev increment,
offline metadata→status, conflict detection, AuthCubit transitions, widget tests for sign-in/indicator/banner.
