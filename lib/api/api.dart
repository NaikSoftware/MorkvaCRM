/// MorkvaCRM data-access layer — the contracts that sit between the domain model
/// and Firebase.
///
/// This barrel exports the public interfaces and pure-Dart state holders defined
/// in Epic 2's foundation. Platform-specific implementations (Firestore auth/data
/// repositories, codec, refs) are wired in by their owning layers and are not
/// exported here.
library;

export 'auth/auth_cubit.dart';
export 'auth/auth_repository.dart';
export 'auth/auth_user.dart';
export 'data/data_repository.dart';
export 'firestore/firestore_refs.dart';
export 'firestore/firestore_value_codec.dart';
export 'sync/sync_status.dart';
export 'sync/sync_status_cubit.dart';
export 'workspace/workspace_resolver.dart';
