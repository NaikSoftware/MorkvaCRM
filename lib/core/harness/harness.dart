/// The Morkva Harness: a versioned, transport-neutral operation API over the
/// workspace, described with JSON Schema and scoped by capabilities. Pure
/// Dart: no Flutter, Firestore or Firebase imports (checked by
/// `test/core/import_boundary_test.dart`).
///
/// This barrel exports the public API (envelope, descriptors, capabilities,
/// context, `Harness`, schema builders, the op registry) and is frozen after
/// T2. Implementation folders (`cache/`, `input/`, `query/`, `plan/`) and the
/// op modules (`ops/*_ops.dart`) are imported directly by path.
library;

export 'api/api_version.dart';
export 'api/capability.dart';
export 'api/envelope.dart';
export 'api/harness.dart';
export 'api/harness_context.dart';
export 'api/operation.dart';
export 'ops/registry.dart';
export 'schema/arg_shapes.dart';
export 'schema/field_specs.dart';
export 'schema/json_schema.dart';
