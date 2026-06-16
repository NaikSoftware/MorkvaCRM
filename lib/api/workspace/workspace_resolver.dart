/// Resolves a signed-in user's id to the workspace id whose data they should
/// read and write.
///
/// Today this is the identity mapping ([UidWorkspaceResolver]). When shared
/// workspaces arrive, a `MembershipWorkspaceResolver` can look up membership
/// without changing any Firestore paths.
abstract interface class WorkspaceResolver {
  /// Resolves [uid] to a workspace id. Must not throw — [uid] is always a safe
  /// fallback when no other mapping is available.
  Future<String> resolveWorkspaceId(String uid);
}

/// Default resolver: a user's workspace id is their own [uid].
final class UidWorkspaceResolver implements WorkspaceResolver {
  /// Creates a [UidWorkspaceResolver].
  const UidWorkspaceResolver();

  @override
  Future<String> resolveWorkspaceId(String uid) async => uid;
}
