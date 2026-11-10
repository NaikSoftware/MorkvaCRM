import '../../domain/collection.dart';
import '../../domain/morkva_object.dart';
import '../cache/workspace_cache.dart';
import '../input/ref_resolver.dart';

/// The [WorkspaceCache] as the input layer reads it: every collection with
/// its lookups resolved (as of the last schema emission) and the cards of
/// the collections the cache holds right now.
///
/// It takes no leases: callers lease what they read first (the query
/// engines lease a collection and its reference targets per call). A
/// collection the cache does not hold reads as empty, so a card ref into it
/// fails as unknown instead of reading stale data.
final class CacheWorkspaceReader implements WorkspaceReader {
  CacheWorkspaceReader(this.cache);

  final WorkspaceCache cache;

  @override
  List<Collection> get collections => cache.collections;

  @override
  List<MorkvaObject> objectsOf(String collectionId) =>
      cache.current(collectionId)?.raw ?? const [];
}
