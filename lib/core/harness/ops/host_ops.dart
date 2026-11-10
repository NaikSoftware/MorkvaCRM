import 'registry.dart';

/// Registers the host-only commit ops: `plans.commit/reject/retryFailed` and
/// `journal.undo/restore` (kind `commit`, user actor only).
///
/// Stub created by T2; T7 fills it (and adds the services its ops need to
/// the signature).
void registerHostOps(OperationRegistry ops) {}
