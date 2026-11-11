/// Shared setup for the strict-input tests: the seed workspace (lookups
/// resolved, as the cache serves it) behind a [StaticWorkspace].
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';
import 'package:morkva_crm/core/harness/harness.dart';
import 'package:morkva_crm/core/harness/input/ref_resolver.dart';

import '../fixtures/seed_workspace.dart';

final SeedWorkspace seed = SeedWorkspace();

/// The seeded workspace with lookups resolved.
final StaticWorkspace workspace = StaticWorkspace(
  resolveLookups(seed.collections),
  seed.objects,
);

Collection get orders => workspace.collections[1];
Collection get clients => workspace.collections[0];
Collection get fabrics => workspace.collections[2];

/// The seed's "today" as the host passes it (a local calendar day).
final DateTime today = DateTime(2026, 11, 10);

HarnessContext context({ScreenContext? focus, Grants? grants, DateTime? on}) =>
    HarnessContext(
      workspaceId: 'w1',
      actor: Actor.assistant,
      grants: grants ?? Grants.all(),
      now: DateTime(2026, 11, 10, 14, 30),
      today: on ?? today,
      focus: focus,
    );

RefResolver resolver({
  ScreenContext? focus,
  Grants? grants,
  DateTime? on,
  Map<String, String> aliases = const {},
}) => RefResolver(
  workspace,
  context(focus: focus, grants: grants, on: on),
  cardAliases: aliases,
);

/// Matches a [HarnessException] with [code] (and, when given, [path] and a
/// message containing [message]).
Matcher throwsHarness(ErrorCode code, {String? path, String? message}) =>
    throwsA(
      isA<HarnessException>()
          .having((e) => e.error.code, 'code', code)
          .having((e) => e.error.path, 'path', path ?? anything)
          .having((e) => e.error.message, 'message', contains(message ?? '')),
    );

/// The error [body] throws.
HarnessError errorOf(void Function() body) {
  try {
    body();
  } on HarnessException catch (e) {
    return e.error;
  }
  fail('expected a HarnessException');
}
