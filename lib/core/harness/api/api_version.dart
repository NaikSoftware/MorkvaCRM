/// The harness protocol major version. A request whose `v` differs gets
/// `unsupported_version`; a breaking change bumps this (or adds a new op id).
const int kHarnessApiVersion = 2;

/// The minor version: additive changes (optional args, result fields, ops,
/// error codes) bump it. `harness.describe` reports `major.minor`.
const int kHarnessMinor = 0;

/// `"2.0"`, as reported by `harness.describe` and used in descriptors' `since`.
const String kHarnessVersion = '$kHarnessApiVersion.$kHarnessMinor';
