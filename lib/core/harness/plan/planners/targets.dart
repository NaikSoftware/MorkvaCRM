import '../../../domain/domain.dart';
import '../../api/envelope.dart';
import '../../input/ref_resolver.dart';
import '../../schema/arg_shapes.dart';
import '../../schema/json_schema.dart';
import 'plan_call.dart';

/// The most cards one `cards.update` target or `cards.delete` may touch.
const int kMaxTargetCards = 500;

/// Above this many matched cards a `where` / screen update needs
/// `expectedCount`.
const int kUnguardedUpdateCards = 20;

/// How a write call named its cards.
enum TargetKind {
  /// `{ids}`: card ids, titles, `@card`, `@selected` or `@c1` refs.
  ids,

  /// `{where}`: filters, frozen to ids at plan time.
  where,

  /// `{screen: true, where?}`: what is on screen, frozen to ids at plan
  /// time.
  screen;

  /// Whether the cards were matched by a query (and so need the
  /// `expectedCount` guard).
  bool get isQuery => this != ids;
}

/// A write target's cards, in display order.
typedef ResolvedTarget = ({TargetKind kind, List<String> ids});

/// `{ids} | {where} | {screen: true, where?}`: the cards a write applies to.
Map<String, Object?> writeTargetSchema() => JsonSchema.anyOf([
  JsonSchema.object(
    {
      'ids': JsonSchema.array(
        JsonSchema.string(),
        minItems: 1,
        maxItems: kMaxTargetCards,
        description:
            'Card ids or titles, "${ScreenRefs.card}" or '
            '"${ScreenRefs.selected}".',
      ),
    },
    required: ['ids'],
  ),
  JsonSchema.object({'where': whereSchema()}, required: ['where']),
  JsonSchema.object(
    {
      'screen': JsonSchema.boolean(
        description: 'true: the cards on screen (the screen query).',
      ),
      'where': whereSchema(),
    },
    required: ['screen'],
  ),
], description: 'Card ids, filters, or {"screen": true} for what is shown.');

/// The cards [raw] (a write target) names in [collection], frozen to ids.
///
/// `where` and `screen` run through the query engine (validated filters,
/// grants, leases); cards a call of this turn deletes are left out.
// shortcut: queries read the cache, so a `where` cannot match a card or a
// field planned earlier in the same turn; name such cards by id or @ref.
Future<ResolvedTarget> resolveTarget(
  PlanCall call,
  Collection collection,
  Object? raw, {
  String path = 'target',
}) async {
  final target = mapArg(raw, path);
  final ids = target['ids'];
  final where = target['where'];
  final screen = target['screen'];
  if (ids != null) {
    final refs = listArg<String>(ids, '$path.ids');
    return (
      kind: TargetKind.ids,
      ids: call.resolver().cards(collection, refs, path: '$path.ids'),
    );
  }
  if (screen != null && screen != true) {
    throw invalidArgs('"screen" is true or left out.', path: '$path.screen');
  }
  if (call.view.isNew(collection.id)) {
    throw invalidArgs(
      '${collection.name} is created in this turn; name its cards by '
      '@ref instead of filters.',
      path: path,
    );
  }
  final queries = call.services.queries;
  final query = <String, Object?>{
    'collection': collection.id,
    if (screen == true) 'from': ScreenRefs.screen,
    'where': ?where,
  };
  final matched = await queries.withScope(query, call.ctx, (scope) async {
    final base = queries.compileBase(scope, query);
    return (await queries.run(base.spec, call.ctx)).ids;
  });
  return (
    kind: screen == true ? TargetKind.screen : TargetKind.where,
    ids: [
      for (final id in matched)
        if (!call.view.isDeleted(collection.id, id)) id,
    ],
  );
}

/// The `expectedCount` guard of a query target: required when [required],
/// and a `count_mismatch` (with `expected` and `actual`) when the live
/// count differs. [ids] targets are checked only when a count is given.
void checkExpectedCount(
  Object? expected,
  int actual, {
  required bool required,
  required String what,
}) {
  if (expected == null) {
    if (!required) return;
    throw HarnessException(
      HarnessError(
        code: ErrorCode.invalidArgs,
        message:
            'This would $what $actual cards; pass expectedCount: $actual if '
            'that is what you saw.',
        path: 'expectedCount',
        hint: 'Query first and pass the count you saw as expectedCount.',
      ),
    );
  }
  if (expected != actual) {
    throw HarnessException(
      HarnessError(
        code: ErrorCode.countMismatch,
        message:
            'expectedCount is $expected but $actual cards match now; query '
            'again and check the filters.',
        path: 'expectedCount',
        expected: expected as int,
        actual: actual,
      ),
    );
  }
}

/// `limit_exceeded` when [count] is above [max]; never truncates.
void checkCap(int count, int max, {required String what}) {
  if (count <= max) return;
  throw HarnessException.of(
    ErrorCode.limitExceeded,
    'This would $what $count cards; one call takes at most $max.',
    hint: 'Narrow the filters, or split the change by a field value.',
  );
}
